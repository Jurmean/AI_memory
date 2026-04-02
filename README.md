# 智能记忆助手 (Memory Helper)

基于 Flutter 的智能记忆 App（Android），融合 **SM-2 + IRT(1PL)** 间隔重复算法、**FSRS 幂律遗忘衰减**，以及 **LLM 认知诊断 + RAG 增强**，帮助学生高效复习、精准定位薄弱知识点。配套 **FastAPI 后端**提供联网搜索 RAG 与本地知识库检索。

---

## 系统架构

```
┌──────────────────────────────────┐
│         Flutter App (Android)     │
│  SQLite 本地数据 · Riverpod 状态  │
│  SM-2/IRT/FSRS 算法 · LLM 诊断   │
└──────────┬───────────────────────┘
           │  HTTP / SSE
┌──────────▼───────────────────────┐
│       FastAPI 后端 (可选)          │
│  LLM 代理 · RAG (联网+本地知识库)  │
│  ChromaDB 向量存储 · 管理后台      │
└──────────────────────────────────┘
```

App 可**独立运行**（直连 LLM API），也可配合后端获得 RAG 增强能力。

---

## 核心特性

### 移动端 (Flutter)

- **SM-2 + IRT 双层融合调度** — 在经典 SM-2 间隔重复的基础上，引入 IRT(1PL) 能力估计动态调整复习间隔
- **多维记忆质量评分 (QS)** — 综合置信度、响应时间、正确性、犹豫次数，替代 SM-2 原始 0-5 评分
- **FSRS 遗忘曲线** — 幂律衰减模型预测能力遗忘，展示实时有效能力值
- **LLM 智能诊断** — 接入 OpenAI 兼容 API（默认 MiniMax），支持：
  - 文本 → 结构化题目导入（含干扰项分析）
  - 答题组 / 综合认知诊断报告（自动 & 手动触发）
  - 流式 AI 对话（Markdown 渲染 + thinking 折叠展示）
  - AI 伴学引导式答疑
- **13+ 精美页面** — Material Design 3 紫色系主题，渐变卡片、玻璃态效果、动画数字、深浅色模式

### 后端 (FastAPI)

- **LLM 代理** — 统一转发 LLM 请求，支持非流式和 SSE 流式响应
- **双路 RAG** — 联网搜索（DuckDuckGo）+ 本地知识库向量检索，结果融合后注入 Prompt
- **本地知识库** — 文本/文件上传 → 自动分块 → BGE 中文 Embedding → ChromaDB 持久化
- **Web 管理后台** — 浏览器访问 `/admin`，可管理本地知识库文档、测试 RAG 问答

---

## 技术栈

| 层级 | 技术 |
|------|------|
| 移动端框架 | Flutter (Dart) |
| 目标平台 | Android |
| 本地数据库 | SQLite via `sqflite` |
| 状态管理 | `flutter_riverpod` (Riverpod 3.x) |
| LLM | OpenAI 兼容 API（默认 MiniMax `MiniMax-M2.7`） |
| HTTP 客户端 | `dio` (Flutter) / `httpx` (后端) |
| 图表 | `fl_chart` |
| 后端框架 | FastAPI + Uvicorn |
| 向量数据库 | ChromaDB |
| 中文 Embedding | `sentence-transformers` (BAAI/bge-small-zh-v1.5) |
| 联网搜索 | `ddgs` (DuckDuckGo) |
| 其他 | `flutter_markdown`, `uuid`, `path_provider`, `shared_preferences`, `file_picker`, `share_plus`, `sse-starlette` |

---

## 项目结构

```
├── lib/                                  # Flutter 移动端
│   ├── main.dart                         # 入口
│   ├── app.dart                          # 导航壳（底部导航 4 页）
│   ├── core/algorithms/                  # 核心算法
│   │   ├── quality_score.dart            #   QS 多维记忆质量评分
│   │   ├── sm2_engine.dart               #   SM-2 间隔重复引擎
│   │   ├── irt_engine.dart               #   IRT(1PL) 能力估计
│   │   ├── scheduler.dart                #   融合调度器
│   │   └── ability_decay.dart            #   FSRS 幂律遗忘衰减
│   ├── data/
│   │   ├── database/database_helper.dart #   SQLite 建表+CRUD+样例数据
│   │   └── models/                       #   数据模型
│   ├── features/                         #   各功能页面
│   │   ├── home/                         #     首页 Dashboard
│   │   ├── study/                        #     答题 + 结果 + 结算
│   │   ├── question_bank/                #     题库管理 + AI 导入
│   │   ├── ability/                      #     能力曲线详情
│   │   ├── queue/                        #     复习队列可视化
│   │   ├── chat/                         #     AI 对话
│   │   ├── diagnosis/                    #     诊断报告列表+详情
│   │   ├── knowledge_base/               #     本地知识库管理
│   │   └── settings/                     #     设置（LLM+后端+画像）
│   ├── llm/
│   │   ├── llm_client.dart               #   LLM 客户端（流式 SSE）
│   │   ├── backend_client.dart           #   后端 API 客户端
│   │   ├── prompts/                      #   Prompt 模板
│   │   └── services/                     #   LLM 服务层
│   ├── providers/                        #   Riverpod 状态管理
│   └── shared/                           #   主题 + 常量
│
├── backend/                              # FastAPI 后端
│   ├── main.py                           #   应用入口 + CORS + 路由注册
│   ├── config.py                         #   Pydantic Settings（.env 配置）
│   ├── models/schemas.py                 #   请求/响应 Pydantic 模型
│   ├── routers/
│   │   ├── llm.py                        #   /api/llm/* LLM 代理
│   │   ├── rag.py                        #   /api/rag/* RAG 问答
│   │   ├── docs.py                       #   /api/docs/* 知识库文档管理
│   │   └── admin.py                      #   /admin 管理后台 (内嵌 HTML)
│   └── services/
│       ├── llm_service.py                #   LLM 调用（非流式+SSE）
│       ├── rag_service.py                #   双路 RAG 编排
│       └── vector_service.py             #   ChromaDB 向量存储
│
├── android/                              # Android 工程配置
└── plan/                                 # 历史规划文档
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

## 快速开始

### 一、Flutter App

#### 环境要求

- Flutter SDK ≥ 3.10
- Android SDK
- Dart ≥ 3.10

#### 构建运行

```bash
flutter pub get
flutter run
flutter build apk --debug
```

#### LLM 配置

App 内置默认 MiniMax API Key，开箱即用。如需更换：
- 打开 App → 设置 → LLM 配置
- 支持任何 OpenAI 兼容格式的 API（如 DeepSeek、OpenAI 等）

### 二、FastAPI 后端（可选）

后端为可选组件，提供 RAG 增强和知识库管理能力。

#### 环境要求

- Python 3.10+（推荐 Miniconda）

#### 安装 & 启动

```bash
# 创建 conda 环境
conda create -n memory_backend python=3.11 -y
conda activate memory_backend

# 安装依赖
cd backend
pip install -r requirements.txt

# 配置环境变量（复制 .env.example 并填写 API Key）
cp .env.example .env
# 编辑 .env，填入 LLM_API_KEY

# 启动服务
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

#### 连接 App

在 App 设置页 → 后端服务 → 填入后端地址（如 `http://192.168.x.x:8000`），保存后 AI 对话和伴学将自动启用 RAG。

#### 管理后台

浏览器打开 `http://localhost:8000/admin`，可以：
- 管理本地知识库（添加文本、上传文件、删除文档）
- 测试 RAG 问答（切换联网搜索 / 本地知识库）

#### 后端 API 概览

| 端点 | 方法 | 说明 |
|------|------|------|
| `/api/health` | GET | 健康检查 |
| `/api/llm/chat` | POST | LLM 对话代理（支持 SSE 流式） |
| `/api/rag/query` | POST | RAG 问答（联网 + 本地知识库） |
| `/api/docs/text` | POST | 添加文本到知识库 |
| `/api/docs/upload` | POST | 上传文件到知识库 |
| `/api/docs/list` | GET | 列出所有知识库文档 |
| `/api/docs/{doc_id}` | DELETE | 删除知识库文档 |
| `/admin` | GET | Web 管理后台 |

---

## 页面预览

| 页面 | 功能 |
|------|------|
| 首页 Dashboard | 渐变头图、待复习数、能力值卡片、学习统计动画、薄弱 TOP3 |
| 复习答题 | 进度条、计时器、犹豫计数、信心评分（可关闭）、10 题上限 |
| 答题结果 | 选项回顾（绿/红标注）、解析、底部固定 AI 伴学入口 |
| 答题结算 | 正确率统计、AI 诊断报告实时生成与查看 |
| AI 对话 | 流式气泡、Markdown 渲染、thinking 折叠、RAG 增强 |
| AI 伴学 | 基于当前题目的引导式答疑，支持 RAG 上下文 |
| 题库管理 | 按知识点分组、难度色条、AI 导入 / 手动添加 |
| 能力详情 | 有效 θ、衰减曲线（蓝实线+橙虚线预测）、稳定性/半衰期 |
| 诊断报告 | 答题组报告 / 总报告 Tab、能力评估、薄弱点柱状图 |
| 知识库管理 | 添加/删除本地知识库文档（需配置后端） |
| 设置 | 用户画像、LLM 配置、后端配置、自定义 Prompt、信心评分开关 |

---

## 与毕设论文对应

| 论文章节 | 项目模块 |
|----------|----------|
| 第 1 章 绪论 | 整体项目背景 |
| 第 2 章 相关技术 | SM-2 / IRT / FSRS 原理、Flutter、LLM、RAG |
| 第 3 章 需求分析与总体设计 | 架构图、数据流图（前后端分离） |
| 第 4 章 核心算法设计 | SM2 + IRT + QS + Scheduler + AbilityDecay |
| 第 5 章 LLM 智能诊断 | Prompt 设计、诊断报告、对话系统、RAG 增强 |
| 第 6 章 详细设计与实现 | DB Schema、类结构、UI、后端 API |
| 第 7 章 测试与分析 | 算法验证、对比实验 |
| 第 8 章 总结与展望 | 创新点归纳 |

---

## 核心创新点

1. **SM-2 + IRT 双层解耦调度** — 微观 SM-2 管理单题间隔，宏观 IRT 估计全局能力并动态调整
2. **QS 多维记忆质量评分** — 融合置信度、响应时间、正确性、犹豫行为，比单一正误更精准
3. **LLM 驱动认知诊断闭环** — 自动生成诊断报告 → 定位薄弱点 → 协同调度 → 针对性复习
4. **RAG 增强学习辅助** — 联网搜索 + 本地知识库双路检索，让 AI 回答更准确、更贴合用户知识体系

---

## License

本项目为毕业设计作品，仅供学术交流使用。
