class ReviewSession {
  final int? id;
  final DateTime startTime;
  final DateTime? endTime;
  final int totalQuestions;
  final double thetaSnapshot;

  const ReviewSession({
    this.id, required this.startTime, this.endTime,
    this.totalQuestions = 0, this.thetaSnapshot = 0.0,
  });

  ReviewSession copyWith({
    int? id,
    DateTime? startTime,
    DateTime? endTime,
    int? totalQuestions,
    double? thetaSnapshot,
  }) => ReviewSession(
    id: id ?? this.id,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    totalQuestions: totalQuestions ?? this.totalQuestions,
    thetaSnapshot: thetaSnapshot ?? this.thetaSnapshot,
  );

  Map<String, dynamic> toDbMap() => {
    if (id != null) 'id': id,
    'start_time': startTime.toIso8601String(),
    'end_time': endTime?.toIso8601String(),
    'total_questions': totalQuestions, 'theta_snapshot': thetaSnapshot,
  };

  factory ReviewSession.fromDbMap(Map<String, dynamic> map) => ReviewSession(
    id: map['id'] as int?,
    startTime: DateTime.parse(map['start_time'] as String),
    endTime: map['end_time'] != null ? DateTime.parse(map['end_time'] as String) : null,
    totalQuestions: map['total_questions'] as int? ?? 0,
    thetaSnapshot: (map['theta_snapshot'] as num?)?.toDouble() ?? 0.0,
  );
}
