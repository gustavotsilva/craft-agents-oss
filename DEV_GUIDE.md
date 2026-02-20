# Dev Guide — Craft Agents

## Prerequisites

| Tool | Install |
|------|---------|
| **Bun** (required) | `curl -fsSL https://bun.sh/install \| bash` |
| **Node.js 18+** | Comes bundled with Electron, but needed for some scripts |

## Install & Run

```bash
# Install all dependencies
bun install

# Create your env file
cp .env.example .env

# Add your Anthropic key to .env (only required variable)
# ANTHROPIC_API_KEY=sk-ant-...

# Run in development (hot reload)
bun run electron:dev
```

That's it. The app opens as a desktop window.

## Environment Variables

**.env file at project root** (gitignored)

**Required:**
```
ANTHROPIC_API_KEY=sk-ant-...        # Your Claude API key
```

**Optional:**
```
CRAFT_MCP_URL=http://...            # Craft MCP server URL
CRAFT_MCP_TOKEN=...                 # Craft MCP bearer token
SLACK_OAUTH_CLIENT_ID=...           # Slack integration
SLACK_OAUTH_CLIENT_SECRET=...       # Slack integration
MICROSOFT_OAUTH_CLIENT_ID=...       # Microsoft integration
SENTRY_ELECTRON_INGEST_URL=...      # Error tracking
```

Google OAuth credentials are **not** set via env — users provide them through the app UI.

## Commands Cheat Sheet

### Development
```bash
bun run electron:dev               # Dev mode with hot reload (primary command)
bun run electron:dev:logs          # Open log tail in separate Terminal window
```

### Build & Run
```bash
bun run electron:build             # Build everything (main + preload + renderer + resources)
bun run electron:start             # Build + run the app
```

### Build Individual Pieces
```bash
bun run electron:build:main        # esbuild → main process (dist/main.cjs)
bun run electron:build:preload     # esbuild → preload script (dist/preload.cjs)
bun run electron:build:renderer    # Vite → React app (dist/renderer/)
bun run electron:build:resources   # Copy icons and assets
```

### Type Check & Lint
```bash
bun run typecheck:all              # Type check core + shared packages
bun run lint                       # Lint electron + shared
```

### Package for Distribution
```bash
bun run electron:dist:mac          # macOS DMG
bun run electron:dist:win          # Windows NSIS installer
bun run electron:dist:linux        # Linux AppImage
bun run electron:dist              # All platforms
```

### Utilities
```bash
bun test                           # Run tests
bun run fresh-start                # Reset all local config (~/.craft-agent/)
bun run print:system-prompt        # Print the system prompt sent to Claude
```

## Troubleshooting

**App crashes immediately with `getAppPath` error:**
You're running from a VS Code terminal. Run this first:
```bash
unset ELECTRON_RUN_AS_NODE
```
Or just use `bun run electron:dev` — it handles this automatically.

**"No LLM connection" warning in logs:**
Normal on first run. Open the app and configure your LLM connection in settings.

**tsconfig warnings about `tsconfig.base.json`:**
Harmless. Ignore them.

## Local Data

Everything the app stores locally lives in `~/.craft-agent/`:
```
~/.craft-agent/
├── config.json                    # Global config, LLM connections
├── credentials.enc                # Encrypted API keys & OAuth tokens
├── themes/                        # Preset themes
├── permissions/                   # Default permission rules
└── workspaces/{id}/
    ├── sessions/                  # Chat sessions (JSONL files)
    ├── sources/                   # Connected data sources
    ├── theme.json                 # Workspace theme
    └── permissions.json           # Workspace permission rules
```

To nuke everything and start fresh: `bun run fresh-start`

## Project Layout (Quick Reference)

```
apps/electron/src/
├── main/           → Electron main process (Node.js context)
├── preload/        → Context bridge between main & renderer
├── renderer/       → React app (browser context)
└── shared/         → IPC channel types shared between main & renderer

packages/
├── core/           → TypeScript types (import from @craft-agent/core)
├── shared/         → All business logic (import from @craft-agent/shared/*)
├── ui/             → Shared React components
├── bridge-mcp-server/    → REST API bridging for Codex sessions
└── session-mcp-server/   → Session-scoped tools for Codex
```

## Logs

```bash
# Main process log
~/Library/Logs/@craft-agent/electron/main.log

# Or open a live tail
bun run electron:dev:logs
```
