import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/user_profile.dart';
import '../core/algorithms/ability_decay.dart';
import 'database_provider.dart';

class UserProfileNotifier extends AsyncNotifier<UserProfile> {
  @override
  Future<UserProfile> build() async {
    final db = ref.read(databaseProvider);
    return db.getUserProfile();
  }

  Future<void> refresh() async {
    final db = ref.read(databaseProvider);
    state = AsyncData(await db.getUserProfile());
  }

  Future<void> recordAnswer({required bool isCorrect, required double newTheta}) async {
    final db = ref.read(databaseProvider);
    final current = state.value ?? const UserProfile();
    final updated = current.copyWith(
      theta: newTheta,
      totalAnswers: current.totalAnswers + 1,
      totalCorrect: current.totalCorrect + (isCorrect ? 1 : 0),
      lastStudyDate: DateTime.now(),
      stability: AbilityDecay.estimateStability(
        (current.totalCorrect + (isCorrect ? 1 : 0)) /
            (current.totalAnswers + 1),
        current.totalAnswers + 1,
      ),
    );
    await db.updateUserProfile(updated);
    state = AsyncData(updated);
  }

  Future<void> updateGrade(String grade) async {
    final db = ref.read(databaseProvider);
    final current = state.value ?? const UserProfile();
    final updated = current.copyWith(grade: grade);
    await db.updateUserProfile(updated);
    state = AsyncData(updated);
  }

  Future<void> updateSubjectPreference(String subject) async {
    final db = ref.read(databaseProvider);
    final current = state.value ?? const UserProfile();
    final updated = current.copyWith(subjectPreference: subject);
    await db.updateUserProfile(updated);
    state = AsyncData(updated);
  }

  Future<void> updateFromReport({
    required String abilityLevel,
    required String strengthsJson,
    required String weakAreasJson,
    required String suggestedFocusJson,
    required String learningTrend,
  }) async {
    final db = ref.read(databaseProvider);
    final current = state.value ?? const UserProfile();
    final updated = current.copyWith(
      abilityLevel: abilityLevel,
      strengthsJson: strengthsJson,
      weakAreasJson: weakAreasJson,
      suggestedFocusJson: suggestedFocusJson,
      learningTrend: learningTrend,
      lastProfileUpdate: DateTime.now(),
    );
    await db.updateUserProfile(updated);
    state = AsyncData(updated);
  }
}

final userProfileProvider =
    AsyncNotifierProvider<UserProfileNotifier, UserProfile>(
        UserProfileNotifier.new);
