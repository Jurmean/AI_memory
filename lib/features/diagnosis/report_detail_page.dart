import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/diagnostic_report.dart';

String _stripJsonFencedBlocks(String input) {
  return input
      .replaceAllMapped(
        RegExp(r'```(?:json)?\s*[\s\S]*?```', caseSensitive: false),
        (_) => '',
      )
      .trim();
}

double? _asDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

List<String> _stringList(dynamic raw) {
  if (raw is! List) return [];
  return raw.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
}

List<MapEntry<String, double>> _weakAreaEntries(Map<String, dynamic> data) {
  final raw = data['weakAreas'];
  if (raw is! List) return [];
  final out = <MapEntry<String, double>>[];
  for (final item in raw) {
    if (item is Map) {
      final name = item['name']?.toString() ?? '';
      final score = _asDouble(item['score']);
      if (name.isNotEmpty && score != null) {
        out.add(MapEntry(name, score));
      }
    }
  }
  return out;
}

Color _abilityColor(String level) {
  switch (level) {
    case '优秀':
      return const Color(0xFF2E7D32);
    case '良好':
      return const Color(0xFF1565C0);
    case '中等':
      return const Color(0xFFE65100);
    case '需加强':
    default:
      return const Color(0xFFC62828);
  }
}

String _truncateLabel(String s, int maxLen) {
  if (s.length <= maxLen) return s;
  return '${s.substring(0, maxLen)}…';
}

class ReportDetailPage extends ConsumerWidget {
  const ReportDetailPage({super.key, required this.report});

  final DiagnosticReport report;

  String _appBarTitle() {
    switch (report.reportType) {
      case 'overall':
        return '总报告';
      case 'session':
      default:
        return '答题组报告';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final data = report.reportData;
    final hasStructuredData = data != null;

    final overallScore = data != null ? _asDouble(data['overallScore']) : null;
    final abilityLevel = data?['abilityLevel']?.toString();
    final strengths = data != null ? _stringList(data['strengths']) : <String>[];
    final weakAreas =
        data != null ? _weakAreaEntries(data) : <MapEntry<String, double>>[];
    final suggestedFocus =
        data != null ? _stringList(data['suggestedFocus']) : <String>[];

    return Scaffold(
      appBar: AppBar(title: Text(_appBarTitle())),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasStructuredData) ...[
              // Score + Ability row
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (overallScore != null)
                      Expanded(child: _ScoreRing(score: overallScore, cs: cs, theme: theme)),
                    if (overallScore != null &&
                        abilityLevel != null &&
                        abilityLevel.isNotEmpty)
                      const SizedBox(width: 12),
                    if (abilityLevel != null && abilityLevel.isNotEmpty)
                      Expanded(
                        child: _AbilityCard(
                          level: abilityLevel,
                          theme: theme,
                        ),
                      ),
                  ],
                ),
              ),

              // Strengths
              if (strengths.isNotEmpty)
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.thumb_up_rounded,
                                color: const Color(0xFF2E7D32), size: 20),
                            const SizedBox(width: 8),
                            Text('优势',
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: strengths
                              .map((s) => Chip(
                                    label: Text(s),
                                    visualDensity: VisualDensity.compact,
                                    side: const BorderSide(
                                        color: Color(0xFF2E7D32), width: 1),
                                    backgroundColor:
                                        const Color(0xFF2E7D32).withValues(alpha: 0.08),
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ),

              // Weak areas chart
              if (weakAreas.isNotEmpty)
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.trending_down_rounded,
                                color: const Color(0xFFC62828), size: 20),
                            const SizedBox(width: 8),
                            Text('薄弱项',
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _WeakAreasChart(weakAreas: weakAreas, cs: cs),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: weakAreas
                              .map((e) => Chip(
                                    label: Text(
                                        '${e.key}  ${e.value.toStringAsFixed(0)}分'),
                                    visualDensity: VisualDensity.compact,
                                    side: const BorderSide(
                                        color: Color(0xFFC62828), width: 1),
                                    backgroundColor:
                                        const Color(0xFFC62828).withValues(alpha: 0.08),
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ),

              // Suggested focus
              if (suggestedFocus.isNotEmpty)
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.lightbulb_rounded,
                                color: cs.primary, size: 20),
                            const SizedBox(width: 8),
                            Text('建议重点',
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...List.generate(suggestedFocus.length, (i) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: cs.primaryContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${i + 1}',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: cs.onPrimaryContainer,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(suggestedFocus[i],
                                      style: theme.textTheme.bodyLarge),
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

            // Fallback: raw markdown only when no structured data
            if (!hasStructuredData)
              Card(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: MarkdownBody(
                      data: _stripJsonFencedBlocks(report.reportContent)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScoreRing extends StatelessWidget {
  const _ScoreRing({
    required this.score,
    required this.cs,
    required this.theme,
  });

  final double score;
  final ColorScheme cs;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final color = score >= 80
        ? const Color(0xFF2E7D32)
        : score >= 60
            ? const Color(0xFFE65100)
            : const Color(0xFFC62828);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: (score / 100).clamp(0.0, 1.0),
                    strokeWidth: 8,
                    backgroundColor: cs.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(color),
                    strokeCap: StrokeCap.round,
                  ),
                  Center(
                    child: Text(
                      score % 1 == 0
                          ? score.toInt().toString()
                          : score.toStringAsFixed(1),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text('综合得分',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _AbilityCard extends StatelessWidget {
  const _AbilityCard({required this.level, required this.theme});

  final String level;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final color = _abilityColor(level);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.12),
                border: Border.all(color: color, width: 3),
              ),
              child: Center(
                child: Icon(
                  level == '优秀'
                      ? Icons.emoji_events_rounded
                      : level == '良好'
                          ? Icons.star_rounded
                          : level == '中等'
                              ? Icons.timelapse_rounded
                              : Icons.fitness_center_rounded,
                  color: color,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              level,
              style: theme.textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text('能力等级',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _WeakAreasChart extends StatelessWidget {
  const _WeakAreasChart({required this.weakAreas, required this.cs});

  final List<MapEntry<String, double>> weakAreas;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final barWidth = weakAreas.length > 6
        ? 12.0
        : weakAreas.length > 4
            ? 16.0
            : 20.0;

    return SizedBox(
      height: 260,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 100,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIdx, rod, rodIdx) {
                final name = weakAreas[group.x].key;
                return BarTooltipItem(
                  '$name\n${rod.toY.toStringAsFixed(0)}分',
                  const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: 25,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 72,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= weakAreas.length) {
                    return const SizedBox.shrink();
                  }
                  final label = _truncateLabel(weakAreas[i].key, 5);
                  return SideTitleWidget(
                    meta: meta,
                    child: Transform.rotate(
                      angle: -math.pi / 5,
                      child: Text(
                        label,
                        style: const TextStyle(fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: cs.outlineVariant.withValues(alpha: 0.5),
              strokeWidth: 1,
            ),
          ),
          barGroups: [
            for (var i = 0; i < weakAreas.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: weakAreas[i].value,
                    color: cs.primary,
                    width: barWidth,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
