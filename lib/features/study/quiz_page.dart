import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/answer_log.dart';
import '../../data/models/question.dart';
import '../../providers/current_quiz_provider.dart';
import '../../providers/llm_provider.dart';
import '../../providers/review_queue_provider.dart';
import 'result_page.dart';

class QuizPage extends ConsumerStatefulWidget {
  const QuizPage({super.key, required this.questions});

  final List<Question> questions;

  @override
  ConsumerState<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends ConsumerState<QuizPage>
    with SingleTickerProviderStateMixin {
  bool _sessionStarted = false;
  int? _selectedIndex;
  int _hesitationCount = 0;
  int _confidence = 3;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timerTick;
  late AnimationController _staggerController;

  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _timerTick?.cancel();
    _staggerController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await ref.read(currentQuizProvider.notifier).startQuiz(widget.questions);
    if (!mounted) return;
    setState(() => _sessionStarted = true);
    _resetQuestionLocalState();
  }

  void _armTimerUi() {
    _timerTick?.cancel();
    _timerTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _resetQuestionLocalState() {
    _selectedIndex = null;
    _hesitationCount = 0;
    _confidence = 3;
    _revealed = false;
    _stopwatch
      ..reset()
      ..start();
    _armTimerUi();
    _staggerController.forward(from: 0);
    setState(() {});
  }

  void _onOptionTap(int index) {
    if (_revealed) return;
    setState(() {
      if (_selectedIndex != null && _selectedIndex != index) {
        _hesitationCount++;
      }
      _selectedIndex = index;
    });
  }

  String _formatElapsed(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    final idx = _selectedIndex;
    if (idx == null || _revealed) return;
    final quiz = ref.read(currentQuizProvider);
    final q = quiz.currentQuestion;
    if (q == null) return;

    _stopwatch.stop();
    _timerTick?.cancel();
    final responseTimeMs = _stopwatch.elapsedMilliseconds;
    final showConf = ref.read(llmSettingsProvider).showConfidenceRating;
    final confRating = showConf ? _confidence.clamp(1, 5) : 3;

    setState(() => _revealed = true);
    await Future<void>.delayed(const Duration(milliseconds: 750));
    if (!mounted) return;

    await ref.read(currentQuizProvider.notifier).submitAnswer(
          selectedOptionIndex: idx,
          responseTimeMs: responseTimeMs,
          confidenceRating: confRating,
          hesitationCount: _hesitationCount,
        );
    if (!mounted) return;

    final finished = ref.read(currentQuizProvider).isFinished;
    final AnswerLog lastLog = ref.read(currentQuizProvider).logs.last;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => ResultPage(
          question: q,
          answerLog: lastLog,
          isLastQuestion: finished,
        ),
      ),
    );
    if (!mounted) return;

    if (finished) {
      Navigator.of(context).pop();
      return;
    }

    _resetQuestionLocalState();
  }

  Future<void> _confirmExit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('结束复习？'),
        content: const Text('提前退出将保存当前进度并结束本轮会话。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('结束'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await ref.read(currentQuizProvider.notifier).endSessionEarly();
      if (mounted) Navigator.of(context).pop();
    }
  }

  Color _optionBorderColor(
    ThemeData theme,
    ColorScheme scheme,
    int i,
    Question q,
  ) {
    if (!_revealed) {
      final sel = _selectedIndex == i;
      return sel ? scheme.primary : scheme.outlineVariant;
    }
    if (i == q.correctIndex) {
      return const Color(0xFF2E7D32);
    }
    if (i == _selectedIndex && i != q.correctIndex) {
      return scheme.error;
    }
    return scheme.outlineVariant;
  }

  Color? _optionFillColor(
    ColorScheme scheme,
    int i,
    Question q,
  ) {
    if (!_revealed) {
      if (_selectedIndex == i) {
        return scheme.primaryContainer.withValues(alpha: 0.65);
      }
      return scheme.surfaceContainerLow;
    }
    if (i == q.correctIndex) {
      return const Color(0xFF2E7D32).withValues(alpha: 0.12);
    }
    if (i == _selectedIndex && i != q.correctIndex) {
      return scheme.errorContainer.withValues(alpha: 0.45);
    }
    return scheme.surfaceContainerLow;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(reviewQueueProvider, (_, _) {});

    if (!_sessionStarted) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final quiz = ref.watch(currentQuizProvider);
    final q = quiz.currentQuestion;
    final total = quiz.totalQuestions;
    final llm = ref.watch(llmSettingsProvider);

    if (q == null || total == 0) {
      return Scaffold(
        appBar: AppBar(title: const Text('复习')),
        body: const Center(child: Text('暂无题目')),
      );
    }

    final progress =
        total > 0 ? (quiz.currentIndex + 1) / total : 0.0;
    final nOpts = q.options.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        await _confirmExit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('复习答题'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Center(
                child: Text(
                  _formatElapsed(_stopwatch.elapsed),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Card(
                      elevation: 0,
                      color: scheme.surfaceContainerHighest,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress.clamp(0.0, 1.0),
                                minHeight: 6,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${quiz.currentIndex + 1} / $total',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            q.stem,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '犹豫：$_hesitationCount 次',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ...List.generate(nOpts, (i) {
                            final start = i / (nOpts + 1);
                            final end = (start + 0.45).clamp(0.0, 1.0);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: FadeTransition(
                                opacity: CurvedAnimation(
                                  parent: _staggerController,
                                  curve: Interval(
                                    start,
                                    end,
                                    curve: Curves.easeOutCubic,
                                  ),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: Card(
                                    elevation: _selectedIndex == i && !_revealed
                                        ? 2
                                        : 0,
                                    color: _optionFillColor(scheme, i, q),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(
                                        color: _optionBorderColor(
                                          theme,
                                          scheme,
                                          i,
                                          q,
                                        ),
                                        width:
                                            _selectedIndex == i || _revealed
                                                ? 2
                                                : 1,
                                      ),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      onTap: _revealed
                                          ? null
                                          : () => _onOptionTap(i),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 18,
                                        ),
                                        child: Row(
                                          children: [
                                            DecoratedBox(
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: scheme
                                                    .secondaryContainer,
                                              ),
                                              child: SizedBox(
                                                width: 32,
                                                height: 32,
                                                child: Center(
                                                  child: Text(
                                                    String.fromCharCode(65 + i),
                                                    style: theme
                                                        .textTheme.labelLarge
                                                        ?.copyWith(
                                                      color: scheme
                                                          .onSecondaryContainer,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Text(
                                                q.options[i],
                                                style: theme.textTheme.bodyLarge,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                          if (llm.showConfidenceRating) ...[
                            const SizedBox(height: 8),
                            Card(
                              elevation: 0,
                              color: scheme.surfaceContainerHighest,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '信心 $_confidence / 5',
                                      style: theme.textTheme.titleSmall,
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: List.generate(5, (i) {
                                        final v = i + 1;
                                        final on = v <= _confidence;
                                        return IconButton(
                                          onPressed: _revealed
                                              ? null
                                              : () => setState(
                                                    () => _confidence = v,
                                                  ),
                                          icon: Icon(
                                            on
                                                ? Icons.star_rounded
                                                : Icons.star_outline_rounded,
                                            color: on
                                                ? scheme.primary
                                                : scheme.outline,
                                            size: 32,
                                          ),
                                        );
                                      }),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: (_selectedIndex == null ||
                                    _revealed)
                                ? null
                                : _submit,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('提交答案'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
