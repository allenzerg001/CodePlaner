# CodingPlaner — Local AI Coding Assistant Aggregation Gateway

CodingPlaner is a native macOS application designed for developers to provide a high-performance, secure, and unified local AI API gateway. It aggregates services from major AI model providers worldwide and transforms them into standard OpenAI-compatible interfaces for seamless use by various AI Coding IDEs.

## 🚀 Key Benefits

In the era of AI-driven development, different IDEs and plugins (such as Cursor, Claude Code, and OpenCode) often require configuring various API Keys and Base URLs. CodingPlaner solves these pain points by establishing a lightweight local proxy service:
- **Unified Entry Point**: Simply configure a local address in your IDE (e.g., `http://localhost:55583/v1`) to access all activated provider models.
- **Smart Routing**: Supports the `provider/model` format (e.g., `deepseek/deepseek-chat`), automatically forwarding requests to the corresponding provider.
- **Enhanced Security**: API Keys are stored encrypted locally, no longer exposed in plain text within IDE configuration files.
- **Performance Optimization**: Optimized streaming SSE forwarding for coding scenarios, providing a smooth typewriter-like response experience.

## ✨ Core Features

- **Multi-Provider Aggregation Management**: Activate, configure, and switch AI providers with one click through a graphical interface.
- **Real-Time Usage Statistics**:
  - **Usage Dashboard**: Statistics on Token consumption and request distribution by provider, supporting real-time daily data refresh.
  - **Clients Dashboard**: Automatically identifies and tracks the usage frequency of different IDEs (e.g., Cursor, OpenCode).
- **One-Click OpenCode Integration**: Specifically optimized for OpenCode, supporting one-click synchronization of local configurations to OpenCode configuration files for zero-config onboarding.
- **Fine-Grained Model Control**: Manually add models and freely choose which models are visible to the IDE.
- **Native macOS Experience**:
  - Resides in the menu bar to monitor background service status in real-time.
  - Automatically hides the Dock icon after the window is closed to keep the desktop tidy while the service runs silently.
  - Full **English and Chinese** multi-language support.
- **Automated Service Management**: Built-in port conflict detection and automatic hot-restart of the service after configuration changes.

## 🌐 Supported AI Model Providers

Currently built-in support for the following **17** providers' OpenAI-compatible interfaces:
- **Major Domestic (China)**: DeepSeek, Moonshot/Kimi, Xiaomi MiMo, Zhipu AI, Volcengine, Alibaba Bailian, Tencent Hunyuan, MiniMax, SiliconFlow.
- **Global Leaders**: OpenAI, Anthropic, Google Gemini, Mistral AI, Groq, Cohere.
- **Aggregation Platforms**: OpenRouter, Together AI.

## 💻 Supported Downstream AI Coding IDEs

Any tool that supports a custom OpenAI Base URL can be connected, with special identity simulation and adaptation for:
- **OpenCode** (supports one-click configuration sync)
- **Cursor**
- **Claude Code** (identity verification issues resolved)
- **Roo Code (Roo Cline)**
- **Continue.dev**
- **Generic OpenAI Clients** (various translation and search plugins, etc.)

## 🛠 Technical Architecture

- **App**: Native macOS application built with Swift 5.9 + SwiftUI.
- **Backend Service**: Lightweight high-performance gateway built with Node.js (TypeScript) + Fastify + better-sqlite3.
- **Storage**: Configuration information and encrypted API Keys are stored in `~/.codingplan/config.json`, and statistical data is stored in `~/.codingplan/usage.db`.

---

## 🛠 Development and Building

### Requirements
- macOS 13.0+
- Node.js 18+
- Xcode 15.0+

### Backend Build
```bash
cd service
npm install
npm run build
```

### Running the App
Open `CodePlaner/CodePlaner.xcodeproj` directly in Xcode and run it. The application will automatically launch the built Node.js service upon startup.

## 📄 License
MIT License
