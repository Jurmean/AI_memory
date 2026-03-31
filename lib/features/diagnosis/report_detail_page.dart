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
    final scheme = Theme.of(context).colorScheme;
    final data = report.reportData;
    final markdownSource = _stripJsonFencedBlocks(report.reportContent);

    final overallScore = data != null ? _asDouble(data['overallScore']) : null;
    final abilityLevel = data?['abilityLevel']?.toString();
    final strengths = data != null ? _stringList(data['strengths']) : <String>[];
    final weakAreas = data != null ? _weakAreaEntries(data) : <MapEntry<String, double>>[];
    final suggestedFocus =
        data != null ? _stringList(data['suggestedFocus']) : <String>[];

    return Scaffold(
      appBar: AppBar(title: Text(_appBarTitle())),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (data != null) ...[
              if (overallScore != null)
                Card(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '综合得分',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          overallScore % 1 == 0
                              ? overallScore.toInt().toString()
                              : overallScore.toStringAsFixed(1),
                          style: Theme.of(context)
                              .textTheme
                              .displayMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: scheme.primary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (abilityLevel != null && abilityLevel.isNotEmpty)
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Text(
                          '能力等级',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(width: 12),
                        Chip(
                          label: Text(abilityLevel),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                ),
              if (strengths.isNotEmpty)
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '优势',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: strengths
                              .map(
                                (s) => Chip(
                                  label: Text(s),
                                  visualDensity: VisualDensity.compact,
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              if (weakAreas.isNotEmpty)
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '薄弱项',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 220,
                          child: BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: 100,
                              barTouchData:
                                  const BarTouchData(enabled: false),
                              titlesData: FlTitlesData(
                                show: true,
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
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
                                    reservedSize: 48,
                                    getTitlesWidget: (value, meta) {
                                      final i = value.toInt();
                                      if (i < 0 || i >= weakAreas.length) {
                                        return const SizedBox.shrink();
                                      }
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          weakAreas[i].key,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 10),
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
                                getDrawingHorizontalLine: (value) =>
                                    FlLine(
                                  color: scheme.outlineVariant.withValues(
                                    alpha: 0.5,
                                  ),
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
                                        color: scheme.primary,
                                        width: 18,
                                        borderRadius:
                                            const BorderRadius.vertical(
                                          top: Radius.circular(4),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (suggestedFocus.isNotEmpty)
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '建议重点',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        ...suggestedFocus.map(
                          (line) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '• ',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                Expanded(
                                  child: Text(
                                    line,
                                    style:
                                        Theme.of(context).textTheme.bodyLarge,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
            Card(
              margin: EdgeInsets.fromLTRB(
                16,
                data != null ? 8 : 16,
                16,
                16,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '报告正文',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    MarkdownBody(data: markdownSource),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
