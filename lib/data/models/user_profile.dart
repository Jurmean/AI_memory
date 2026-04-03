import 'dart:convert';

class UserProfile {
  final double theta;
  final double stability;
  final int totalAnswers;
  final int totalCorrect;
  final DateTime? lastStudyDate;
  final String grade;
  final String subjectPreference;

  final String abilityLevel;
  final String strengthsJson;
  final String weakAreasJson;
  final String suggestedFocusJson;
  final String learningTrend;
  final DateTime? lastProfileUpdate;

  const UserProfile({
    this.theta = 0.0,
    this.stability = 30.0,
    this.totalAnswers = 0,
    this.totalCorrect = 0,
    this.lastStudyDate,
    this.grade = '',
    this.subjectPreference = '',
    this.abilityLevel = '',
    this.strengthsJson = '[]',
    this.weakAreasJson = '[]',
    this.suggestedFocusJson = '[]',
    this.learningTrend = '未知',
    this.lastProfileUpdate,
  });

  double get correctRate =>
      totalAnswers > 0 ? totalCorrect / totalAnswers : 0.0;

  int get daysSinceLastStudy {
    if (lastStudyDate == null) return 999;
    return DateTime.now().difference(lastStudyDate!).inDays;
  }

  List<String> get strengths {
    try {
      return List<String>.from(jsonDecode(strengthsJson) as List);
    } catch (_) {
      return [];
    }
  }

  List<Map<String, dynamic>> get weakAreas {
    try {
      return List<Map<String, dynamic>>.from(
          (jsonDecode(weakAreasJson) as List).map((e) => e as Map<String, dynamic>));
    } catch (_) {
      return [];
    }
  }

  List<String> get suggestedFocus {
    try {
      return List<String>.from(jsonDecode(suggestedFocusJson) as List);
    } catch (_) {
      return [];
    }
  }

  bool get hasProfileData => abilityLevel.isNotEmpty;

  UserProfile copyWith({
    double? theta,
    double? stability,
    int? totalAnswers,
    int? totalCorrect,
    DateTime? lastStudyDate,
    String? grade,
    String? subjectPreference,
    String? abilityLevel,
    String? strengthsJson,
    String? weakAreasJson,
    String? suggestedFocusJson,
    String? learningTrend,
    DateTime? lastProfileUpdate,
  }) =>
      UserProfile(
        theta: theta ?? this.theta,
        stability: stability ?? this.stability,
        totalAnswers: totalAnswers ?? this.totalAnswers,
        totalCorrect: totalCorrect ?? this.totalCorrect,
        lastStudyDate: lastStudyDate ?? this.lastStudyDate,
        grade: grade ?? this.grade,
        subjectPreference: subjectPreference ?? this.subjectPreference,
        abilityLevel: abilityLevel ?? this.abilityLevel,
        strengthsJson: strengthsJson ?? this.strengthsJson,
        weakAreasJson: weakAreasJson ?? this.weakAreasJson,
        suggestedFocusJson: suggestedFocusJson ?? this.suggestedFocusJson,
        learningTrend: learningTrend ?? this.learningTrend,
        lastProfileUpdate: lastProfileUpdate ?? this.lastProfileUpdate,
      );

  Map<String, dynamic> toDbMap() => {
        'id': 1,
        'theta': theta,
        'stability': stability,
        'total_answers': totalAnswers,
        'total_correct': totalCorrect,
        'last_study_date': lastStudyDate?.toIso8601String(),
        'grade': grade,
        'subject_preference': subjectPreference,
        'ability_level': abilityLevel,
        'strengths_json': strengthsJson,
        'weak_areas_json': weakAreasJson,
        'suggested_focus_json': suggestedFocusJson,
        'learning_trend': learningTrend,
        'last_profile_update': lastProfileUpdate?.toIso8601String(),
      };

  factory UserProfile.fromDbMap(Map<String, dynamic> map) => UserProfile(
        theta: (map['theta'] as num?)?.toDouble() ?? 0.0,
        stability: (map['stability'] as num?)?.toDouble() ?? 30.0,
        totalAnswers: map['total_answers'] as int? ?? 0,
        totalCorrect: map['total_correct'] as int? ?? 0,
        lastStudyDate: map['last_study_date'] != null
            ? DateTime.tryParse(map['last_study_date'] as String)
            : null,
        grade: map['grade'] as String? ?? '',
        subjectPreference: map['subject_preference'] as String? ?? '',
        abilityLevel: map['ability_level'] as String? ?? '',
        strengthsJson: map['strengths_json'] as String? ?? '[]',
        weakAreasJson: map['weak_areas_json'] as String? ?? '[]',
        suggestedFocusJson: map['suggested_focus_json'] as String? ?? '[]',
        learningTrend: map['learning_trend'] as String? ?? '未知',
        lastProfileUpdate: map['last_profile_update'] != null
            ? DateTime.tryParse(map['last_profile_update'] as String)
            : null,
      );
}
