import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../shared/constants.dart';

class LLMException implements Exception {
  final String message;
  final int? statusCode;
  final bool isTimeout;
  const LLMException(this.message, {this.statusCode, this.isTimeout = false});
  @override
  String toString() => 'LLMException($statusCode): $message';
}

class StreamChunk {
  final String content;
  final String? thinkingContent;
  const StreamChunk({this.content = '', this.thinkingContent});
}

class LLMClient {
  final String baseUrl;
  final String model;
  final String apiKey;
  final Dio _dio;

  LLMClient({
    String? baseUrl,
    String? model,
    String? apiKey,
  })  : baseUrl = _normalizeUrl(baseUrl ?? AppConstants.defaultBaseUrl),
        model = model ?? AppConstants.defaultModel,
        apiKey = apiKey ?? AppConstants.defaultApiKey,
        _dio = Dio(BaseOptions(
          connectTimeout: const Duration(milliseconds: AppConstants.llmConnectTimeoutMs),
          receiveTimeout: const Duration(milliseconds: AppConstants.llmReceiveTimeoutMs),
        ));

  bool get isConfigured => apiKey.isNotEmpty;

  static String _normalizeUrl(String url) {
    url = url.trim();
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    if (url.endsWith('/v1') || url.endsWith('/v1/chat')) {
      if (!url.endsWith('/chat/completions')) {
        if (url.endsWith('/v1')) url += '/chat/completions';
        if (url.endsWith('/v1/chat')) url += '/completions';
      }
    }
    return url;
  }

  Map<String, String> _buildHeaders() => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      };

  ({List<Map<String, dynamic>> messages, String? systemPrompt})
      _separateSystemMessages(
          List<Map<String, dynamic>> messages, String? systemPrompt) {
    final systemParts = <String>[];
    final filtered = <Map<String, dynamic>>[];

    for (final msg in messages) {
      if (msg['role'] == 'system') {
        systemParts.add(msg['content'] as String);
      } else {
        filtered.add(msg);
      }
    }

    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      systemParts.insert(0, systemPrompt);
    }

    final combined = systemParts.isNotEmpty ? systemParts.join('\n\n') : null;
    return (messages: filtered, systemPrompt: combined);
  }

  Future<String> chat(List<Map<String, dynamic>> messages,
      {String? systemPrompt, int maxRetries = 3}) async {
    final separated = _separateSystemMessages(messages, systemPrompt);
    final body = <String, dynamic>{
      'model': model,
      'messages': [
        if (separated.systemPrompt != null)
          {'role': 'system', 'content': separated.systemPrompt},
        ...separated.messages,
      ],
      'stream': false,
    };

    LLMException? lastError;
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      if (attempt > 0) {
        await Future.delayed(Duration(seconds: 2 * attempt));
      }
      try {
        final response = await _dio.post(
          baseUrl,
          data: jsonEncode(body),
          options: Options(headers: _buildHeaders()),
        );
        final data = response.data is String
            ? jsonDecode(response.data as String)
            : response.data;
        final content = _extractContent(data);
        return _stripThinkingTags(content);
      } on DioException catch (e) {
        final code = e.response?.statusCode;
        final retriable = (code != null && code >= 500) ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionTimeout;
        if (retriable && attempt < maxRetries) {
          lastError = LLMException(
            e.response?.data?.toString() ?? e.message ?? '网络请求失败',
            statusCode: code,
          );
          continue;
        }
        _handleDioError(e);
      }
    }
    throw lastError ?? const LLMException('请求失败（已重试）');
  }

  Stream<StreamChunk> chatStream(List<Map<String, dynamic>> messages,
      {String? systemPrompt}) async* {
    final separated = _separateSystemMessages(messages, systemPrompt);
    final body = <String, dynamic>{
      'model': model,
      'messages': [
        if (separated.systemPrompt != null)
          {'role': 'system', 'content': separated.systemPrompt},
        ...separated.messages,
      ],
      'stream': true,
    };

    try {
      final response = await _dio.post<ResponseBody>(
        baseUrl,
        data: jsonEncode(body),
        options: Options(
          headers: _buildHeaders(),
          responseType: ResponseType.stream,
        ),
      );

      final stream = response.data!.stream;
      final buffer = StringBuffer();
      var insideThink = false;
      final thinkBuffer = StringBuffer();

      final transformed = stream.transform(
        StreamTransformer<Uint8List, String>.fromHandlers(
          handleData: (data, sink) => sink.add(utf8.decode(data)),
        ),
      );
      await for (final chunk in transformed) {
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

            // DeepSeek reasoning_content
            final reasoning = deltaMap['reasoning_content'] as String?;
            if (reasoning != null && reasoning.isNotEmpty) {
              thinkBuffer.write(reasoning);
              yield StreamChunk(thinkingContent: reasoning);
              continue;
            }

            final content = deltaMap['content'] as String?;
            if (content == null || content.isEmpty) continue;

            // Parse <think> tags in content
            var remaining = content;
            while (remaining.isNotEmpty) {
              if (insideThink) {
                final endIdx = remaining.indexOf('</think>');
                if (endIdx == -1) {
                  thinkBuffer.write(remaining);
                  yield StreamChunk(thinkingContent: remaining);
                  remaining = '';
                } else {
                  final part = remaining.substring(0, endIdx);
                  if (part.isNotEmpty) {
                    thinkBuffer.write(part);
                    yield StreamChunk(thinkingContent: part);
                  }
                  insideThink = false;
                  remaining = remaining.substring(endIdx + 8);
                }
              } else {
                final startIdx = remaining.indexOf('<think>');
                if (startIdx == -1) {
                  buffer.write(remaining);
                  yield StreamChunk(content: remaining);
                  remaining = '';
                } else {
                  if (startIdx > 0) {
                    final part = remaining.substring(0, startIdx);
                    buffer.write(part);
                    yield StreamChunk(content: part);
                  }
                  insideThink = true;
                  remaining = remaining.substring(startIdx + 7);
                }
              }
            }
          } catch (_) {
            continue;
          }
        }
      }
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  String _extractContent(dynamic data) {
    try {
      final choices = data['choices'] as List;
      final message = choices.first['message'] as Map<String, dynamic>;
      return message['content'] as String? ?? '';
    } catch (_) {
      return data.toString();
    }
  }

  String _stripThinkingTags(String text) {
    return text.replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '').trim();
  }

  Never _handleDioError(DioException e) {
    final isTimeout = e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout;
    final statusCode = e.response?.statusCode;
    final msg = isTimeout
        ? '请求超时，请检查网络或缩短输入内容'
        : e.response?.data?.toString() ?? e.message ?? '网络请求失败';
    throw LLMException(msg, statusCode: statusCode, isTimeout: isTimeout);
  }
}
