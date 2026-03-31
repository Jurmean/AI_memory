# 智能记忆助手 (Memory Helper)

基于 Flutter 的纯本地智能记忆 App（Android），融合 **SM-2 + IRT(1PL)** 间隔重复算法、**FSRS 幂律遗忘衰减**、**知识图谱协同调度**，以及 **LLM 认知诊断**，帮助学生高效复习、精准定位薄弱知识点。

---

## 核心特性

- **SM-2 + IRT 双层融合调度** — 在经典 SM-2 间隔重复的基础上，引入 IRT(1PL) 能力估计动态调整复习间隔
- **多维记忆质量评分 (QS)** — 综合置信度、响应时间、正确性、犹豫次数，替代 SM-2 原始 0-5 评分
- **FSRS 遗忘曲线** — 幂律衰减模型预测能力遗忘，展示实时有效能力值
- **知识图谱协同** — BFS 深度 2 层关联调度，关联知识点联动复习
- **LLM 智能诊断** — 接入 OpenAI 兼容 API（默认 MiniMax），支持：
  - 文本 → 结构化题目导入（含干扰项分析）
  - 答题组 / 综合认知诊断报告（自动 & 手动触发）
  - 流式 AI 对话（Markdown 渲染 + thinking 折叠展示）
- **13+ 精美页面** — Material Design 3 紫色系主题，渐变卡片、玻璃态效果、动画数字、深浅色模式

---

## 技术栈

| 层级 | 技术 |
|------|------|
| 框架 | Flutter (Dart) |
| 目标平台 | Android |
| 数据库 | SQLite via `sqflite` |
| 状态管理 | `flutter_riverpod` (Riverpod 3.x) |
| LLM | OpenAI 兼容 API（默认 MiniMax `MiniMax-M2.7`） |
| HTTP | `dio` |
| 图表 | `fl_chart` |
| 其他 | `flutter_markdown`, `uuid`, `path_provider`, `shared_preferences`, `file_picker`, `share_plus` |

---

## 项目结构

```
lib/
├── main.dart                          # 入口
├── app.dart                           # 导航壳（底部导航 4 页）
├── core/
│   ├── algorithms/
│   │   ├── quality_score.dart         # QS 多维记忆质量评分
│   │   ├── sm2_engine.dart            # SM-2 间隔重复引擎
│   │   ├── irt_engine.dart            # IRT(1PL) 能力估计 (Newton-Raphson)
│   │   ├── scheduler.dart             # 融合调度器（紧迫度+信息增益+图谱协同）
│   │   └── ability_decay.dart         # FSRS 幂律遗忘衰减
│   └── knowledge_graph/
│       └── graph_engine.dart          # 知识图谱 BFS 协同
├── data/
│   ├── database/
│   │   └── database_helper.dart       # SQLite 全部表+索引+样例数据+CRUD
│   └── models/                        # 9 个数据模型（含 DistractorInfo）
├── features/
│   ├── home/home_page.dart            # 首页 Dashboard
│   ├── study/
│   │   ├── quiz_page.dart             # 复习答题（10题上限+信心评分+犹豫计数）
│   │   └── result_page.dart           # 答题结果（固定底部 AI 伴学入口）
│   ├── question_bank/
│   │   ├── question_bank_page.dart    # 题库管理（按知识点分组）
│   │   ├── question_detail_page.dart  # 题目详情（干扰项分析柱状图）
│   │   ├── import_page.dart           # AI 文本导入（可编辑+重试）
│   │   └── manual_add_page.dart       # 手动添加题目
│   ├── ability/ability_detail_page.dart  # 能力曲线详情（衰减预测图）
│   ├── queue/review_queue_page.dart   # 复习队列可视化
│   ├── chat/chat_page.dart            # AI 对话（流式+thinking+Markdown）
│   ├── diagnosis/
│   │   ├── report_list_page.dart      # 诊断报告列表（Tab 分栏）
│   │   └── report_detail_page.dart    # 报告详情（图表+薄弱点分析）
│   └── settings/settings_page.dart    # 设置（画像+LLM+Prompt+开关）
├── llm/
│   ├── llm_client.dart                # 通用 LLM 客户端（流式 SSE+thinking 解析）
│   ├── prompts/                       # 3 个 Prompt 模板 + PromptBuilder
│   └── services/                      # 4 个 LLM Service
├── providers/                         # 7 个 Riverpod Provider
└── shared/
    ├── theme/app_theme.dart           # Material Design 3 主题
    └── constants.dart                 # 全局常量
```

---

## 核心算法

### QS 记忆质量评分
```
QS = 0.35×confidence + 0.25×time_score + 0.30×correctness + 0.10×hesitation_penalty
```
映射到 [0, 5]，替代 SM-2 原始评分。

### SM-2 + IRT 融合
```
区间调整因子: f(d) = 1 + 0.3 × tanh(θ - b)
最终间隔:     I_final = I(n) × f(θ - b)
```

### FSRS 遗忘衰减
```
R(t) = (1 + 19/81 × t/S) ^ (-0.5)
θ_effective = θ_last × R(t)
```

---

## 数据库

SQLite 一次性建表，10 张表 + 1 张联接表，内置 **10 道高中化学样例题** + 知识点 + 关联关系 + 干扰度数据，首次打开即可复习。

---

## 快速开始

### 环境要求

- Flutter SDK ≥ 3.10
- Android SDK
- Dart ≥ 3.10

### 构建运行

```bash
# 获取依赖
flutter pub get

# 运行（连接 Android 设备或模拟器）
flutter run

# 构建 APK
flutter build apk --debug
```

### LLM 配置

App 内置默认 MiniMax API Key，开箱即用。如需更换：
- 打开 App → 设置 → LLM 配置
- 支持任何 OpenAI 兼容格式的 API（如 DeepSeek、OpenAI 等）

---

## 页面预览

| 页面 | 功能 |
|------|------|
| 首页 Dashboard | 渐变头图、待复习数、能力值卡片、学习统计动画、薄弱 TOP3 |
| 复习答题 | 进度条、计时器、犹豫计数、信心评分（可关闭）、10 题上限 |
| 答题结果 | 选项回顾（绿/红标注）、解析、底部固定 AI 伴学入口 |
| AI 对话 | 流式气泡、Markdown 渲染、thinking 折叠、跨 session 记忆 |
| 题库管理 | 按知识点分组、难度色条、AI 导入 / 手动添加 |
| 能力详情 | 有效 θ、衰减曲线（蓝实线+橙虚线预测）、稳定性/半衰期 |
| 诊断报告 | 答题组报告 / 总报告 Tab、能力评估、薄弱点柱状图 |
| 设置 | 用户画像、LLM 配置、自定义 Prompt、信心评分开关 |

---

## 与毕设论文对应

| 论文章节 | 项目模块 |
|----------|----------|
| 第 1 章 绪论 | 整体项目背景 |
| 第 2 章 相关技术 | SM-2 / IRT / FSRS 原理、Flutter、LLM |
| 第 3 章 需求分析与总体设计 | 架构图、数据流图 |
| 第 4 章 核心算法设计 | SM2 + IRT + QS + Scheduler + KG + AbilityDecay |
| 第 5 章 LLM 智能诊断 | Prompt 设计、诊断报告、对话系统 |
| 第 6 章 详细设计与实现 | DB Schema、类结构、UI |
| 第 7 章 测试与分析 | 算法验证、对比实验 |
| 第 8 章 总结与展望 | 创新点归纳 |

---

## 核心创新点

1. **SM-2 + IRT 双层解耦调度** — 微观 SM-2 管理单题间隔，宏观 IRT 估计全局能力并动态调整
2. **QS 多维记忆质量评分** — 融合置信度、响应时间、正确性、犹豫行为，比单一正误更精准
3. **LLM 驱动认知诊断闭环** — 自动生成诊断报告 → 定位薄弱点 → 协同调度 → 针对性复习

---

## License

本项目为毕业设计作品，仅供学术交流使用。
