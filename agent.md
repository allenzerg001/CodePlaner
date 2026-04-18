# CodingPlan — Agent 工作指南

本文件为 AI 智能体（agentic workers）在此代码库执行任务时的操作规范。

## 关键约束

- **不得发送真实厂商 API 请求**：所有测试必须使用 Mock，绝不消耗真实 API 额度
- **API Key 加密**：如需写入配置，始终调用 `crypto.py` 的加密函数，禁止明文存储
- **端口固定**：服务默认监听 `127.0.0.1:9800`，不得修改默认值
- **Python 版本**：兼容 Python 3.9+，不使用 3.10+ 专属语法（如 `match`）

## 代码库导航

### Python 服务入口

- `service/src/main.py` — FastAPI 应用创建、路由注册、启动配置
- `service/src/models.py` — 所有 Pydantic 请求/响应模型定义
- `service/src/config.py` — 配置加载逻辑和预制厂商表

### 核心链路（请求处理顺序）

```
routers/openai.py 或 routers/anthropic.py
  → core/router.py        # 解析 provider/model
  → providers/<name>.py   # 厂商适配器
  → core/converter.py     # 格式转换（如需要）
  → core/fallback.py      # 失败时触发
  → core/usage.py         # 记录用量
```

### 添加新功能的检查清单

**新增厂商适配器：**
- [ ] `service/src/providers/<name>.py` — 继承 `BaseProvider`，实现 `chat_completions()` 和 `stream_chat_completions()`
- [ ] `service/src/providers/__init__.py` — 注册到 `PROVIDER_REGISTRY`
- [ ] `service/src/config.py` — 添加预制厂商配置（base_url、默认模型列表）
- [ ] `service/tests/test_providers/test_<name>.py` — Mock HTTP 测试

**新增 API 端点：**
- [ ] 在对应 `service/src/routers/` 文件中添加路由
- [ ] 在 `service/src/models.py` 中添加 Pydantic 模型
- [ ] 在 `service/tests/` 中添加集成测试

**修改 Swift 应用：**
- [ ] UI 变更在对应 `Views/*.swift` 中实现
- [ ] 网络调用通过 `Services/UsageStatsService.swift` 或新建 Service
- [ ] 配置变更通过 `Services/ConfigManager.swift`

## 测试执行

```bash
# 标准测试（在 service/ 目录下）
cd service && pytest

# 带覆盖率
pytest --cov=src --cov-report=term-missing

# 只运行特定模块测试
pytest tests/test_router.py tests/test_converter.py -v

# 端到端测试
pytest tests/test_e2e_openai.py tests/test_e2e_anthropic.py -v
```

覆盖率目标：≥ 80%（当前：81%）

## Mock 规范

测试中使用 `service/tests/mocks/` 下的工具：

```python
# mock_responses.py — 预定义各厂商标准响应
from tests.mocks.mock_responses import bailian_chat_response, deepseek_stream_chunk

# mock_providers.py — httpx MockTransport
from tests.mocks.mock_providers import MockProviderTransport
```

`conftest.py` 提供共享 fixtures：`test_client`、`mock_config`、`mock_provider_response`

## 格式转换规则

`core/converter.py` 处理双向转换：

| 方向 | 函数 | 关键映射 |
|------|------|----------|
| OpenAI → Anthropic | `openai_to_anthropic()` | `messages` → `messages`，`tools` → `tools`（格式不同） |
| Anthropic → OpenAI | `anthropic_to_openai()` | `content[]` → `message.content`，`tool_use` → `tool_calls` |
| Streaming chunk | `convert_stream_chunk()` | SSE delta 格式对齐 |

## 厂商路由解析

`core/router.py` 的 `parse_model_string(model: str)` 返回 `(provider_id, model_name)`：

- `"bailian/qwen-max"` → `("bailian", "qwen-max")`
- `"qwen-max"` → `(default_provider, "qwen-max")`
- 未知 provider → 抛出 `ProviderNotFoundError`

## 故障转移行为

`core/fallback.py` 在以下情况触发 fallback：
- HTTP 5xx 响应
- 连接超时（`httpx.TimeoutException`）
- 配额耗尽（厂商返回特定错误码）

fallback 时：保留原始对话内容，替换 provider 和 model 为默认厂商的默认模型。

`fallback_enabled: false` 时直接向客户端返回错误。

## Swift ↔ Python 通信

Swift 通过 `UsageStatsService.swift` 调用 Python 管理端点：

```swift
// 查询用量
GET http://127.0.0.1:9800/admin/usage

// 热重载配置（Swift 写完 config.json 后调用）
POST http://127.0.0.1:9800/admin/reload-config

// 检查服务状态
GET http://127.0.0.1:9800/admin/status
```

Python 进程由 `PythonProcessManager.swift` 管理：App 启动时启动、退出时终止。

## 常见任务模式

### 调试路由问题
1. 检查 `core/router.py` 的 `parse_model_string()`
2. 确认 `config.py` 中该 provider 已注册且 `enabled: true`
3. 运行 `pytest tests/test_router.py -v`

### 调试格式转换问题
1. 检查 `core/converter.py` 对应方向的函数
2. 对比厂商 API 文档的实际响应结构
3. 运行 `pytest tests/test_converter.py -v`

### 调试 streaming 问题
1. 检查对应 provider 的 `stream_chat_completions()` 实现
2. 检查 `core/converter.py` 的 `convert_stream_chunk()`
3. 运行 `pytest tests/test_e2e_streaming.py -v`

## 文件命名约定

- Provider 适配器：`service/src/providers/<provider_id>.py`（snake_case）
- Provider 测试：`service/tests/test_providers/test_<provider_id>.py`
- 路由测试：`service/tests/test_<router_name>.py`
- E2E 测试：`service/tests/test_e2e_<scenario>.py`
