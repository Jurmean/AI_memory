---
name: 功能增强与UI美化
overview: 新增手动导入题目表单和 AI 生成题目编辑功能，美化核心页面 UI，将答题结果页底部按钮固定，并修复答题后 AI 对话的流式输出问题。另外生成 app 图标素材。
todos:
  - id: manual-add
    content: 新建 ManualAddPage 手动导入表单 + 在 QuestionBankPage 添加入口
    status: completed
  - id: ai-edit-import
    content: ImportPage 中 AI 生成题目增加 Checkbox 选择 + 编辑 + 删除功能
    status: completed
  - id: ui-theme
    content: 主题微调（种子色、卡片阴影、导航栏）+ 首页渐变头图和动画数字 + 导入页空态
    status: completed
  - id: app-icon
    content: 配置 flutter_launcher_icons + 生成图标 + 告知用户导入路径
    status: completed
  - id: result-bottom-fix
    content: result_page 底部按钮固定：Column+Expanded+固定底部容器
    status: completed
  - id: guidance-stream-fix
    content: 排查并修复 guidance 模式 AI 对话流式输出问题（读 ChatService 确认流路径）
    status: completed
isProject: false
---

# 功能增强与 UI 美化

## 1. 手动导入题目

**现状**：[import_page.dart](lib/features/question_bank/import_page.dart) 只支持「输入文本 -> AI 结构化生成」一种方式，无法手动逐题录入。

**方案**：

- 在 [question_bank_page.dart](lib/features/question_bank/question_bank_page.dart) 顶栏「导入」按钮旁新增「手动添加」入口，或在 `ImportPage` 顶部加 Tab 栏：「AI 生成」/「手动录入」
- 新建 `ManualAddPage`（`ConsumerStatefulWidget`），表单包含：
  - 题干 `TextField`（多行）
  - 4 个选项 `TextField`（支持增减选项数量，默认 4 个）
  - 正确答案下拉选择（A/B/C/D）
  - 折叠的「高级参数」：难度滑杆（1-5，默认 3）、解析文本、知识点标签（逗号分隔）
- 点击「保存」时用 `uuid` 生成 ID、`difficultyB = (difficulty - 3.0)`，写入 DB 并创建 `ReviewState`
- `sourceType` 标记为 `'manual'`

**涉及文件**：新建 `lib/features/question_bank/manual_add_page.dart`，修改 `question_bank_page.dart` 添加入口

## 2. AI 生成题目可编辑后导入

**现状**：[import_page.dart](lib/features/question_bank/import_page.dart) 中 AI 生成的题目只能整体预览、整体导入，不能逐题编辑或选择性导入。

**方案**：

- 在 `_result` 预览区域，给每道题添加「编辑」和「删除」按钮
- 「编辑」弹出 `showModalBottomSheet` 或跳转编辑页，可修改题干、选项、正确答案、难度
- 每题前面加一个 `Checkbox`，默认全选，用户可取消不想导入的题目
- 「确认导入」只导入勾选的题目
- 修改 `_result` 从 `StructureResult?` 改为持有一个 `List<_EditableQuestion>` 状态对象，以便追踪修改

**涉及文件**：修改 `lib/features/question_bank/import_page.dart`

## 3. UI 美化（重点核心页面 + 主题微调）

**现状**：已有 Material 3 基础，种子色为 `#1565C0`（蓝色），整体偏素。

**方案**：

### 3a. 主题微调 — [app_theme.dart](lib/shared/theme/app_theme.dart)

- 种子色改为更有活力的颜色（如 `#6750A4` 紫色或 `#0D7377` 青色），可同时影响全局色调
- `CardTheme` 增加轻微阴影（`elevation: 1`）让卡片有层次感
- 底部导航栏增加 `elevation` 和微妙分割线

### 3b. 首页美化 — [home_page.dart](lib/features/home/home_page.dart)

- 顶部添加一个轻量级渐变头图或波浪装饰
- 问候语区域增加用户头像占位符
- 统计卡片动画（数字递增效果 `TweenAnimationBuilder`）

### 3c. 导入页和题库页微调

- `ImportPage` 的文本输入框增加引导占位图（空状态图标）
- `QuestionBankPage` 分组卡片之间增加微妙动画

### 3d. 设置页、报告页不做大改，保持一致性

## 4. App 图标

**现状**：各平台图标位置（`android/app/src/main/res/mipmap-`*、`ios/Runner/Assets.xcassets/AppIcon.appiconset`、`web/icons/`）均为空或使用 Flutter 默认占位。

**方案**：

- 用工具生成一个 1024x1024 的图标 PNG（主题色背景 + 脑/书本/闪电组合图形）
- 告知用户将该图标文件放到项目根目录后，使用 `flutter_launcher_icons` 包自动生成各平台尺寸
- 在 `pubspec.yaml` 添加 `flutter_launcher_icons` dev 依赖和配置
- 用户只需放入一张高清 PNG 即可

## 5. 答题结果页底部按钮固定

**现状**：[result_page.dart](lib/features/study/result_page.dart) 的「AI 伴学」入口和「下一题」按钮在 `ListView` 末尾，随内容滚动，可能滚出视野。

**方案**：

- 将 body 改为 `Column`：`Expanded(ListView(...))` + 底部固定区域
- 底部固定区域包含：「AI 伴学」按钮 + 「下一题」按钮，用 `SafeArea` 包裹
- 从 `ListView.children` 中移除这两个 widget，放入底部 `Container`
- 底部区域加顶部分割线和微妙阴影，与内容区视觉分离

```dart
body: Column(
  children: [
    Expanded(
      child: ListView(
        // ... 题目结果、选项回顾、解析 ...
      ),
    ),
    // 固定底部
    Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant...)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            // AI 伴学入口（紧凑版）
            // 下一题按钮
          ]),
        ),
      ),
    ),
  ],
)
```

## 6. 修复答题后 AI 对话非流式输出

**现状分析**：`chat_provider.dart` 的 `_sendMessageInternal` 方法 **已经使用流式输出**（`service.sendMessageStream`）。`startInstantGuidance` 调用的也是同一方法。即 guidance 模式本身就是流式的。

**可能的实际问题**：`ChatPage` 在 `isInstantGuidance = true` 时的 `initState` 不调用 `loadHistory()`，而 `startInstantGuidance` 在 `ChatNotifier` 里是同步触发 `_sendMessageInternal`（一个 async 方法但不 await），这意味着页面 `push` 后 `ChatPage.build` 可能在流式数据开始之前就执行了。但流式数据通过 `state` 更新会触发 rebuild，所以理论上应该正常显示。

**需要排查**：

- `_getService()` 在 guidance 模式下是否正确创建了新的 `ChatService`（每次都会创建新实例，看起来没问题）
- `chatStream` 方法在 `ChatService.sendMessageStream` 中的调用路径是否正确触发了流式返回

我会读取 `ChatService` 确认 `sendMessageStream` 的实现，确保 guidance 模式走的也是 `chatStream` 而非 `chat`。如果确实是流式的，问题可能出在 UI 层（气泡渲染顺序或 scroll），需要微调。