---
name: LLM增强与用户画像
overview: 修复诊断报告不触发的 bug，增加用户画像设置，增强 AI 对话（可记忆 + thinking 区分 + Markdown 渲染），LLM 生成题目加入干扰度分析，全面重构 prompt 体系。
todos:
  - id: fix-diagnosis-trigger
    content: "修复诊断报告不触发: 在 _endSession 中调用 triggerDiagnosis，检查 answeredCount >= 10"
    status: completed
  - id: user-profile-model
    content: UserProfile 新增 grade/subjectPreference 字段；DB v4 升级；provider 更新方法
    status: completed
  - id: user-profile-ui
    content: 设置页新增"用户画像"卡片（年级下拉 + 学科下拉 + 保存）
    status: completed
  - id: prompt-builder
    content: 新增 prompt_builder.dart 统一上下文注入器，自动组合画像 + 薄弱点 + 自定义 prompt
    status: completed
  - id: prompt-upgrade
    content: 重构三个 prompt 文件（chat/diagnosis/question），注入画像并升级内容质量
    status: completed
  - id: thinking-parse
    content: llm_client.dart chatStream 解析 reasoning_content 和 think 标签；ChatState 新增 thinkingContent
    status: completed
  - id: chat-ui-enhance
    content: "chat_page.dart: thinking 折叠区分块 + 流式光标动画 + Markdown 渲染增强"
    status: completed
  - id: chat-memory
    content: chat_provider 加载 DB 历史到 ChatService._history，实现跨 session 记忆
    status: completed
  - id: question-gen-distractor
    content: question_structure_prompt 增加干扰度要求；service 解析 distractorAnalysis 填入 Question
    status: completed
  - id: verify-build-2
    content: flutter analyze + flutter build web 验证编译通过
    status: completed
isProject: false
---

# LLM 增强与用户画像

## 问题诊断

### BUG: 诊断报告未触发

`diagnosisTriggerCount = 10` 定义于 [constants.dart](lib/shared/constants.dart) 但**从未被引用**。`triggerDiagnosis()` 定义于 [diagnosis_provider.dart](lib/providers/diagnosis_provider.dart) 但**从未被调用**。quiz 流程中 `_endSession()` 只更新 session 状态而不触发诊断。

---

## 一、修复诊断报告自动生成

在 [current_quiz_provider.dart](lib/providers/current_quiz_provider.dart) 的 `_endSession()` 中：

- 检查 `state.answeredCount >= AppConstants.diagnosisTriggerCount`
- 若满足且 LLM 已配置，调用 `ref.read(diagnosisProvider.notifier).triggerDiagnosis(sessionId)`
- 异步执行，不阻塞 session 结束流程

---

## 二、用户画像系统

### 2.1 数据模型

扩展 UserProfile 或新建 `UserProfileInfo`，新增字段：

- `grade` (String): 年级，如"高一"、"高二"、"高三"
- `subjectPreference` (String): 学科偏好，如"化学"、"物理"

DB 升级 v3->v4，`ALTER TABLE user_profile ADD COLUMN grade TEXT DEFAULT ''` 和 `subject_preference TEXT DEFAULT ''`。

### 2.2 设置页面

在 [settings_page.dart](lib/features/settings/settings_page.dart) 中 LLM 配置区域之前，新增"用户画像"卡片：

- 年级下拉选择（高一/高二/高三/大一/其他）
- 学科偏好下拉选择（化学/物理/数学/生物/其他）
- 保存按钮

### 2.3 Prompt 注入

构建一个 `UserProfileContext.buildContext(profile)` 工具方法，生成形如：

```
用户画像：高三学生，主攻化学。能力值θ=0.35，正确率72%，已答150题，薄弱点：氧化还原反应(55%)、化学平衡(62%)。
```

此上下文在**所有 LLM 调用**时自动注入（chat、diagnosis、question generation）。

---

## 三、AI 对话增强

### 3.1 可记忆型对话

当前 [chat_provider.dart](lib/providers/chat_provider.dart) 已有数据库持久化和 `loadHistory()`。需要增强：

- `sendMessage` 时从 DB 加载最近 N 条历史（而非仅当前 session），传入 ChatService 的 `_history`
- ChatService 的 `_history` 初始化时填入持久化的历史记录

### 3.2 Thinking 模块区分

在 [llm_client.dart](lib/llm/llm_client.dart) 的 `chatStream` 中：

- 解析 SSE 中的 `reasoning_content`（DeepSeek 格式）和 `<think>...</think>` 标签（通用格式）
- yield 时区分普通 content 和 thinking content
- ChatState 新增 `thinkingContent` 字段

在 [chat_page.dart](lib/features/chat/chat_page.dart) 中：

- 新增 `_ThinkingBlock` widget，折叠式展示思维链内容
- 样式区分：浅灰背景 + 斜体 + "思考过程"标题

### 3.3 Markdown 渲染增强

当前已使用 `flutter_markdown`。增强：

- 代码块语法高亮
- 数学公式基础支持（可选）
- 列表/表格样式优化

### 3.4 流式输出

当前已实现流式输出（`chatStream` + `streamingContent`），但 `isStreaming` 属性未被 `_ChatBubble` 实际使用。增强：

- 流式时显示光标闪烁动画
- thinking 内容实时更新

---

## 四、LLM 生成题目加入干扰度

### 4.1 Prompt 升级

修改 [question_structure_prompt.dart](lib/llm/prompts/question_structure_prompt.dart) 的 `buildStructurePrompt`，要求 LLM 在 JSON 中额外输出：

```json
"distractorAnalysis": [
  {"optionIndex": 0, "attractiveness": 0.35, "commonMistakeReason": "..."},
  ...
]
```

### 4.2 解析升级

修改 [question_structure_service.dart](lib/llm/services/question_structure_service.dart) 的 `_parseResponse`，解析 `distractorAnalysis` 字段并填入 `Question.distractorAnalysis`。

---

## 五、Prompt 体系重构

### 5.1 统一上下文注入器

新增 `lib/llm/prompts/prompt_builder.dart`，集中管理：

- `buildSystemPrompt(profile, customPrompt)` -- 合并用户画像 + 自定义 prompt + 默认 prompt
- `buildDiagnosisPrompt(profile, session, logs, ...)` -- 注入画像
- `buildQuestionPrompt(profile, rawText, customPrompt)` -- 注入画像 + 干扰度要求

### 5.2 各 Prompt 升级要点

**Chat System Prompt** -- 注入用户画像，让 AI 了解学生年级、学科、能力水平：

```
你是一个友善的AI学习伴侣。当前用户情况：{用户画像}。
请根据用户的实际水平调整你的回答深度和风格。
```

**Diagnosis Prompt** -- 注入画像 + 历史趋势：

```
用户画像：{画像}
稳定性S={S}天，距上次学习{days}天，能力衰减至{R*100}%
```

**Question Structure Prompt** -- 增加干扰度分析要求 + 画像适配难度

---

## 六、数据库升级

version 3 -> 4:

- `ALTER TABLE user_profile ADD COLUMN grade TEXT DEFAULT ''`
- `ALTER TABLE user_profile ADD COLUMN subject_preference TEXT DEFAULT ''`

---

## 七、涉及文件清单

新增文件:

- `lib/llm/prompts/prompt_builder.dart` -- 统一上下文构建器

修改文件（约 12 个）:

- `lib/data/models/user_profile.dart` -- 新增 grade, subjectPreference
- `lib/data/database/database_helper.dart` -- DB v4 升级
- `lib/providers/user_profile_provider.dart` -- 画像更新方法
- `lib/providers/current_quiz_provider.dart` -- _endSession 触发诊断
- `lib/providers/chat_provider.dart` -- 历史记忆加载 + thinking 状态
- `lib/providers/diagnosis_provider.dart` -- 注入画像上下文
- `lib/llm/llm_client.dart` -- chatStream 解析 thinking
- `lib/llm/services/chat_service.dart` -- 注入画像
- `lib/llm/services/question_structure_service.dart` -- 解析干扰度
- `lib/llm/prompts/chat_prompt.dart` -- 升级 prompt
- `lib/llm/prompts/question_structure_prompt.dart` -- 升级 prompt + 干扰度
- `lib/llm/prompts/diagnosis_prompt.dart` -- 升级 prompt
- `lib/features/settings/settings_page.dart` -- 用户画像设置 UI
- `lib/features/chat/chat_page.dart` -- thinking 区分 UI + 光标动画

