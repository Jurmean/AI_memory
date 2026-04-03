import '../../data/models/user_profile.dart';
import '../../data/models/diagnostic_report.dart';
import '../../core/algorithms/ability_decay.dart';

class PromptBuilder {
  const PromptBuilder._();

  static String buildProfileContext(UserProfile profile,
      {Map<String, double>? weakPoints,
      List<DiagnosticReport>? recentReports}) {
    final parts = <String>[];
    if (profile.grade.isNotEmpty) parts.add('年级：${profile.grade}');
    if (profile.subjectPreference.isNotEmpty) {
      parts.add('主攻学科：${profile.subjectPreference}');
    }
    parts.add('能力值θ=${profile.theta.toStringAsFixed(2)}');
    parts.add('正确率${(profile.correctRate * 100).toStringAsFixed(0)}%');
    parts.add('已答${profile.totalAnswers}题');

    if (profile.lastStudyDate != null) {
      final days = profile.daysSinceLastStudy;
      final r =
          AbilityDecay.retrievability(days.toDouble(), profile.stability);
      final effTheta = AbilityDecay.effectiveTheta(
          profile.theta, days.toDouble(), profile.stability);
      parts.add('距上次学习$days天');
      parts.add(
          '有效能力值${effTheta.toStringAsFixed(2)}（保留率${(r * 100).toStringAsFixed(0)}%）');
    }

    if (profile.abilityLevel.isNotEmpty) {
      parts.add('能力等级：${profile.abilityLevel}');
    }
    if (profile.learningTrend != '未知') {
      parts.add('学习趋势：${profile.learningTrend}');
    }
    if (profile.strengths.isNotEmpty) {
      parts.add('优势知识点：${profile.strengths.join("、")}');
    }
    final wa = profile.weakAreas;
    if (wa.isNotEmpty) {
      final waStr =
          wa.map((w) => '${w['name']}(${w['score']}分)').join('、');
      parts.add('薄弱知识点：$waStr');
    } else if (weakPoints != null && weakPoints.isNotEmpty) {
      final top = weakPoints.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final wpStr = top
          .take(3)
          .map((e) =>
              '${e.key}(错误率${(e.value * 100).toStringAsFixed(0)}%)')
          .join('、');
      parts.add('薄弱点：$wpStr');
    }
    if (profile.suggestedFocus.isNotEmpty) {
      parts.add('建议复习方向：${profile.suggestedFocus.join("、")}');
    }

    final buf = StringBuffer('用户画像：${parts.join("，")}。');

    if (recentReports != null && recentReports.isNotEmpty) {
      buf.write('\n\n');
      buf.write(buildHistoryContext(recentReports));
    }

    return buf.toString();
  }

  static String buildHistoryContext(List<DiagnosticReport> reports) {
    if (reports.isEmpty) return '';
    final lines = <String>[];
    // reports are ordered newest-first; display oldest-first for chronological reading
    for (final r in reports.reversed) {
      final data = r.reportData;
      if (data == null) continue;
      final date = r.generatedAt.toIso8601String().substring(0, 10);
      final score = data['overallScore'] ?? '?';
      final level = data['abilityLevel'] ?? '';
      final weak = data['weakAreas'] as List?;
      final weakStr = weak != null && weak.isNotEmpty
          ? weak.map((w) {
              final m = w as Map<String, dynamic>;
              return m['name'] ?? '';
            }).join('、')
          : '无';
      lines.add('$date: 得分$score，$level，薄弱点：$weakStr');
    }
    if (lines.isEmpty) return '';
    return '历史诊断记录（从旧到新）：\n${lines.join('\n')}';
  }

  static String buildChatSystemPrompt(
      UserProfile profile, String? customPrompt,
      {Map<String, double>? weakPoints,
      List<DiagnosticReport>? recentReports}) {
    final ctx = buildProfileContext(profile,
        weakPoints: weakPoints, recentReports: recentReports);
    final base = customPrompt?.isNotEmpty == true
        ? customPrompt!
        : '你是一个友善的AI学习伴侣，擅长用启发式提问帮助学生理解知识。'
            '请用简洁的Markdown格式回复，适当使用列表和加粗。'
            '根据用户水平调整回答深度。'
            '如果用户画像中有历史诊断记录，请结合趋势变化给出建议。';
    return '$ctx\n\n$base';
  }

  static String buildDiagnosisContext(UserProfile profile,
      {Map<String, double>? weakPoints,
      List<DiagnosticReport>? recentReports}) {
    final ctx = buildProfileContext(profile,
        weakPoints: weakPoints, recentReports: recentReports);
    final parts = <String>[ctx];
    parts.add('稳定性S=${profile.stability.toStringAsFixed(1)}天');
    return parts.join('\n');
  }

  static String buildQuestionGenContext(UserProfile profile) {
    final parts = <String>[];
    if (profile.grade.isNotEmpty) parts.add('目标年级：${profile.grade}');
    if (profile.subjectPreference.isNotEmpty) {
      parts.add('学科：${profile.subjectPreference}');
    }
    parts.add('当前能力θ=${profile.theta.toStringAsFixed(2)}');
    if (profile.abilityLevel.isNotEmpty) {
      parts.add('能力等级：${profile.abilityLevel}');
    }
    if (profile.weakAreas.isNotEmpty) {
      final waStr = profile.weakAreas
          .map((w) => w['name'] as String? ?? '')
          .where((n) => n.isNotEmpty)
          .join('、');
      if (waStr.isNotEmpty) parts.add('薄弱知识点：$waStr');
    }
    return parts.join('，');
  }
}
