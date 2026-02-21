# Bug: Sessions not visible after restart in packaged app

## Summary

Sessions created in the packaged macOS app (installed via DMG to `/Applications`) do not appear in the sidebar after quitting and reopening the app. The session data IS persisted to disk correctly — only the UI fails to display it.

## Reproduction Steps

1. Build and install: `bun run electron:dist:mac` → install DMG to `/Applications`
2. Open "Craft Agents" from `/Applications`
3. Create a new session, send a message, get a response — works fine
4. Quit the app (Cmd+Q)
5. Reopen the app
6. **Expected:** Session appears in sidebar
7. **Actual:** Sidebar is empty, no sessions shown

## Evidence

### Data persists on disk

```
~/.craft-agent/workspaces/my-workspace/sessions/260220-still-torrent/session.jsonl
```

Contains 3 lines (metadata + user message + assistant response). File is readable (`-rw-r--r--`), owned by the correct user.

### Config is correct

`~/.craft-agent/config.json` has the right workspace ID, rootPath, and LLM connection. The workspace directory exists and is accessible.

### Dev mode works fine

Running `bun run electron:dev` shows all sessions correctly, including ones created by the packaged app. The same `~/.craft-agent/` directory is used by both.

## Key Observations

### Different `userData` paths

- **Dev mode:** `~/Library/Application Support/@craft-agent/electron/` (from package.json `name: "@craft-agent/electron"`)
- **Packaged app:** `~/Library/Application Support/Craft Agents/` (from electron-builder `productName: "Craft Agents"`)

This means Electron's internal storage (Local Storage, Session Storage, cookies) is separate between dev and packaged builds. If the renderer caches session list state in Electron's web storage, it would appear empty in one context vs the other.

### Log file not being written

The packaged app does not write to `~/Library/Logs/@craft-agent/electron/main.log`. The `electron-log` preload path warning from earlier (`ENOENT .../electron-log-preload.js`) may indicate that `electron-log` isn't initializing correctly in the packaged app, making debugging harder.

### Main process loads sessions correctly

When working (dev mode), the log shows:
```
[session] Loaded 8 sessions from disk (metadata only)
```

This confirms the main process `listSessions` IPC handler reads the JSONL files correctly. The issue is downstream — either the IPC response isn't reaching the renderer, or the renderer isn't rendering the data.

## Likely Root Causes (in order of probability)

### 1. IPC timing race condition

The renderer requests the session list via IPC before the main process has finished initializing the SessionManager. The response returns an empty array, and the renderer doesn't retry.

**Where to look:**
- `apps/electron/src/renderer/App.tsx` — session list fetching on mount
- `apps/electron/src/main/ipc.ts` — `GET_SESSIONS` handler
- `apps/electron/src/main/sessions.ts` — `listSessions()` method

### 2. Jotai atom not hydrating from IPC

The session list atom (`sessionAtomFamily` or similar in `apps/electron/src/renderer/atoms/sessions.ts`) might not be populated on initial render in the packaged app due to a timing difference in how the renderer loads (file:// URL vs localhost dev server).

**Where to look:**
- `apps/electron/src/renderer/atoms/sessions.ts`
- `apps/electron/src/renderer/hooks/useSession.ts`

### 3. electron-log not initializing in packaged builds

The missing `electron-log-preload.js` error suggests electron-log can't find its preload script in the packaged app. If session loading errors occur but aren't logged, the bug appears silent.

**Where to look:**
- `apps/electron/src/main/logger.ts`
- Check if `electron-log` `initialize()` needs a custom path in packaged builds

## Environment

- **OS:** macOS 15.4 (Darwin 25.2.0), Apple Silicon (arm64)
- **Electron:** 39.2.7
- **Node (embedded):** 22.21.1
- **Build tool:** electron-builder 26.4.0
- **Package manager:** Bun 1.3.9

## How to Debug

1. Open the packaged app
2. Use `Cmd+Option+I` to open DevTools
3. Check the Console tab for errors during startup
4. In the Network tab, look for the IPC calls to `GET_SESSIONS`
5. In the Console, try: `window.electronAPI.getSessions()` to see if the IPC returns data
