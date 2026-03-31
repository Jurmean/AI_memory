import '../../data/models/user_profile.dart';
import '../../core/algorithms/ability_decay.dart';

class PromptBuilder {
  const PromptBuilder._();

  static String buildProfileContext(UserProfile profile,
      {Map<String, double>? weakPoints}) {
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
      final r = AbilityDecay.retrievability(days.toDouble(), profile.stability);
      final effTheta = AbilityDecay.effectiveTheta(
          profile.theta, days.toDouble(), profile.stability);
      parts.add('距上次学习$days天');
      parts.add('有效能力值${effTheta.toStringAsFixed(2)}（保留率${(r * 100).toStringAsFixed(0)}%）');
    }

    if (weakPoints != null && weakPoints.isNotEmpty) {
      final top = weakPoints.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final wpStr = top
          .take(3)
          .map((e) => '${e.key}(错误率${(e.value * 100).toStringAsFixed(0)}%)')
          .join('、');
      parts.add('薄弱点：$wpStr');
    }

    return '用户画像：${parts.join("，")}。';
  }

  static String buildChatSystemPrompt(
      UserProfile profile, String? customPrompt,
      {Map<String, double>? weakPoints}) {
    final ctx = buildProfileContext(profile, weakPoints: weakPoints);
    final base = customPrompt?.isNotEmpty == true
        ? customPrompt!
        : '你是一个友善的AI学习伴侣，擅长用启发式提问帮助学生理解知识。'
            '请用简洁的Markdown格式回复，适当使用列表和加粗。'
            '根据用户水平调整回答深度。';
    return '$ctx\n\n$base';
  }

  static String buildDiagnosisContext(UserProfile profile,
      {Map<String, double>? weakPoints}) {
    final ctx = buildProfileContext(profile, weakPoints: weakPoints);
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
    return parts.join('，');
  }
}
