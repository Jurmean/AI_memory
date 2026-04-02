import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/answer_log.dart';
import '../../data/models/question.dart';
import '../../llm/llm_client.dart';
import '../../providers/llm_provider.dart';

class GuidanceChatPage extends ConsumerStatefulWidget {
  const GuidanceChatPage({
    super.key,
    required this.question,
    required this.answerLog,
  });

  final Question question;
  final AnswerLog answerLog;

  @override
  ConsumerState<GuidanceChatPage> createState() => _GuidanceChatPageState();
}

class _GuidanceChatPageState extends ConsumerState<GuidanceChatPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  late final AnimationController _cursorController;

  final List<_GuidanceMsg> _messages = [];
  bool _isStreaming = false;
  String _streamingContent = '';
  String? _thinkingContent;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 530),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sendInitialMessage());
  }

  @override
  void dispose() {
    _cursorController.dispose();
    _textController.dispose();
    super.dispose();
  }

  String _buildInitialPrompt() {
    final q = widget.question;
    final log = widget.answerLog;
    final correct = log.isCorrect ? '回答正确' : '回答错误';
    final selected = log.selectedOptionIndex < q.options.length
        ? q.options[log.selectedOptionIndex]
        : '未知';
    final correctAnswer = q.correctIndex < q.options.length
        ? q.options[q.correctIndex]
        : '未知';

    return '我刚做了一道题，请帮我分析：\n\n'
        '**题目**：${q.stem}\n'
        '**选项**：${q.options.asMap().entries.map((e) => '${String.fromCharCode(65 + e.key)}. ${e.value}').join('  ')}\n'
        '**我的选择**：$selected（$correct）\n'
        '**正确答案**：$correctAnswer\n'
        '${q.explanation != null ? '**解析**：${q.explanation}\n' : ''}'
        '\n请详细讲解这道题的知识点和解题思路。';
  }

  Future<void> _sendInitialMessage() async {
    final prompt = _buildInitialPrompt();
    _messages.add(_GuidanceMsg(role: 'user', content: prompt));
    setState(() {});
    await _streamResponse([
      {'role': 'user', 'content': prompt},
    ]);
  }

  Future<void> _sendUserMessage(String text) async {
    if (text.trim().isEmpty || _isStreaming) return;
    _textController.clear();
    _messages.add(_GuidanceMsg(role: 'user', content: text.trim()));
    setState(() => _error = null);

    final history = _messages
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();
    await _streamResponse(history);
  }

  Future<void> _streamResponse(List<Map<String, dynamic>> messages) async {
    setState(() {
      _isStreaming = true;
      _streamingContent = '';
      _thinkingContent = null;
    });

    final contentBuf = StringBuffer();
    final thinkBuf = StringBuffer();
    final backend = ref.read(backendClientProvider);

    try {
      if (backend != null) {
        final lastMsg = messages.last['content'] as String? ?? '';
        final result = await backend.ragQuery(
          question: lastMsg,
          context: '学习辅导场景',
        );
        final raw = (result['answer'] ?? '') as String;
        final parsed = _extractThinking(raw);
        contentBuf.write(parsed.content);
        if (parsed.thinking.isNotEmpty) {
          thinkBuf.write(parsed.thinking);
          setState(() => _thinkingContent = thinkBuf.toString());
        }
        setState(() => _streamingContent = contentBuf.toString());
      } else {
        final client = ref.read(llmClientProvider);
        await for (final chunk in client.chatStream(
          messages,
          systemPrompt: '你是一位耐心的学习辅导老师。请用简明清晰的方式讲解题目，帮助学生理解知识点。',
        )) {
          if (chunk.content.isNotEmpty) {
            contentBuf.write(chunk.content);
            setState(() => _streamingContent = contentBuf.toString());
          }
          if (chunk.thinkingContent != null) {
            thinkBuf.write(chunk.thinkingContent);
            setState(() => _thinkingContent = thinkBuf.toString());
          }
        }
      }

      _messages.add(_GuidanceMsg(
        role: 'assistant',
        content: contentBuf.toString(),
      ));
      setState(() {
        _isStreaming = false;
        _streamingContent = '';
      });
    } catch (e) {
      setState(() {
        _isStreaming = false;
        _error = e is LLMException ? e.message : '请求失败：$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('AI 伴学')),
      body: Column(
        children: [
          if (_error != null)
            Material(
              color: cs.errorContainer,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: cs.onErrorContainer, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_error!,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: cs.onErrorContainer)),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: cs.onErrorContainer, size: 20),
                      onPressed: () => setState(() => _error = null),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: _messages.isEmpty && !_isStreaming
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    itemCount: _messages.length + (_isStreaming ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_isStreaming && index == 0) {
                        return _buildStreamingBubble(theme, cs);
                      }
                      final msgIndex = _isStreaming
                          ? _messages.length - index
                          : _messages.length - 1 - index;
                      final msg = _messages[msgIndex];
                      return _buildBubble(msg, theme, cs);
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    enabled: !_isStreaming,
                    minLines: 1,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: '继续提问…',
                      filled: true,
                      fillColor: cs.surfaceContainerHighest,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: cs.outlineVariant),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: cs.primary, width: 2),
                      ),
                    ),
                    onSubmitted: (t) => _sendUserMessage(t),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _isStreaming
                      ? null
                      : () => _sendUserMessage(_textController.text),
                  icon: const Icon(Icons.send_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    disabledBackgroundColor: cs.surfaceContainerHighest,
                    disabledForegroundColor: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamingBubble(ThemeData theme, ColorScheme cs) {
    final hasThinking =
        _thinkingContent != null && _thinkingContent!.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.88),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasThinking)
                Theme(
                  data: theme.copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    title: Text('思考过程',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(color: cs.onSurfaceVariant)),
                    children: [
                      SelectableText(_thinkingContent!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant.withValues(alpha: 0.85),
                            fontStyle: FontStyle.italic,
                            height: 1.4,
                          )),
                    ],
                  ),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    bottomLeft: Radius.circular(6),
                    topRight: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: MarkdownBody(
                          data: _streamingContent.isEmpty
                              ? '\u200b'
                              : _streamingContent,
                          selectable: true,
                        ),
                      ),
                      FadeTransition(
                        opacity: _cursorController,
                        child: Text('▌',
                            style: theme.textTheme.bodyLarge
                                ?.copyWith(color: cs.onSurfaceVariant, height: 1.2)),
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

  Widget _buildBubble(_GuidanceMsg msg, ThemeData theme, ColorScheme cs) {
    final isUser = msg.role == 'user';
    if (isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Align(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(6),
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Text(msg.content,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(color: cs.onPrimary)),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.88),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
              ),
            ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: MarkdownBody(data: msg.content, selectable: true),
            ),
          ),
        ),
      ),
    );
  }
}

class _GuidanceMsg {
  final String role;
  final String content;
  const _GuidanceMsg({required this.role, required this.content});
}

class _ThinkParsed {
  final String thinking;
  final String content;
  const _ThinkParsed({required this.thinking, required this.content});
}

_ThinkParsed _extractThinking(String text) {
  final re = RegExp(r'<think>([\s\S]*?)</think>', multiLine: true);
  final match = re.firstMatch(text);
  if (match == null) return _ThinkParsed(thinking: '', content: text.trim());
  final thinking = match.group(1)?.trim() ?? '';
  final content = text.replaceFirst(re, '').trim();
  return _ThinkParsed(thinking: thinking, content: content);
}
