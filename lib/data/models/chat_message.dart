class ChatMessage {
  final int? id;
  final String role;
  final String content;
  final String? contextRef;
  final String sessionType;
  final DateTime timestamp;

  const ChatMessage({
    this.id, required this.role, required this.content,
    this.contextRef, this.sessionType = 'chat', required this.timestamp,
  });

  Map<String, dynamic> toDbMap() => {
    if (id != null) 'id': id,
    'role': role, 'content': content, 'context_ref': contextRef,
    'session_type': sessionType, 'timestamp': timestamp.toIso8601String(),
  };

  factory ChatMessage.fromDbMap(Map<String, dynamic> map) => ChatMessage(
    id: map['id'] as int?,
    role: map['role'] as String,
    content: map['content'] as String,
    contextRef: map['context_ref'] as String?,
    sessionType: map['session_type'] as String? ?? 'chat',
    timestamp: DateTime.parse(map['timestamp'] as String),
  );

  Map<String, dynamic> toApiMessage() => {'role': role, 'content': content};
}
