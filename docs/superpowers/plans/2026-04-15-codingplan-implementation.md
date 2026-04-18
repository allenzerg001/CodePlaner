# CodingPlan Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a local macOS app (Swift UI + Python FastAPI service) that aggregates domestic Chinese AI Coding Plan providers into a single OpenAI/Anthropic dual-format API gateway.

**Architecture:** Swift app manages a Python FastAPI child process that listens on localhost:9800. The Python service accepts both OpenAI (`/v1/chat/completions`) and Anthropic (`/v1/messages`) API formats, routes by `provider/model` name, converts formats, forwards to domestic providers, and tracks usage. Swift provides menu bar UI, settings, and usage dashboard.

**Tech Stack:** Python 3.11+, FastAPI, httpx, uvicorn, pytest, Swift 5, SwiftUI

**Spec:** `docs/superpowers/specs/2026-04-15-codingplan-design.md`

---

## File Structure

```
CodingPlaner/
├── service/
│   ├── pyproject.toml
│   ├── src/
│   │   ├── __init__.py
│   │   ├── main.py
│   │   ├── models.py
│   │   ├── config.py
│   │   ├── crypto.py
│   │   ├── core/
│   │   │   ├── __init__.py
│   │   │   ├── router.py
│   │   │   ├── converter.py
│   │   │   ├── fallback.py
│   │   │   └── usage.py
│   │   ├── providers/
│   │   │   ├── __init__.py
│   │   │   ├── base.py
│   │   │   ├── bailian.py
│   │   │   ├── zhipu.py
│   │   │   ├── deepseek.py
│   │   │   ├── volcengine.py
│   │   │   ├── minimax.py
│   │   │   ├── xiaomi.py
│   │   │   ├── moonshot.py
│   │   │   └── custom.py
│   │   └── routers/
│   │       ├── __init__.py
│   │       ├── openai.py
│   │       ├── anthropic.py
│   │       └── admin.py
│   └── tests/
│       ├── conftest.py
│       ├── mocks/
│       │   ├── __init__.py
│       │   ├── mock_responses.py
│       │   └── mock_providers.py
│       ├── test_models.py
│       ├── test_config.py
│       ├── test_crypto.py
│       ├── test_router.py
│       ├── test_converter.py
│       ├── test_fallback.py
│       ├── test_usage.py
│       ├── test_provider_base.py
│       ├── test_openai_chat.py
│       ├── test_anthropic_messages.py
│       ├── test_models_endpoint.py
│       ├── test_admin.py
│       ├── test_fallback_integration.py
│       ├── test_providers/
│       │   ├── __init__.py
│       │   ├── test_bailian.py
│       │   ├── test_zhipu.py
│       │   └── test_deepseek.py
│       ├── test_e2e_openai.py
│       ├── test_e2e_anthropic.py
│       ├── test_e2e_fallback.py
│       └── test_e2e_streaming.py
├── app/
│   ├── CodingPlan/
│   │   ├── CodingPlanApp.swift
│   │   ├── AppDelegate.swift
│   │   ├── StatusBarController.swift
│   │   ├── Views/
│   │   │   ├── SettingsView.swift
│   │   │   ├── ProviderRowView.swift
│   │   │   ├── UsageDashboardView.swift
│   │   │   └── UsageChartView.swift
│   │   ├── Services/
│   │   │   ├── PythonProcessManager.swift
│   │   │   ├── ConfigManager.swift
│   │   │   ├── KeychainManager.swift
│   │   │   └── UsageStatsService.swift
│   │   └── Models/
│   │       ├── Provider.swift
│   │       └── UsageRecord.swift
│   └── CodingPlan.xcodeproj
└── docs/
    └── superpowers/
        └── specs/
            └── 2026-04-15-codingplan-design.md
```

---

## Phase 1: Python Service Core

### Task 1: Project Setup & Data Models

**Files:**
- Create: `service/pyproject.toml`
- Create: `service/src/__init__.py`
- Create: `service/src/models.py`
- Create: `service/tests/__init__.py`
- Create: `service/tests/test_models.py`

- [ ] **Step 1: Create pyproject.toml**

```toml
[project]
name = "codingplan-service"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = [
    "fastapi>=0.110.0",
    "uvicorn[standard]>=0.27.0",
    "httpx>=0.27.0",
    "pydantic>=2.6.0",
    "cryptography>=42.0.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=8.0.0",
    "pytest-asyncio>=0.23.0",
    "pytest-cov>=4.1.0",
]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.pytest.ini_options]
asyncio_mode = "auto"
testpaths = ["tests"]
```

- [ ] **Step 2: Write failing test for data models**

```python
# service/tests/test_models.py
import pytest
from pydantic import ValidationError
from src.models import ProviderConfig, ServerConfig, AppConfig, UsageRecord


def test_provider_config_defaults():
    p = ProviderConfig(enabled=True, base_url="https://api.example.com/v1")
    assert p.enabled is True
    assert p.api_key_encrypted == ""
    assert p.models == []


def test_provider_config_validation():
    with pytest.raises(ValidationError):
        ProviderConfig(enabled=True, base_url="")


def test_server_config_defaults():
    s = ServerConfig()
    assert s.host == "127.0.0.1"
    assert s.port == 9800


def test_app_config_defaults():
    c = AppConfig(
        providers={"test": ProviderConfig(enabled=True, base_url="https://api.example.com/v1")}
    )
    assert c.default_provider == "test"
    assert c.fallback_enabled is True
    assert c.custom_providers == {}


def test_usage_record():
    r = UsageRecord(
        provider="bailian",
        model="qwen-max",
        prompt_tokens=100,
        completion_tokens=200,
        total_tokens=300,
    )
    assert r.provider == "bailian"
    assert r.total_tokens == 300
    assert r.timestamp is not None
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd service && python -m pytest tests/test_models.py -v`
Expected: FAIL with ModuleNotFoundError

- [ ] **Step 4: Write data models**

```python
# service/src/models.py
from datetime import datetime
from pydantic import BaseModel, Field


class ProviderConfig(BaseModel):
    enabled: bool = True
    base_url: str = Field(..., min_length=1)
    api_key_encrypted: str = ""
    models: list[str] = []


class ServerConfig(BaseModel):
    host: str = "127.0.0.1"
    port: int = 9800


class AppConfig(BaseModel):
    default_provider: str = ""
    fallback_enabled: bool = True
    server: ServerConfig = ServerConfig()
    providers: dict[str, ProviderConfig] = {}
    custom_providers: dict[str, ProviderConfig] = {}


class UsageRecord(BaseModel):
    provider: str
    model: str
    prompt_tokens: int = 0
    completion_tokens: int = 0
    total_tokens: int = 0
    latency_ms: int = 0
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    cost_estimate: float = 0.0


class ProviderStatus(BaseModel):
    name: str
    enabled: bool
    connected: bool
    models: list[str] = []
    last_error: str | None = None
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd service && python -m pytest tests/test_models.py -v`
Expected: all PASS

- [ ] **Step 6: Commit**

```bash
git add service/pyproject.toml service/src/__init__.py service/src/models.py service/tests/__init__.py service/tests/test_models.py
git commit -m "feat(service): add project setup and data models"
```

---

### Task 2: Configuration & Crypto

**Files:**
- Create: `service/src/crypto.py`
- Create: `service/src/config.py`
- Create: `service/tests/test_crypto.py`
- Create: `service/tests/test_config.py`
- Create: `service/tests/conftest.py`

- [ ] **Step 1: Write failing tests for crypto**

```python
# service/tests/test_crypto.py
from src.crypto import encrypt_api_key, decrypt_api_key


def test_encrypt_decrypt_roundtrip():
    key = "sk-test-key-12345"
    encrypted = encrypt_api_key(key)
    assert encrypted != key
    assert decrypt_api_key(encrypted) == key


def test_encrypt_produces_base64():
    import base64
    encrypted = encrypt_api_key("test")
    base64.b64decode(encrypted)


def test_decrypt_invalid_returns_empty():
    assert decrypt_api_key("not-valid-base64!!") == ""
```

- [ ] **Step 2: Write failing tests for config**

```python
# service/tests/test_config.py
import json
import tempfile
from pathlib import Path
from src.config import ConfigManager
from src.models import ProviderConfig


def test_load_config_creates_default(tmp_path):
    config_file = tmp_path / "config.json"
    mgr = ConfigManager(str(config_file))
    cfg = mgr.load()
    assert cfg.server.port == 9800
    assert cfg.fallback_enabled is True


def test_load_config_from_file(tmp_path):
    config_file = tmp_path / "config.json"
    config_file.write_text(json.dumps({
        "default_provider": "bailian",
        "providers": {
            "bailian": {"enabled": True, "base_url": "https://api.test.com/v1"}
        }
    }))
    mgr = ConfigManager(str(config_file))
    cfg = mgr.load()
    assert cfg.default_provider == "bailian"
    assert "bailian" in cfg.providers


def test_save_and_reload_config(tmp_path):
    config_file = tmp_path / "config.json"
    mgr = ConfigManager(str(config_file))
    mgr.load()
    mgr.config.default_provider = "deepseek"
    mgr.save()
    mgr2 = ConfigManager(str(config_file))
    cfg2 = mgr2.load()
    assert cfg2.default_provider == "deepseek"


def test_set_provider_api_key(tmp_path):
    config_file = tmp_path / "config.json"
    mgr = ConfigManager(str(config_file))
    mgr.load()
    mgr.set_provider_api_key("bailian", "sk-my-key")
    cfg = mgr.get()
    assert cfg.providers["bailian"].api_key_encrypted != ""
    assert mgr.get_provider_api_key("bailian") == "sk-my-key"


def test_get_all_enabled_providers(tmp_path):
    config_file = tmp_path / "config.json"
    config_file.write_text(json.dumps({
        "providers": {
            "bailian": {"enabled": True, "base_url": "https://a.com/v1"},
            "zhipu": {"enabled": False, "base_url": "https://b.com/v1"},
        },
        "custom_providers": {
            "custom1": {"enabled": True, "base_url": "https://c.com/v1"}
        }
    }))
    mgr = ConfigManager(str(config_file))
    mgr.load()
    enabled = mgr.get_enabled_providers()
    assert set(enabled.keys()) == {"bailian", "custom1"}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `cd service && python -m pytest tests/test_crypto.py tests/test_config.py -v`
Expected: FAIL with ModuleNotFoundError

- [ ] **Step 4: Implement crypto module**

```python
# service/src/crypto.py
import base64
import os
import hashlib
from cryptography.hazmat.primitives.ciphers.aead import AESGCM


def _get_or_create_key() -> bytes:
    """Get encryption key from environment or generate a dev key."""
    key_str = os.environ.get("CODINGPLAN_CRYPTO_KEY", "codingplan-dev-key-change-in-prod")
    return hashlib.sha256(key_str.encode()).digest()


def encrypt_api_key(plain_text: str) -> str:
    if not plain_text:
        return ""
    key = _get_or_create_key()
    aesgcm = AESGCM(key)
    nonce = os.urandom(12)
    ciphertext = aesgcm.encrypt(nonce, plain_text.encode(), None)
    return base64.b64encode(nonce + ciphertext).decode()


def decrypt_api_key(encrypted: str) -> str:
    if not encrypted:
        return ""
    try:
        data = base64.b64decode(encrypted)
        key = _get_or_create_key()
        aesgcm = AESGCM(key)
        nonce, ciphertext = data[:12], data[12:]
        return aesgcm.decrypt(nonce, ciphertext, None).decode()
    except Exception:
        return ""
```

- [ ] **Step 5: Implement config manager**

```python
# service/src/config.py
import json
from pathlib import Path
from src.models import AppConfig, ProviderConfig, ServerConfig
from src.crypto import encrypt_api_key, decrypt_api_key

PRESET_PROVIDERS = {
    "bailian": {"base_url": "https://dashscope.aliyuncs.com/compatible-mode/v1"},
    "volcengine": {"base_url": "https://ark.cn-beijing.volces.com/api/v3"},
    "zhipu": {"base_url": "https://open.bigmodel.cn/api/paas/v4"},
    "minimax": {"base_url": "https://api.minimax.chat/v1"},
    "xiaomi": {"base_url": "https://api.xiaomi.com/v1"},
    "deepseek": {"base_url": "https://api.deepseek.com/v1"},
    "moonshot": {"base_url": "https://api.moonshot.cn/v1"},
}


class ConfigManager:
    def __init__(self, config_path: str = ""):
        if not config_path:
            home = Path.home()
            config_dir = home / ".codingplan"
            config_dir.mkdir(exist_ok=True)
            config_path = str(config_dir / "config.json")
        self.config_path = Path(config_path)
        self.config = AppConfig()

    def load(self) -> AppConfig:
        if self.config_path.exists():
            data = json.loads(self.config_path.read_text())
            self.config = AppConfig(**data)
        else:
            self._init_preset_providers()
            self.save()
        return self.config

    def _init_preset_providers(self):
        for name, info in PRESET_PROVIDERS.items():
            self.config.providers[name] = ProviderConfig(
                enabled=False,
                base_url=info["base_url"],
            )

    def save(self):
        self.config_path.write_text(self.config.model_dump_json(indent=2))

    def get(self) -> AppConfig:
        return self.config

    def set_provider_api_key(self, provider_name: str, api_key: str):
        encrypted = encrypt_api_key(api_key)
        if provider_name in self.config.providers:
            self.config.providers[provider_name].api_key_encrypted = encrypted
        elif provider_name in self.config.custom_providers:
            self.config.custom_providers[provider_name].api_key_encrypted = encrypted
        self.save()

    def get_provider_api_key(self, provider_name: str) -> str:
        if provider_name in self.config.providers:
            return decrypt_api_key(self.config.providers[provider_name].api_key_encrypted)
        if provider_name in self.config.custom_providers:
            return decrypt_api_key(self.config.custom_providers[provider_name].api_key_encrypted)
        return ""

    def get_enabled_providers(self) -> dict[str, ProviderConfig]:
        result = {}
        for name, cfg in self.config.providers.items():
            if cfg.enabled:
                result[name] = cfg
        for name, cfg in self.config.custom_providers.items():
            if cfg.enabled:
                result[name] = cfg
        return result
```

- [ ] **Step 6: Create conftest.py with shared fixtures**

```python
# service/tests/conftest.py
import json
import tempfile
from pathlib import Path
import pytest
from src.config import ConfigManager


@pytest.fixture
def tmp_config(tmp_path):
    config_file = tmp_path / "config.json"
    config_file.write_text(json.dumps({
        "default_provider": "bailian",
        "providers": {
            "bailian": {
                "enabled": True,
                "base_url": "https://dashscope.aliyuncs.com/compatible-mode/v1",
                "api_key_encrypted": "",
                "models": ["qwen-max", "qwen-plus"]
            },
            "zhipu": {
                "enabled": True,
                "base_url": "https://open.bigmodel.cn/api/paas/v4",
                "api_key_encrypted": "",
                "models": ["glm-4"]
            },
            "deepseek": {
                "enabled": False,
                "base_url": "https://api.deepseek.com/v1",
                "api_key_encrypted": "",
                "models": ["deepseek-chat"]
            }
        }
    }))
    mgr = ConfigManager(str(config_file))
    mgr.load()
    return mgr
```

- [ ] **Step 7: Run all tests to verify they pass**

Run: `cd service && python -m pytest tests/test_crypto.py tests/test_config.py tests/conftest.py -v`
Expected: all PASS

- [ ] **Step 8: Commit**

```bash
git add service/src/crypto.py service/src/config.py service/tests/test_crypto.py service/tests/test_config.py service/tests/conftest.py
git commit -m "feat(service): add config management and API key encryption"
```

---

### Task 3: Provider Base & Adapter Implementations

**Files:**
- Create: `service/src/providers/__init__.py`
- Create: `service/src/providers/base.py`
- Create: `service/src/providers/bailian.py`
- Create: `service/src/providers/zhipu.py`
- Create: `service/src/providers/deepseek.py`
- Create: `service/src/providers/custom.py`
- Create: `service/tests/test_provider_base.py`
- Create: `service/tests/mocks/__init__.py`
- Create: `service/tests/mocks/mock_responses.py`
- Create: `service/tests/mocks/mock_providers.py`
- Create: `service/tests/test_providers/__init__.py`
- Create: `service/tests/test_providers/test_bailian.py`
- Create: `service/tests/test_providers/test_zhipu.py`
- Create: `service/tests/test_providers/test_deepseek.py`

- [ ] **Step 1: Write failing test for provider base**

```python
# service/tests/test_provider_base.py
import pytest
from src.providers.base import BaseProvider


def test_base_provider_is_abstract():
    with pytest.raises(TypeError):
        BaseProvider(base_url="https://api.test.com/v1", api_key="sk-test")


def test_base_provider_interface():
    """Verify that concrete providers must implement required methods."""
    from src.providers.base import BaseProvider

    class IncompleteProvider(BaseProvider):
        pass

    with pytest.raises(TypeError):
        IncompleteProvider(base_url="https://test.com", api_key="sk-test")
```

- [ ] **Step 2: Implement provider base class**

```python
# service/src/providers/base.py
from abc import ABC, abstractmethod
from collections.abc import AsyncIterator
from src.models import UsageRecord


class BaseProvider(ABC):
    def __init__(self, base_url: str, api_key: str):
        self.base_url = base_url.rstrip("/")
        self.api_key = api_key

    @abstractmethod
    async def chat_completion(
        self,
        model: str,
        messages: list[dict],
        stream: bool = False,
        tools: list[dict] | None = None,
        **kwargs,
    ) -> dict | AsyncIterator[bytes]:
        """Send a chat completion request. Returns dict or async iterator of SSE bytes."""
        ...

    @abstractmethod
    async def list_models(self) -> list[str]:
        """List available models from the provider."""
        ...

    @abstractmethod
    def extract_usage(self, response: dict) -> UsageRecord:
        """Extract usage data from a response."""
        ...

    def get_headers(self) -> dict[str, str]:
        """Get HTTP headers for requests to this provider."""
        return {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }
```

- [ ] **Step 3: Write failing tests for bailian adapter**

```python
# service/tests/test_providers/test_bailian.py
import json
import pytest
from unittest.mock import AsyncMock, patch
import httpx
from src.providers.bailian import BailianProvider


@pytest.fixture
def provider():
    return BailianProvider(
        base_url="https://dashscope.aliyuncs.com/compatible-mode/v1",
        api_key="sk-test-key",
    )


def test_bailian_headers(provider):
    headers = provider.get_headers()
    assert headers["Authorization"] == "Bearer sk-test-key"
    assert headers["Content-Type"] == "application/json"


def test_bailian_extract_usage(provider):
    response = {
        "usage": {
            "prompt_tokens": 50,
            "completion_tokens": 100,
            "total_tokens": 150,
        }
    }
    record = provider.extract_usage(response)
    assert record.provider == "bailian"
    assert record.prompt_tokens == 50
    assert record.completion_tokens == 100
    assert record.total_tokens == 150


@pytest.mark.asyncio
async def test_bailian_chat_completion(provider):
    mock_response = httpx.Response(
        200,
        json={
            "id": "chatcmpl-test",
            "choices": [{"message": {"role": "assistant", "content": "Hello"}, "index": 0, "finish_reason": "stop"}],
            "usage": {"prompt_tokens": 10, "completion_tokens": 5, "total_tokens": 15},
        },
        request=httpx.Request("POST", "https://test.com/v1/chat/completions"),
    )
    with patch.object(provider, "_request", new_callable=AsyncMock, return_value=mock_response.json()):
        result = await provider.chat_completion(
            model="qwen-max",
            messages=[{"role": "user", "content": "Hello"}],
        )
        assert "choices" in result
        assert result["choices"][0]["message"]["content"] == "Hello"
```

- [ ] **Step 4: Implement bailian adapter**

```python
# service/src/providers/bailian.py
import httpx
from collections.abc import AsyncIterator
from src.providers.base import BaseProvider
from src.models import UsageRecord


class BailianProvider(BaseProvider):
    async def _request(self, path: str, data: dict) -> dict:
        async with httpx.AsyncClient(timeout=120.0) as client:
            resp = await client.post(
                f"{self.base_url}{path}",
                json=data,
                headers=self.get_headers(),
            )
            resp.raise_for_status()
            return resp.json()

    async def _stream_request(self, path: str, data: dict) -> AsyncIterator[bytes]:
        async with httpx.AsyncClient(timeout=120.0) as client:
            async with client.stream(
                "POST",
                f"{self.base_url}{path}",
                json=data,
                headers=self.get_headers(),
            ) as resp:
                resp.raise_for_status()
                async for chunk in resp.aiter_bytes():
                    yield chunk

    async def chat_completion(
        self,
        model: str,
        messages: list[dict],
        stream: bool = False,
        tools: list[dict] | None = None,
        **kwargs,
    ) -> dict | AsyncIterator[bytes]:
        data = {"model": model, "messages": messages, "stream": stream, **kwargs}
        if tools:
            data["tools"] = tools
        if stream:
            return self._stream_request("/chat/completions", data)
        return await self._request("/chat/completions", data)

    async def list_models(self) -> list[str]:
        try:
            result = await self._request("/models", {})
            return [m["id"] for m in result.get("data", [])]
        except Exception:
            return ["qwen-max", "qwen-plus", "qwen-coder"]

    def extract_usage(self, response: dict) -> UsageRecord:
        usage = response.get("usage", {})
        return UsageRecord(
            provider="bailian",
            model=response.get("model", "unknown"),
            prompt_tokens=usage.get("prompt_tokens", 0),
            completion_tokens=usage.get("completion_tokens", 0),
            total_tokens=usage.get("total_tokens", 0),
        )
```

- [ ] **Step 5: Run provider tests**

Run: `cd service && python -m pytest tests/test_provider_base.py tests/test_providers/test_bailian.py -v`
Expected: all PASS

- [ ] **Step 6: Implement zhipu and deepseek adapters (same pattern)**

```python
# service/src/providers/zhipu.py
import httpx
from collections.abc import AsyncIterator
from src.providers.base import BaseProvider
from src.models import UsageRecord


class ZhipuProvider(BaseProvider):
    async def _request(self, path: str, data: dict) -> dict:
        async with httpx.AsyncClient(timeout=120.0) as client:
            resp = await client.post(
                f"{self.base_url}{path}",
                json=data,
                headers=self.get_headers(),
            )
            resp.raise_for_status()
            return resp.json()

    async def _stream_request(self, path: str, data: dict) -> AsyncIterator[bytes]:
        async with httpx.AsyncClient(timeout=120.0) as client:
            async with client.stream(
                "POST", f"{self.base_url}{path}", json=data, headers=self.get_headers()
            ) as resp:
                resp.raise_for_status()
                async for chunk in resp.aiter_bytes():
                    yield chunk

    async def chat_completion(self, model, messages, stream=False, tools=None, **kwargs):
        data = {"model": model, "messages": messages, "stream": stream, **kwargs}
        if tools:
            data["tools"] = tools
        if stream:
            return self._stream_request("/chat/completions", data)
        return await self._request("/chat/completions", data)

    async def list_models(self) -> list[str]:
        try:
            result = await self._request("/models", {})
            return [m["id"] for m in result.get("data", [])]
        except Exception:
            return ["glm-4", "glm-4-flash"]

    def extract_usage(self, response):
        usage = response.get("usage", {})
        return UsageRecord(
            provider="zhipu",
            model=response.get("model", "unknown"),
            prompt_tokens=usage.get("prompt_tokens", 0),
            completion_tokens=usage.get("completion_tokens", 0),
            total_tokens=usage.get("total_tokens", 0),
        )
```

```python
# service/src/providers/deepseek.py
import httpx
from collections.abc import AsyncIterator
from src.providers.base import BaseProvider
from src.models import UsageRecord


class DeepseekProvider(BaseProvider):
    async def _request(self, path: str, data: dict) -> dict:
        async with httpx.AsyncClient(timeout=120.0) as client:
            resp = await client.post(
                f"{self.base_url}{path}",
                json=data,
                headers=self.get_headers(),
            )
            resp.raise_for_status()
            return resp.json()

    async def _stream_request(self, path: str, data: dict) -> AsyncIterator[bytes]:
        async with httpx.AsyncClient(timeout=120.0) as client:
            async with client.stream(
                "POST", f"{self.base_url}{path}", json=data, headers=self.get_headers()
            ) as resp:
                resp.raise_for_status()
                async for chunk in resp.aiter_bytes():
                    yield chunk

    async def chat_completion(self, model, messages, stream=False, tools=None, **kwargs):
        data = {"model": model, "messages": messages, "stream": stream, **kwargs}
        if tools:
            data["tools"] = tools
        if stream:
            return self._stream_request("/chat/completions", data)
        return await self._request("/chat/completions", data)

    async def list_models(self) -> list[str]:
        try:
            result = await self._request("/models", {})
            return [m["id"] for m in result.get("data", [])]
        except Exception:
            return ["deepseek-chat", "deepseek-coder"]

    def extract_usage(self, response):
        usage = response.get("usage", {})
        return UsageRecord(
            provider="deepseek",
            model=response.get("model", "unknown"),
            prompt_tokens=usage.get("prompt_tokens", 0),
            completion_tokens=usage.get("completion_tokens", 0),
            total_tokens=usage.get("total_tokens", 0),
        )
```

- [ ] **Step 7: Implement custom provider adapter**

```python
# service/src/providers/custom.py
import httpx
from collections.abc import AsyncIterator
from src.providers.base import BaseProvider
from src.models import UsageRecord


class CustomProvider(BaseProvider):
    def __init__(self, base_url: str, api_key: str, name: str = "custom"):
        super().__init__(base_url, api_key)
        self.name = name

    async def _request(self, path: str, data: dict) -> dict:
        async with httpx.AsyncClient(timeout=120.0) as client:
            resp = await client.post(
                f"{self.base_url}{path}",
                json=data,
                headers=self.get_headers(),
            )
            resp.raise_for_status()
            return resp.json()

    async def _stream_request(self, path: str, data: dict) -> AsyncIterator[bytes]:
        async with httpx.AsyncClient(timeout=120.0) as client:
            async with client.stream(
                "POST", f"{self.base_url}{path}", json=data, headers=self.get_headers()
            ) as resp:
                resp.raise_for_status()
                async for chunk in resp.aiter_bytes():
                    yield chunk

    async def chat_completion(self, model, messages, stream=False, tools=None, **kwargs):
        data = {"model": model, "messages": messages, "stream": stream, **kwargs}
        if tools:
            data["tools"] = tools
        if stream:
            return self._stream_request("/chat/completions", data)
        return await self._request("/chat/completions", data)

    async def list_models(self) -> list[str]:
        try:
            result = await self._request("/models", {})
            return [m["id"] for m in result.get("data", [])]
        except Exception:
            return []

    def extract_usage(self, response):
        usage = response.get("usage", {})
        return UsageRecord(
            provider=self.name,
            model=response.get("model", "unknown"),
            prompt_tokens=usage.get("prompt_tokens", 0),
            completion_tokens=usage.get("completion_tokens", 0),
            total_tokens=usage.get("total_tokens", 0),
        )
```

- [ ] **Step 8: Create provider factory**

```python
# service/src/providers/__init__.py
from src.providers.base import BaseProvider
from src.providers.bailian import BailianProvider
from src.providers.zhipu import ZhipuProvider
from src.providers.deepseek import DeepseekProvider
from src.providers.custom import CustomProvider
from src.models import ProviderConfig

PROVIDER_CLASSES: dict[str, type[BaseProvider]] = {
    "bailian": BailianProvider,
    "zhipu": ZhipuProvider,
    "deepseek": DeepseekProvider,
    "volcengine": CustomProvider,
    "minimax": CustomProvider,
    "xiaomi": CustomProvider,
    "moonshot": CustomProvider,
}


def create_provider(name: str, config: ProviderConfig, api_key: str) -> BaseProvider:
    cls = PROVIDER_CLASSES.get(name, CustomProvider)
    if cls is CustomProvider:
        return cls(base_url=config.base_url, api_key=api_key, name=name)
    return cls(base_url=config.base_url, api_key=api_key)
```

- [ ] **Step 9: Create mock helpers for tests**

```python
# service/tests/mocks/mock_responses.py

OPENAI_CHAT_RESPONSE = {
    "id": "chatcmpl-test123",
    "object": "chat.completion",
    "created": 1700000000,
    "model": "qwen-max",
    "choices": [
        {
            "index": 0,
            "message": {"role": "assistant", "content": "Hello! How can I help?"},
            "finish_reason": "stop",
        }
    ],
    "usage": {"prompt_tokens": 10, "completion_tokens": 8, "total_tokens": 18},
}

OPENAI_CHAT_STREAM_CHUNKS = [
    b'data: {"id":"chatcmpl-test","choices":[{"delta":{"role":"assistant","content":""},"index":0}]}\n\n',
    b'data: {"id":"chatcmpl-test","choices":[{"delta":{"content":"Hello"},"index":0}]}\n\n',
    b'data: {"id":"chatcmpl-test","choices":[{"delta":{"content":" world"},"index":0}]}\n\n',
    b'data: {"id":"chatcmpl-test","choices":[{"delta":{},"index":0,"finish_reason":"stop"}],"usage":{"prompt_tokens":5,"completion_tokens":2,"total_tokens":7}}\n\n',
    b"data: [DONE]\n\n",
]

ANTHROPIC_MESSAGE_RESPONSE = {
    "id": "msg-test123",
    "type": "message",
    "role": "assistant",
    "content": [{"type": "text", "text": "Hello! How can I help?"}],
    "model": "claude-sonnet-4-20250514",
    "stop_reason": "end_turn",
    "usage": {"input_tokens": 10, "output_tokens": 8},
}

ANTHROPIC_TOOL_USE_RESPONSE = {
    "id": "msg-test456",
    "type": "message",
    "role": "assistant",
    "content": [
        {"type": "text", "text": "I'll read that file for you."},
        {
            "type": "tool_use",
            "id": "toolu_abc123",
            "name": "read_file",
            "input": {"path": "/test.py"},
        },
    ],
    "model": "claude-sonnet-4-20250514",
    "stop_reason": "tool_use",
    "usage": {"input_tokens": 20, "completion_tokens": 15},
}
```

```python
# service/tests/mocks/mock_providers.py
import httpx
from unittest.mock import AsyncMock


def create_mock_transport(responses: dict[str, dict]):
    """Create an httpx mock transport that returns predefined responses by URL path."""

    async def handler(request: httpx.Request) -> httpx.Response:
        path = request.url.path
        if path in responses:
            data = responses[path]
            return httpx.Response(200, json=data, request=request)
        return httpx.Response(404, json={"error": "not found"}, request=request)

    return httpx.MockTransport(handler)
```

- [ ] **Step 10: Run all provider tests**

Run: `cd service && python -m pytest tests/test_provider_base.py tests/test_providers/ -v`
Expected: all PASS

- [ ] **Step 11: Commit**

```bash
git add service/src/providers/ service/tests/test_provider_base.py service/tests/mocks/ service/tests/test_providers/
git commit -m "feat(service): add provider base class and adapter implementations"
```

---

### Task 4: Router, Converter, Fallback, Usage

**Files:**
- Create: `service/src/core/__init__.py`
- Create: `service/src/core/router.py`
- Create: `service/src/core/converter.py`
- Create: `service/src/core/fallback.py`
- Create: `service/src/core/usage.py`
- Create: `service/tests/test_router.py`
- Create: `service/tests/test_converter.py`
- Create: `service/tests/test_fallback.py`
- Create: `service/tests/test_usage.py`

- [ ] **Step 1: Write failing tests for router**

```python
# service/tests/test_router.py
import pytest
from src.core.router import parse_model_name


def test_parse_provider_model():
    provider, model = parse_model_name("bailian/qwen-max")
    assert provider == "bailian"
    assert model == "qwen-max"


def test_parse_no_provider():
    provider, model = parse_model_name("qwen-max")
    assert provider is None
    assert model == "qwen-max"


def test_parse_multiple_slashes():
    provider, model = parse_model_name("volcengine/ep-20240101/doubao")
    assert provider == "volcengine"
    assert model == "ep-20240101/doubao"


def test_parse_empty_string():
    provider, model = parse_model_name("")
    assert provider is None
    assert model == ""
```

- [ ] **Step 2: Implement router**

```python
# service/src/core/router.py
def parse_model_name(model: str) -> tuple[str | None, str]:
    """Parse 'provider/model_name' format.

    Returns (provider_name, model_name). provider_name is None if no prefix.
    """
    if not model:
        return None, ""
    if "/" in model:
        parts = model.split("/", 1)
        return parts[0], parts[1]
    return None, model
```

- [ ] **Step 3: Run router tests**

Run: `cd service && python -m pytest tests/test_router.py -v`
Expected: all PASS

- [ ] **Step 4: Write failing tests for converter**

```python
# service/tests/test_converter.py
from src.core.converter import (
    openai_to_anthropic_request,
    anthropic_to_openai_request,
    openai_to_anthropic_response,
    anthropic_to_openai_response,
)


def test_openai_to_anthropic_request():
    openai_req = {
        "model": "gpt-4",
        "messages": [
            {"role": "system", "content": "You are helpful."},
            {"role": "user", "content": "Hello"},
        ],
        "max_tokens": 100,
        "temperature": 0.7,
    }
    result = openai_to_anthropic_request(openai_req)
    assert result["model"] == "gpt-4"
    assert result["system"] == "You are helpful."
    assert len(result["messages"]) == 1
    assert result["messages"][0]["role"] == "user"
    assert result["max_tokens"] == 100


def test_openai_to_anthropic_with_tools():
    openai_req = {
        "model": "gpt-4",
        "messages": [{"role": "user", "content": "Read file"}],
        "tools": [
            {
                "type": "function",
                "function": {
                    "name": "read_file",
                    "description": "Read a file",
                    "parameters": {"type": "object", "properties": {"path": {"type": "string"}}},
                },
            }
        ],
    }
    result = openai_to_anthropic_request(openai_req)
    assert len(result["tools"]) == 1
    assert result["tools"][0]["name"] == "read_file"


def test_anthropic_to_openai_request():
    anth_req = {
        "model": "claude-sonnet-4-20250514",
        "system": "You are helpful.",
        "messages": [{"role": "user", "content": "Hello"}],
        "max_tokens": 100,
    }
    result = anthropic_to_openai_request(anth_req)
    assert result["model"] == "claude-sonnet-4-20250514"
    assert len(result["messages"]) == 2
    assert result["messages"][0]["role"] == "system"


def test_openai_to_anthropic_response():
    openai_resp = {
        "id": "chatcmpl-123",
        "choices": [
            {
                "message": {"role": "assistant", "content": "Hello!"},
                "finish_reason": "stop",
            }
        ],
        "usage": {"prompt_tokens": 10, "completion_tokens": 5, "total_tokens": 15},
    }
    result = openai_to_anthropic_response(openai_resp)
    assert result["type"] == "message"
    assert result["content"][0]["text"] == "Hello!"
    assert result["stop_reason"] == "end_turn"
    assert result["usage"]["input_tokens"] == 10


def test_openai_tool_calls_to_anthropic():
    openai_resp = {
        "id": "chatcmpl-123",
        "choices": [
            {
                "message": {
                    "role": "assistant",
                    "content": None,
                    "tool_calls": [
                        {
                            "id": "call_abc",
                            "type": "function",
                            "function": {
                                "name": "read_file",
                                "arguments": '{"path": "/test.py"}',
                            },
                        }
                    ],
                },
                "finish_reason": "tool_calls",
            }
        ],
        "usage": {"prompt_tokens": 20, "completion_tokens": 10, "total_tokens": 30},
    }
    result = openai_to_anthropic_response(openai_resp)
    assert result["stop_reason"] == "tool_use"
    assert result["content"][0]["type"] == "tool_use"
    assert result["content"][0]["name"] == "read_file"


def test_anthropic_to_openai_response():
    anth_resp = {
        "id": "msg-123",
        "role": "assistant",
        "content": [{"type": "text", "text": "Hello!"}],
        "model": "claude-sonnet-4-20250514",
        "stop_reason": "end_turn",
        "usage": {"input_tokens": 10, "output_tokens": 5},
    }
    result = anthropic_to_openai_response(anth_resp)
    assert result["choices"][0]["message"]["content"] == "Hello!"
    assert result["choices"][0]["finish_reason"] == "stop"
    assert result["usage"]["total_tokens"] == 15
```

- [ ] **Step 5: Implement converter**

```python
# service/src/core/converter.py
import json
import uuid


def openai_to_anthropic_request(req: dict) -> dict:
    """Convert OpenAI chat completion request to Anthropic messages request."""
    messages = req.get("messages", [])
    system = ""
    anthropic_messages = []

    for msg in messages:
        if msg["role"] == "system":
            system = msg["content"]
        elif msg["role"] == "tool":
            anthropic_messages.append({
                "role": "user",
                "content": [
                    {
                        "type": "tool_result",
                        "tool_use_id": msg.get("tool_call_id", ""),
                        "content": msg["content"],
                    }
                ],
            })
        else:
            anthropic_messages.append(msg)

    result = {
        "model": req.get("model", ""),
        "messages": anthropic_messages,
        "max_tokens": req.get("max_tokens", 4096),
    }

    if system:
        result["system"] = system
    if "temperature" in req:
        result["temperature"] = req["temperature"]

    tools = req.get("tools")
    if tools:
        result["tools"] = []
        for t in tools:
            fn = t.get("function", {})
            result["tools"].append({
                "name": fn.get("name", ""),
                "description": fn.get("description", ""),
                "input_schema": fn.get("parameters", {"type": "object", "properties": {}}),
            })

    return result


def anthropic_to_openai_request(req: dict) -> dict:
    """Convert Anthropic messages request to OpenAI chat completion request."""
    messages = []
    system = req.get("system", "")
    if system:
        messages.append({"role": "system", "content": system})

    for msg in req.get("messages", []):
        content = msg.get("content", "")
        if isinstance(content, list):
            text_parts = []
            for part in content:
                if part.get("type") == "text":
                    text_parts.append(part["text"])
                elif part.get("type") == "tool_result":
                    messages.append({
                        "role": "tool",
                        "tool_call_id": part.get("tool_use_id", ""),
                        "content": part.get("content", ""),
                    })
            if text_parts:
                messages.append({"role": msg["role"], "content": "\n".join(text_parts)})
        else:
            messages.append(msg)

    result = {
        "model": req.get("model", ""),
        "messages": messages,
    }

    if "max_tokens" in req:
        result["max_tokens"] = req["max_tokens"]
    if "temperature" in req:
        result["temperature"] = req["temperature"]

    tools = req.get("tools")
    if tools:
        result["tools"] = []
        for t in tools:
            result["tools"].append({
                "type": "function",
                "function": {
                    "name": t.get("name", ""),
                    "description": t.get("description", ""),
                    "parameters": t.get("input_schema", {}),
                },
            })

    return result


def openai_to_anthropic_response(resp: dict) -> dict:
    """Convert OpenAI chat completion response to Anthropic messages response."""
    choice = resp.get("choices", [{}])[0]
    message = choice.get("message", {})
    usage = resp.get("usage", {})

    content = []
    finish_reason = choice.get("finish_reason", "stop")

    tool_calls = message.get("tool_calls")
    if tool_calls:
        for tc in tool_calls:
            content.append({
                "type": "tool_use",
                "id": tc.get("id", f"toolu_{uuid.uuid4().hex[:24]}"),
                "name": tc.get("function", {}).get("name", ""),
                "input": json.loads(tc.get("function", {}).get("arguments", "{}")),
            })
    elif message.get("content"):
        content.append({"type": "text", "text": message["content"]})

    stop_reason_map = {
        "stop": "end_turn",
        "length": "max_tokens",
        "tool_calls": "tool_use",
    }

    return {
        "id": f"msg_{resp.get('id', uuid.uuid4().hex[:24])}",
        "type": "message",
        "role": "assistant",
        "content": content,
        "model": resp.get("model", ""),
        "stop_reason": stop_reason_map.get(finish_reason, "end_turn"),
        "usage": {
            "input_tokens": usage.get("prompt_tokens", 0),
            "output_tokens": usage.get("completion_tokens", 0),
        },
    }


def anthropic_to_openai_response(resp: dict) -> dict:
    """Convert Anthropic messages response to OpenAI chat completion response."""
    content = resp.get("content", [])
    usage = resp.get("usage", {})

    text_parts = []
    tool_calls = []
    for part in content:
        if part.get("type") == "text":
            text_parts.append(part["text"])
        elif part.get("type") == "tool_use":
            tool_calls.append({
                "id": part.get("id", ""),
                "type": "function",
                "function": {
                    "name": part.get("name", ""),
                    "arguments": json.dumps(part.get("input", {})),
                },
            })

    stop_reason_map = {
        "end_turn": "stop",
        "max_tokens": "length",
        "tool_use": "tool_calls",
    }

    message = {
        "role": "assistant",
        "content": "\n".join(text_parts) if text_parts else None,
    }
    if tool_calls:
        message["tool_calls"] = tool_calls

    return {
        "id": f"chatcmpl-{resp.get('id', uuid.uuid4().hex[:24])}",
        "object": "chat.completion",
        "created": 0,
        "model": resp.get("model", ""),
        "choices": [
            {
                "index": 0,
                "message": message,
                "finish_reason": stop_reason_map.get(resp.get("stop_reason", ""), "stop"),
            }
        ],
        "usage": {
            "prompt_tokens": usage.get("input_tokens", 0),
            "completion_tokens": usage.get("output_tokens", 0),
            "total_tokens": usage.get("input_tokens", 0) + usage.get("output_tokens", 0),
        },
    }
```

- [ ] **Step 6: Write failing tests for fallback**

```python
# service/tests/test_fallback.py
import pytest
from unittest.mock import AsyncMock
from src.core.fallback import execute_with_fallback


@pytest.mark.asyncio
async def test_primary_succeeds_no_fallback():
    primary = AsyncMock(return_value={"result": "ok"})
    fallback = AsyncMock(return_value={"result": "fallback"})
    result, used_fallback = await execute_with_fallback(
        primary_fn=primary,
        fallback_fn=fallback,
    )
    assert result == {"result": "ok"}
    assert used_fallback is False
    fallback.assert_not_called()


@pytest.mark.asyncio
async def test_primary_fails_triggers_fallback():
    primary = AsyncMock(side_effect=Exception("rate limit"))
    fallback = AsyncMock(return_value={"result": "fallback"})
    result, used_fallback = await execute_with_fallback(
        primary_fn=primary,
        fallback_fn=fallback,
    )
    assert result == {"result": "fallback"}
    assert used_fallback is True


@pytest.mark.asyncio
async def test_both_fail_raises():
    primary = AsyncMock(side_effect=Exception("fail"))
    fallback = AsyncMock(side_effect=Exception("also fail"))
    with pytest.raises(Exception, match="also fail"):
        await execute_with_fallback(
            primary_fn=primary,
            fallback_fn=fallback,
        )
```

- [ ] **Step 7: Implement fallback**

```python
# service/src/core/fallback.py
from collections.abc import Callable, Awaitable
from typing import TypeVar

T = TypeVar("T")


async def execute_with_fallback(
    primary_fn: Callable[[], Awaitable[T]],
    fallback_fn: Callable[[], Awaitable[T]],
) -> tuple[T, bool]:
    """Execute primary function, fallback on failure.

    Returns (result, used_fallback).
    """
    try:
        result = await primary_fn()
        return result, False
    except Exception:
        result = await fallback_fn()
        return result, True
```

- [ ] **Step 8: Write failing tests for usage**

```python
# service/tests/test_usage.py
from src.core.usage import UsageTracker
from src.models import UsageRecord
from datetime import datetime


def test_record_usage():
    tracker = UsageTracker()
    record = UsageRecord(provider="bailian", model="qwen-max", total_tokens=100)
    tracker.record(record)
    stats = tracker.get_stats()
    assert stats["bailian"]["requests"] == 1
    assert stats["bailian"]["total_tokens"] == 100


def test_multiple_providers():
    tracker = UsageTracker()
    tracker.record(UsageRecord(provider="bailian", model="qwen-max", total_tokens=100))
    tracker.record(UsageRecord(provider="zhipu", model="glm-4", total_tokens=200))
    tracker.record(UsageRecord(provider="bailian", model="qwen-plus", total_tokens=50))
    stats = tracker.get_stats()
    assert stats["bailian"]["requests"] == 2
    assert stats["bailian"]["total_tokens"] == 150
    assert stats["zhipu"]["requests"] == 1


def test_get_today_stats():
    tracker = UsageTracker()
    tracker.record(UsageRecord(provider="bailian", model="qwen-max", total_tokens=100))
    today = tracker.get_today_stats()
    assert today["total_requests"] == 1
    assert today["total_tokens"] == 100
```

- [ ] **Step 9: Implement usage tracker**

```python
# service/src/core/usage.py
from collections import defaultdict
from datetime import datetime
from src.models import UsageRecord


class UsageTracker:
    def __init__(self):
        self.records: list[UsageRecord] = []
        self._stats: dict[str, dict] = defaultdict(lambda: {
            "requests": 0,
            "total_tokens": 0,
            "prompt_tokens": 0,
            "completion_tokens": 0,
            "cost_estimate": 0.0,
        })

    def record(self, record: UsageRecord):
        self.records.append(record)
        s = self._stats[record.provider]
        s["requests"] += 1
        s["total_tokens"] += record.total_tokens
        s["prompt_tokens"] += record.prompt_tokens
        s["completion_tokens"] += record.completion_tokens
        s["cost_estimate"] += record.cost_estimate

    def get_stats(self) -> dict:
        return dict(self._stats)

    def get_today_stats(self) -> dict:
        today = datetime.utcnow().date()
        today_records = [r for r in self.records if r.timestamp.date() == today]
        return {
            "total_requests": len(today_records),
            "total_tokens": sum(r.total_tokens for r in today_records),
            "total_prompt_tokens": sum(r.prompt_tokens for r in today_records),
            "total_completion_tokens": sum(r.completion_tokens for r in today_records),
            "by_provider": self._aggregate_by_provider(today_records),
        }

    def _aggregate_by_provider(self, records: list[UsageRecord]) -> dict:
        result = {}
        for r in records:
            if r.provider not in result:
                result[r.provider] = {"requests": 0, "tokens": 0}
            result[r.provider]["requests"] += 1
            result[r.provider]["tokens"] += r.total_tokens
        return result
```

- [ ] **Step 10: Run all core tests**

Run: `cd service && python -m pytest tests/test_router.py tests/test_converter.py tests/test_fallback.py tests/test_usage.py -v`
Expected: all PASS

- [ ] **Step 11: Commit**

```bash
git add service/src/core/ service/tests/test_router.py service/tests/test_converter.py service/tests/test_fallback.py service/tests/test_usage.py
git commit -m "feat(service): add router, converter, fallback, and usage tracking"
```

---

### Task 5: API Endpoints (OpenAI + Anthropic + Admin)

**Files:**
- Create: `service/src/routers/__init__.py`
- Create: `service/src/routers/openai.py`
- Create: `service/src/routers/anthropic.py`
- Create: `service/src/routers/admin.py`
- Create: `service/src/main.py`
- Create: `service/tests/test_openai_chat.py`
- Create: `service/tests/test_anthropic_messages.py`
- Create: `service/tests/test_models_endpoint.py`
- Create: `service/tests/test_admin.py`

- [ ] **Step 1: Write failing test for OpenAI chat completions endpoint**

```python
# service/tests/test_openai_chat.py
import json
import pytest
from httpx import AsyncClient, ASGITransport
from unittest.mock import AsyncMock, patch
from src.main import create_app


@pytest.fixture
async def client():
    app = create_app()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c


@pytest.mark.asyncio
async def test_chat_completion_non_stream(client):
    mock_resp = {
        "id": "chatcmpl-test",
        "choices": [{"message": {"role": "assistant", "content": "Hi"}, "index": 0, "finish_reason": "stop"}],
        "usage": {"prompt_tokens": 5, "completion_tokens": 3, "total_tokens": 8},
        "model": "qwen-max",
    }
    with patch("src.routers.openai.route_request", new_callable=AsyncMock, return_value=mock_resp):
        resp = await client.post("/v1/chat/completions", json={
            "model": "bailian/qwen-max",
            "messages": [{"role": "user", "content": "Hello"}],
        })
        assert resp.status_code == 200
        data = resp.json()
        assert data["choices"][0]["message"]["content"] == "Hi"


@pytest.mark.asyncio
async def test_chat_completion_missing_model(client):
    resp = await client.post("/v1/chat/completions", json={
        "messages": [{"role": "user", "content": "Hello"}],
    })
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_chat_completion_unknown_provider(client):
    resp = await client.post("/v1/chat/completions", json={
        "model": "unknown/qwen-max",
        "messages": [{"role": "user", "content": "Hello"}],
    })
    assert resp.status_code == 404
    assert "unknown" in resp.json()["detail"].lower()
```

- [ ] **Step 2: Write failing test for Anthropic messages endpoint**

```python
# service/tests/test_anthropic_messages.py
import json
import pytest
from httpx import AsyncClient, ASGITransport
from unittest.mock import AsyncMock, patch
from src.main import create_app


@pytest.fixture
async def client():
    app = create_app()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c


@pytest.mark.asyncio
async def test_anthropic_message(client):
    mock_resp = {
        "id": "msg-test",
        "type": "message",
        "role": "assistant",
        "content": [{"type": "text", "text": "Hi there!"}],
        "model": "qwen-max",
        "stop_reason": "end_turn",
        "usage": {"input_tokens": 5, "output_tokens": 3},
    }
    with patch("src.routers.anthropic.route_request", new_callable=AsyncMock, return_value=mock_resp):
        resp = await client.post("/v1/messages", json={
            "model": "bailian/qwen-max",
            "messages": [{"role": "user", "content": "Hello"}],
            "max_tokens": 1024,
        })
        assert resp.status_code == 200
        data = resp.json()
        assert data["content"][0]["text"] == "Hi there!"


@pytest.mark.asyncio
async def test_anthropic_count_tokens(client):
    resp = await client.post("/v1/messages/count_tokens", json={
        "model": "bailian/qwen-max",
        "messages": [{"role": "user", "content": "Hello world"}],
    })
    assert resp.status_code == 200
    assert "input_tokens" in resp.json()
```

- [ ] **Step 3: Write failing test for models endpoint**

```python
# service/tests/test_models_endpoint.py
import pytest
from httpx import AsyncClient, ASGITransport
from src.main import create_app


@pytest.fixture
async def client():
    app = create_app()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c


@pytest.mark.asyncio
async def test_list_models(client):
    resp = await client.get("/v1/models")
    assert resp.status_code == 200
    data = resp.json()
    assert data["object"] == "list"
    assert isinstance(data["data"], list)
```

- [ ] **Step 4: Implement main.py with app factory**

```python
# service/src/main.py
from contextlib import asynccontextmanager
from fastapi import FastAPI
from src.config import ConfigManager
from src.core.usage import UsageTracker
from src.routers import openai, anthropic, admin

config_manager: ConfigManager | None = None
usage_tracker: UsageTracker | None = None


def get_config_manager() -> ConfigManager:
    return config_manager


def get_usage_tracker() -> UsageTracker:
    return usage_tracker


@asynccontextmanager
async def lifespan(app: FastAPI):
    global config_manager, usage_tracker
    config_manager = ConfigManager()
    config_manager.load()
    usage_tracker = UsageTracker()
    yield
    config_manager = None
    usage_tracker = None


def create_app() -> FastAPI:
    app = FastAPI(title="CodingPlan", version="0.1.0", lifespan=lifespan)
    app.include_router(openai.router)
    app.include_router(anthropic.router)
    app.include_router(admin.router)
    return app


app = create_app()


def main():
    import uvicorn
    cfg = ConfigManager()
    cfg.load()
    uvicorn.run(app, host=cfg.get().server.host, port=cfg.get().server.port)


if __name__ == "__main__":
    main()
```

- [ ] **Step 5: Implement OpenAI router**

```python
# service/src/routers/openai.py
import json
from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import StreamingResponse
from src.core.router import parse_model_name
from src.core.converter import anthropic_to_openai_response
from src.core.fallback import execute_with_fallback
from src.core.usage import UsageTracker
from src.providers import create_provider

router = APIRouter()


def _get_provider_for_model(model: str, config_manager):
    provider_name, actual_model = parse_model_name(model)
    if not provider_name:
        provider_name = config_manager.get().default_provider
        actual_model = model

    enabled = config_manager.get_enabled_providers()
    if provider_name not in enabled:
        raise HTTPException(status_code=404, detail=f"Provider '{provider_name}' not found or not enabled")

    api_key = config_manager.get_provider_api_key(provider_name)
    provider_cfg = enabled[provider_name]
    return provider_name, actual_model, create_provider(provider_name, provider_cfg, api_key)


@router.post("/v1/chat/completions")
async def chat_completions(request: Request):
    from src.main import get_config_manager, get_usage_tracker
    body = await request.json()
    model = body.get("model", "")
    if not model:
        raise HTTPException(status_code=422, detail="model is required")

    config_manager = get_config_manager()
    usage_tracker = get_usage_tracker()

    try:
        provider_name, actual_model, provider = _get_provider_for_model(model, config_manager)
    except HTTPException:
        if config_manager.get().fallback_enabled and config_manager.get().default_provider:
            default = config_manager.get().default_provider
            default_cfg = config_manager.get_enabled_providers().get(default)
            if default_cfg:
                api_key = config_manager.get_provider_api_key(default)
                provider = create_provider(default, default_cfg, api_key)
                provider_name = default
                actual_model = default_cfg.models[0] if default_cfg.models else model
            else:
                raise
        else:
            raise

    body["model"] = actual_model
    stream = body.get("stream", False)

    if stream:
        return StreamingResponse(
            _stream_chat(provider, body, provider_name, actual_model, usage_tracker),
            media_type="text/event-stream",
        )

    result = await provider.chat_completion(**body)
    if usage_tracker:
        usage_tracker.record(provider.extract_usage(result))
    return result


async def _stream_chat(provider, body, provider_name, model, usage_tracker):
    stream_iter = await provider.chat_completion(**body)
    async for chunk in stream_iter:
        yield chunk
    if usage_tracker:
        from src.models import UsageRecord
        usage_tracker.record(UsageRecord(provider=provider_name, model=model))


@router.get("/v1/models")
async def list_models():
    from src.main import get_config_manager
    config_manager = get_config_manager()
    enabled = config_manager.get_enabled_providers()
    models = []
    for name, cfg in enabled.items():
        for m in cfg.models:
            models.append({
                "id": f"{name}/{m}",
                "object": "model",
                "owned_by": name,
            })
    return {"object": "list", "data": models}
```

- [ ] **Step 6: Implement Anthropic router**

```python
# service/src/routers/anthropic.py
import json
from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import StreamingResponse
from src.core.router import parse_model_name
from src.core.converter import (
    anthropic_to_openai_request,
    openai_to_anthropic_response,
)
from src.providers import create_provider

router = APIRouter()


@router.post("/v1/messages")
async def messages(request: Request):
    from src.main import get_config_manager, get_usage_tracker
    body = await request.json()
    model = body.get("model", "")
    if not model:
        raise HTTPException(status_code=422, detail="model is required")

    config_manager = get_config_manager()
    usage_tracker = get_usage_tracker()

    provider_name, actual_model = parse_model_name(model)
    if not provider_name:
        provider_name = config_manager.get().default_provider
        actual_model = model

    enabled = config_manager.get_enabled_providers()
    if provider_name not in enabled:
        raise HTTPException(status_code=404, detail=f"Provider '{provider_name}' not found or not enabled")

    api_key = config_manager.get_provider_api_key(provider_name)
    provider_cfg = enabled[provider_name]
    provider = create_provider(provider_name, provider_cfg, api_key)

    openai_req = anthropic_to_openai_request(body)
    openai_req["model"] = actual_model

    stream = body.get("stream", False)
    if stream:
        return StreamingResponse(
            _stream_anthropic(provider, openai_req, provider_name, actual_model, usage_tracker),
            media_type="text/event-stream",
        )

    result = await provider.chat_completion(**openai_req)
    anthropic_resp = openai_to_anthropic_response(result)
    if usage_tracker:
        from src.models import UsageRecord
        usage = result.get("usage", {})
        usage_tracker.record(UsageRecord(
            provider=provider_name,
            model=actual_model,
            prompt_tokens=usage.get("prompt_tokens", 0),
            completion_tokens=usage.get("completion_tokens", 0),
            total_tokens=usage.get("total_tokens", 0),
        ))
    return anthropic_resp


async def _stream_anthropic(provider, openai_req, provider_name, model, usage_tracker):
    stream_iter = await provider.chat_completion(**openai_req)
    async for chunk in stream_iter:
        yield chunk


@router.post("/v1/messages/count_tokens")
async def count_tokens(request: Request):
    body = await request.json()
    messages = body.get("messages", [])
    total = sum(len(m.get("content", "")) for m in messages if isinstance(m.get("content"), str))
    return {"input_tokens": total}
```

- [ ] **Step 7: Implement admin router**

```python
# service/src/routers/admin.py
from fastapi import APIRouter
from src.models import ProviderStatus

router = APIRouter(prefix="/admin")


@router.get("/status")
async def status():
    from src.main import get_config_manager
    config_manager = get_config_manager()
    enabled = config_manager.get_enabled_providers()
    providers = []
    for name, cfg in enabled.items():
        providers.append(ProviderStatus(
            name=name,
            enabled=cfg.enabled,
            connected=True,
            models=cfg.models,
        ))
    return {"providers": [p.model_dump() for p in providers]}


@router.get("/usage")
async def usage():
    from src.main import get_usage_tracker
    tracker = get_usage_tracker()
    return tracker.get_today_stats()


@router.post("/reload-config")
async def reload_config():
    from src.main import get_config_manager
    config_manager = get_config_manager()
    config_manager.load()
    return {"status": "ok"}


@router.get("/providers")
async def list_providers():
    from src.main import get_config_manager
    config_manager = get_config_manager()
    enabled = config_manager.get_enabled_providers()
    return {
        name: {"models": cfg.models, "base_url": cfg.base_url}
        for name, cfg in enabled.items()
    }
```

- [ ] **Step 8: Run API endpoint tests**

Run: `cd service && python -m pytest tests/test_openai_chat.py tests/test_anthropic_messages.py tests/test_models_endpoint.py tests/test_admin.py -v`
Expected: all PASS

- [ ] **Step 9: Commit**

```bash
git add service/src/routers/ service/src/main.py service/tests/test_openai_chat.py service/tests/test_anthropic_messages.py service/tests/test_models_endpoint.py service/tests/test_admin.py
git commit -m "feat(service): add OpenAI, Anthropic, and Admin API endpoints"
```

---

### Task 6: Integration & E2E Tests

**Files:**
- Create: `service/tests/test_fallback_integration.py`
- Create: `service/tests/test_e2e_openai.py`
- Create: `service/tests/test_e2e_anthropic.py`
- Create: `service/tests/test_e2e_fallback.py`
- Create: `service/tests/test_e2e_streaming.py`

- [ ] **Step 1: Write fallback integration tests**

```python
# service/tests/test_fallback_integration.py
import pytest
from httpx import AsyncClient, ASGITransport
from unittest.mock import AsyncMock, patch
from src.main import create_app


@pytest.fixture
async def client():
    app = create_app()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c


@pytest.mark.asyncio
async def test_fallback_on_provider_error(client):
    mock_resp = {
        "id": "chatcmpl-fallback",
        "choices": [{"message": {"role": "assistant", "content": "fallback response"}, "index": 0, "finish_reason": "stop"}],
        "usage": {"prompt_tokens": 5, "completion_tokens": 3, "total_tokens": 8},
        "model": "qwen-max",
    }

    async def mock_route(model, body, config_manager):
        if "zhipu" in model:
            raise Exception("provider error")
        return mock_resp

    with patch("src.routers.openai.route_request", new_callable=AsyncMock, side_effect=mock_route):
        resp = await client.post("/v1/chat/completions", json={
            "model": "zhipu/glm-4",
            "messages": [{"role": "user", "content": "Hello"}],
        })
        assert resp.status_code == 200
```

- [ ] **Step 2: Write E2E test for OpenAI flow**

```python
# service/tests/test_e2e_openai.py
import json
import pytest
from httpx import AsyncClient, ASGITransport, MockTransport
from unittest.mock import patch, AsyncMock
from src.main import create_app


MOCK_PROVIDER_RESPONSE = {
    "id": "chatcmpl-e2e",
    "choices": [{"message": {"role": "assistant", "content": "E2E response"}, "index": 0, "finish_reason": "stop"}],
    "usage": {"prompt_tokens": 10, "completion_tokens": 5, "total_tokens": 15},
    "model": "qwen-max",
}


@pytest.fixture
async def client():
    app = create_app()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c


@pytest.mark.asyncio
async def test_e2e_openai_chat_completion(client):
    mock_provider = AsyncMock()
    mock_provider.chat_completion = AsyncMock(return_value=MOCK_PROVIDER_RESPONSE)
    mock_provider.extract_usage = AsyncMock(return_value=None)

    with patch("src.providers.create_provider", return_value=mock_provider):
        resp = await client.post("/v1/chat/completions", json={
            "model": "bailian/qwen-max",
            "messages": [{"role": "user", "content": "Hello"}],
        })
        assert resp.status_code == 200
        data = resp.json()
        assert data["choices"][0]["message"]["content"] == "E2E response"
        mock_provider.chat_completion.assert_called_once()
```

- [ ] **Step 3: Write E2E test for Anthropic flow**

```python
# service/tests/test_e2e_anthropic.py
import pytest
from httpx import AsyncClient, ASGITransport
from unittest.mock import AsyncMock, patch
from src.main import create_app


@pytest.fixture
async def client():
    app = create_app()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c


@pytest.mark.asyncio
async def test_e2e_anthropic_message(client):
    openai_resp = {
        "id": "chatcmpl-e2e",
        "choices": [{"message": {"role": "assistant", "content": "Hello!"}, "index": 0, "finish_reason": "stop"}],
        "usage": {"prompt_tokens": 10, "completion_tokens": 5, "total_tokens": 15},
        "model": "qwen-max",
    }

    mock_provider = AsyncMock()
    mock_provider.chat_completion = AsyncMock(return_value=openai_resp)

    with patch("src.providers.create_provider", return_value=mock_provider):
        resp = await client.post("/v1/messages", json={
            "model": "bailian/qwen-max",
            "messages": [{"role": "user", "content": "Hello"}],
            "max_tokens": 1024,
        })
        assert resp.status_code == 200
        data = resp.json()
        assert data["content"][0]["text"] == "Hello!"
        assert data["stop_reason"] == "end_turn"
```

- [ ] **Step 4: Write E2E streaming test**

```python
# service/tests/test_e2e_streaming.py
import pytest
from httpx import AsyncClient, ASGITransport
from unittest.mock import AsyncMock, patch
from src.main import create_app


async def mock_stream():
    chunks = [
        b'data: {"choices":[{"delta":{"content":"Hello"}}]}\n\n',
        b'data: {"choices":[{"delta":{"content":" world"}}]}\n\n',
        b'data: [DONE]\n\n',
    ]
    for chunk in chunks:
        yield chunk


@pytest.fixture
async def client():
    app = create_app()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c


@pytest.mark.asyncio
async def test_e2e_streaming(client):
    mock_provider = AsyncMock()
    mock_provider.chat_completion = AsyncMock(return_value=mock_stream())

    with patch("src.providers.create_provider", return_value=mock_provider):
        async with client.stream("POST", "/v1/chat/completions", json={
            "model": "bailian/qwen-max",
            "messages": [{"role": "user", "content": "Hello"}],
            "stream": True,
        }) as resp:
            assert resp.status_code == 200
            assert resp.headers["content-type"] == "text/event-stream; charset=utf-8"
            body = b""
            async for chunk in resp.aiter_bytes():
                body += chunk
            assert b"Hello" in body
            assert b"[DONE]" in body
```

- [ ] **Step 5: Run all tests**

Run: `cd service && python -m pytest tests/ -v --tb=short`
Expected: all PASS

- [ ] **Step 6: Commit**

```bash
git add service/tests/test_fallback_integration.py service/tests/test_e2e_openai.py service/tests/test_e2e_anthropic.py service/tests/test_e2e_streaming.py
git commit -m "test(service): add integration and E2E tests"
```

---

## Phase 2: Swift App (Menu Bar)

### Task 7: Swift App Scaffold & Python Process Manager

**Files:**
- Create: `app/CodingPlan/CodingPlanApp.swift`
- Create: `app/CodingPlan/AppDelegate.swift`
- Create: `app/CodingPlan/Services/PythonProcessManager.swift`

- [ ] **Step 1: Create Swift app entry point**

```swift
// app/CodingPlan/CodingPlanApp.swift
import SwiftUI

@main
struct CodingPlanApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
```

- [ ] **Step 2: Create AppDelegate with status bar**

```swift
// app/CodingPlan/AppDelegate.swift
import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?
    var pythonManager: PythonProcessManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        pythonManager = PythonProcessManager()
        pythonManager?.start()

        statusBarController = StatusBarController(pythonManager: pythonManager!)
    }

    func applicationWillTerminate(_ notification: Notification) {
        pythonManager?.stop()
    }
}
```

- [ ] **Step 3: Create Python process manager**

```swift
// app/CodingPlan/Services/PythonProcessManager.swift
import Foundation
import Combine

class PythonProcessManager: ObservableObject {
    @Published var isRunning = false
    @Published var lastError: String?

    private var process: Process?
    private let servicePort = 9800

    var serviceURL: String {
        "http://127.0.0.1:\(servicePort)"
    }

    func start() {
        guard process == nil else { return }

        let process = Process()
        let servicePath = findServicePath()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = ["-m", "uvicorn", "src.main:app", "--host", "127.0.0.1", "--port", "\(servicePort)"]
        process.currentDirectoryURL = URL(fileURLWithPath: servicePath)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                print("[CodingPlan Service] \(output)")
            }
        }

        do {
            try process.run()
            self.process = process
            self.isRunning = true
            self.lastError = nil
        } catch {
            self.lastError = error.localizedDescription
            self.isRunning = false
        }
    }

    func stop() {
        process?.terminate()
        process?.waitUntilExit()
        process = nil
        isRunning = false
    }

    func restart() {
        stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.start()
        }
    }

    private func findServicePath() -> String {
        let appBundle = Bundle.main.bundlePath
        let servicePath = (appBundle as NSString).appendingPathComponent("Contents/Resources/service")

        if FileManager.default.fileExists(atPath: servicePath) {
            return servicePath
        }

        // Development fallback
        let devPath = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("service").path

        if FileManager.default.fileExists(atPath: devPath) {
            return devPath
        }

        return "."
    }
}
```

- [ ] **Step 4: Create placeholder StatusBarController**

```swift
// app/CodingPlan/StatusBarController.swift
import Cocoa
import Combine

class StatusBarController {
    private var statusItem: NSStatusItem
    private var pythonManager: PythonProcessManager
    private var cancellables = Set<AnyCancellable>()

    init(pythonManager: PythonProcessManager) {
        self.pythonManager = pythonManager
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.title = "● CodingPlan"
        }

        setupMenu()
        observeStatus()
    }

    private func setupMenu() {
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "当前: 未配置", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())

        let providerMenu = NSMenuItem(title: "厂商切换", action: nil, keyEquivalent: "")
        menu.addItem(providerMenu)
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "今日用量", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "📊 打开用量面板...", action: #selector(openUsage), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "⚙️ 设置...", action: #selector(openSettings), keyEquivalent: ""))
        menu.addItem(.separator())

        let statusTitle = pythonManager.isRunning ? "服务状态: ● 运行中" : "服务状态: ○ 已停止"
        menu.addItem(NSMenuItem(title: statusTitle, action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "重启服务", action: #selector(restartService), keyEquivalent: ""))
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "退出 CodingPlan", action: #selector(quit), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    private func observeStatus() {
        pythonManager.$isRunning
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.setupMenu()
            }
            .store(in: &cancellables)
    }

    @objc private func openSettings() {
        // TODO: Open settings window
    }

    @objc private func openUsage() {
        // TODO: Open usage dashboard
    }

    @objc private func restartService() {
        pythonManager.restart()
    }

    @objc private func quit() {
        pythonManager.stop()
        NSApp.terminate(nil)
    }
}
```

- [ ] **Step 5: Verify app builds**

Run: Open in Xcode and build, or `xcodebuild -project app/CodingPlan.xcodeproj -scheme CodingPlan build`

- [ ] **Step 6: Commit**

```bash
git add app/CodingPlan/CodingPlanApp.swift app/CodingPlan/AppDelegate.swift app/CodingPlan/Services/PythonProcessManager.swift app/CodingPlan/StatusBarController.swift
git commit -m "feat(app): add Swift app scaffold with Python process management"
```

---

### Task 8: Config Manager & Keychain (Swift)

**Files:**
- Create: `app/CodingPlan/Services/ConfigManager.swift`
- Create: `app/CodingPlan/Services/KeychainManager.swift`
- Create: `app/CodingPlan/Models/Provider.swift`

- [ ] **Step 1: Create Provider model**

```swift
// app/CodingPlan/Models/Provider.swift
import Foundation

struct Provider: Codable, Identifiable {
    var id: String { name }
    let name: String
    var enabled: Bool
    let baseURL: String
    var models: [String]

    enum CodingKeys: String, CodingKey {
        case name, enabled
        case baseURL = "base_url"
        case models
    }
}
```

- [ ] **Step 2: Create KeychainManager**

```swift
// app/CodingPlan/Services/KeychainManager.swift
import Foundation
import Security

class KeychainManager {
    private let service = "com.codingplan.apikeys"

    func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
        ]
        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }

    func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }
}
```

- [ ] **Step 3: Create ConfigManager**

```swift
// app/CodingPlan/Services/ConfigManager.swift
import Foundation

class ConfigManager: ObservableObject {
    @Published var providers: [Provider] = []
    @Published var defaultProvider: String = ""
    @Published var fallbackEnabled: Bool = true

    private let configPath: String
    private let keychain = KeychainManager()

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        self.configPath = (home as NSString).appendingPathComponent(".codingplan/config.json")
        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        defaultProvider = json["default_provider"] as? String ?? ""
        fallbackEnabled = json["fallback_enabled"] as? Bool ?? true

        if let providersDict = json["providers"] as? [String: [String: Any]] {
            providers = providersDict.map { name, cfg in
                Provider(
                    name: name,
                    enabled: cfg["enabled"] as? Bool ?? false,
                    baseURL: cfg["base_url"] as? String ?? "",
                    models: cfg["models"] as? [String] ?? []
                )
            }
        }
    }

    func setAPIKey(provider: String, key: String) {
        _ = keychain.save(key: provider, value: key)
    }

    func getAPIKey(provider: String) -> String? {
        return keychain.load(key: provider)
    }
}
```

- [ ] **Step 4: Commit**

```bash
git add app/CodingPlan/Services/ConfigManager.swift app/CodingPlan/Services/KeychainManager.swift app/CodingPlan/Models/Provider.swift
git commit -m "feat(app): add config manager and Keychain API key storage"
```

---

### Task 9: Settings & Usage Views (Swift)

**Files:**
- Create: `app/CodingPlan/Views/SettingsView.swift`
- Create: `app/CodingPlan/Views/ProviderRowView.swift`
- Create: `app/CodingPlan/Views/UsageDashboardView.swift`
- Create: `app/CodingPlan/Views/UsageChartView.swift`
- Create: `app/CodingPlan/Services/UsageStatsService.swift`
- Create: `app/CodingPlan/Models/UsageRecord.swift`

- [ ] **Step 1: Create UsageRecord model**

```swift
// app/CodingPlan/Models/UsageRecord.swift
import Foundation

struct UsageRecord: Codable {
    let provider: String
    let model: String
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case provider, model
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
        case timestamp
    }
}
```

- [ ] **Step 2: Create UsageStatsService**

```swift
// app/CodingPlan/Services/UsageStatsService.swift
import Foundation

class UsageStatsService: ObservableObject {
    @Published var todayStats: [String: Any] = [:]
    @Published var isLoading = false

    private let serviceURL = "http://127.0.0.1:9800"

    func fetchUsage() {
        guard let url = URL(string: "\(serviceURL)/admin/usage") else { return }
        isLoading = true

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            defer { DispatchQueue.main.async { self?.isLoading = false } }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return
            }
            DispatchQueue.main.async {
                self?.todayStats = json
            }
        }.resume()
    }
}
```

- [ ] **Step 3: Create SettingsView**

```swift
// app/CodingPlan/Views/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @ObservedObject var config: ConfigManager
    @State private var apiKeys: [String: String] = [:]
    @State private var editingProvider: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("CodingPlan 设置")
                .font(.title2)
                .bold()

            HStack {
                Text("默认厂商:")
                Picker("", selection: $config.defaultProvider) {
                    Text("无").tag("")
                    ForEach(config.providers) { provider in
                        Text(provider.name).tag(provider.name)
                    }
                }
            }

            Toggle("自动故障转移", isOn: $config.fallbackEnabled)

            Divider()

            Text("厂商配置")
                .font(.headline)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(config.providers) { provider in
                        ProviderRowView(
                            provider: provider,
                            apiKey: Binding(
                                get: { apiKeys[provider.name] ?? "" },
                                set: { apiKeys[provider.name] = $0 }
                            ),
                            onToggle: { enabled in
                                // Toggle provider enabled state
                            },
                            onSaveKey: {
                                if let key = apiKeys[provider.name] {
                                    config.setAPIKey(provider: provider.name, key: key)
                                }
                            }
                        )
                    }
                }
            }
        }
        .padding()
        .frame(width: 500, height: 400)
    }
}
```

- [ ] **Step 4: Create ProviderRowView**

```swift
// app/CodingPlan/Views/ProviderRowView.swift
import SwiftUI

struct ProviderRowView: View {
    let provider: Provider
    @Binding var apiKey: String
    var onToggle: (Bool) -> Void
    var onSaveKey: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Toggle("", isOn: Binding(
                    get: { provider.enabled },
                    set: { onToggle($0) }
                ))
                .toggleStyle(.switch)

                Text(provider.name)
                    .font(.body)
                    .bold()

                Spacer()

                Text(provider.baseURL)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if provider.enabled {
                HStack {
                    SecureField("API Key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)

                    Button("保存") {
                        onSaveKey()
                    }
                }
                .padding(.leading, 30)

                if !provider.models.isEmpty {
                    Text("模型: \(provider.models.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 30)
                }
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }
}
```

- [ ] **Step 5: Create UsageDashboardView**

```swift
// app/CodingPlan/Views/UsageDashboardView.swift
import SwiftUI

struct UsageDashboardView: View {
    @ObservedObject var usageService: UsageStatsService

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("今日用量")
                .font(.title2)
                .bold()

            HStack(spacing: 24) {
                StatCard(title: "请求数", value: "\(usageService.todayStats["total_requests"] as? Int ?? 0)")
                StatCard(title: "总 Token", value: "\(usageService.todayStats["total_tokens"] as? Int ?? 0)")
                StatCard(title: "输入 Token", value: "\(usageService.todayStats["total_prompt_tokens"] as? Int ?? 0)")
                StatCard(title: "输出 Token", value: "\(usageService.todayStats["total_completion_tokens"] as? Int ?? 0)")
            }

            Divider()

            Text("按厂商分布")
                .font(.headline)

            UsageChartView(stats: usageService.todayStats)

            Spacer()
        }
        .padding()
        .frame(width: 600, height: 400)
        .onAppear {
            usageService.fetchUsage()
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack {
            Text(value)
                .font(.title)
                .bold()
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 100)
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}
```

- [ ] **Step 6: Create UsageChartView**

```swift
// app/CodingPlan/Views/UsageChartView.swift
import SwiftUI
import Charts

struct UsageChartView: View {
    let stats: [String: Any]

    var chartData: [(provider: String, tokens: Int)] {
        guard let byProvider = stats["by_provider"] as? [String: [String: Any]] else {
            return []
        }
        return byProvider.map { name, data in
            (provider: name, tokens: data["tokens"] as? Int ?? 0)
        }.sorted { $0.tokens > $1.tokens }
    }

    var body: some View {
        if chartData.isEmpty {
            Text("暂无数据")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: 200)
        } else {
            Chart(chartData, id: \.provider) { item in
                BarMark(
                    x: .value("Token", item.tokens),
                    y: .value("厂商", item.provider)
                )
                .foregroundStyle(by: .value("厂商", item.provider))
            }
            .frame(height: 200)
        }
    }
}
```

- [ ] **Step 7: Update StatusBarController to wire views**

Update `StatusBarController.swift` to open SettingsView and UsageDashboardView windows.

- [ ] **Step 8: Commit**

```bash
git add app/CodingPlan/Views/ app/CodingPlan/Services/UsageStatsService.swift app/CodingPlan/Models/UsageRecord.swift app/CodingPlan/StatusBarController.swift
git commit -m "feat(app): add settings view, usage dashboard, and chart components"
```

---

## Verification

- [ ] Run full Python test suite: `cd service && python -m pytest tests/ -v --cov=src --cov-report=term-missing`
- [ ] Verify coverage ≥ 80%
- [ ] Build Swift app in Xcode
- [ ] Manual test: launch app → configure API key → verify menu bar shows status
- [ ] Manual test: `curl -X POST http://localhost:9800/v1/chat/completions -H 'Content-Type: application/json' -d '{"model":"bailian/qwen-max","messages":[{"role":"user","content":"hi"}]}'`
