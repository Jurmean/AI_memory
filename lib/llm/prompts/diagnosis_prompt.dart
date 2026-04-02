class DiagnosisPrompt {
  const DiagnosisPrompt._();

  static String buildSessionDiagnosisPrompt({
    required String profileContext,
    required int totalQuestions,
    required int correctCount,
    required double theta,
    required List<Map<String, dynamic>> questionDetails,
    String? customPrompt,
  }) {
    final base = customPrompt?.isNotEmpty == true ? customPrompt! : _defaultSessionPrompt;
    return '''$profileContext

## 本轮答题数据
- 共$totalQuestions题，答对$correctCount题，正确率${totalQuestions > 0 ? (correctCount / totalQuestions * 100).toStringAsFixed(0) : 0}%
- 当前能力值θ=${theta.toStringAsFixed(2)}

## 各题详情
${questionDetails.map((q) => '- ${q['stem']}：${q['correct'] ? "✓" : "✗"} | 用时${q['time']}s | 信心${q['confidence']}').join('\n')}

## 你的任务
$base

请用以下JSON格式输出（外面包裹Markdown代码块）：
```json
{
  "overallScore": 0-100的综合得分,
  "abilityLevel": "优秀/良好/中等/需加强",
  "strengths": ["掌握较好的知识点"],
  "weakAreas": [{"name": "薄弱知识点", "score": 0-100}],
  "suggestedFocus": ["建议重点复习的方向"],
  "content": "详细的诊断分析文字（Markdown格式）"
}
```

注意：
- overallScore 和 weakAreas 中的 score 必须是整数，不要带小数
- content 字段必须包含详尽的分析文字
- 所有字段都必须填写，不能为空''';
  }

  static String buildOverallDiagnosisPrompt({
    required String profileContext,
    required int totalSessions,
    required int totalAnswers,
    required int totalCorrect,
    required Map<String, double> kpMastery,
    String? customPrompt,
  }) {
    final base = customPrompt?.isNotEmpty == true ? customPrompt! : _defaultOverallPrompt;
    final kpStr = kpMastery.entries
        .map((e) => '- ${e.key}：掌握度${(e.value * 100).toStringAsFixed(0)}%')
        .join('\n');

    return '''$profileContext

## 全局学习数据
- 总学习会话：$totalSessions次
- 总答题：$totalAnswers道，正确$totalCorrect道（${totalAnswers > 0 ? (totalCorrect / totalAnswers * 100).toStringAsFixed(0) : 0}%）

## 各知识点掌握度
$kpStr

## 你的任务
$base

请用以下JSON格式输出（外面包裹Markdown代码块）：
```json
{
  "overallScore": 0-100的综合得分,
  "abilityLevel": "优秀/良好/中等/需加强",
  "strengths": ["掌握较好的知识点"],
  "weakAreas": [{"name": "薄弱知识点", "score": 0-100}],
  "suggestedFocus": ["建议重点复习的方向"],
  "content": "详细的诊断分析文字（Markdown格式），包含整体评估、各知识点分析、学习趋势和具体改进建议"
}
```

注意：
- overallScore 和 weakAreas 中的 score 必须是整数，不要带小数
- content 字段必须包含详尽的分析文字，不少于200字
- 所有字段都必须填写，不能为空''';
  }

  static const String _defaultSessionPrompt =
      '请分析这轮答题表现，指出薄弱环节，给出针对性复习建议。'
      '分析要基于具体错题，不要泛泛而谈。';

  static const String _defaultOverallPrompt =
      '请对用户的整体学习情况做全面诊断分析。'
      '从知识点掌握度、学习趋势、薄弱环节等维度给出评估和建议。';
}
