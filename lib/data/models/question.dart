import 'dart:convert';

class DistractorInfo {
  final int optionIndex;
  final double attractiveness;
  final String? commonMistakeReason;

  const DistractorInfo({
    required this.optionIndex,
    required this.attractiveness,
    this.commonMistakeReason,
  });

  Map<String, dynamic> toJson() => {
        'optionIndex': optionIndex,
        'attractiveness': attractiveness,
        'commonMistakeReason': commonMistakeReason,
      };

  factory DistractorInfo.fromJson(Map<String, dynamic> json) => DistractorInfo(
        optionIndex: json['optionIndex'] as int,
        attractiveness: (json['attractiveness'] as num).toDouble(),
        commonMistakeReason: json['commonMistakeReason'] as String?,
      );
}

class Question {
  final String id;
  final String stem;
  final List<String> options;
  final int correctIndex;
  final String? explanation;
  final double difficultyB;
  final String? sourceType;
  final List<DistractorInfo>? distractorAnalysis;
  final DateTime createdAt;

  const Question({
    required this.id,
    required this.stem,
    required this.options,
    required this.correctIndex,
    this.explanation,
    this.difficultyB = 0.0,
    this.sourceType,
    this.distractorAnalysis,
    required this.createdAt,
  });

  Question copyWith({
    String? id, String? stem, List<String>? options, int? correctIndex,
    String? explanation, double? difficultyB, String? sourceType,
    List<DistractorInfo>? distractorAnalysis, DateTime? createdAt,
  }) => Question(
    id: id ?? this.id, stem: stem ?? this.stem,
    options: options ?? this.options, correctIndex: correctIndex ?? this.correctIndex,
    explanation: explanation ?? this.explanation, difficultyB: difficultyB ?? this.difficultyB,
    sourceType: sourceType ?? this.sourceType,
    distractorAnalysis: distractorAnalysis ?? this.distractorAnalysis,
    createdAt: createdAt ?? this.createdAt,
  );

  Map<String, dynamic> toDbMap() => {
        'id': id, 'stem': stem,
        'options_json': jsonEncode(options),
        'correct_index': correctIndex,
        'explanation': explanation,
        'difficulty_b': difficultyB,
        'source_type': sourceType,
        'distractor_analysis_json': distractorAnalysis != null
            ? jsonEncode(distractorAnalysis!.map((d) => d.toJson()).toList())
            : null,
        'created_at': createdAt.toIso8601String(),
      };

  factory Question.fromDbMap(Map<String, dynamic> map) => Question(
        id: map['id'] as String,
        stem: map['stem'] as String,
        options: List<String>.from(jsonDecode(map['options_json'] as String)),
        correctIndex: map['correct_index'] as int,
        explanation: map['explanation'] as String?,
        difficultyB: (map['difficulty_b'] as num?)?.toDouble() ?? 0.0,
        sourceType: map['source_type'] as String?,
        distractorAnalysis: map['distractor_analysis_json'] != null
            ? (jsonDecode(map['distractor_analysis_json'] as String) as List)
                .map((e) => DistractorInfo.fromJson(e as Map<String, dynamic>))
                .toList()
            : null,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'stem': stem, 'options': options,
        'correctIndex': correctIndex, 'explanation': explanation,
        'difficultyB': difficultyB, 'sourceType': sourceType,
        'distractorAnalysis': distractorAnalysis?.map((d) => d.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory Question.fromJson(Map<String, dynamic> json) => Question(
        id: json['id'] as String,
        stem: json['stem'] as String,
        options: List<String>.from(json['options'] as List),
        correctIndex: json['correctIndex'] as int,
        explanation: json['explanation'] as String?,
        difficultyB: (json['difficultyB'] as num?)?.toDouble() ?? 0.0,
        sourceType: json['sourceType'] as String?,
        distractorAnalysis: json['distractorAnalysis'] != null
            ? (json['distractorAnalysis'] as List)
                .map((e) => DistractorInfo.fromJson(e as Map<String, dynamic>))
                .toList()
            : null,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
