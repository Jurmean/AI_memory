import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/chat_message.dart';
import '../llm/llm_client.dart';
import '../llm/services/chat_service.dart';
import '../llm/prompts/prompt_builder.dart';
import 'database_provider.dart';
import 'llm_provider.dart';
import 'user_profile_provider.dart';

class ChatState {
  final List<ChatMessage> messages;
  final bool isStreaming;
  final String streamingContent;
  final String? thinkingContent;
  final String? error;

  const ChatState({
    this.messages = const [],
    this.isStreaming = false,
    this.streamingContent = '',
    this.thinkingContent,
    this.error,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isStreaming,
    String? streamingContent,
    String? thinkingContent,
    String? error,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        isStreaming: isStreaming ?? this.isStreaming,
        streamingContent: streamingContent ?? this.streamingContent,
        thinkingContent: thinkingContent ?? this.thinkingContent,
        error: error,
      );
}

class ChatNotifier extends Notifier<ChatState> {
  ChatService? _service;

  @override
  ChatState build() {
    _loadHistory();
    return const ChatState();
  }

  Future<void> _loadHistory() async {
    final db = ref.read(databaseProvider);
    final chatOnly = await db.getChatHistory(sessionType: 'chat');
    state = state.copyWith(messages: chatOnly);

    _initService();
    _service!.loadHistory(chatOnly.map((m) => m.toApiMessage()).toList());
  }

  void _initService() {
    final client = ref.read(llmClientProvider);
    final settings = ref.read(llmSettingsProvider);
    _service = ChatService(client,
        customSystemPrompt: settings.customSystemPrompt);
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || state.isStreaming) return;

    final db = ref.read(databaseProvider);
    final profileAsync = ref.read(userProfileProvider);
    final profile = profileAsync.value;

    _initService();

    if (profile != null) {
      final weakPoints = await db.getWeakKnowledgePoints();
      final recentReports = await db.getRecentReports(limit: 3);
      final sp = PromptBuilder.buildChatSystemPrompt(
        profile,
        ref.read(llmSettingsProvider).customSystemPrompt.isEmpty
            ? null
            : ref.read(llmSettingsProvider).customSystemPrompt,
        weakPoints: weakPoints,
        recentReports: recentReports,
      );
      _service!.customSystemPrompt = sp;
    }

    final userMsg = ChatMessage(
      role: 'user',
      content: text,
      sessionType: 'chat',
      timestamp: DateTime.now(),
    );
    await db.insertChatMessage(userMsg);

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isStreaming: true,
      streamingContent: '',
      thinkingContent: null,
      error: null,
    );

    final contentBuf = StringBuffer();
    final thinkBuf = StringBuffer();
    final backend = ref.read(backendClientProvider);

    try {
      if (backend != null) {
        final result = await backend.ragQuery(question: text);
        final raw = (result['answer'] ?? '') as String;
        final parsed = _extractThinking(raw);
        contentBuf.write(parsed.content);
        if (parsed.thinking.isNotEmpty) {
          thinkBuf.write(parsed.thinking);
          state = state.copyWith(thinkingContent: thinkBuf.toString());
        }

        final sources = result['sources'] as List?;
        if (sources != null && sources.isNotEmpty) {
          contentBuf.write('\n\n---\n**参考来源：**\n');
          for (final src in sources) {
            final s = src as Map<String, dynamic>;
            final title = s['title'] ?? '';
            final url = s['url'];
            final type = s['source_type'] == 'local' ? '📚 本地' : '🌐 网络';
            if (url != null && url.toString().isNotEmpty) {
              contentBuf.write('- $type [$title]($url)\n');
            } else {
              contentBuf.write('- $type $title\n');
            }
          }
        }
        state = state.copyWith(streamingContent: contentBuf.toString());
      } else {
        // No backend → direct LLM streaming
        await for (final chunk in _service!.sendMessageStream(text)) {
          if (chunk.content.isNotEmpty) {
            contentBuf.write(chunk.content);
            state = state.copyWith(streamingContent: contentBuf.toString());
          }
          if (chunk.thinkingContent != null) {
            thinkBuf.write(chunk.thinkingContent);
            state = state.copyWith(thinkingContent: thinkBuf.toString());
          }
        }
      }

      final assistantMsg = ChatMessage(
        role: 'assistant',
        content: contentBuf.toString(),
        sessionType: 'chat',
        timestamp: DateTime.now(),
      );
      await db.insertChatMessage(assistantMsg);

      state = state.copyWith(
        messages: [...state.messages, assistantMsg],
        isStreaming: false,
        streamingContent: '',
      );
    } catch (e) {
      state = state.copyWith(
        isStreaming: false,
        error: e is LLMException ? e.message : '发送失败：$e',
      );
    }
  }

  void clearError() => state = state.copyWith(error: null);
}

final chatProvider =
    NotifierProvider<ChatNotifier, ChatState>(ChatNotifier.new);

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
