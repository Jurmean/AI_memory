class UserProfile {
  final double theta;
  final double stability;
  final int totalAnswers;
  final int totalCorrect;
  final DateTime? lastStudyDate;
  final String grade;
  final String subjectPreference;

  const UserProfile({
    this.theta = 0.0, this.stability = 30.0,
    this.totalAnswers = 0, this.totalCorrect = 0,
    this.lastStudyDate, this.grade = '', this.subjectPreference = '',
  });

  double get correctRate => totalAnswers > 0 ? totalCorrect / totalAnswers : 0.0;

  int get daysSinceLastStudy {
    if (lastStudyDate == null) return 999;
    return DateTime.now().difference(lastStudyDate!).inDays;
  }

  UserProfile copyWith({
    double? theta, double? stability, int? totalAnswers, int? totalCorrect,
    DateTime? lastStudyDate, String? grade, String? subjectPreference,
  }) => UserProfile(
    theta: theta ?? this.theta, stability: stability ?? this.stability,
    totalAnswers: totalAnswers ?? this.totalAnswers,
    totalCorrect: totalCorrect ?? this.totalCorrect,
    lastStudyDate: lastStudyDate ?? this.lastStudyDate,
    grade: grade ?? this.grade, subjectPreference: subjectPreference ?? this.subjectPreference,
  );

  Map<String, dynamic> toDbMap() => {
    'id': 1, 'theta': theta, 'stability': stability,
    'total_answers': totalAnswers, 'total_correct': totalCorrect,
    'last_study_date': lastStudyDate?.toIso8601String(),
    'grade': grade, 'subject_preference': subjectPreference,
  };

  factory UserProfile.fromDbMap(Map<String, dynamic> map) => UserProfile(
    theta: (map['theta'] as num?)?.toDouble() ?? 0.0,
    stability: (map['stability'] as num?)?.toDouble() ?? 30.0,
    totalAnswers: map['total_answers'] as int? ?? 0,
    totalCorrect: map['total_correct'] as int? ?? 0,
    lastStudyDate: map['last_study_date'] != null ? DateTime.tryParse(map['last_study_date'] as String) : null,
    grade: map['grade'] as String? ?? '',
    subjectPreference: map['subject_preference'] as String? ?? '',
  );
}
