import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../data/models/question.dart';
import '../../data/models/answer_log.dart';
import '../../data/models/knowledge_point.dart';
import '../../data/models/review_state.dart';
import '../../providers/database_provider.dart';

class QuestionDetailPage extends ConsumerStatefulWidget {
  const QuestionDetailPage({super.key, required this.question});

  final Question question;

  @override
  ConsumerState<QuestionDetailPage> createState() => _QuestionDetailPageState();
}

class _QuestionDetailPageState extends ConsumerState<QuestionDetailPage> {
  List<KnowledgePoint> _kps = [];
  List<AnswerLog> _logs = [];
  ReviewState? _reviewState;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = ref.read(databaseProvider);
    final kps = await db.getKnowledgePointsForQuestion(widget.question.id);
    final logs = await db.getAnswerLogsByQuestion(widget.question.id);
    final rs = await db.getReviewState(widget.question.id);
    if (!mounted) return;
    setState(() {
      _kps = kps;
      _logs = logs;
      _reviewState = rs;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('题目详情')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(q.stem, style: theme.textTheme.titleMedium),
                          const SizedBox(height: 16),
                          ...List.generate(q.options.length, (i) {
                            final isCorrect = i == q.correctIndex;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isCorrect
                                          ? cs.primaryContainer
                                          : cs.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      String.fromCharCode(65 + i),
                                      style: theme.textTheme.labelLarge?.copyWith(
                                        color: isCorrect
                                            ? cs.onPrimaryContainer
                                            : cs.onSurfaceVariant,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(q.options[i],
                                        style: theme.textTheme.bodyLarge),
                                  ),
                                  if (isCorrect)
                                    Icon(Icons.check_circle,
                                        color: cs.primary, size: 20),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          _ParamChip(
                            label: '难度 b',
                            value: q.difficultyB.toStringAsFixed(2),
                            color: q.difficultyB > 0.5
                                ? cs.errorContainer
                                : q.difficultyB < -0.5
                                    ? cs.primaryContainer
                                    : cs.secondaryContainer,
                          ),
                          const SizedBox(width: 12),
                          if (q.sourceType != null)
                            _ParamChip(
                              label: '来源',
                              value: q.sourceType!,
                              color: cs.tertiaryContainer,
                            ),
                          if (_reviewState != null) ...[
                            const SizedBox(width: 12),
                            _ParamChip(
                              label: 'EF',
                              value: _reviewState!.easinessFactor
                                  .toStringAsFixed(2),
                              color: cs.surfaceContainerHighest,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  if (_kps.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('知识点',
                                style: theme.textTheme.titleSmall),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: _kps
                                  .map((kp) => Chip(
                                        label: Text(kp.name),
                                        visualDensity: VisualDensity.compact,
                                      ))
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  if (q.explanation != null &&
                      q.explanation!.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Card(
                      color: cs.primaryContainer.withValues(alpha: 0.3),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('解析',
                                style: theme.textTheme.titleSmall),
                            const SizedBox(height: 8),
                            Text(q.explanation!,
                                style: theme.textTheme.bodyMedium),
                          ],
                        ),
                      ),
                    ),
                  ],

                  if (q.distractorAnalysis != null &&
                      q.distractorAnalysis!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _DistractorChart(
                      distractors: q.distractorAnalysis!,
                      options: q.options,
                      theme: theme,
                    ),
                  ],

                  if (_reviewState != null) ...[
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('复习状态',
                                style: theme.textTheme.titleSmall),
                            const SizedBox(height: 12),
                            _InfoRow('复习次数',
                                '${_reviewState!.reviewCount} 次'),
                            _InfoRow('当前间隔',
                                '${_reviewState!.intervalDays} 天'),
                            _InfoRow(
                              '下次复习',
                              _formatDate(_reviewState!.nextReviewDate),
                            ),
                            _InfoRow('最近 QS',
                                _reviewState!.lastQS.toStringAsFixed(2)),
                          ],
                        ),
                      ),
                    ),
                  ],

                  if (_logs.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('答题历史',
                                style: theme.textTheme.titleSmall),
                            const SizedBox(height: 12),
                            ..._logs.reversed.take(10).map((log) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Icon(
                                      log.isCorrect
                                          ? Icons.check_circle_outline
                                          : Icons.cancel_outlined,
                                      size: 18,
                                      color: log.isCorrect
                                          ? Colors.green
                                          : cs.error,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      String.fromCharCode(65 + log.selectedOptionIndex),
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      '${(log.responseTimeMs / 1000).toStringAsFixed(1)}s',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                    const Spacer(),
                                    Text(
                                      _formatDateTime(log.timestamp),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                              color: cs.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _formatDateTime(DateTime d) =>
      '${_formatDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _ParamChip extends StatelessWidget {
  const _ParamChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _DistractorChart extends StatelessWidget {
  const _DistractorChart({
    required this.distractors,
    required this.options,
    required this.theme,
  });

  final List<DistractorInfo> distractors;
  final List<String> options;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('干扰项分析', style: theme.textTheme.titleSmall),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 1.0,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, gIdx, rod, rIdx) {
                        final d = distractors[group.x.toInt()];
                        return BarTooltipItem(
                          '${d.commonMistakeReason ?? ""}  ${(d.attractiveness * 100).toStringAsFixed(0)}%',
                          theme.textTheme.bodySmall!
                              .copyWith(color: cs.onInverseSurface),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles:
                        const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles:
                        const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        interval: 0.25,
                        getTitlesWidget: (v, _) => Text(
                          '${(v * 100).toInt()}%',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= distractors.length) {
                            return const SizedBox.shrink();
                          }
                          final oi = distractors[i].optionIndex;
                          final label = oi < options.length
                              ? String.fromCharCode(65 + oi)
                              : '${oi + 1}';
                          return Text(label,
                              style: theme.textTheme.labelMedium);
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (v) => FlLine(
                      color: cs.outlineVariant.withValues(alpha: 0.5),
                      strokeWidth: 1,
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < distractors.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: distractors[i].attractiveness,
                            color: cs.tertiary,
                            width: 22,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4)),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...distractors.map((d) {
              final oi = d.optionIndex;
              final label = oi < options.length
                  ? '${String.fromCharCode(65 + oi)}. ${options[oi]}'
                  : '选项 ${oi + 1}';
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '$label — ${d.commonMistakeReason ?? ""}',
                  style: theme.textTheme.bodySmall,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
