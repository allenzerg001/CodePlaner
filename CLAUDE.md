# CodingPlan — CLAUDE.md

## 项目概述

CodingPlan 是一个 macOS 本地应用，提供 OpenAI/Anthropic 双协议兼容的 API 网关，聚合国内厂商 Coding Plan 服务（百炼、火山引擎、智谱、DeepSeek 等）。AI Coding IDE 只需接入 `http://localhost:9800`，即可路由到任意厂商模型。

## 项目结构

```
CodingPlaner/
├── service/          # Node.js Fastify 服务（核心网关）
│   ├── src/
│   │   ├── main.ts           # Fastify 应用入口
│   │   ├── models.ts         # TypeScript 接口定义
│   │   ├── config.ts         # 配置加载 (config.yaml)
│   │   ├── crypto.ts         # AES-256-CBC API Key 加密
│   │   ├── core/
│   │   │   ├── router.ts     # provider/model 路由解析
│   │   │   ├── converter.ts  # OpenAI ↔ Anthropic 格式互转
│   │   │   └── usage.ts      # 用量统计逻辑
│   │   ├── providers/        # 厂商适配器
│   │   │   ├── base.ts       # 抽象基类
│   │   │   ├── deepseek.ts   # DeepSeek
│   │   │   └── index.ts      # 导出所有适配器
│   │   └── routers/
│   │       ├── openai.ts     # POST /v1/chat/completions, GET /v1/models
│   │       └── admin.ts      # GET/POST /admin/*
│   ├── dist/                 # 编译产物
│   │   └── codingplan-service # SEA 独立可执行二进制
│   ├── package.json          # NPM 依赖与脚本
│   └── tsconfig.json         # TS 配置
├── CodePlaner/       # Swift macOS 应用
│   ├── CodePlaner/
│   │   ├── Services/
│   │   │   ├── PythonProcessManager.swift  # 管理服务进程生命周期
│   │   │   ├── ConfigManager.swift         # 读写 config.yaml
│   │   │   └── UsageStatsService.swift     # 用量数据查询
│   │   └── Views/            # SwiftUI 视图
└── docs/superpowers/
    ├── specs/2026-04-17-node-migration-design.md    # Node 迁移设计
    └── plans/2026-04-17-node-migration-plan.md      # 迁移计划
```

## 技术栈

| 组件 | 技术 |
|------|------|
| Node.js 服务 | Node.js 20+, Fastify, TypeScript, esbuild |
| 二进制封装 | Node.js SEA (Single Executable Applications), postject |
| 加密 | Node.js Crypto (AES-256-CBC) |
| 数据存储 | SQLite, YAML config |
| Swift 应用 | Swift 5, SwiftUI, macOS 13+, Alamofire |

## 开发命令

### Node.js 服务

```bash
cd service

# 安装依赖
npm install

# 开发模式运行
npm run dev

# 构建 JS Bundle
npm run build

# 生成独立二进制 (dist/codingplan-service)
./build_service.sh
```

### Swift 应用

使用 Xcode 打开 `CodePlaner/CodePlaner.xcodeproj` 构建并运行。

## API 端点

| 端点 | 格式 | 说明 |
|------|------|------|
| `POST /v1/chat/completions` | OpenAI | 支持 streaming、tool_calls、multi-turn |
| `GET /v1/models` | OpenAI | 所有已启用厂商的模型列表 |
| `GET /admin/status` | 内部 | 服务状态 |
| `POST /admin/reload-config` | 内部 | 热重载配置 |

## 路由规则

- `model` 字段格式：`provider/model_name`（如 `deepseek/deepseek-chat`）
- 无前缀时使用 `default_provider`
- 厂商请求失败时自动 fallback 到默认厂商

## 安全注意事项

- API Key 必须加密存储 (AES-256-CBC)，绝不明文写入配置文件
- 本地服务只监听 `127.0.0.1`，不对外暴露
