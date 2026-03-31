import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/database_provider.dart';
import '../../providers/llm_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../shared/constants.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final TextEditingController _baseUrlController;
  late final TextEditingController _modelController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _systemPromptController;
  late final TextEditingController _questionPromptController;
  late final TextEditingController _diagnosisPromptController;

  late final FocusNode _baseUrlFocus;
  late final FocusNode _modelFocus;
  late final FocusNode _apiKeyFocus;

  Timer? _debounceSystem;
  Timer? _debounceQuestion;
  Timer? _debounceDiagnosis;

  String _apiKeyPlaceholder() {
    final k = AppConstants.defaultApiKey;
    if (k.length <= 16) {
      return 'API Key';
    }
    return '${k.substring(0, 10)}…${k.substring(k.length - 4)}';
  }

  void _applyLlmToControllers(LLMSettings s) {
    if (_baseUrlController.text != s.baseUrl) {
      _baseUrlController.text = s.baseUrl;
    }
    if (_modelController.text != s.model) {
      _modelController.text = s.model;
    }
    if (_apiKeyController.text != s.apiKey) {
      _apiKeyController.text = s.apiKey;
    }
    if (_systemPromptController.text != s.customSystemPrompt) {
      _systemPromptController.text = s.customSystemPrompt;
    }
    if (_questionPromptController.text != s.customQuestionPrompt) {
      _questionPromptController.text = s.customQuestionPrompt;
    }
    if (_diagnosisPromptController.text != s.customDiagnosisPrompt) {
      _diagnosisPromptController.text = s.customDiagnosisPrompt;
    }
  }

  void _schedulePromptSave(
    Timer? Function() getter,
    void Function(Timer? v) setter,
    void Function() save,
  ) {
    getter()?.cancel();
    setter(
      Timer(const Duration(milliseconds: 450), () {
        if (!mounted) return;
        save();
      }),
    );
  }

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController();
    _modelController = TextEditingController();
    _apiKeyController = TextEditingController();
    _systemPromptController = TextEditingController();
    _questionPromptController = TextEditingController();
    _diagnosisPromptController = TextEditingController();

    _baseUrlFocus = FocusNode();
    _modelFocus = FocusNode();
    _apiKeyFocus = FocusNode();

    void attachUrlSave(FocusNode n, VoidCallback save) {
      n.addListener(() {
        if (!n.hasFocus) save();
      });
    }

    attachUrlSave(_baseUrlFocus, () {
      ref.read(llmSettingsProvider.notifier).updateSettings(
            baseUrl: _baseUrlController.text.trim(),
          );
    });
    attachUrlSave(_modelFocus, () {
      ref.read(llmSettingsProvider.notifier).updateSettings(
            model: _modelController.text.trim(),
          );
    });
    attachUrlSave(_apiKeyFocus, () {
      ref.read(llmSettingsProvider.notifier).updateSettings(
            apiKey: _apiKeyController.text,
          );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyLlmToControllers(ref.read(llmSettingsProvider));
    });
  }

  @override
  void dispose() {
    _debounceSystem?.cancel();
    _debounceQuestion?.cancel();
    _debounceDiagnosis?.cancel();
    _baseUrlController.dispose();
    _modelController.dispose();
    _apiKeyController.dispose();
    _systemPromptController.dispose();
    _questionPromptController.dispose();
    _diagnosisPromptController.dispose();
    _baseUrlFocus.dispose();
    _modelFocus.dispose();
    _apiKeyFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(databaseProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final llm = ref.watch(llmSettingsProvider);

    ref.listen<LLMSettings>(llmSettingsProvider, (previous, next) {
      _applyLlmToControllers(next);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _SectionLabel(text: '用户与学习画像', colorScheme: cs, textTheme: theme.textTheme),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ref.watch(userProfileProvider).when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (e, _) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '无法加载用户画像',
                          style: theme.textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => ref.invalidate(userProfileProvider),
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                    data: (profile) {
                      final gradeOk =
                          profile.grade.isNotEmpty &&
                              AppConstants.gradeOptions.contains(profile.grade);
                      final subjectOk = profile.subjectPreference.isNotEmpty &&
                          AppConstants.subjectOptions
                              .contains(profile.subjectPreference);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DropdownButtonFormField<String>(
                            key: ValueKey('grade_${profile.grade}'),
                            initialValue: gradeOk ? profile.grade : null,
                            decoration: const InputDecoration(
                              labelText: '年级',
                              border: OutlineInputBorder(),
                            ),
                            hint: const Text('请选择年级'),
                            items: [
                              for (final g in AppConstants.gradeOptions)
                                DropdownMenuItem(value: g, child: Text(g)),
                            ],
                            onChanged: (v) {
                              if (v != null) {
                                ref
                                    .read(userProfileProvider.notifier)
                                    .updateGrade(v);
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            key: ValueKey('subject_${profile.subjectPreference}'),
                            initialValue: subjectOk ? profile.subjectPreference : null,
                            decoration: const InputDecoration(
                              labelText: '学科偏好',
                              border: OutlineInputBorder(),
                            ),
                            hint: const Text('请选择学科'),
                            items: [
                              for (final s in AppConstants.subjectOptions)
                                DropdownMenuItem(value: s, child: Text(s)),
                            ],
                            onChanged: (v) {
                              if (v != null) {
                                ref
                                    .read(userProfileProvider.notifier)
                                    .updateSubjectPreference(v);
                              }
                            },
                          ),
                        ],
                      );
                    },
                  ),
            ),
          ),
          const SizedBox(height: 16),
          _SectionLabel(text: 'LLM 配置', colorScheme: cs, textTheme: theme.textTheme),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _baseUrlController,
                    focusNode: _baseUrlFocus,
                    decoration: InputDecoration(
                      labelText: 'Base URL',
                      hintText: AppConstants.defaultBaseUrl,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _modelFocus.requestFocus(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _modelController,
                    focusNode: _modelFocus,
                    decoration: InputDecoration(
                      labelText: '模型',
                      hintText: AppConstants.defaultModel,
                      border: const OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _apiKeyFocus.requestFocus(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _apiKeyController,
                    focusNode: _apiKeyFocus,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'API Key',
                      hintText: _apiKeyPlaceholder(),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SectionLabel(text: '自定义 Prompt', colorScheme: cs, textTheme: theme.textTheme),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ExpansionTile(
                  title: const Text('对话系统 Prompt'),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    TextField(
                      controller: _systemPromptController,
                      minLines: 4,
                      maxLines: 12,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      onChanged: (_) {
                        _schedulePromptSave(
                          () => _debounceSystem,
                          (t) => _debounceSystem = t,
                          () => ref.read(llmSettingsProvider.notifier).updateSettings(
                                customSystemPrompt: _systemPromptController.text,
                              ),
                        );
                      },
                    ),
                  ],
                ),
                const Divider(height: 1),
                ExpansionTile(
                  title: const Text('题目生成 Prompt'),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    TextField(
                      controller: _questionPromptController,
                      minLines: 4,
                      maxLines: 12,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      onChanged: (_) {
                        _schedulePromptSave(
                          () => _debounceQuestion,
                          (t) => _debounceQuestion = t,
                          () => ref.read(llmSettingsProvider.notifier).updateSettings(
                                customQuestionPrompt:
                                    _questionPromptController.text,
                              ),
                        );
                      },
                    ),
                  ],
                ),
                const Divider(height: 1),
                ExpansionTile(
                  title: const Text('诊断报告 Prompt'),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    TextField(
                      controller: _diagnosisPromptController,
                      minLines: 4,
                      maxLines: 12,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      onChanged: (_) {
                        _schedulePromptSave(
                          () => _debounceDiagnosis,
                          (t) => _debounceDiagnosis = t,
                          () => ref.read(llmSettingsProvider.notifier).updateSettings(
                                customDiagnosisPrompt:
                                    _diagnosisPromptController.text,
                              ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionLabel(text: '测验', colorScheme: cs, textTheme: theme.textTheme),
          Card(
            clipBehavior: Clip.antiAlias,
            child: SwitchListTile(
              title: const Text('答题时显示信心评分'),
              subtitle: const Text('关闭后测验中不再要求信心等级'),
              value: llm.showConfidenceRating,
              onChanged: (v) {
                ref
                    .read(llmSettingsProvider.notifier)
                    .updateSettings(showConfidenceRating: v);
              },
            ),
          ),
          const SizedBox(height: 16),
          _SectionLabel(text: '数据', colorScheme: cs, textTheme: theme.textTheme),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () {
                      ref.read(databaseProvider);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('导出功能')),
                      );
                    },
                    icon: const Icon(Icons.upload_outlined),
                    label: const Text('导出数据'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      ref.read(databaseProvider);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('导入功能')),
                      );
                    },
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('导入数据'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.text,
    required this.colorScheme,
    required this.textTheme,
  });

  final String text;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8, top: 4),
      child: Text(
        text,
        style: textTheme.titleSmall?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
