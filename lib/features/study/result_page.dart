import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/question.dart';
import '../../data/models/answer_log.dart';

class ResultPage extends ConsumerWidget {
  const ResultPage({
    super.key,
    required this.question,
    required this.answerLog,
    this.isLastQuestion = false,
  });

  final Question question;
  final AnswerLog answerLog;
  final bool isLastQuestion;

  static const _labelChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _ResultHeader(isCorrect: answerLog.isCorrect)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            question.stem,
                            style: theme.textTheme.titleMedium?.copyWith(
                              height: 1.45,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '选项回顾',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(question.options.length, (i) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _OptionReviewTile(
                            label: i < _labelChars.length
                                ? _labelChars[i]
                                : '${i + 1}',
                            text: question.options[i],
                            isCorrectOption: i == question.correctIndex,
                            isWrongSelection: i == answerLog.selectedOptionIndex &&
                                !answerLog.isCorrect,
                          ),
                        );
                      }),
                      if (question.explanation != null &&
                          question.explanation!.trim().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          '解析',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Card(
                          margin: EdgeInsets.zero,
                          color: cs.primaryContainer.withValues(alpha: 0.35),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              question.explanation!.trim(),
                              style: theme.textTheme.bodyLarge?.copyWith(
                                height: 1.5,
                                color: cs.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ]),
                  ),
                ),
              ],
            ),
          ),
          Material(
            elevation: 3,
            shadowColor: cs.shadow.withValues(alpha: 0.2),
            color: cs.surface,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('AI伴学功能')),
                          );
                        },
                        child: const Text('AI 伴学'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          if (isLastQuestion) {
                            Navigator.of(context)
                                .popUntil((route) => route.isFirst);
                          } else {
                            Navigator.of(context).pop();
                          }
                        },
                        child: Text(isLastQuestion ? '完成' : '下一题'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({required this.isCorrect});

  final bool isCorrect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isCorrect
          ? const [
              Color(0xFF1B5E20),
              Color(0xFF43A047),
            ]
          : const [
              Color(0xFFB71C1C),
              Color(0xFFE53935),
            ],
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 24,
        16,
        28,
      ),
      decoration: BoxDecoration(gradient: gradient),
      child: Column(
        children: [
          Icon(
            isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 72,
            color: Colors.white.withValues(alpha: 0.95),
          ),
          const SizedBox(height: 12),
          Text(
            isCorrect ? '回答正确!' : '回答错误',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionReviewTile extends StatelessWidget {
  const _OptionReviewTile({
    required this.label,
    required this.text,
    required this.isCorrectOption,
    required this.isWrongSelection,
  });

  final String label;
  final String text;
  final bool isCorrectOption;
  final bool isWrongSelection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    Color? borderColor;
    Color? bgTint;
    Widget? trailing;

    if (isCorrectOption) {
      borderColor = const Color(0xFF2E7D32);
      bgTint = const Color(0xFF2E7D32).withValues(alpha: 0.08);
      trailing = Icon(Icons.check_circle_rounded, color: borderColor, size: 24);
    } else if (isWrongSelection) {
      borderColor = const Color(0xFFC62828);
      bgTint = const Color(0xFFC62828).withValues(alpha: 0.08);
      trailing = Icon(Icons.cancel_rounded, color: borderColor, size: 24);
    }

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: bgTint ?? cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: borderColor ?? cs.outlineVariant.withValues(alpha: 0.5),
          width: borderColor != null ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '$label.',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                ),
              ),
            ),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.4),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
