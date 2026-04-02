import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../providers/user_profile_provider.dart';
import '../../providers/review_queue_provider.dart';
import '../../providers/database_provider.dart';
import '../../core/algorithms/ability_decay.dart';
import '../../data/models/user_profile.dart';
import '../settings/settings_page.dart';
import '../study/quiz_page.dart';
import '../queue/review_queue_page.dart';
import '../ability/ability_detail_page.dart';

final homeWeakKnowledgeProvider =
    FutureProvider.autoDispose<Map<String, double>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getWeakKnowledgePoints(limit: 3);
});

Future<void> _refreshHome(WidgetRef ref) async {
  await Future.wait([
    ref.read(userProfileProvider.notifier).refresh(),
    ref.read(reviewQueueProvider.notifier).refresh(),
  ]);
  ref.invalidate(homeWeakKnowledgeProvider);
}

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  static const _headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final queueAsync = ref.watch(reviewQueueProvider);
    final weakAsync = ref.watch(homeWeakKnowledgeProvider);

    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => _ProfileErrorView(
        onRetry: () => ref.invalidate(userProfileProvider),
      ),
      data: (profile) {
        return SafeArea(
          child: RefreshIndicator(
            onRefresh: () => _refreshHome(ref),
            edgeOffset: 8,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _GradientHeader(
                    gradient: _headerGradient,
                    greeting: _timeGreeting(),
                    profile: profile,
                    onSettings: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => const SettingsPage(),
                        ),
                      );
                    },
                  ),
                  Transform.translate(
                    offset: const Offset(0, -10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        queueAsync.when(
                          loading: () => const _SectionLoadingCard(height: 92),
                          error: (e, st) => _InlineErrorCard(
                            title: '复习队列',
                            message: '加载失败',
                            onRetry: () =>
                                ref.invalidate(reviewQueueProvider),
                          ),
                          data: (_) => _DueReviewGradientCard(
                            count: ref
                                .read(reviewQueueProvider.notifier)
                                .dueItems
                                .length,
                            onTap: () {
                              Navigator.of(context).push<void>(
                                MaterialPageRoute<void>(
                                  builder: (_) => const ReviewQueuePage(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                        _AnimatedStatsRow(profile: profile),
                        const SizedBox(height: 14),
                        _AbilityGradientCard(
                          effectiveTheta: AbilityDecay.effectiveTheta(
                            profile.theta,
                            profile.daysSinceLastStudy.toDouble(),
                            profile.stability,
                          ),
                          retrieval: AbilityDecay.retrievability(
                            profile.daysSinceLastStudy.toDouble(),
                            profile.stability,
                          ),
                          rawTheta: profile.theta,
                          onTap: () {
                            Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (_) => const AbilityDetailPage(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        weakAsync.when(
                          loading: () =>
                              const _SectionLoadingCard(height: 140),
                          error: (e, st) => _InlineErrorCard(
                            title: '薄弱知识点',
                            message: '加载失败',
                            onRetry: () =>
                                ref.invalidate(homeWeakKnowledgeProvider),
                          ),
                          data: (map) => _WeakTop3Card(weakKps: map),
                        ),
                        const SizedBox(height: 14),
                        _PredictedThetaChart(
                          theta: profile.theta,
                          stability: profile.stability,
                        ),
                        const SizedBox(height: 20),
                        queueAsync.when(
                          loading: () => FilledButton.icon(
                            onPressed: null,
                            icon: const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            label: const Text('开始复习'),
                          ),
                          error: (e, st) => FilledButton.icon(
                            onPressed: () =>
                                ref.invalidate(reviewQueueProvider),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('重试加载队列'),
                          ),
                          data: (_) {
                            final due = ref
                                .read(reviewQueueProvider.notifier)
                                .dueItems;
                            final questions =
                                due.map((e) => e.question).toList();
                            return FilledButton.icon(
                              onPressed: questions.isEmpty
                                  ? null
                                  : () {
                                      Navigator.of(context).push<void>(
                                        MaterialPageRoute<void>(
                                          builder: (_) => QuizPage(
                                            questions: questions,
                                          ),
                                        ),
                                      );
                                    },
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('开始复习'),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static String _timeGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return '早上好';
    if (h < 18) return '下午好';
    return '晚上好';
  }
}

class _ProfileErrorView extends StatelessWidget {
  const _ProfileErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text('加载失败', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              FilledButton(onPressed: onRetry, child: const Text('重试')),
            ],
          ),
        ),
      ),
    );
  }
}

class _GradientHeader extends StatelessWidget {
  const _GradientHeader({
    required this.gradient,
    required this.greeting,
    required this.profile,
    required this.onSettings,
  });

  final LinearGradient gradient;
  final String greeting;
  final UserProfile profile;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = <String>[];
    if (profile.grade.isNotEmpty) parts.add(profile.grade);
    if (profile.subjectPreference.isNotEmpty) {
      parts.add(profile.subjectPreference);
    }
    final meta = parts.isEmpty ? '记忆助手' : parts.join(' · ');

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        greeting,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        meta,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onSettings,
                  icon: const Icon(Icons.settings_rounded),
                  color: Colors.white,
                  tooltip: '设置',
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              '能力 θ ${profile.theta.toStringAsFixed(2)} · '
              '稳定性 ${profile.stability.toStringAsFixed(0)} 天 · '
              '累计 ${profile.totalAnswers} 题',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.88),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DueReviewGradientCard extends StatelessWidget {
  const _DueReviewGradientCard({
    required this.count,
    required this.onTap,
  });

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cs.primaryContainer.withValues(alpha: 0.95),
                cs.tertiaryContainer.withValues(alpha: 0.75),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: cs.primary.withValues(alpha: 0.22),
            ),
            boxShadow: [
              BoxShadow(
                color: cs.primary.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.schedule_rounded,
                      color: cs.primary, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '待复习',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        count > 0 ? '$count 道题已到复习时间' : '暂无到期题目',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedStatsRow extends StatelessWidget {
  const _AnimatedStatsRow({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _GradientStatTile(
            label: '总答题',
            gradient: const LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
            ),
            child: TweenAnimationBuilder<double>(
              key: ValueKey('ta_${profile.totalAnswers}'),
              tween: Tween(begin: 0, end: profile.totalAnswers.toDouble()),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => Text(
                v.round().toString(),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _GradientStatTile(
            label: '正确率',
            gradient: const LinearGradient(
              colors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
            ),
            child: TweenAnimationBuilder<double>(
              key: ValueKey(
                  'cr_${profile.totalCorrect}_${profile.totalAnswers}'),
              tween: Tween(begin: 0, end: profile.correctRate),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => Text(
                '${(v * 100).toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GradientStatTile extends StatelessWidget {
  const _GradientStatTile({
    required this.label,
    required this.gradient,
    required this.child,
  });

  final String label;
  final LinearGradient gradient;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.22),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _AbilityGradientCard extends StatelessWidget {
  const _AbilityGradientCard({
    required this.effectiveTheta,
    required this.retrieval,
    required this.rawTheta,
    required this.onTap,
  });

  final double effectiveTheta;
  final double retrieval;
  final double rawTheta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cs.surfaceContainerLow,
                cs.primaryContainer.withValues(alpha: 0.45),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.bolt_rounded,
                              color: cs.primary, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            '有效能力 θ',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TweenAnimationBuilder<double>(
                        key: ValueKey(effectiveTheta),
                        tween: Tween(begin: 0, end: effectiveTheta),
                        duration: const Duration(milliseconds: 1000),
                        curve: Curves.easeOutCubic,
                        builder: (context, v, _) => Text(
                          v.toStringAsFixed(3),
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: cs.primary,
                              ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '原始 θ ${rawTheta.toStringAsFixed(3)} · '
                        '可提取度 ${(retrieval * 100).toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WeakTop3Card extends StatelessWidget {
  const _WeakTop3Card({required this.weakKps});

  final Map<String, double> weakKps;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final entries = weakKps.entries.toList();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.errorContainer.withValues(alpha: 0.35),
            cs.surfaceContainerLow,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_outlined, color: cs.error, size: 22),
              const SizedBox(width: 8),
              Text(
                '薄弱知识点 TOP3',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Text(
              '暂无足够答题数据，继续练习后会在此展示',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            )
          else
            ...List.generate(entries.length, (i) {
              final e = entries[i];
              return Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: cs.errorContainer.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: cs.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        e.key,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    Text(
                      '${(e.value * 100).toStringAsFixed(0)}% 错率',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _PredictedThetaChart extends StatelessWidget {
  const _PredictedThetaChart({
    required this.theta,
    required this.stability,
  });

  final double theta;
  final double stability;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const primary = Color(0xFF4F46E5);
    final points = AbilityDecay.predictedCurve(theta, stability, futureDays: 14);
    final spots = <FlSpot>[
      for (var i = 0; i < points.length; i++)
        FlSpot(points[i]['day']!, points[i]['theta']!),
    ];
    double minY = spots.first.y;
    double maxY = spots.first.y;
    for (final s in spots) {
      if (s.y < minY) minY = s.y;
      if (s.y > maxY) maxY = s.y;
    }
    final pad = (maxY - minY).abs() < 0.01 ? 0.2 : (maxY - minY) * 0.15;

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.surface,
            cs.primaryContainer.withValues(alpha: 0.25),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '有效 θ 预测（未来 14 天）',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: minY - pad,
                maxY: maxY + pad,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          'D${spot.x.toInt()}  θ=${spot.y.toStringAsFixed(2)}',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: cs.outlineVariant.withValues(alpha: 0.4),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (v, m) => Text(
                        v.toStringAsFixed(2),
                        style: TextStyle(
                          fontSize: 10,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 3,
                      getTitlesWidget: (v, m) => Text(
                        'D${v.toInt()}',
                        style: TextStyle(
                          fontSize: 9,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.28,
                    color: primary,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: primary.withValues(alpha: 0.12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLoadingCard extends StatelessWidget {
  const _SectionLoadingCard({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

class _InlineErrorCard extends StatelessWidget {
  const _InlineErrorCard({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: cs.error),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context).textTheme.titleSmall),
                Text(message,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}
