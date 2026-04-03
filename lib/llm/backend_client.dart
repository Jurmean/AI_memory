import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'llm_client.dart';

class BackendClient {
  final String backendUrl;
  final Dio _dio;

  BackendClient({required this.backendUrl})
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 3),
        ));

  String _url(String path) {
    var base = backendUrl.trim();
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    return '$base$path';
  }

  // ── LLM Proxy ──────────────────────────────────

  Future<String> chat(
    List<Map<String, dynamic>> messages, {
    String? systemPrompt,
    int maxRetries = 3,
  }) async {
    Exception? lastError;
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      if (attempt > 0) {
        await Future.delayed(Duration(seconds: 2 * attempt));
      }
      try {
        final resp = await _dio.post(
          _url('/api/llm/chat'),
          data: jsonEncode({
            'messages': messages,
            'system_prompt': systemPrompt,
            'stream': false,
          }),
          options: Options(headers: {'Content-Type': 'application/json'}),
        );
        final data = resp.data is String
            ? jsonDecode(resp.data as String)
            : resp.data;
        return data['content'] as String? ?? '';
      } on DioException catch (e) {
        final code = e.response?.statusCode;
        final retriable = (code != null && code >= 500) ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionTimeout;
        if (retriable && attempt < maxRetries) {
          lastError = e;
          continue;
        }
        rethrow;
      }
    }
    throw lastError ?? Exception('请求失败（已重试）');
  }

  Stream<StreamChunk> chatStream(
    List<Map<String, dynamic>> messages, {
    String? systemPrompt,
  }) async* {
    final resp = await _dio.post<ResponseBody>(
      _url('/api/llm/chat/stream'),
      data: jsonEncode({
        'messages': messages,
        'system_prompt': systemPrompt,
        'stream': true,
      }),
      options: Options(
        headers: {'Content-Type': 'application/json'},
        responseType: ResponseType.stream,
      ),
    );

    final stream = resp.data!.stream.transform(
      StreamTransformer<Uint8List, String>.fromHandlers(
        handleData: (data, sink) => sink.add(utf8.decode(data)),
      ),
    );

    await for (final chunk in stream) {
      for (final line in chunk.split('\n')) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('data: ')) continue;
        final payload = trimmed.substring(6).trim();
        if (payload == '[DONE]') break;

        try {
          final json = jsonDecode(payload) as Map<String, dynamic>;
          final delta = (json['choices'] as List?)?.firstOrNull;
          if (delta == null) continue;
          final deltaMap = delta['delta'] as Map<String, dynamic>? ?? {};
          final content = deltaMap['content'] as String?;
          if (content != null && content.isNotEmpty) {
            yield StreamChunk(content: content);
          }
        } catch (_) {
          continue;
        }
      }
    }
  }

  // ── RAG Query ──────────────────────────────────

  Future<Map<String, dynamic>> ragQuery({
    required String question,
    String? context,
    bool useWebSearch = true,
    bool useLocalKb = true,
    int topK = 5,
  }) async {
    final resp = await _dio.post(
      _url('/api/rag/query'),
      data: jsonEncode({
        'question': question,
        'context': context,
        'use_web_search': useWebSearch,
        'use_local_kb': useLocalKb,
        'top_k': topK,
      }),
      options: Options(headers: {'Content-Type': 'application/json'}),
    );
    final data = resp.data is String ? jsonDecode(resp.data as String) : resp.data;
    return data as Map<String, dynamic>;
  }

  /// Streaming RAG: yields [RagStreamEvent] -- first a sources event, then content deltas.
  Stream<RagStreamEvent> ragQueryStream({
    required String question,
    String? context,
    bool useWebSearch = true,
    bool useLocalKb = true,
    int topK = 5,
  }) async* {
    final resp = await _dio.post<ResponseBody>(
      _url('/api/rag/query/stream'),
      data: jsonEncode({
        'question': question,
        'context': context,
        'use_web_search': useWebSearch,
        'use_local_kb': useLocalKb,
        'top_k': topK,
      }),
      options: Options(
        headers: {'Content-Type': 'application/json'},
        responseType: ResponseType.stream,
      ),
    );

    final stream = resp.data!.stream.transform(
      StreamTransformer<Uint8List, String>.fromHandlers(
        handleData: (data, sink) => sink.add(utf8.decode(data)),
      ),
    );

    String currentEvent = '';
    await for (final chunk in stream) {
      for (final line in chunk.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        if (trimmed.startsWith('event: ')) {
          currentEvent = trimmed.substring(7).trim();
          continue;
        }

        if (trimmed.startsWith('data: ')) {
          final payload = trimmed.substring(6);

          if (currentEvent == 'sources') {
            try {
              final sources = jsonDecode(payload) as List;
              yield RagStreamEvent.sources(
                List<Map<String, dynamic>>.from(
                    sources.map((s) => s as Map<String, dynamic>)),
              );
            } catch (_) {}
          } else if (currentEvent == 'delta') {
            if (payload == '[DONE]') break;
            try {
              final json = jsonDecode(payload) as Map<String, dynamic>;
              final delta = (json['choices'] as List?)?.firstOrNull;
              if (delta == null) continue;
              final deltaMap = delta['delta'] as Map<String, dynamic>? ?? {};
              final content = deltaMap['content'] as String?;
              if (content != null && content.isNotEmpty) {
                yield RagStreamEvent.delta(content);
              }
            } catch (_) {
              continue;
            }
          }
        }
      }
    }
  }

  // ── Documents (知识库管理) ─────────────────────

  Future<Map<String, dynamic>> addDocText({
    required String title,
    required String content,
  }) async {
    final resp = await _dio.post(
      _url('/api/docs/text'),
      data: jsonEncode({'title': title, 'content': content}),
      options: Options(headers: {'Content-Type': 'application/json'}),
    );
    final data = resp.data is String ? jsonDecode(resp.data as String) : resp.data;
    return data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listDocs() async {
    final resp = await _dio.get(_url('/api/docs/list'));
    final data = resp.data is String ? jsonDecode(resp.data as String) : resp.data;
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<void> deleteDoc(String docId) async {
    await _dio.delete(_url('/api/docs/$docId'));
  }

  // ── Health Check ───────────────────────────────

  Future<bool> healthCheck() async {
    try {
      final resp = await _dio.get(
        _url('/api/health'),
        options: Options(receiveTimeout: const Duration(seconds: 5)),
      );
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

enum RagStreamEventType { sources, delta }

class RagStreamEvent {
  final RagStreamEventType type;
  final List<Map<String, dynamic>>? sources;
  final String? content;

  const RagStreamEvent._({required this.type, this.sources, this.content});

  factory RagStreamEvent.sources(List<Map<String, dynamic>> sources) =>
      RagStreamEvent._(type: RagStreamEventType.sources, sources: sources);

  factory RagStreamEvent.delta(String content) =>
      RagStreamEvent._(type: RagStreamEventType.delta, content: content);
}
