import 'dart:convert';
import '../../data/models/diagnostic_report.dart';
import '../llm_client.dart';
import '../backend_client.dart';
import '../prompts/diagnosis_prompt.dart';

class DiagnosisService {
  final LLMClient client;
  final BackendClient? backend;

  const DiagnosisService(this.client, {this.backend});

  Future<String> _chat(String prompt) async {
    final messages = [
      {'role': 'user', 'content': prompt}
    ];
    if (backend != null) {
      return backend!.chat(messages);
    }
    return client.chat(messages);
  }

  Future<DiagnosticReport> generateSessionReport({
    required int sessionId,
    required String profileContext,
    required int totalQuestions,
    required int correctCount,
    required double theta,
    required List<Map<String, dynamic>> questionDetails,
    String? customPrompt,
  }) async {
    final prompt = DiagnosisPrompt.buildSessionDiagnosisPrompt(
      profileContext: profileContext,
      totalQuestions: totalQuestions,
      correctCount: correctCount,
      theta: theta,
      questionDetails: questionDetails,
      customPrompt: customPrompt,
    );

    final response = await _chat(prompt);
    return _parseReport(response, sessionId, 'session');
  }

  Future<DiagnosticReport> generateOverallReport({
    required String profileContext,
    required int totalSessions,
    required int totalAnswers,
    required int totalCorrect,
    required Map<String, double> kpMastery,
    String? customPrompt,
  }) async {
    final prompt = DiagnosisPrompt.buildOverallDiagnosisPrompt(
      profileContext: profileContext,
      totalSessions: totalSessions,
      totalAnswers: totalAnswers,
      totalCorrect: totalCorrect,
      kpMastery: kpMastery,
      customPrompt: customPrompt,
    );

    final response = await _chat(prompt);
    return _parseReport(response, 0, 'overall');
  }

  DiagnosticReport _parseReport(String response, int sessionId, String type) {
    Map<String, dynamic>? data;
    var content = response;

    final jsonMatch =
        RegExp(r'```json\s*([\s\S]*?)```').firstMatch(response);
    if (jsonMatch != null) {
      try {
        data = jsonDecode(jsonMatch.group(1)!.trim()) as Map<String, dynamic>;
        content = data['content'] as String? ?? response;
      } catch (_) {
        // plain text
      }
    }

    return DiagnosticReport(
      sessionId: sessionId,
      reportContent: content,
      reportData: data,
      reportType: type,
      generatedAt: DateTime.now(),
    );
  }
}
