import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/knowledge_point.dart';
import '../../data/models/question.dart';
import '../../data/models/review_state.dart';
import '../../providers/database_provider.dart';

class ManualAddPage extends ConsumerStatefulWidget {
  const ManualAddPage({super.key});

  @override
  ConsumerState<ManualAddPage> createState() => _ManualAddPageState();
}

class _ManualAddPageState extends ConsumerState<ManualAddPage> {
  final _formKey = GlobalKey<FormState>();
  final _stemCtrl = TextEditingController();
  final _optA = TextEditingController();
  final _optB = TextEditingController();
  final _optC = TextEditingController();
  final _optD = TextEditingController();
  final _explanationCtrl = TextEditingController();
  final _kpCtrl = TextEditingController();
  static const _uuid = Uuid();

  int _correctIndex = 0;
  double _difficulty = 0.0;

  @override
  void dispose() {
    _stemCtrl.dispose();
    _optA.dispose();
    _optB.dispose();
    _optC.dispose();
    _optD.dispose();
    _explanationCtrl.dispose();
    _kpCtrl.dispose();
    super.dispose();
  }

  String? _required(String? v, String label) {
    if (v == null || v.trim().isEmpty) {
      return '请填写$label';
    }
    return null;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final stem = _stemCtrl.text.trim();
    final options = [
      _optA.text.trim(),
      _optB.text.trim(),
      _optC.text.trim(),
      _optD.text.trim(),
    ];
    final explanation = _explanationCtrl.text.trim();
    final kpRaw = _kpCtrl.text.trim();
    final kpNames = kpRaw.isEmpty
        ? <String>[]
        : kpRaw
            .split(RegExp(r'[,，]'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();

    final q = Question(
      id: _uuid.v4(),
      stem: stem,
      options: options,
      correctIndex: _correctIndex,
      explanation: explanation.isEmpty ? null : explanation,
      difficultyB: _difficulty,
      sourceType: 'manual',
      createdAt: DateTime.now(),
    );

    final db = ref.read(databaseProvider);
    await db.insertQuestion(q);
    await db.upsertReviewState(
      ReviewState(questionId: q.id, nextReviewDate: DateTime.now()),
    );

    for (final name in kpNames) {
      final kp = KnowledgePoint(id: _uuid.v4(), name: name);
      await db.insertKnowledgePoint(kp);
      await db.linkQuestionToKP(q.id, kp.id);
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('手动添加题目'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _stemCtrl,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: '题干',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (v) => _required(v, '题干'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _optA,
                decoration: const InputDecoration(
                  labelText: '选项 A',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => _required(v, '选项 A'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _optB,
                decoration: const InputDecoration(
                  labelText: '选项 B',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => _required(v, '选项 B'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _optC,
                decoration: const InputDecoration(
                  labelText: '选项 C',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => _required(v, '选项 C'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _optD,
                decoration: const InputDecoration(
                  labelText: '选项 D',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => _required(v, '选项 D'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                key: ValueKey(_correctIndex),
                initialValue: _correctIndex,
                decoration: const InputDecoration(
                  labelText: '正确答案',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('A')),
                  DropdownMenuItem(value: 1, child: Text('B')),
                  DropdownMenuItem(value: 2, child: Text('C')),
                  DropdownMenuItem(value: 3, child: Text('D')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _correctIndex = v);
                  }
                },
              ),
              const SizedBox(height: 20),
              Text(
                '难度（IRT b） ${_difficulty.toStringAsFixed(1)}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Slider(
                value: _difficulty,
                min: -2.0,
                max: 2.0,
                divisions: 40,
                label: _difficulty.toStringAsFixed(1),
                onChanged: (v) => setState(() => _difficulty = v),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _explanationCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '解析（选填）',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _kpCtrl,
                decoration: const InputDecoration(
                  labelText: '知识点（逗号分隔，选填）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _save,
                child: const Text('保存'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
