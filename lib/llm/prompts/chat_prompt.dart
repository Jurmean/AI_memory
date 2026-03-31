import '../../data/models/question.dart';
import '../../data/models/answer_log.dart';

class ChatPrompt {
  const ChatPrompt._();

  static const String defaultSystemPrompt =
      '你是一个友善的AI学习伴侣，擅长用启发式提问帮助学生理解知识。'
      '请用Markdown格式回复。如果学生答错了题目，先分析错因再给出正确解释。'
      '回复应简洁有条理，适当使用加粗、列表和分段。';

  static String buildInstantGuidancePrompt(
      Question question, AnswerLog log) {
    final selectedOption = question.options[log.selectedOptionIndex];
    final correctOption = question.options[question.correctIndex];
    final isCorrect = log.isCorrect;

    return '''你是一位善于启发式教学的AI伴学。学生刚完成一道题目，请根据以下信息进行即时指导。

## 题目信息
- 题干：${question.stem}
- 选项：${question.options.asMap().entries.map((e) => '${String.fromCharCode(65 + e.key)}. ${e.value}').join('、')}
- 正确答案：${String.fromCharCode(65 + question.correctIndex)}. $correctOption
- 学生选择：${String.fromCharCode(65 + log.selectedOptionIndex)}. $selectedOption
- 结果：${isCorrect ? "正确" : "错误"}
- 用时：${log.responseTimeMs / 1000}秒
- 犹豫次数：${log.hesitationCount}
${question.explanation != null ? '- 参考解析：${question.explanation}' : ''}

## 指导要求
${isCorrect ? '学生答对了，但请检查是否真正理解。可以追问延伸问题。' : '学生答错了。请先分析为什么选了$selectedOption，再引导到正确答案$correctOption。不要直接给答案，用启发式提问。'}
${log.hesitationCount > 1 ? '学生有明显犹豫（切换了${log.hesitationCount}次选项），说明对该知识点不确定。' : ''}
请用Markdown格式回复，保持亲切友好的语气。''';
  }
}
