import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../providers/chat_provider.dart';
import '../../data/models/chat_message.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  late final AnimationController _cursorController;

  @override
  void initState() {
    super.initState();
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 530),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _cursorController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final chat = ref.watch(chatProvider);
    final notifier = ref.read(chatProvider.notifier);

    final messages = chat.messages;
    final showEmpty = messages.isEmpty && !chat.isStreaming;

    return SafeArea(
      child: Column(
        children: [
          if (chat.error != null)
            Material(
              color: colorScheme.errorContainer,
              child: Dismissible(
                key: ValueKey(chat.error),
                direction: DismissDirection.up,
                onDismissed: (_) => notifier.clearError(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: colorScheme.onErrorContainer,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          chat.error!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: colorScheme.onErrorContainer,
                          size: 20,
                        ),
                        onPressed: notifier.clearError,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: showEmpty
                ? Center(
                    child: Text(
                      '开始和 AI 助手对话吧',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    itemCount:
                        messages.length + (chat.isStreaming ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (chat.isStreaming && index == 0) {
                        return _StreamingAssistantBlock(
                          chat: chat,
                          assistantBg: colorScheme.surfaceContainerHighest,
                          cursorAnimation: _cursorController,
                        );
                      }
                      final msgIndex = chat.isStreaming
                          ? messages.length - index
                          : messages.length - 1 - index;
                      final msg = messages[msgIndex];
                      return _MessageBubble(
                        message: msg,
                        userColor: colorScheme.primary,
                        userOnColor: colorScheme.onPrimary,
                        assistantBg: colorScheme.surfaceContainerHighest,
                      );
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
                    enabled: !chat.isStreaming,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: '输入消息…',
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: colorScheme.outlineVariant,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: colorScheme.outlineVariant
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    onSubmitted: (_) =>
                        _send(notifier, chat.isStreaming),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: chat.isStreaming
                      ? null
                      : () => _send(notifier, chat.isStreaming),
                  icon: const Icon(Icons.send_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    disabledBackgroundColor:
                        colorScheme.surfaceContainerHighest,
                    disabledForegroundColor: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _send(ChatNotifier notifier, bool isStreaming) {
    if (isStreaming) return;
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    notifier.sendMessage(text);
  }
}

class _StreamingAssistantBlock extends StatelessWidget {
  const _StreamingAssistantBlock({
    required this.chat,
    required this.assistantBg,
    required this.cursorAnimation,
  });

  final ChatState chat;
  final Color assistantBg;
  final Animation<double> cursorAnimation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final thinking = chat.thinkingContent;
    final hasThinking =
        thinking != null && thinking.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.88,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasThinking)
                Theme(
                  data: theme.copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding:
                        const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    title: Text(
                      '思考过程',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    children: [
                      SelectableText(
                        thinking,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.85),
                          fontStyle: FontStyle.italic,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: assistantBg,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    bottomLeft: Radius.circular(6),
                    topRight: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: MarkdownBody(
                          data: chat.streamingContent.isEmpty
                              ? '\u200b'
                              : chat.streamingContent,
                          selectable: true,
                          styleSheet: MarkdownStyleSheet(
                            p: theme.textTheme.bodyLarge,
                            code: theme.textTheme.bodyMedium?.copyWith(
                              fontFamily: 'monospace',
                              backgroundColor:
                                  colorScheme.surfaceContainerHigh,
                            ),
                          ),
                        ),
                      ),
                      if (chat.isStreaming)
                        FadeTransition(
                          opacity: cursorAnimation,
                          child: Text(
                            '▌',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.2,
                            ),
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
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.userColor,
    required this.userOnColor,
    required this.assistantBg,
  });

  final ChatMessage message;
  final Color userColor;
  final Color userOnColor;
  final Color assistantBg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isUser = message.role == 'user';
    final timeText = _formatTime(message.timestamp);

    if (isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Align(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.78,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: userColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(6),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Text(
                      message.content,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: userOnColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timeText,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final parsed = _extractThinking(message.content);
    final hasThinking = parsed.thinking.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.88,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasThinking)
                Theme(
                  data: theme.copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding:
                        const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    title: Text('思考过程',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant)),
                    children: [
                      SelectableText(
                        parsed.thinking,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.85),
                          fontStyle: FontStyle.italic,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: assistantBg,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: MarkdownBody(
                    data: parsed.content,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: theme.textTheme.bodyLarge,
                      code: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                        backgroundColor:
                            colorScheme.surfaceContainerHigh,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                timeText,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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

String _formatTime(DateTime t) {
  final h = t.hour.toString().padLeft(2, '0');
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m';
}
