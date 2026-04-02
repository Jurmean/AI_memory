import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/question.dart';
import '../data/models/review_state.dart';
import '../core/algorithms/scheduler.dart';
import 'database_provider.dart';
import 'user_profile_provider.dart';

class QueueItem {
  final Question question;
  final ReviewState reviewState;
  final double priority;

  const QueueItem({
    required this.question,
    required this.reviewState,
    required this.priority,
  });
}

class ReviewQueueNotifier extends AsyncNotifier<List<QueueItem>> {
  @override
  Future<List<QueueItem>> build() => _buildQueue();

  Future<List<QueueItem>> _buildQueue() async {
    final db = ref.read(databaseProvider);
    final profileAsync = ref.read(userProfileProvider);
    final profile = profileAsync.value;
    if (profile == null) return [];

    final reviews = await db.getAllReviewStates();
    if (reviews.isEmpty) return [];

    final scheduler = const ReviewScheduler();
    final allQuestions = await db.getAllQuestions();

    final items = <QueueItem>[];
    for (final rs in reviews) {
      final question = allQuestions
          .cast<Question?>()
          .firstWhere((q) => q!.id == rs.questionId, orElse: () => null);
      if (question == null) continue;

      final priority = scheduler.calculatePriority(
        rs,
        profile.theta,
        question.difficultyB,
      );

      items.add(QueueItem(
        question: question,
        reviewState: rs,
        priority: priority,
      ));
    }

    items.sort((a, b) => b.priority.compareTo(a.priority));
    return items;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _buildQueue());
  }

  List<QueueItem> get dueItems {
    final now = DateTime.now();
    return (state.value ?? [])
        .where((i) => !i.reviewState.nextReviewDate.isAfter(now))
        .toList();
  }
}

final reviewQueueProvider =
    AsyncNotifierProvider<ReviewQueueNotifier, List<QueueItem>>(
        ReviewQueueNotifier.new);
