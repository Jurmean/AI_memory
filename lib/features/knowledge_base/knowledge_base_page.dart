import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/llm_provider.dart';

class KnowledgeBasePage extends ConsumerStatefulWidget {
  const KnowledgeBasePage({super.key});

  @override
  ConsumerState<KnowledgeBasePage> createState() => _KnowledgeBasePageState();
}

class _KnowledgeBasePageState extends ConsumerState<KnowledgeBasePage> {
  List<Map<String, dynamic>> _docs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDocs());
  }

  Future<void> _loadDocs() async {
    final backend = ref.read(backendClientProvider);
    if (backend == null) {
      setState(() {
        _loading = false;
        _error = '请先在设置中配置后端 URL';
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final docs = await backend.listDocs();
      setState(() {
        _docs = docs;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = '加载失败：$e';
      });
    }
  }

  Future<void> _addText() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => _AddTextDialog(),
    );
    if (result == null) return;

    final backend = ref.read(backendClientProvider);
    if (backend == null) return;

    try {
      final resp = await backend.addDocText(
        title: result['title'] ?? '',
        content: result['content'] ?? '',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已添加，切分为 ${resp['chunk_count']} 个片段'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadDocs();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('添加失败：$e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _deleteDocs(String docId) async {
    final backend = ref.read(backendClientProvider);
    if (backend == null) return;
    try {
      await backend.deleteDoc(docId);
      _loadDocs();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除失败：$e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('本地知识库')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addText,
        icon: const Icon(Icons.add),
        label: const Text('添加文本'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_off, size: 48, color: cs.onSurfaceVariant),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge),
                      ],
                    ),
                  ),
                )
              : _docs.isEmpty
                  ? Center(
                      child: Text('还没有任何知识库文档\n点击右下角添加',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: cs.onSurfaceVariant,
                          )),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadDocs,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _docs.length,
                        itemBuilder: (context, i) {
                          final doc = _docs[i];
                          return Card(
                            child: ListTile(
                              leading: Icon(Icons.article, color: cs.primary),
                              title: Text(doc['title'] ?? 'untitled'),
                              subtitle: Text('${doc['chunk_count'] ?? 0} 个片段'),
                              trailing: IconButton(
                                icon: Icon(Icons.delete_outline,
                                    color: cs.error),
                                onPressed: () => _deleteDocs(
                                    doc['doc_id']?.toString() ?? ''),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _AddTextDialog extends StatefulWidget {
  @override
  State<_AddTextDialog> createState() => _AddTextDialogState();
}

class _AddTextDialogState extends State<_AddTextDialog> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加文本到知识库'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '标题',
                hintText: '如：高中化学笔记',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentController,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: '内容',
                hintText: '粘贴学习笔记、知识点整理、文档内容…',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            if (_contentController.text.trim().isEmpty) return;
            Navigator.pop(context, {
              'title': _titleController.text.trim(),
              'content': _contentController.text.trim(),
            });
          },
          child: const Text('添加'),
        ),
      ],
    );
  }
}
