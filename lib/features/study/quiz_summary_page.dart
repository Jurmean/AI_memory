import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/current_quiz_provider.dart';
import '../../providers/diagnosis_provider.dart';
import '../diagnosis/report_detail_page.dart';

class QuizSummaryPage extends ConsumerWidget {
  const QuizSummaryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final quiz = ref.watch(currentQuizProvider);
    final diagnosis = ref.watch(diagnosisProvider);

    final total = quiz.totalQuestions;
    final correct = quiz.correctCount;
    final wrong = total - correct;
    final rate = total > 0 ? (correct / total * 100) : 0.0;

    final latestReport = diagnosis.latestReport;
    final isGenerating = diagnosis.isGenerating;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('答题总结'),
          automaticallyImplyLeading: false,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ScoreHeader(rate: rate, cs: cs, theme: theme),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: '总题数',
                      value: '$total',
                      color: cs.primary,
                      theme: theme,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: '答对',
                      value: '$correct',
                      color: const Color(0xFF2E7D32),
                      theme: theme,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: '答错',
                      value: '$wrong',
                      color: const Color(0xFFC62828),
                      theme: theme,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Icon(Icons.auto_awesome, size: 20, color: cs.primary),
                  const SizedBox(width: 8),
                  Text(
                    'AI 诊断报告',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (isGenerating)
                _ReportLoadingCard(cs: cs, theme: theme)
              else if (latestReport != null)
                _ReportReadyCard(
                  cs: cs,
                  theme: theme,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            ReportDetailPage(report: latestReport),
                      ),
                    );
                  },
                )
              else if (diagnosis.error != null)
                Card(
                  color: cs.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.error_outline,
                                color: cs.onErrorContainer, size: 20),
                            const SizedBox(width: 8),
                            Text('报告生成失败',
                                style: theme.textTheme.titleSmall?.copyWith(
                                    color: cs.onErrorContainer,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          diagnosis.error!,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: cs.onErrorContainer),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('返回首页'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreHeader extends StatelessWidget {
  const _ScoreHeader({
    required this.rate,
    required this.cs,
    required this.theme,
  });

  final double rate;
  final ColorScheme cs;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final color = rate >= 80
        ? const Color(0xFF2E7D32)
        : rate >= 60
            ? const Color(0xFFE65100)
            : const Color(0xFFC62828);

    return Column(
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: rate / 100,
                strokeWidth: 10,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(color),
                strokeCap: StrokeCap.round,
              ),
              Center(
                child: Text(
                  '${rate.toStringAsFixed(0)}%',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '正确率',
          style: theme.textTheme.titleMedium
              ?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _ReportLoadingCard extends StatelessWidget {
  const _ReportLoadingCard({required this.cs, required this.theme});

  final ColorScheme cs;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '正在生成诊断报告…',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'AI 正在分析您的作答表现，请稍候',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: null,
                minHeight: 4,
                color: cs.primary,
                backgroundColor: cs.surfaceContainerHighest,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportReadyCard extends StatefulWidget {
  const _ReportReadyCard({
    required this.cs,
    required this.theme,
    required this.onTap,
  });

  final ColorScheme cs;
  final ThemeData theme;
  final VoidCallback onTap;

  @override
  State<_ReportReadyCard> createState() => _ReportReadyCardState();
}

class _ReportReadyCardState extends State<_ReportReadyCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final theme = widget.theme;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Card(
          clipBehavior: Clip.antiAlias,
          elevation: 2,
          child: InkWell(
            onTap: widget.onTap,
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: cs.primary, width: 4),
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.assessment_rounded,
                        color: cs.onPrimaryContainer, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('诊断报告已生成',
                            style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('点击查看详细分析与建议',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: cs.onSurfaceVariant, size: 28),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.theme,
  });

  final String label;
  final String value;
  final Color color;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: [
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
