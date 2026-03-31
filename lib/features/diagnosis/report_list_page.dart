import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/diagnostic_report.dart';
import '../../providers/diagnosis_provider.dart';
import 'report_detail_page.dart';

class ReportListPage extends ConsumerWidget {
  const ReportListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diagnosisState = ref.watch(diagnosisProvider);

    ref.listen<DiagnosisState>(diagnosisProvider, (previous, next) {
      final err = next.error;
      if (err != null && err != previous?.error) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err)),
          );
        });
      }
    });

    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              tabs: const [
                Tab(text: '答题组报告'),
                Tab(text: '总报告'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _SessionReportsTab(
                  reports: diagnosisState.sessionReports,
                ),
                _OverallReportsTab(
                  reports: diagnosisState.overallReports,
                  isGenerating: diagnosisState.isGenerating,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionReportsTab extends StatelessWidget {
  const _SessionReportsTab({required this.reports});

  final List<DiagnosticReport> reports;

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return Center(
        child: Text(
          '暂无答题组报告',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: reports.length,
      itemBuilder: (context, index) =>
          _ReportCard(report: reports[index]),
    );
  }
}

class _OverallReportsTab extends ConsumerWidget {
  const _OverallReportsTab({
    required this.reports,
    required this.isGenerating,
  });

  final List<DiagnosticReport> reports;
  final bool isGenerating;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: FilledButton.tonal(
            onPressed: isGenerating
                ? null
                : () => ref
                    .read(diagnosisProvider.notifier)
                    .generateOverallReport(),
            child: const Text('生成总报告'),
          ),
        ),
        if (isGenerating)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Center(child: CircularProgressIndicator()),
          ),
        Expanded(
          child: reports.isEmpty
              ? Center(
                  child: Text(
                    '暂无总报告',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: reports.length,
                  itemBuilder: (context, index) =>
                      _ReportCard(report: reports[index]),
                ),
        ),
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});

  final DiagnosticReport report;

  String _typeLabel(String type) {
    switch (type) {
      case 'overall':
        return '总报告';
      case 'session':
      default:
        return '答题组';
    }
  }

  String? _abilityLevel() {
    final data = report.reportData;
    if (data == null) return null;
    final v = data['abilityLevel'];
    return v?.toString();
  }

  String _preview(String content) {
    final plain = content
        .replaceAll(RegExp(r'```[\s\S]*?```'), '')
        .replaceAll(RegExp(r'#{1,6}\s*'), '')
        .replaceAll(RegExp(r'\*{1,3}([^*]+)\*{1,3}'), r'$1')
        .replaceAll(RegExp(r'`([^`]+)`'), r'$1')
        .replaceAll(RegExp(r'^>\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^[-*+]\s+', multiLine: true), '')
        .replaceAll(RegExp(r'^\d+\.\s+', multiLine: true), '')
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1')
        .replaceAll(RegExp(r'\n{2,}'), '\n')
        .trim();
    if (plain.length <= 120) return plain;
    return '${plain.substring(0, 120)}…';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dateStr =
        '${report.generatedAt.year}-${report.generatedAt.month.toString().padLeft(2, '0')}-${report.generatedAt.day.toString().padLeft(2, '0')} '
        '${report.generatedAt.hour.toString().padLeft(2, '0')}:${report.generatedAt.minute.toString().padLeft(2, '0')}';
    final ability = _abilityLevel();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ReportDetailPage(report: report),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Chip(
                    label: Text(_typeLabel(report.reportType)),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                    labelPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  ),
                  Text(
                    dateStr,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
              if (ability != null && ability.isNotEmpty) ...[
                const SizedBox(height: 8),
                Chip(
                  label: Text('能力：$ability'),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
              const SizedBox(height: 8),
              Text(
                _preview(report.reportContent),
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
