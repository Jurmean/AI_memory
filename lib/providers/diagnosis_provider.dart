import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/answer_log.dart';
import '../data/models/question.dart';
import '../data/models/diagnostic_report.dart';
import '../llm/services/diagnosis_service.dart';
import '../llm/prompts/prompt_builder.dart';
import 'database_provider.dart';
import 'llm_provider.dart';
import 'user_profile_provider.dart';

class DiagnosisState {
  final List<DiagnosticReport> reports;
  final bool isGenerating;
  final String? error;
  final DiagnosticReport? latestReport;

  const DiagnosisState({
    this.reports = const [],
    this.isGenerating = false,
    this.error,
    this.latestReport,
  });

  DiagnosisState copyWith({
    List<DiagnosticReport>? reports,
    bool? isGenerating,
    String? error,
    DiagnosticReport? latestReport,
  }) =>
      DiagnosisState(
        reports: reports ?? this.reports,
        isGenerating: isGenerating ?? this.isGenerating,
        error: error,
        latestReport: latestReport ?? this.latestReport,
      );

  List<DiagnosticReport> get sessionReports =>
      reports.where((r) => r.reportType == 'session').toList();
  List<DiagnosticReport> get overallReports =>
      reports.where((r) => r.reportType == 'overall').toList();
}

class DiagnosisNotifier extends Notifier<DiagnosisState> {
  @override
  DiagnosisState build() {
    _loadReports();
    return const DiagnosisState();
  }

  Future<void> _loadReports() async {
    final db = ref.read(databaseProvider);
    final reports = await db.getAllReports();
    state = state.copyWith(reports: reports);
  }

  Future<void> triggerSessionDiagnosis({
    required int sessionId,
    required List<AnswerLog> logs,
    required List<Question> questions,
  }) async {
    state = state.copyWith(isGenerating: true, error: null);

    try {
      final db = ref.read(databaseProvider);
      final client = ref.read(llmClientProvider);
      final settings = ref.read(llmSettingsProvider);
      final profileAsync = ref.read(userProfileProvider);
      final profile = profileAsync.value;
      if (profile == null) return;

      final weakPoints = await db.getWeakKnowledgePoints();
      final recentReports = await db.getRecentReports(limit: 3);
      final profileCtx = PromptBuilder.buildDiagnosisContext(
        profile,
        weakPoints: weakPoints,
        recentReports: recentReports,
      );

      final questionDetails = logs.map((l) {
        final q = questions.firstWhere((q) => q.id == l.questionId);
        return <String, dynamic>{
          'stem': q.stem,
          'correct': l.isCorrect,
          'time': (l.responseTimeMs / 1000).toStringAsFixed(1),
          'confidence': l.confidenceRating,
        };
      }).toList();

      final backend = ref.read(backendClientProvider);
      final service = DiagnosisService(client, backend: backend);
      final report = await service.generateSessionReport(
        sessionId: sessionId,
        profileContext: profileCtx,
        totalQuestions: logs.length,
        correctCount: logs.where((l) => l.isCorrect).length,
        theta: profile.theta,
        questionDetails: questionDetails,
        customPrompt: settings.customDiagnosisPrompt.isNotEmpty
            ? settings.customDiagnosisPrompt
            : null,
      );

      await db.insertReport(report);
      state = state.copyWith(
        isGenerating: false,
        reports: [...state.reports, report],
        latestReport: report,
      );

      await _updateProfileFromReport(report);
    } catch (e) {
      state = state.copyWith(
        isGenerating: false,
        error: '诊断报告生成失败：$e',
      );
    }
  }

  Future<void> generateOverallReport() async {
    state = state.copyWith(isGenerating: true, error: null);

    try {
      final db = ref.read(databaseProvider);
      final client = ref.read(llmClientProvider);
      final settings = ref.read(llmSettingsProvider);
      final profileAsync = ref.read(userProfileProvider);
      final profile = profileAsync.value;
      if (profile == null) return;

      final weakPoints = await db.getWeakKnowledgePoints();
      final recentReports = await db.getRecentReports(limit: 3);
      final profileCtx = PromptBuilder.buildDiagnosisContext(
        profile,
        weakPoints: weakPoints,
        recentReports: recentReports,
      );

      final sessions = await db.getAllSessions();
      final kpMastery = await db.getWeakKnowledgePoints();

      final backend = ref.read(backendClientProvider);
      final service = DiagnosisService(client, backend: backend);
      final report = await service.generateOverallReport(
        profileContext: profileCtx,
        totalSessions: sessions.length,
        totalAnswers: profile.totalAnswers,
        totalCorrect: profile.totalCorrect,
        kpMastery: kpMastery,
        customPrompt: settings.customDiagnosisPrompt.isNotEmpty
            ? settings.customDiagnosisPrompt
            : null,
      );

      await db.insertReport(report);
      state = state.copyWith(
        isGenerating: false,
        reports: [...state.reports, report],
        latestReport: report,
      );

      await _updateProfileFromReport(report);
    } catch (e) {
      state = state.copyWith(
        isGenerating: false,
        error: '总报告生成失败：$e',
      );
    }
  }

  Future<void> _updateProfileFromReport(DiagnosticReport report) async {
    final data = report.reportData;
    if (data == null) return;

    final abilityLevel = data['abilityLevel'] as String? ?? '';
    final strengths = data['strengths'] as List? ?? [];
    final weakAreas = data['weakAreas'] as List? ?? [];
    final suggestedFocus = data['suggestedFocus'] as List? ?? [];

    final trend = await _computeLearningTrend();

    try {
      await ref.read(userProfileProvider.notifier).updateFromReport(
            abilityLevel: abilityLevel,
            strengthsJson: jsonEncode(strengths),
            weakAreasJson: jsonEncode(weakAreas),
            suggestedFocusJson: jsonEncode(suggestedFocus),
            learningTrend: trend,
          );
    } catch (_) {
      // non-critical: don't fail the report flow
    }
  }

  Future<String> _computeLearningTrend() async {
    final db = ref.read(databaseProvider);
    final recent = await db.getRecentReports(limit: 5);
    if (recent.length < 2) return '未知';

    final scores = recent
        .where((r) => r.reportData != null && r.reportData!['overallScore'] != null)
        .map((r) => (r.reportData!['overallScore'] as num).toDouble())
        .toList();

    if (scores.length < 2) return '未知';

    // scores[0] is newest, scores[last] is oldest
    final oldHalf = scores.sublist(scores.length ~/ 2);
    final newHalf = scores.sublist(0, scores.length ~/ 2);
    final oldAvg = oldHalf.reduce((a, b) => a + b) / oldHalf.length;
    final newAvg = newHalf.reduce((a, b) => a + b) / newHalf.length;
    final diff = newAvg - oldAvg;

    if (diff > 5) return '上升';
    if (diff < -5) return '下降';
    return '平稳';
  }

  void clearLatestReport() {
    state = state.copyWith(isGenerating: false, error: null);
    state = DiagnosisState(reports: state.reports);
  }

  Future<void> refresh() async {
    await _loadReports();
  }
}

final diagnosisProvider =
    NotifierProvider<DiagnosisNotifier, DiagnosisState>(
        DiagnosisNotifier.new);
