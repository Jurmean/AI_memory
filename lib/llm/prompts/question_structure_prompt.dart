class QuestionStructurePrompt {
  const QuestionStructurePrompt._();

  static String buildStructurePrompt(
    String rawText, {
    String? profileContext,
    String? customPrompt,
    List<String> existingKnowledgePoints = const [],
  }) {
    final base = customPrompt?.isNotEmpty == true ? customPrompt! : _defaultPrompt;
    final existingKpSection = existingKnowledgePoints.isNotEmpty
        ? '\n## 已有知识点库（优先复用，不要重复创建）\n${existingKnowledgePoints.join('、')}\n'
        : '';
    return '''${profileContext != null ? '$profileContext\n\n' : ''}## 任务
$base
$existingKpSection
## 用户输入的原始文本
$rawText

## 输出要求
请严格按照以下JSON数组格式输出（外面包裹Markdown代码块），每道题一个对象：
```json
[
  {
    "stem": "题干文本",
    "options": ["选项A", "选项B", "选项C", "选项D"],
    "correctIndex": 0,
    "explanation": "详细解析",
    "difficultyB": 0.0,
    "knowledgePoints": ["知识点1", "知识点2"],
    "distractorAnalysis": [
      {"optionIndex": 1, "attractiveness": 0.3, "commonMistakeReason": "误选原因"},
      {"optionIndex": 2, "attractiveness": 0.2, "commonMistakeReason": "误选原因"},
      {"optionIndex": 3, "attractiveness": 0.1, "commonMistakeReason": "误选原因"}
    ]
  }
]
```

注意：
- difficultyB 范围 [-2, 2]，0为中等难度
- correctIndex 是正确选项的索引（0-3）
- distractorAnalysis 只分析错误选项（不包含正确选项）
- attractiveness 范围 [0, 1]，表示该错误选项的干扰吸引度
- 确保生成的题目准确、选项合理、解析详尽
- 知识点命名要具有概括性，粒度对标教材章节级别（如"有机化学反应类型"而非"苯的亲电取代反应中卤代反应的区域选择性"）
- 如果上方"已有知识点库"中有可涵盖的知识点，必须直接复用该名称，不要创建新的细分知识点
- 遵循奥卡姆剃刀原则：每题知识点不超过2-3个，能用1个概括的就不要拆成多个''';
  }

  static const String _defaultPrompt =
      '请将以下文本内容转化为高质量的选择题。'
      '每道题4个选项，只有1个正确答案。'
      '题目应覆盖文本的核心知识点，难度适中。'
      '为每个错误选项提供干扰度分析。';
}
