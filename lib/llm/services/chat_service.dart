import '../llm_client.dart';

class ChatService {
  final LLMClient client;
  final List<Map<String, dynamic>> _history = [];
  String? _customSystemPrompt;

  ChatService(this.client, {String? customSystemPrompt})
      : _customSystemPrompt = customSystemPrompt;

  set customSystemPrompt(String? value) => _customSystemPrompt = value;

  void loadHistory(List<Map<String, dynamic>> messages) {
    _history.clear();
    _history.addAll(messages);
  }

  Stream<StreamChunk> sendMessageStream(String message,
      {String? questionContext}) async* {
    if (questionContext != null && _history.isEmpty) {
      _history.add({'role': 'system', 'content': questionContext});
    }
    _history.add({'role': 'user', 'content': message});

    final hasSystemMsg = _history.any((m) => m['role'] == 'system');
    final sysPrompt = hasSystemMsg ? null : _customSystemPrompt;

    final buffer = StringBuffer();
    await for (final chunk
        in client.chatStream(_history, systemPrompt: sysPrompt)) {
      yield chunk;
      if (chunk.content.isNotEmpty) buffer.write(chunk.content);
    }

    _history.add({'role': 'assistant', 'content': buffer.toString()});
  }

  void clearHistory() => _history.clear();

  List<Map<String, dynamic>> get history => List.unmodifiable(_history);
}
