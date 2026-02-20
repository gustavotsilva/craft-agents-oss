# CLAUDE.md

This file provides guidance to Claude Code when working with the Craft Agents OSS monorepo.

## Project Overview

Craft Agents is an open-source **desktop AI agent application** built with Electron + React. It provides a multi-session inbox for interacting with AI agents (Claude, OpenAI Codex, GitHub Copilot) and connecting them to external data sources via MCP (Model Context Protocol).

**Runtime:** Bun
**Desktop:** Electron 39 + React 18
**UI:** shadcn/ui + Tailwind CSS v4
**State:** Jotai atoms
**Build:** esbuild (main process) + Vite (renderer)
**Validation:** Zod v4

## Quick Setup

```bash
# Prerequisites: Bun (https://bun.sh)
bun install
cp .env.example .env
# Edit .env — add ANTHROPIC_API_KEY at minimum

# Development (hot reload)
bun run electron:dev

# Build and run
bun run electron:start
```

## Environment Variables

| Variable | Required | Purpose |
|----------|----------|---------|
| `ANTHROPIC_API_KEY` | **Yes** | Claude API key (`sk-ant-...`) |
| `CRAFT_MCP_URL` | No | Craft MCP server endpoint |
| `CRAFT_MCP_TOKEN` | No | Bearer token for Craft MCP |
| `GOOGLE_OAUTH_CLIENT_ID` / `SECRET` | No | Google OAuth (users provide via UI) |
| `SLACK_OAUTH_CLIENT_ID` / `SECRET` | No | Slack integration (baked at build) |
| `MICROSOFT_OAUTH_CLIENT_ID` | No | Microsoft OAuth (baked at build) |
| `SENTRY_ELECTRON_INGEST_URL` | No | Error tracking |

The `.env` file is gitignored. OAuth secrets are baked into builds via esbuild `--define` flags.

## Monorepo Structure

```
craft-agents-oss/
├── apps/
│   ├── electron/              # Desktop app (primary interface)
│   │   ├── src/main/          # Electron main process
│   │   ├── src/preload/       # Context bridge
│   │   ├── src/renderer/      # React app
│   │   └── src/shared/        # IPC types and routes
│   └── viewer/                # Session viewer web component
├── packages/
│   ├── core/                  # Shared TypeScript types
│   ├── shared/                # Business logic (~75K lines)
│   ├── ui/                    # React UI components
│   ├── bridge-mcp-server/     # REST API → MCP bridge for Codex
│   ├── session-mcp-server/    # Session-scoped MCP tools
│   ├── session-tools-core/    # Core session tool handlers
│   ├── codex-types/           # Codex type definitions
│   ├── mermaid/               # Diagram rendering
│   └── eslint-rules/          # Custom lint rules
└── scripts/                   # Build and dev scripts
```

## Key Files

| File | Purpose |
|------|---------|
| `apps/electron/src/main/index.ts` | Electron app entry point, lifecycle |
| `apps/electron/src/main/sessions.ts` | Agent wrapper, session lifecycle (~3900 lines) |
| `apps/electron/src/main/ipc.ts` | IPC handlers (~3900 lines) |
| `apps/electron/src/renderer/App.tsx` | React root, event processing (~2400 lines) |
| `packages/shared/src/agent/claude-agent.ts` | Claude SDK wrapper |
| `packages/shared/src/agent/mode-manager.ts` | Permission mode state |
| `packages/shared/src/config/storage.ts` | Config persistence |
| `packages/shared/src/sources/server-builder.ts` | MCP/API server construction |
| `packages/shared/src/credentials/manager.ts` | AES-256-GCM encrypted storage |
| `packages/shared/src/sessions/storage.ts` | Session persistence (JSONL) |
| `scripts/electron-dev.ts` | Dev mode launcher |
| `scripts/electron-build-main.ts` | Production build script |

## Commands

```bash
# Development
bun run electron:dev           # Hot-reload dev mode
bun run electron:dev:logs      # Open log tail in Terminal

# Build
bun run electron:build         # Full build (main + preload + renderer + resources)
bun run electron:start         # Build and run
bun run typecheck:all          # Type check core + shared
bun run lint                   # Lint electron + shared

# Distribution
bun run electron:dist:mac      # macOS DMG
bun run electron:dist:win      # Windows NSIS
bun run electron:dist:linux    # Linux AppImage

# Testing
bun test                       # Run tests

# Utilities
bun run print:system-prompt    # Print the system prompt sent to Claude
bun run fresh-start            # Reset local config
```

## Architecture

### Agent System

Three agent backends:
- **ClaudeAgent** — Claude Agent SDK (`@anthropic-ai/claude-agent-sdk`)
- **CodexAgent** — OpenAI Codex via forked app-server (JSON-RPC over stdio)
- **CopilotAgent** — GitHub Copilot SDK

### Permission Modes (per-session)

| Mode | Display | Behavior |
|------|---------|----------|
| `safe` | Explore | Read-only, blocks writes |
| `ask` | Ask to Edit | Prompts for approval (default) |
| `allow-all` | Auto | Auto-approves all |

Cycled with SHIFT+TAB in UI.

### Data Flow

```
Electron Main Process
  ├─ SessionManager → CraftAgent (wraps Claude/Codex/Copilot SDK)
  ├─ loadStoredConfig() → LLM connections, workspaces
  ├─ getCredentialManager() → AES-256-GCM encrypted secrets
  ├─ buildServersFromSources() → MCP/API servers
  └─ listenForAgentEvents() → stream to renderer via IPC
         │
         ▼
Electron Renderer (React + Jotai)
  ├─ sessionAtomFamily → per-session state
  ├─ useEventProcessor() → handle agent events
  └─ ChatInput / ChatDisplay / SessionList
```

### Config Storage

All local data at `~/.craft-agent/`:
- `config.json` — Global config, LLM connections
- `credentials.enc` — AES-256-GCM encrypted API keys and OAuth tokens
- `workspaces/{id}/` — Per-workspace sessions, sources, themes, permissions
- `themes/` — App-level preset themes

### Session Persistence

Sessions are JSONL files at `~/.craft-agent/workspaces/{id}/sessions/{sessionId}.jsonl`. Writes are debounced (500ms) via a persistence queue.

## Known Issues & Gotchas

### ELECTRON_RUN_AS_NODE (Critical for VS Code users)

VS Code extensions (including Claude Code) set `ELECTRON_RUN_AS_NODE=1` in the environment. This makes the Electron binary behave as plain Node.js, breaking `require('electron')`. The dev script strips this env var before spawning Electron. If you see `TypeError: Cannot read properties of undefined (reading 'getAppPath')`, this is the cause.

**Fix:** Already handled in `scripts/electron-dev.ts`. If running Electron manually, ensure `ELECTRON_RUN_AS_NODE` is unset:
```bash
unset ELECTRON_RUN_AS_NODE && bun run electron:dev
```

### @sentry/electron Import Crash

`@sentry/electron` accesses `app.getAppPath()` at module import time, before Electron is ready. The Sentry import is conditional — only loaded when `SENTRY_ELECTRON_INGEST_URL` is set. `@sentry/electron` is marked as external in esbuild to prevent bundling.

### electron-updater Import Crash

`electron-updater` also accesses `app.getVersion()` at module load time. The `auto-update.ts` module is imported lazily via `import()` in index.ts to defer its evaluation until after `app.whenReady()`.

### SDK Path Resolution

The Claude Agent SDK path must be explicitly set after bundling because esbuild breaks auto-detection:
```typescript
setPathToClaudeCodeExecutable('/path/to/cli.js')
```
This is handled in `sessions.ts` during initialization.

### OAuth Secrets Baked at Build Time

Google OAuth is NOT baked in — users provide credentials via source config in the UI. Slack and Microsoft OAuth client IDs ARE baked via esbuild `--define` flags from `.env`.

### tsconfig.base.json Warnings

Some sub-packages (`bridge-mcp-server`, `session-mcp-server`, `session-tools-core`) reference `../../tsconfig.base.json` which doesn't exist in the OSS repo. These are harmless build warnings.

### Environment Variable Filtering

Subprocess environments are filtered to prevent leaking credentials to MCP servers. Variables like `ANTHROPIC_API_KEY`, `GITHUB_TOKEN`, `AWS_*` are blocked from child processes.

## Coding Conventions

- **TypeScript** everywhere, strict mode enabled
- **ES Modules** (`"type": "module"` in root package.json) — `.cjs` extension for CJS output
- **Imports:** Use subpath exports from workspace packages (`@craft-agent/shared/agent`, `@craft-agent/shared/config`, etc.)
- **State management:** Jotai atoms in the renderer, no Redux
- **Styling:** Tailwind CSS v4 + shadcn/ui components
- **Error handling:** Structured errors with `TypedError` type (code, title, canRetry)
- **Logging:** `electron-log` in main process, `debug()` utility in shared
- **IPC:** Type-safe channels defined in `src/shared/types.ts`

## Workspace Package Imports

```typescript
// Agent
import { CraftAgent, setPermissionMode } from '@craft-agent/shared/agent'

// Config
import { loadStoredConfig, getWorkspaces } from '@craft-agent/shared/config'

// Credentials
import { getCredentialManager } from '@craft-agent/shared/credentials'

// Sources
import { loadWorkspaceSources } from '@craft-agent/shared/sources'

// Types
import type { Session, Message, AgentEvent } from '@craft-agent/core'
```
