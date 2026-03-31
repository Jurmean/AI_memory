import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../llm/llm_client.dart';
import '../shared/constants.dart';

class LLMSettings {
  final String apiKey;
  final String baseUrl;
  final String model;
  final String customSystemPrompt;
  final String customQuestionPrompt;
  final String customDiagnosisPrompt;
  final bool showConfidenceRating;

  const LLMSettings({
    this.apiKey = '',
    this.baseUrl = '',
    this.model = '',
    this.customSystemPrompt = '',
    this.customQuestionPrompt = '',
    this.customDiagnosisPrompt = '',
    this.showConfidenceRating = true,
  });

  LLMSettings copyWith({
    String? apiKey,
    String? baseUrl,
    String? model,
    String? customSystemPrompt,
    String? customQuestionPrompt,
    String? customDiagnosisPrompt,
    bool? showConfidenceRating,
  }) =>
      LLMSettings(
        apiKey: apiKey ?? this.apiKey,
        baseUrl: baseUrl ?? this.baseUrl,
        model: model ?? this.model,
        customSystemPrompt: customSystemPrompt ?? this.customSystemPrompt,
        customQuestionPrompt: customQuestionPrompt ?? this.customQuestionPrompt,
        customDiagnosisPrompt: customDiagnosisPrompt ?? this.customDiagnosisPrompt,
        showConfidenceRating: showConfidenceRating ?? this.showConfidenceRating,
      );

  String get effectiveApiKey =>
      apiKey.isNotEmpty ? apiKey : AppConstants.defaultApiKey;
  String get effectiveBaseUrl =>
      baseUrl.isNotEmpty ? baseUrl : AppConstants.defaultBaseUrl;
  String get effectiveModel =>
      model.isNotEmpty ? model : AppConstants.defaultModel;
}

class LLMSettingsNotifier extends Notifier<LLMSettings> {
  @override
  LLMSettings build() {
    _loadSettings();
    return const LLMSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    state = LLMSettings(
      apiKey: prefs.getString('llm_api_key') ?? '',
      baseUrl: prefs.getString('llm_base_url') ?? '',
      model: prefs.getString('llm_model') ?? '',
      customSystemPrompt: prefs.getString('llm_custom_system_prompt') ?? '',
      customQuestionPrompt: prefs.getString('llm_custom_question_prompt') ?? '',
      customDiagnosisPrompt: prefs.getString('llm_custom_diagnosis_prompt') ?? '',
      showConfidenceRating: prefs.getBool('show_confidence_rating') ?? true,
    );
  }

  Future<void> updateSettings({
    String? apiKey,
    String? baseUrl,
    String? model,
    String? customSystemPrompt,
    String? customQuestionPrompt,
    String? customDiagnosisPrompt,
    bool? showConfidenceRating,
  }) async {
    state = state.copyWith(
      apiKey: apiKey,
      baseUrl: baseUrl,
      model: model,
      customSystemPrompt: customSystemPrompt,
      customQuestionPrompt: customQuestionPrompt,
      customDiagnosisPrompt: customDiagnosisPrompt,
      showConfidenceRating: showConfidenceRating,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('llm_api_key', state.apiKey);
    await prefs.setString('llm_base_url', state.baseUrl);
    await prefs.setString('llm_model', state.model);
    await prefs.setString('llm_custom_system_prompt', state.customSystemPrompt);
    await prefs.setString('llm_custom_question_prompt', state.customQuestionPrompt);
    await prefs.setString('llm_custom_diagnosis_prompt', state.customDiagnosisPrompt);
    await prefs.setBool('show_confidence_rating', state.showConfidenceRating);
  }
}

final llmSettingsProvider =
    NotifierProvider<LLMSettingsNotifier, LLMSettings>(LLMSettingsNotifier.new);

final llmClientProvider = Provider<LLMClient>((ref) {
  final settings = ref.watch(llmSettingsProvider);
  return LLMClient(
    apiKey: settings.effectiveApiKey,
    baseUrl: settings.effectiveBaseUrl,
    model: settings.effectiveModel,
  );
});
