---
name: Bug修复与功能增强
overview: 修复 5 个问题：聊天隔离、报告增强（thinking剥离+图表+分栏+等待页）、超时修复、以及答题评价可关闭。
todos:
  - id: chat-isolation
    content: 答题对话与AI对话隔离：guidance消息不入库、loadHistory只加载chat类型、退出guidance恢复chat状态
    status: completed
  - id: thinking-strip
    content: 诊断报告剥离thinking标签：在diagnosis_service中正则去除<think>块
    status: completed
  - id: report-type-split
    content: 区分答题组报告/总报告：模型新增reportType、DB v5升级、Tab分栏UI、总报告prompt与生成逻辑
    status: completed
  - id: report-detail-charts
    content: 报告详情页美化：结构化卡片+fl_chart图表+JSON代码块不渲染
    status: completed
  - id: quiz-wait-report
    content: 答题完成后等待报告页：监听diagnosisProvider、显示加载动画、完成后直接查看报告
    status: completed
  - id: timeout-fix
    content: 修复题目生成超时：提高receiveTimeout到180s、优化错误提示、添加重试
    status: completed
  - id: confidence-toggle
    content: 答题评价可关闭：新增showConfidenceRating设置项+Switch开关、关闭时跳过弹窗用默认值
    status: completed
isProject: false
---

# Bug 修复与功能增强

## 问题 1：答题对话与 AI 对话隔离

**现状**：`chatProvider` 是全局单例，`startInstantGuidance` 虽清内存但写入同一张 `chat_messages` 表，导致普通 AI 对话 `loadHistory` 时会拉出答题对话的消息。

**方案**：

- 在 `ChatMessage` 模型 ([lib/data/models/chat_message.dart](lib/data/models/chat_message.dart)) 添加 `sessionType` 字段（`'chat'` / `'guidance'`），DB 表增加列（v5 升级）
- `startInstantGuidance` 写入的消息标记为 `guidance`，普通对话标记为 `chat`
- `loadHistory` 只加载 `sessionType = 'chat'` 的消息
- `clearChat` 只清除 `chat` 类型
- `startInstantGuidance` **不再写入 DB**（即时性，退出即消失），只在内存中运行
- 如果用户退出 guidance 页面回到普通 AI 对话，恢复之前的 chat 历史

**涉及文件**：

- `lib/data/models/chat_message.dart` — 新增字段
- `lib/data/database/database_helper.dart` — DB v5 升级，查询/插入添加 sessionType
- `lib/providers/chat_provider.dart` — guidance 消息不持久化；普通 chat 恢复隔离
- `lib/llm/services/chat_service.dart` — 无需改动（已有 loadHistory / clearHistory）

## 问题 2：报告生成增强

**2a. Thinking 块剥离**

- `DiagnosisService.generateReport` 用的是非流式 `client.chat()`，LLM 返回可能包含 `<think>...</think>` 标签
- 在 [lib/llm/services/diagnosis_service.dart](lib/llm/services/diagnosis_service.dart) 的 `generateReport` 中，对返回的 `response` 做正则剥离 `<think>` 标签内容

**2b. 区分「答题组报告」与「总报告」**

- `DiagnosticReport` 模型新增 `reportType` 字段：`'session'`（10题一组自动生成）/ `'overall'`（手动点击生成）
- DB 表增加 `report_type` 列（v5 升级）
- 新增「总报告」生成逻辑：汇总所有历史会话数据 + 全局 θ + 所有薄弱点
- 新增专用 prompt `DiagnosisPrompt.buildOverallDiagnosisPrompt`
- 报告列表页增加顶部 Tab 栏：「答题组报告」/「总报告」，可分栏查看
- 报告列表页添加「生成总报告」按钮

**2c. 报告详情页美化**

- 结构化展示：从 `reportData` 提取 `overallScore`、`abilityLevel`、`weakAreas`、`strengths`、`suggestedFocus` 做卡片/图表展示
- 使用 `fl_chart` 绘制能力雷达图（或柱状图展示各知识点掌握度）
- 弱点分析用进度条可视化
- Markdown 正文部分仅展示文字分析，JSON 代码块不渲染

## 问题 3：答题后等待报告页

**现状**：答满 10 题后 `_endSession` fire-and-forget 触发 `triggerDiagnosis`，用户看到的是「复习完成」页面，需手动去报告列表查看。

**方案**：

- 在 [lib/features/study/quiz_page.dart](lib/features/study/quiz_page.dart) 的「复习完成」界面中，当 `answeredCount >= 10` 时，显示报告生成等待 UI
- 监听 `diagnosisProvider` 状态，报告生成完成后自动显示「查看本轮报告」按钮
- 点击直接跳转 `ReportDetailPage`
- 生成中显示加载动画 + 提示文案

## 问题 4：文本生成题目超时

**现状**：`LLMClient` 的 `receiveTimeout` 仅 60 秒，题目结构化需要 LLM 生成较长的 JSON，容易超时。

**方案**：

- 在 [lib/llm/llm_client.dart](lib/llm/llm_client.dart) 中将 `receiveTimeout` 从 60s 提高到 180s（3分钟）
- 在 `chat()` 方法调用时，允许传入自定义超时（对题目生成场景特别设置更长时间）
- 在 [lib/features/question_bank/import_page.dart](lib/features/question_bank/import_page.dart) 的错误提示中区分超时错误，给出更友好的提示（如「生成时间较长，请稍后重试或缩短输入文本」）
- 考虑添加重试按钮

## 问题 5：答题评价（信心评分）可关闭

**现状**：每道题提交后强制弹出 5 级信心评价 `_ConfidenceSheet`，打断心流。

**方案**：

- 在 [lib/providers/llm_provider.dart](lib/providers/llm_provider.dart) 的 `LLMSettings`（或新建一个 `AppSettings`）中添加 `showConfidenceRating` 布尔字段，默认 `true`
- 在 [lib/features/settings/settings_page.dart](lib/features/settings/settings_page.dart) 添加 Switch 开关「答题后显示信心评价」
- 在 [lib/features/study/quiz_page.dart](lib/features/study/quiz_page.dart) 中：
  - 开启时：维持现有流程，弹出 `_ConfidenceSheet`
  - 关闭时：直接以默认信心值（3，即"一般"）调用 `submitAnswer(3)`，跳过弹窗
- 持久化到 `SharedPreferences`

