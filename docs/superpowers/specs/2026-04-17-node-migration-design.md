# Design Spec: Node.js Migration and Standalone Binary Generation

## 1. Goal
Migrate the existing Python-based `codingplan-service` to Node.js (TypeScript) and package it as a standalone macOS binary (SEA). This removes the user's dependency on a local Python environment and ensures a consistent, high-performance experience.

## 2. Architecture
The service will follow the same modular architecture as the Python version:
- **Web Framework:** Fastify (for speed and schema validation).
- **Runtime:** Node.js 20+ (using SEA for binary distribution).
- **Bundler:** esbuild (for single-file JS generation).

### Directory Structure (within `service/`)
- `src/main.ts`: Entry point.
- `src/config.ts`: Configuration management (YAML/JSON).
- `src/core/`: Router, protocol converter, usage tracking.
- `src/providers/`: Implementations for DeepSeek, Zhipu, etc.
- `src/routers/`: API route definitions (OpenAI, Anthropic, Admin).
- `package.json`: NPM dependencies and build scripts.
- `build_service.sh`: Unified build script for creating the binary.

## 3. Implementation Details

### Logic Porting
- **Protocol Conversion:** Port logic from `converter.py` to `src/core/converter.ts`.
- **Streaming:** Use Node.js stream API and `EventSource` style SSE for LLM responses.
- **HTTP Client:** Use `fetch` (native in Node 18+) or `axios` for provider requests.
- **Crypto:** Port `crypto.py` logic for API key encryption using Node's `crypto` module.

### Binary Generation (SEA)
1. **Bundle:** `esbuild src/main.ts --bundle --platform=node --outfile=dist/bundle.js`.
2. **Config:** Create `sea-config.json`.
3. **Blob:** `node --experimental-sea-config sea-config.json`.
4. **Executable:** 
   - `cp $(which node) dist/codingplan-service`.
   - `postject dist/codingplan-service NODE_SEA_BLOB dist/sea-prep.blob --sentinel-fuse NODE_SEA_FUSE_fce680ab2cc467b6e072b8b5df1996b2`.
5. **Codesign:** `codesign -s - dist/codingplan-service` (ad-hoc signature for macOS).

## 4. Swift Integration
- No changes to `PythonProcessManager.swift` logic, as it already checks for `dist/codingplan-service`.
- Xcode Build Phase will execute `service/build_service.sh` to ensure the binary is fresh before bundling.

## 5. Success Criteria
- Standalone binary `dist/codingplan-service` runs without `node` or `python` installed.
- API behavior is identical to the Python version (verified by existing tests ported to Jest/Vitest).
- Swift app successfully launches and communicates with the Node.js service.
