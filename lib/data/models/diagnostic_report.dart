import 'dart:convert';

class DiagnosticReport {
  final int? id;
  final int sessionId;
  final String reportContent;
  final Map<String, dynamic>? reportData;
  final String reportType;
  final DateTime generatedAt;

  const DiagnosticReport({
    this.id, required this.sessionId, required this.reportContent,
    this.reportData, this.reportType = 'session', required this.generatedAt,
  });

  Map<String, dynamic> toDbMap() => {
    if (id != null) 'id': id,
    'session_id': sessionId,
    'report_json': reportData != null ? jsonEncode(reportData) : reportContent,
    'report_type': reportType,
    'generated_at': generatedAt.toIso8601String(),
  };

  factory DiagnosticReport.fromDbMap(Map<String, dynamic> map) {
    final raw = map['report_json'] as String? ?? '';
    Map<String, dynamic>? data;
    String content = raw;
    try {
      data = jsonDecode(raw) as Map<String, dynamic>;
      content = data['content'] as String? ?? raw;
    } catch (_) {
      // plain text report
    }
    return DiagnosticReport(
      id: map['id'] as int?,
      sessionId: map['session_id'] as int? ?? 0,
      reportContent: content,
      reportData: data,
      reportType: map['report_type'] as String? ?? 'session',
      generatedAt: DateTime.parse(map['generated_at'] as String),
    );
  }
}
