import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/database_provider.dart';
import '../../data/models/question.dart';
import '../../data/models/knowledge_point.dart'; // ignore: unused_import
import 'question_detail_page.dart';
import 'import_page.dart';
import 'manual_add_page.dart';

class QuestionBankPage extends ConsumerStatefulWidget {
  const QuestionBankPage({super.key});

  @override
  ConsumerState<QuestionBankPage> createState() => _QuestionBankPageState();
}

class _QuestionBankPageState extends ConsumerState<QuestionBankPage> {
  Future<({Map<String, List<Question>> grouped, int count})>? _load;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final db = ref.read(databaseProvider);
    setState(() {
      _load = () async {
        final grouped = await db.getQuestionsGroupedByKP();
        final count = await db.getQuestionCount();
        return (grouped: grouped, count: count);
      }();
    });
  }

  Color _difficultyBarColor(double b) {
    if (b < -0.5) return const Color(0xFF2E7D32);
    if (b > 0.5) return const Color(0xFFC62828);
    return const Color(0xFFF9A825);
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

  Future<void> _openImport() async {
    final imported = await Navigator.of(context).push<int>(
      MaterialPageRoute<int>(builder: (_) => const ImportPage()),
    );
    _reload();
    if (!mounted || imported == null || imported <= 0) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已导入 $imported 道题')),
    );
  }

  Future<void> _openManualAdd() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const ManualAddPage()),
    );
    _reload();
  }

  Future<void> _openDetail(Question q) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => QuestionDetailPage(question: q),
      ),
    );
  }

  int _sumGrouped(Map<String, List<Question>> grouped) {
    var n = 0;
    for (final list in grouped.values) {
      n += list.length;
    }
    return n;
  }

  List<MapEntry<String, List<Question>>> _sortedEntries(
    Map<String, List<Question>> grouped,
  ) {
    final entries = grouped.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'qb_ai_import',
            onPressed: _openImport,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('AI导入'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'qb_manual_add',
            onPressed: _openManualAdd,
            icon: const Icon(Icons.edit_note_outlined),
            label: const Text('手动添加'),
          ),
        ],
      ),
      body: FutureBuilder<({Map<String, List<Question>> grouped, int count})>(
        future: _load,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '加载失败：${snap.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final data = snap.data!;
          final grouped = data.grouped;
          final count = data.count;
          final entries = _sortedEntries(grouped);

          if (count == 0) {
            return RefreshIndicator(
              onRefresh: () async {
                _reload();
                await _load;
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
                  Icon(
                    Icons.quiz_outlined,
                    size: 72,
                    color: cs.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '还没有题目',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '用 AI 导入教材或试卷，也可以手动录入单题。',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: _openImport,
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: const Text('AI导入'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _openManualAdd,
                    icon: const Icon(Icons.edit_note_outlined),
                    label: const Text('手动添加'),
                  ),
                ],
              ),
            );
          }

          final listed = _sumGrouped(grouped);

          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              await _load;
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '共 $count 题',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (listed != count)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '已按知识点展示 $listed 题',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final e = entries[index];
                        final kpName = e.key;
                        final questions = e.value;
                        return _StaggerTile(
                          index: index,
                          child: Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            clipBehavior: Clip.antiAlias,
                            child: Theme(
                              data: theme.copyWith(
                                dividerColor: Colors.transparent,
                              ),
                              child: ExpansionTile(
                                shape: const RoundedRectangleBorder(),
                                collapsedShape: const RoundedRectangleBorder(),
                                title: Text(
                                  kpName,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                trailing: Badge.count(count: questions.length),
                                children: [
                                  for (var qi = 0; qi < questions.length; qi++)
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        8,
                                        0,
                                        8,
                                        8,
                                      ),
                                      child: _QuestionBankTile(
                                        question: questions[qi],
                                        difficultyBarColor: _difficultyBarColor(
                                          questions[qi].difficultyB,
                                        ),
                                        difficultyLabel: _difficultyLabel(
                                          questions[qi].difficultyB,
                                        ),
                                        badgeBackground: _difficultyBadgeColor(
                                          context,
                                          questions[qi].difficultyB,
                                        ),
                                        badgeForeground: _difficultyBadgeForeground(
                                          context,
                                          questions[qi].difficultyB,
                                        ),
                                        onTap: () =>
                                            _openDetail(questions[qi]),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: entries.length,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StaggerTile extends StatefulWidget {
  const _StaggerTile({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_StaggerTile> createState() => _StaggerTileState();
}

class _StaggerTileState extends State<_StaggerTile> {
  var _visible = false;

  @override
  void initState() {
    super.initState();
    final delay = Duration(milliseconds: 28 * widget.index);
    Future<void>(() async {
      await Future<void>.delayed(delay);
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.06),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class _QuestionBankTile extends StatelessWidget {
  const _QuestionBankTile({
    required this.question,
    required this.difficultyBarColor,
    required this.difficultyLabel,
    required this.badgeBackground,
    required this.badgeForeground,
    required this.onTap,
  });

  final Question question;
  final Color difficultyBarColor;
  final String difficultyLabel;
  final Color badgeBackground;
  final Color badgeForeground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final source = question.sourceType?.trim();

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: difficultyBarColor,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(12),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        question.stem,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Chip(
                            label: Text(difficultyLabel),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            backgroundColor: badgeBackground,
                            labelStyle: theme.textTheme.labelMedium?.copyWith(
                              color: badgeForeground,
                              fontWeight: FontWeight.w600,
                            ),
                            side: BorderSide.none,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          if (source != null && source.isNotEmpty)
                            Chip(
                              label: Text(source),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              side: BorderSide(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant,
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
    );
  }
}
