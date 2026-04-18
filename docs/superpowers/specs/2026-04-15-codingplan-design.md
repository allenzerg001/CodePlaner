# CodingPlan — 本地 Coding Plan 聚合网关

## 概述

CodingPlan 是一个 macOS 本地应用，提供 OpenAI/Anthropic 双协议兼容的 API 网关，聚合国内各大厂商的 Coding Plan 服务（百炼、火山引擎、智谱、MiniMax、小米、DeepSeek、月之暗面等）。AI Coding IDE（Claude Code、Codex、Gemini CLI 等）只需接入本地这一个服务，即可使用所有厂商的模型，新增厂商无需重新配置 IDE。

## 技术栈

| 组件 | 技术 |
|------|------|
| UI / 菜单栏 App | Swift (原生 macOS) |
| API 代理服务 | Python + FastAPI |
| 通信方式 | Swift 管理 Python 子进程，Python 服务监听 localhost HTTP |
| 配置存储 | JSON 文件 (`~/.codingplan/config.json`) |
| API Key 存储 | AES-256-GCM 加密，密钥存 macOS Keychain |
| 用量统计 | SQLite (`~/.codingplan/usage.db`) |

## 架构

```
AI Coding IDEs (Claude Code / Codex / Gemini CLI)
        │
        │ OpenAI / Anthropic API 格式
        ▼
┌─────────────────────────────────────┐
│  Python Service (FastAPI)            │
│  监听 localhost:9800                 │
│                                      │
│  API 适配层                          │
│  ├─ POST /v1/chat/completions       │
│  ├─ POST /v1/messages               │
│  ├─ GET  /v1/models                 │
│  ├─ POST /v1/messages/count_tokens  │
│  ├─ GET  /admin/status              │
│  ├─ GET  /admin/usage               │
│  ├─ POST /admin/reload-config       │
│  └─ GET  /admin/providers           │
│                                      │
│  核心层                              │
│  ├─ 路由层 (provider/model → 厂商)   │
│  ├─ 格式转换 (OpenAI ↔ Anthropic)    │
│  ├─ 故障转移 (自动 fallback 默认厂商) │
│  ├─ 用量统计层                      │
│  └─ Provider 适配器 (可插拔)         │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  Swift App (主进程)                  │
│  ├─ 菜单栏 UI                       │
│  ├─ 设置界面 (厂商配置、API Key)     │
│  ├─ 用量面板 (图表、日志、预警)      │
│  ├─ Python 进程生命周期管理          │
│  └─ 配置文件读写                    │
└─────────────────────────────────────┘
```

## 预制厂商

| 厂商 | 标识 | Base URL | 模型示例 |
|------|------|----------|----------|
| 百炼 (阿里) | `bailian` | `https://dashscope.aliyuncs.com/compatible-mode/v1` | qwen-max, qwen-plus, qwen-coder |
| 火山引擎 (字节) | `volcengine` | `https://ark.cn-beijing.volces.com/api/v3` | doubao-pro, doubao-lite |
| 智谱 | `zhipu` | `https://open.bigmodel.cn/api/paas/v4` | glm-4, glm-4-flash |
| MiniMax | `minimax` | `https://api.minimax.chat/v1` | abab6.5s-chat |
| 小米 | `xiaomi` | `https://api.xiaomi.com/v1` | miLM-Pro |
| DeepSeek | `deepseek` | `https://api.deepseek.com/v1` | deepseek-chat, deepseek-coder |
| 月之暗面 (Kimi) | `moonshot` | `https://api.moonshot.cn/v1` | moonshot-v1-128k |

- 用户只需填 API Key，Base URL 和模型名预制
- 支持自定义厂商：用户手动填 Base URL + Key，自动探测模型列表（调用 `/v1/models`）

## API 接口

### OpenAI 格式端点

| 端点 | 说明 |
|------|------|
| `POST /v1/chat/completions` | 核心对话接口，支持 streaming (SSE)、tool_calls、multi-turn |
| `GET /v1/models` | 模型列表，聚合所有已启用厂商的模型 |

### Anthropic 格式端点

| 端点 | 说明 |
|------|------|
| `POST /v1/messages` | 核心对话接口，支持 streaming、tool_use、multi-turn |
| `POST /v1/messages/count_tokens` | token 计数 |

### 内部管理端点 (Swift ↔ Python)

| 端点 | 说明 |
|------|------|
| `GET /admin/status` | 服务状态、各厂商连通性 |
| `GET /admin/usage` | 用量统计数据 |
| `POST /admin/reload-config` | 热重载配置 |
| `GET /admin/providers` | 厂商列表 + 模型列表 |

### 路由逻辑

- 请求中 `model` 字段格式为 `provider/model_name`（如 `bailian/qwen-max`）
- 解析出 provider → 查找对应适配器 → 格式转换 → 转发
- 若无 provider 前缀，使用当前默认厂商

### 故障转移

- 当某厂商请求失败（额度耗尽、服务不可用、超时），自动 fallback 到默认厂商
- fallback 请求保留原始对话上下文，仅替换模型为目标厂商的默认模型

### 兼容特性

- SSE streaming (`"stream": true`)
- tool_calls / function_calling（OpenAI 格式）
- tool_use（Anthropic 格式）
- system prompt 支持
- multi-turn conversations
- temperature, top_p 等参数透传

## Swift App 设计

### 菜单栏

```
菜单栏图标: [●] CodingPlan

下拉菜单:
├─ 当前: 百炼 / qwen-max
├─ ──────────────────
├─ 厂商切换 ▸
│   ├─ ☑ 百炼 (qwen-max, qwen-plus)
│   ├─ ☐ 火山引擎 (doubao-pro)
│   ├─ ☐ 智谱 (glm-4)
│   ├─ ☐ DeepSeek (deepseek-chat)
│   ├─ ────────────
│   └─ ○ 使用自动选择
├─ ──────────────────
├─ 今日用量
│   ├─ 请求数: 47  │ Token: 128.3k
│   └─ 预估费用: ¥3.82
├─ ──────────────────
├─ 📊 打开用量面板...
├─ ⚙️ 设置...
├─ ──────────────────
├─ 服务状态: ● 运行中 (localhost:9800)
└─ 退出 CodingPlan
```

### 设置界面

- 厂商列表（预制 + 自定义）
- 每个厂商：启用/禁用开关、API Key 输入框（不展示已存储的 Key）
- 默认厂商选择
- 自定义厂商：添加 Base URL、API Key，自动探测模型
- 故障转移开关
- 服务端口配置

### 用量面板（独立窗口）

- 各厂商今日/本周/本月用量柱状图
- 请求日志（时间、厂商、模型、token 数、耗时）
- 配额预警（余额低于阈值时状态栏图标变色）

## 配置文件

路径：`~/.codingplan/config.json`

```json
{
  "default_provider": "bailian",
  "fallback_enabled": true,
  "server": {
    "host": "127.0.0.1",
    "port": 9800
  },
  "providers": {
    "bailian": {
      "enabled": true,
      "base_url": "https://dashscope.aliyuncs.com/compatible-mode/v1",
      "api_key_encrypted": "base64:xxxxx",
      "models": ["qwen-max", "qwen-plus", "qwen-coder"]
    },
    "volcengine": {
      "enabled": false,
      "base_url": "https://ark.cn-beijing.volces.com/api/v3",
      "api_key_encrypted": "",
      "models": []
    }
  },
  "custom_providers": {
    "my_provider": {
      "enabled": true,
      "base_url": "https://api.example.com/v1",
      "api_key_encrypted": "base64:xxxxx",
      "models": []
    }
  }
}
```

## 项目结构

```
CodingPlaner/
├── app/                          # Swift App
│   ├── CodingPlan.xcodeproj
│   ├── Sources/
│   │   ├── AppDelegate.swift
│   │   ├── StatusBarController.swift
│   │   ├── SettingsWindow.swift
│   │   ├── UsageWindow.swift
│   │   ├── PythonProcessManager.swift
│   │   ├── ConfigManager.swift
│   │   ├── KeychainManager.swift
│   │   └── UsageStats.swift
│   └── Resources/
│       └── Assets.xcassets
├── service/                      # Python Service
│   ├── pyproject.toml
│   ├── src/
│   │   ├── main.py              # FastAPI 入口
│   │   ├── routers/
│   │   │   ├── openai.py        # /v1/chat/completions, /v1/models
│   │   │   ├── anthropic.py     # /v1/messages, /v1/messages/count_tokens
│   │   │   └── admin.py         # /admin/* 管理端点
│   │   ├── core/
│   │   │   ├── router.py        # provider/model 路由
│   │   │   ├── converter.py     # 格式转换 (OpenAI ↔ Anthropic)
│   │   │   ├── fallback.py      # 故障转移逻辑
│   │   │   └── usage.py         # 用量统计
│   │   ├── providers/
│   │   │   ├── base.py          # Provider 抽象基类
│   │   │   ├── bailian.py
│   │   │   ├── volcengine.py
│   │   │   ├── zhipu.py
│   │   │   ├── minimax.py
│   │   │   ├── xiaomi.py
│   │   │   ├── deepseek.py
│   │   │   ├── moonshot.py
│   │   │   └── custom.py        # 自定义厂商适配器
│   │   ├── config.py            # 配置加载
│   │   └── models.py            # Pydantic 数据模型
│   └── tests/
├── docs/
│   └── superpowers/
│       └── specs/
│           └── 2026-04-15-codingplan-design.md
├── CLAUDE.md
└── README.md
```

## 用户使用流程

1. 安装 CodingPlan.app
2. 首次启动 → 设置界面自动弹出
3. 选择要启用的厂商 → 填入 API Key
4. 点击"测试连通性" → 自动探测可用模型
5. 服务自动启动 (localhost:9800)
6. 在 AI Coding IDE 中配置：
   - Base URL: `http://localhost:9800`
   - API Key: 任意非空值（本地服务不校验）
7. 使用时指定模型：`bailian/qwen-max` 或 `deepseek/deepseek-chat`
8. 菜单栏实时显示当前模型和用量

## 测试策略 (Python Service)

测试框架：pytest + pytest-asyncio + httpx (TestClient)

### 单元测试

| 模块 | 测试文件 | 覆盖内容 |
|------|----------|----------|
| `router.py` | `tests/test_router.py` | `bailian/qwen-max` 格式解析、无前缀时使用默认厂商、未知厂商抛异常 |
| `converter.py` | `tests/test_converter.py` | OpenAI → Anthropic 格式转换、Anthropic → OpenAI 格式转换、streaming chunk 转换、tool_calls ↔ tool_use 双向转换 |
| `fallback.py` | `tests/test_fallback.py` | 请求失败触发 fallback、fallback 使用默认厂商默认模型、连续失败上限处理、fallback 禁用时直接报错 |
| `usage.py` | `tests/test_usage.py` | 记录请求、token 统计累加、按厂商/日期聚合查询、费用计算 |
| `config.py` | `tests/test_config.py` | 配置文件加载、API Key 解密、配置热重载、缺失字段默认值 |
| `providers/base.py` | `tests/test_provider_base.py` | 抽象基类接口约束、流式响应迭代 |

### 集成测试

| 场景 | 测试文件 | 覆盖内容 |
|------|----------|----------|
| OpenAI Chat Completions | `tests/test_openai_chat.py` | 非流式请求、流式 SSE 请求、tool_calls 请求、多轮对话、无效 model 报 404 |
| Anthropic Messages | `tests/test_anthropic_messages.py` | 非流式请求、流式 SSE 请求、tool_use 请求、多轮对话、count_tokens 端点 |
| Models 列表 | `tests/test_models.py` | 返回所有已启用厂商模型、禁用厂商模型不出现在列表中 |
| Admin 端点 | `tests/test_admin.py` | status 端点返回厂商连通性、usage 端点返回统计数据、reload-config 热重载 |
| 故障转移 | `tests/test_fallback_integration.py` | Mock 厂商返回 500 → 自动 fallback、Mock 厂商超时 → 自动 fallback、fallback 后响应格式正确 |

### Provider 适配器测试

每个厂商适配器使用 Mock HTTP 客户端测试，不发真实请求：

| 测试文件 | 覆盖内容 |
|----------|----------|
| `tests/test_providers/test_bailian.py` | 请求构造（headers、body 格式）、响应解析、流式 chunk 解析 |
| `tests/test_providers/test_volcengine.py` | 同上 |
| `tests/test_providers/test_zhipu.py` | 同上 |
| `tests/test_providers/test_custom.py` | 自定义厂商请求/响应处理、模型自动发现 |

### 端到端测试

使用 httpx TestClient 启动完整 FastAPI 应用，Mock 所有外部厂商 HTTP 请求：

| 测试文件 | 覆盖内容 |
|----------|----------|
| `tests/test_e2e_openai.py` | 完整 OpenAI 格式请求链路：IDE 请求 → 路由 → 格式转换 → Mock 厂商 → 响应返回 |
| `tests/test_e2e_anthropic.py` | 完整 Anthropic 格式请求链路：IDE 请求 → 路由 → 格式转换 → Mock 厂商 → 响应返回 |
| `tests/test_e2e_fallback.py` | 完整故障转移链路：主厂商 Mock 返回错误 → 自动 fallback → 成功返回 |
| `tests/test_e2e_streaming.py` | 完整流式请求链路：SSE 流式响应逐 chunk 正确转发、stream 结束标记正确 |

### 测试工具

```
service/tests/
├── conftest.py              # 共享 fixtures (mock config、TestClient、mock provider responses)
├── mocks/
│   ├── __init__.py
│   ├── mock_responses.py    # 各厂商标准响应的 mock 数据
│   └── mock_providers.py    # httpx MockTransport，模拟厂商 API 行为
├── test_router.py
├── test_converter.py
├── test_fallback.py
├── test_usage.py
├── test_config.py
├── test_provider_base.py
├── test_openai_chat.py
├── test_anthropic_messages.py
├── test_models.py
├── test_admin.py
├── test_fallback_integration.py
├── test_providers/
│   ├── test_bailian.py
│   ├── test_volcengine.py
│   ├── test_zhipu.py
│   └── test_custom.py
├── test_e2e_openai.py
├── test_e2e_anthropic.py
├── test_e2e_fallback.py
└── test_e2e_streaming.py
```

## 验收标准

- [ ] FastAPI 服务启动后监听 localhost:9800
- [ ] `POST /v1/chat/completions` 正确路由到对应厂商，支持 streaming
- [ ] `POST /v1/messages` 正确转换 Anthropic 格式，支持 streaming + tool_use
- [ ] `GET /v1/models` 返回所有已启用厂商的模型列表
- [ ] 至少完成 3 家厂商适配器（百炼、智谱、DeepSeek）
- [ ] 故障转移：厂商请求失败自动 fallback 到默认厂商
- [ ] Swift App 菜单栏显示当前厂商/模型和今日用量
- [ ] 设置界面可配置 API Key、启用/禁用厂商、选择默认厂商
- [ ] API Key 加密存储，界面不展示已存 Key
- [ ] App 退出时 Python 服务自动关闭
- [ ] Python 服务单元测试覆盖率 ≥ 80%
- [ ] 集成测试覆盖所有 API 端点（OpenAI + Anthropic + Admin）
- [ ] 端到端测试覆盖核心链路（非流式、流式、故障转移）
- [ ] 所有测试通过 `pytest` 命令一键执行
