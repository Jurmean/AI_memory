import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/knowledge_point.dart';
import '../../data/models/question.dart';
import '../../data/models/review_state.dart';
import '../../data/models/user_profile.dart';
import '../../llm/llm_client.dart';
import '../../llm/prompts/prompt_builder.dart';
import '../../llm/services/question_structure_service.dart';
import '../../providers/database_provider.dart';
import '../../providers/llm_provider.dart';
import '../../providers/user_profile_provider.dart';

class ImportPage extends ConsumerStatefulWidget {
  const ImportPage({super.key});

  @override
  ConsumerState<ImportPage> createState() => _ImportPageState();
}

class _ImportRow {
  _ImportRow({
    required this.question,
    required this.selected,
    required this.kpNames,
  })  : stemCtrl = TextEditingController(text: question.stem),
        optionCtrls = List.generate(
          question.options.length,
          (i) => TextEditingController(text: question.options[i]),
        ),
        correctIndex = question.correctIndex;

  Question question;
  bool selected;
  List<String> kpNames;
  final TextEditingController stemCtrl;
  final List<TextEditingController> optionCtrls;
  int correctIndex;

  void dispose() {
    stemCtrl.dispose();
    for (final c in optionCtrls) {
      c.dispose();
    }
  }

  Question toQuestion() {
    return question.copyWith(
      stem: stemCtrl.text.trim(),
      options: List.generate(
        optionCtrls.length,
        (i) => optionCtrls[i].text.trim(),
      ),
      correctIndex: correctIndex,
    );
  }
}

class _ImportPageState extends ConsumerState<ImportPage> {
  final _rawCtrl = TextEditingController();
  bool _loading = false;
  String? _errorMessage;
  List<_ImportRow> _rows = [];
  List<KnowledgePoint> _structureKps = [];

  @override
  void dispose() {
    _rawCtrl.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _clearRows() {
    for (final r in _rows) {
      r.dispose();
    }
    _rows = [];
    _structureKps = [];
  }

  Future<void> _runStructure() async {
    final raw = _rawCtrl.text.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先粘贴题目原文')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _errorMessage = null;
      _clearRows();
    });

    final profile = ref.read(userProfileProvider).value ?? const UserProfile();
    final profileContext = PromptBuilder.buildQuestionGenContext(profile);
    final custom = ref.read(llmSettingsProvider).customQuestionPrompt;
    final client = ref.read(llmClientProvider);
    final service = QuestionStructureService(client);

    try {
      final result = await service
          .structurizeText(
            raw,
            profileContext: profileContext,
            customPrompt: custom.isEmpty ? null : custom,
          )
          .timeout(
            const Duration(minutes: 3),
            onTimeout: () => throw TimeoutException('LLM 请求超时'),
          );

      if (!mounted) return;
      setState(() {
        _loading = false;
        _structureKps = List.from(result.knowledgePoints);
        _rows = [
          for (var i = 0; i < result.questions.length; i++)
            _ImportRow(
              question: result.questions[i],
              selected: true,
              kpNames: List<String>.from(
                i < result.questionKnowledgePointNames.length
                    ? result.questionKnowledgePointNames[i]
                    : const [],
              ),
            ),
        ];
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage =
            '请求超时，可能是网络较慢或服务繁忙。请稍后重试，或缩短输入文本后再试。';
      });
    } on LLMException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = e.isTimeout
            ? '连接超时，请检查网络后重试。'
            : e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = '结构化失败：$e';
      });
    }
  }

  Future<void> _importSelected() async {
    final selected = _rows.where((r) => r.selected).toList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少勾选一道题')),
      );
      return;
    }

    final db = ref.read(databaseProvider);
    final kpByName = {
      for (final kp in _structureKps) kp.name: kp,
    };

    for (final kp in _structureKps) {
      await db.insertKnowledgePoint(kp);
    }

    for (final row in selected) {
      final q = row.toQuestion();
      await db.insertQuestion(q);
      await db.upsertReviewState(
        ReviewState(questionId: q.id, nextReviewDate: DateTime.now()),
      );
      for (final name in row.kpNames) {
        final kp = kpByName[name];
        if (kp != null) {
          await db.linkQuestionToKP(q.id, kp.id);
        }
      }
    }

    if (!mounted) return;
    final n = selected.length;
    Navigator.of(context).pop(n);
  }

  void _removeRow(int index) {
    setState(() {
      final r = _rows.removeAt(index);
      r.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final showResults = _rows.isNotEmpty && !_loading;

    Widget body;
    if (_loading) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              '正在AI结构化…',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      );
    } else if (showResults) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '步骤 2：核对并勾选要导入的题目',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colorScheme.primary,
                  ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              itemCount: _rows.length,
              itemBuilder: (context, index) {
                final row = _rows[index];
                const labels = 'ABCD';
                final optCount = row.optionCtrls.length;
                final safeCorrect = optCount > 0
                    ? row.correctIndex.clamp(0, optCount - 1)
                    : 0;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: row.selected,
                              onChanged: (v) {
                                setState(() => row.selected = v ?? false);
                              },
                            ),
                            Expanded(
                              child: Text(
                                '题目 ${index + 1}',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            IconButton(
                              tooltip: '从列表移除',
                              onPressed: () => _removeRow(index),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                        TextField(
                          controller: row.stemCtrl,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: '题干',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (var i = 0; i < row.optionCtrls.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: TextField(
                              controller: row.optionCtrls[i],
                              decoration: InputDecoration(
                                labelText: i < labels.length
                                    ? '选项 ${labels[i]}'
                                    : '选项 ${i + 1}',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                        if (optCount > 0) ...[
                          const SizedBox(height: 4),
                          DropdownButtonFormField<int>(
                            key: ValueKey(
                              '${row.question.id}_${safeCorrect}_$optCount',
                            ),
                            initialValue: safeCorrect,
                            decoration: const InputDecoration(
                              labelText: '正确答案',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (var i = 0; i < optCount; i++)
                                DropdownMenuItem(
                                  value: i,
                                  child: Text(
                                    i < labels.length
                                        ? '选项 ${labels[i]}'
                                        : '选项 ${i + 1}',
                                  ),
                                ),
                            ],
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => row.correctIndex = v);
                              }
                            },
                          ),
                        ],
                        if (row.kpNames.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            '知识点：${row.kpNames.join('、')}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    } else {
      body = SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '步骤 1：粘贴原文',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _rawCtrl,
              maxLines: 8,
              minLines: 6,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '将题目、选项等原始文本粘贴到此处…',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _runStructure,
              icon: const Icon(Icons.auto_fix_high_outlined),
              label: const Text('开始结构化'),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Card(
                color: colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: colorScheme.onErrorContainer),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: _runStructure,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 导入题目'),
      ),
      body: body,
      bottomNavigationBar: showResults
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: _importSelected,
                  child: const Text('导入选中'),
                ),
              ),
            )
          : null,
    );
  }
}
