class ReviewState {
  final String questionId;
  final double easinessFactor;
  final int intervalDays;
  final int reviewCount;
  final DateTime nextReviewDate;
  final double lastQS;

  const ReviewState({
    required this.questionId, this.easinessFactor = 2.5,
    this.intervalDays = 1, this.reviewCount = 0,
    required this.nextReviewDate, this.lastQS = 0.0,
  });

  ReviewState copyWith({
    String? questionId, double? easinessFactor, int? intervalDays,
    int? reviewCount, DateTime? nextReviewDate, double? lastQS,
  }) => ReviewState(
    questionId: questionId ?? this.questionId,
    easinessFactor: easinessFactor ?? this.easinessFactor,
    intervalDays: intervalDays ?? this.intervalDays,
    reviewCount: reviewCount ?? this.reviewCount,
    nextReviewDate: nextReviewDate ?? this.nextReviewDate,
    lastQS: lastQS ?? this.lastQS,
  );

  Map<String, dynamic> toDbMap() => {
    'question_id': questionId, 'easiness_factor': easinessFactor,
    'interval_days': intervalDays, 'review_count': reviewCount,
    'next_review_date': nextReviewDate.toIso8601String(), 'last_qs': lastQS,
  };

  factory ReviewState.fromDbMap(Map<String, dynamic> map) => ReviewState(
    questionId: map['question_id'] as String,
    easinessFactor: (map['easiness_factor'] as num?)?.toDouble() ?? 2.5,
    intervalDays: map['interval_days'] as int? ?? 1,
    reviewCount: map['review_count'] as int? ?? 0,
    nextReviewDate: DateTime.parse(map['next_review_date'] as String),
    lastQS: (map['last_qs'] as num?)?.toDouble() ?? 0.0,
  );
}
