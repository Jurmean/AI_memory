import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../core/algorithms/ability_decay.dart';
import '../../data/models/user_profile.dart';
import '../../providers/user_profile_provider.dart';

class AbilityDetailPage extends ConsumerWidget {
  const AbilityDetailPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final asyncProfile = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('能力详情'),
      ),
      body: asyncProfile.when(
        data: (profile) => _AbilityDetailBody(profile: profile, theme: theme),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '加载失败',
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class _AbilityDetailBody extends StatelessWidget {
  const _AbilityDetailBody({
    required this.profile,
    required this.theme,
  });

  final UserProfile profile;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final days = profile.daysSinceLastStudy.toDouble();
    final stability = profile.stability;
    final effective = AbilityDecay.effectiveTheta(profile.theta, days, stability);
    final r = AbilityDecay.retrievability(days, stability);
    final rPercent = r * 100;
    final curve = AbilityDecay.predictedCurve(
      profile.theta,
      profile.stability,
      futureDays: 30,
    );
    final halfLife = AbilityDecay.halfLife(profile.stability);

    final thetaSpots = curve
        .map((p) => FlSpot(p['day']!, p['theta']!))
        .toList();
    final rSpots = curve
        .map((p) => FlSpot(p['day']!, p['retrievability']!))
        .toList();

    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    for (final p in curve) {
      final t = p['theta']!;
      final rv = p['retrievability']!;
      minY = math.min(minY, math.min(t, rv));
      maxY = math.max(maxY, math.max(t, rv));
    }
    if (!minY.isFinite || !maxY.isFinite) {
      minY = 0;
      maxY = 1;
    } else if (maxY == minY) {
      maxY = minY + 1;
    }
    final pad = (maxY - minY) * 0.08;
    minY = math.max(0, minY - pad);
    maxY = maxY + pad;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '有效能力 θ',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    effective.toStringAsFixed(3),
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '可提取性',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${rPercent.toStringAsFixed(1)}%',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '预测衰减曲线（未来 30 天）',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _LegendDot(color: Colors.blue, label: '有效 θ'),
                      const SizedBox(width: 16),
                      _LegendDot(
                        color: Colors.orange,
                        label: '可提取性 (0–1)',
                        dashed: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 260,
                    child: LineChart(
                      LineChartData(
                        minX: 0,
                        maxX: 30,
                        minY: minY,
                        maxY: maxY,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: true,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: theme.colorScheme.outlineVariant
                                .withValues(alpha: 0.5),
                            strokeWidth: 1,
                          ),
                          getDrawingVerticalLine: (value) => FlLine(
                            color: theme.colorScheme.outlineVariant
                                .withValues(alpha: 0.5),
                            strokeWidth: 1,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              interval: 5,
                              getTitlesWidget: (value, meta) {
                                if (value < 0 || value > 30) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    value.toInt().toString(),
                                    style: theme.textTheme.bodySmall,
                                  ),
                                );
                              },
                            ),
                            axisNameWidget: Text(
                              '天数',
                              style: theme.textTheme.labelSmall,
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 44,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  value.toStringAsFixed(2),
                                  style: theme.textTheme.bodySmall,
                                );
                              },
                            ),
                            axisNameWidget: Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                '数值',
                                style: theme.textTheme.labelSmall,
                              ),
                            ),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: thetaSpots,
                            isCurved: true,
                            color: Colors.blue,
                            barWidth: 3,
                            dotData: const FlDotData(show: false),
                          ),
                          LineChartBarData(
                            spots: rSpots,
                            isCurved: true,
                            color: Colors.orange,
                            barWidth: 2,
                            dashArray: const [6, 4],
                            dotData: const FlDotData(show: false),
                          ),
                        ],
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((s) {
                                final label = s.barIndex == 0 ? 'θ' : 'R';
                                return LineTooltipItem(
                                  '$label: ${s.y.toStringAsFixed(3)}',
                                  theme.textTheme.bodySmall!.copyWith(
                                    color: theme.colorScheme.onInverseSurface,
                                  ),
                                );
                              }).toList();
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: const Text('稳定性 S'),
              subtitle: Text(
                '${stability.toStringAsFixed(1)} 天',
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: const Text('半衰期'),
              subtitle: Text(
                '${halfLife.toStringAsFixed(1)} 天',
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
    this.dashed = false,
  });

  final Color color;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 24,
          height: 3,
          child: dashed
              ? CustomPaint(
                  painter: _DashedLinePainter(color: color),
                )
              : DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    const dash = 4.0;
    const gap = 3.0;
    var x = 0.0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + dash, size.width), y), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
