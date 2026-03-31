class QuestionStructurePrompt {
  const QuestionStructurePrompt._();

  static String buildStructurePrompt(String rawText,
      {String? profileContext, String? customPrompt}) {
    final base = customPrompt?.isNotEmpty == true ? customPrompt! : _defaultPrompt;
    return '''${profileContext != null ? '$profileContext\n\n' : ''}## 任务
$base

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
- 确保生成的题目准确、选项合理、解析详尽''';
  }

  static const String _defaultPrompt =
      '请将以下文本内容转化为高质量的选择题。'
      '每道题4个选项，只有1个正确答案。'
      '题目应覆盖文本的核心知识点，难度适中。'
      '为每个错误选项提供干扰度分析。';
}
