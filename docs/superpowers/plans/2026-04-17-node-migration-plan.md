# Node.js Migration and Standalone Binary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate the Python service to a standalone Node.js binary to eliminate runtime dependencies.

**Architecture:** A Fastify-based TypeScript server bundled with `esbuild` and packaged into a single executable using Node.js SEA (Single Executable Applications).

**Tech Stack:** Node.js 20+, TypeScript, Fastify, esbuild, postject.

---

### Task 1: Project Initialization

**Files:**
- Create: `service/package.json`
- Create: `service/tsconfig.json`
- Create: `service/src/models.ts`

- [ ] **Step 1: Create package.json with dependencies**
```json
{
  "name": "codingplan-service",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "build": "esbuild src/main.ts --bundle --platform=node --format=esm --outfile=dist/bundle.js",
    "dev": "tsx src/main.ts"
  },
  "dependencies": {
    "fastify": "^4.26.0",
    "@fastify/cors": "^9.0.1",
    "yaml": "^2.4.1",
    "zod": "^3.22.4",
    "undici": "^6.13.0"
  },
  "devDependencies": {
    "@types/node": "^20.11.0",
    "esbuild": "^0.20.0",
    "tsx": "^4.7.1",
    "typescript": "^5.3.3"
  }
}
```

- [ ] **Step 2: Create tsconfig.json**
```json
{
  "compilerOptions": {
    "target": "ESNext",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true
  },
  "include": ["src/**/*"]
}
```

- [ ] **Step 3: Define core models in models.ts**
```typescript
export interface ProviderConfig {
  base_url: string;
  api_key: string;
  models: string[];
  enabled: boolean;
}

export interface AppConfig {
  server: {
    host: string;
    port: number;
  };
  default_provider: string;
  fallback_enabled: boolean;
  providers: Record<string, ProviderConfig>;
}

export interface UsageRecord {
  timestamp: string;
  client_id: string;
  provider: string;
  model: string;
  prompt_tokens: number;
  completion_tokens: number;
  total_tokens: number;
}
```

- [ ] **Step 4: Install dependencies**
Run: `cd service && npm install`

- [ ] **Step 5: Commit**
```bash
git add service/package.json service/tsconfig.json service/src/models.ts
git commit -m "chore: init nodejs project and models"
```

---

### Task 2: Port Core Utilities (Crypto & Config)

**Files:**
- Create: `service/src/crypto.ts`
- Create: `service/src/config.ts`

- [ ] **Step 1: Implement crypto.ts** (using Node.js crypto module)
```typescript
import crypto from 'node:crypto';

const ALGORITHM = 'aes-256-cbc';
const KEY = crypto.scryptSync('codingplan-secret-key', 'salt', 32);
const IV_LENGTH = 16;

export function encrypt(text: string): string {
  const iv = crypto.randomBytes(IV_LENGTH);
  const cipher = crypto.createCipheriv(ALGORITHM, KEY, iv);
  let encrypted = cipher.update(text, 'utf8', 'hex');
  encrypted += cipher.final('hex');
  return `${iv.toString('hex')}:${encrypted}`;
}

export function decrypt(text: string): string {
  const [ivHex, encryptedHex] = text.split(':');
  if (!ivHex || !encryptedHex) return text;
  const iv = Buffer.from(ivHex, 'hex');
  const decipher = crypto.createDecipheriv(ALGORITHM, KEY, iv);
  let decrypted = decipher.update(encryptedHex, 'hex', 'utf8');
  decrypted += decipher.final('utf8');
  return decrypted;
}
```

- [ ] **Step 2: Implement config.ts**
```typescript
import fs from 'node:fs';
import path from 'node:path';
import { parse } from 'yaml';
import { AppConfig } from './models.js';

export class ConfigManager {
  private config: AppConfig | null = null;
  private configPath: string;

  constructor() {
    this.configPath = path.join(process.cwd(), 'config.yaml');
  }

  load() {
    if (fs.existsSync(this.configPath)) {
      const file = fs.readFileSync(this.configPath, 'utf8');
      this.config = parse(file);
    } else {
      this.config = this.getDefaultConfig();
    }
  }

  get(): AppConfig {
    return this.config!;
  }

  private getDefaultConfig(): AppConfig {
    return {
      server: { host: '127.0.0.1', port: 9800 },
      default_provider: 'deepseek',
      fallback_enabled: true,
      providers: {}
    };
  }
}
```

- [ ] **Step 3: Commit**
```bash
git add service/src/crypto.ts service/src/config.ts
git commit -m "feat: port crypto and config managers"
```

---

### Task 3: Port Core Logic (Router, Converter, Usage)

**Files:**
- Create: `service/src/core/router.ts`
- Create: `service/src/core/converter.ts`
- Create: `service/src/core/usage.ts`

- [ ] **Step 1: Implement core/router.ts**
```typescript
export const PROVIDER_ALIASES: Record<string, string> = {
  "volcano": "volcengine",
};

export function canonicalProviderName(name: string | null): string | null {
  if (!name) return null;
  return PROVIDER_ALIASES[name] || name;
}

export function parseModelName(model: string): [string | null, string] {
  if (!model) return [null, ""];
  if (model.includes("/")) {
    const [provider, name] = model.split("/", 2);
    return [canonicalProviderName(provider), name];
  }
  return [null, model];
}
```

- [ ] **Step 2: Implement core/converter.ts** (OpenAI ↔ Anthropic)
```typescript
// Implement openaiToAnthropicRequest, anthropicToOpenAIRequest, etc.
// Follow the logic in service/src/core/converter.py accurately.
```

- [ ] **Step 3: Implement core/usage.ts**
```typescript
import { UsageRecord } from '../models.js';

export class UsageTracker {
  record(record: UsageRecord) {
    console.log(`[Usage] ${record.provider}/${record.model} by ${record.client_id}`);
    // Optional: write to local JSON file as in Python version
  }
}

export function parseClient(userAgent: string | undefined): string {
  if (!userAgent) return 'unknown';
  // simple parser logic
  return userAgent.split(' ')[0] || 'unknown';
}
```

- [ ] **Step 4: Commit**
```bash
git add service/src/core/
git commit -m "feat: port core routing and conversion logic"
```

---

### Task 4: Port Providers

**Files:**
- Create: `service/src/providers/base.ts`
- Create: `service/src/providers/deepseek.ts`

- [ ] **Step 1: Implement base.ts**
```typescript
export abstract class BaseProvider {
  constructor(protected baseUrl: string, protected apiKey: string) {}
  abstract chatCompletion(params: any): Promise<any>;
}
```

- [ ] **Step 2: Implement deepseek.ts**
```typescript
import { BaseProvider } from './base.js';

export class DeepseekProvider extends BaseProvider {
  async chatCompletion(params: any) {
    const response = await fetch(`${this.baseUrl}/chat/completions`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${this.apiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(params)
    });
    return response.json();
  }
}
```

- [ ] **Step 3: Commit**
```bash
git add service/src/providers/
git commit -m "feat: port providers"
```

---

### Task 5: Port Routers and Main Entry

**Files:**
- Create: `service/src/routers/openai.ts`
- Create: `service/src/main.ts`

- [ ] **Step 1: Implement routers/openai.ts**
```typescript
import { FastifyInstance } from 'fastify';

export default async function openaiRouter(fastify: FastifyInstance) {
  fastify.post('/v1/chat/completions', async (request, reply) => {
    // Port logic from service/src/routers/openai.py
  });
}
```

- [ ] **Step 2: Implement main.ts**
```typescript
import Fastify from 'fastify';
import openaiRouter from './routers/openai.js';
import { ConfigManager } from './config.js';

const fastify = Fastify({ logger: true });
const configManager = new ConfigManager();
configManager.load();

fastify.register(openaiRouter);

const start = async () => {
  try {
    const config = configManager.get();
    await fastify.listen({ port: config.server.port, host: config.server.host });
  } catch (err) {
    fastify.log.error(err);
    process.exit(1);
  }
};
start();
```

- [ ] **Step 3: Commit**
```bash
git add service/src/routers/ service/src/main.ts
git commit -m "feat: implement main entry and openai router"
```

---

### Task 6: Binary Generation Build Script

**Files:**
- Create: `service/sea-config.json`
- Modify: `service/build_service.sh`

- [ ] **Step 1: Create sea-config.json**
```json
{
  "main": "dist/bundle.js",
  "output": "dist/sea-prep.blob"
}
```

- [ ] **Step 2: Update build_service.sh**
```bash
#!/bin/bash
set -e

# Build JS
npm run build

# Generate Blob
node --experimental-sea-config sea-config.json

# Prepare Binary
cp $(which node) dist/codingplan-service
# Remove existing signature to allow postject
codesign --remove-signature dist/codingplan-service

# Inject Blob
npx postject dist/codingplan-service NODE_SEA_BLOB dist/sea-prep.blob \
    --sentinel-fuse NODE_SEA_FUSE_fce680ab2cc467b6e072b8b5df1996b2

# Codesign for macOS
codesign -s - dist/codingplan-service

echo "Binary generated at dist/codingplan-service"
```

- [ ] **Step 3: Run the build script**
Run: `chmod +x build_service.sh && ./build_service.sh`

- [ ] **Step 4: Verify the binary**
Run: `./dist/codingplan-service --version` (or verify it starts)

- [ ] **Step 5: Commit**
```bash
git add service/sea-config.json service/build_service.sh
git commit -m "feat: implement SEA binary generation"
```

---

### Task 7: Final Verification and Cleanup

- [ ] **Step 1: Test with Swift App**
Build the Swift app in Xcode and ensure it bundles the new binary and communicates correctly.

- [ ] **Step 2: Remove old Python files (optional but recommended)**
Run: `rm -rf service/src/*.py service/src/core/*.py service/src/providers/*.py service/src/routers/*.py`

- [ ] **Step 3: Commit**
```bash
git commit -m "cleanup: remove python service files"
```
