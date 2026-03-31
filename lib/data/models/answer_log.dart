class AnswerLog {
  final int? id;
  final String questionId;
  final int sessionId;
  final bool isCorrect;
  final int selectedOptionIndex;
  final int responseTimeMs;
  final int confidenceRating;
  final int hesitationCount;
  final DateTime timestamp;
  final int reviewNumber;

  const AnswerLog({
    this.id, required this.questionId, required this.sessionId,
    required this.isCorrect, required this.selectedOptionIndex,
    required this.responseTimeMs, this.confidenceRating = 3,
    this.hesitationCount = 0, required this.timestamp, this.reviewNumber = 1,
  });

  Map<String, dynamic> toDbMap() => {
    if (id != null) 'id': id,
    'question_id': questionId, 'session_id': sessionId,
    'is_correct': isCorrect ? 1 : 0, 'selected_option': selectedOptionIndex,
    'response_time_ms': responseTimeMs, 'confidence_rating': confidenceRating,
    'hesitation_count': hesitationCount,
    'timestamp': timestamp.toIso8601String(), 'review_number': reviewNumber,
  };

  factory AnswerLog.fromDbMap(Map<String, dynamic> map) => AnswerLog(
    id: map['id'] as int?, questionId: map['question_id'] as String,
    sessionId: map['session_id'] as int,
    isCorrect: (map['is_correct'] as int) == 1,
    selectedOptionIndex: map['selected_option'] as int,
    responseTimeMs: map['response_time_ms'] as int,
    confidenceRating: map['confidence_rating'] as int? ?? 3,
    hesitationCount: map['hesitation_count'] as int? ?? 0,
    timestamp: DateTime.parse(map['timestamp'] as String),
    reviewNumber: map['review_number'] as int? ?? 1,
  );
}
