import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/question.dart';
import '../../providers/review_queue_provider.dart';
import '../study/quiz_page.dart';

String _formatReviewDate(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

String _difficultyLabel(double b) {
  if (b < -0.5) return '易';
  if (b > 0.5) return '难';
  return '中';
}

Color _difficultyBadgeColor(BuildContext context, double b) {
  final cs = Theme.of(context).colorScheme;
  if (b < -0.5) return cs.primaryContainer;
  if (b > 0.5) return cs.errorContainer;
  return cs.secondaryContainer;
}

Color _difficultyBadgeForeground(BuildContext context, double b) {
  final cs = Theme.of(context).colorScheme;
  if (b < -0.5) return cs.onPrimaryContainer;
  if (b > 0.5) return cs.onErrorContainer;
  return cs.onSecondaryContainer;
}

Color _priorityBarColor(double t) {
  return Color.lerp(
        const Color(0xFF2E7D32),
        const Color(0xFFC62828),
        t.clamp(0.0, 1.0),
      ) ??
      const Color(0xFF2E7D32);
}

class ReviewQueuePage extends ConsumerWidget {
  const ReviewQueuePage({super.key});

  void _startReview(BuildContext context, WidgetRef ref) {
    final due = ref.read(reviewQueueProvider.notifier).dueItems;
    if (due.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前没有到期的复习项')),
      );
      return;
    }
    final List<Question> questions = due.map((e) => e.question).toList();
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => QuizPage(questions: questions),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(reviewQueueProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('复习队列'),
      ),
      floatingActionButton: async.maybeWhen(
        data: (_) => FloatingActionButton.extended(
          onPressed: () => _startReview(context, ref),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('开始复习'),
        ),
        orElse: () => null,
      ),
      body: async.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 64,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '队列为空',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '暂无待复习题目',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            );
          }

          final maxP = items
              .map((e) => e.priority)
              .fold<double>(0, (a, b) => math.max(a, b));
          final denom = maxP > 0 ? maxP : 1.0;

          return RefreshIndicator(
            onRefresh: () =>
                ref.read(reviewQueueProvider.notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final q = item.question;
                final rs = item.reviewState;
                final t = (item.priority / denom).clamp(0.0, 1.0);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  q.stem,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _difficultyBadgeColor(
                                    context,
                                    q.difficultyB,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _difficultyLabel(q.difficultyB),
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: _difficultyBadgeForeground(
                                      context,
                                      q.difficultyB,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: t,
                              minHeight: 6,
                              backgroundColor:
                                  theme.colorScheme.surfaceContainerHighest,
                              color: _priorityBarColor(t),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '下次复习：${_formatReviewDate(rs.nextReviewDate)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  err.toString(),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () =>
                      ref.read(reviewQueueProvider.notifier).refresh(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
