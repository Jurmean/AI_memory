import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../data/models/question.dart';
import '../../data/models/knowledge_point.dart';
import '../llm_client.dart';
import '../prompts/question_structure_prompt.dart';

class StructureResult {
  final List<Question> questions;
  final List<KnowledgePoint> knowledgePoints;
  final List<List<String>> questionKnowledgePointNames;

  const StructureResult({
    required this.questions,
    required this.knowledgePoints,
    required this.questionKnowledgePointNames,
  });
}

class QuestionStructureService {
  final LLMClient client;
  static const _uuid = Uuid();

  const QuestionStructureService(this.client);

  Future<StructureResult> structurizeText(
    String rawText, {
    String? profileContext,
    String? customPrompt,
    List<String> existingKnowledgePoints = const [],
  }) async {
    final prompt = QuestionStructurePrompt.buildStructurePrompt(
      rawText,
      profileContext: profileContext,
      customPrompt: customPrompt,
      existingKnowledgePoints: existingKnowledgePoints,
    );

    final response = await client.chat([
      {'role': 'user', 'content': prompt}
    ]);

    return _parseResponse(response);
  }

  StructureResult _parseResponse(String response) {
    final jsonMatch =
        RegExp(r'```json\s*([\s\S]*?)```').firstMatch(response);
    if (jsonMatch == null) {
      throw const LLMException('无法解析LLM返回的JSON，请重试');
    }

    final raw = jsonMatch.group(1)!.trim();
    final List<dynamic> jsonList;
    try {
      jsonList = jsonDecode(raw) as List<dynamic>;
    } catch (e) {
      throw LLMException('JSON解析失败: $e');
    }

    final questions = <Question>[];
    final kpSet = <String, KnowledgePoint>{};
    final questionKpNames = <List<String>>[];
    final now = DateTime.now();

    for (final item in jsonList) {
      final map = item as Map<String, dynamic>;
      final qId = _uuid.v4();
      final namesForQ = <String>[];

      List<DistractorInfo>? distractors;
      if (map['distractorAnalysis'] != null) {
        distractors = (map['distractorAnalysis'] as List)
            .map((d) => DistractorInfo.fromJson(d as Map<String, dynamic>))
            .toList();
      }

      questions.add(Question(
        id: qId,
        stem: map['stem'] as String,
        options: List<String>.from(map['options'] as List),
        correctIndex: map['correctIndex'] as int,
        explanation: map['explanation'] as String?,
        difficultyB: (map['difficultyB'] as num?)?.toDouble() ?? 0.0,
        sourceType: 'ai_generated',
        distractorAnalysis: distractors,
        createdAt: now,
      ));

      if (map['knowledgePoints'] != null) {
        for (final kpName in (map['knowledgePoints'] as List).cast<String>()) {
          namesForQ.add(kpName);
          kpSet.putIfAbsent(
            kpName,
            () => KnowledgePoint(id: _uuid.v4(), name: kpName),
          );
        }
      }
      questionKpNames.add(namesForQ);
    }

    return StructureResult(
      questions: questions,
      knowledgePoints: kpSet.values.toList(),
      questionKnowledgePointNames: questionKpNames,
    );
  }
}
