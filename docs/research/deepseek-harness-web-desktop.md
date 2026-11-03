# DeepSeek Harness Web / Desktop Implementation Research

English | [中文](deepseek-harness-web-desktop.zh.md)

Research date: 2026-11-03. This research covers the official [deepseek-ai/deepseek-harness](https://github.com/deepseek-ai/deepseek-harness) repository, not a community desktop wrapper. The source is pinned to commit [`ce7073d51254c26cd63b22a60835b8f948deb447`](https://github.com/deepseek-ai/deepseek-harness/tree/ce7073d51254c26cd63b22a60835b8f948deb447), dated 2026-10-30; the root package version is `0.2.2-alpha.2`, and Node `>=24.9.0` is required.

This research consisted of static reading of the documentation and source code. It did not include installing dependencies, building or running Harness, calling a model, or testing on a physical iOS device. Below, “implemented” means an implementation exists in that commit; the proposed iOS approaches are recommendations based on the available evidence. Upstream explicitly labels the project a developer preview, with breaking changes possible.

## Conclusions

Web and desktop are different hosts for the same product: they share the TypeScript/Cordis Agent runtime, React Web client, tool system, and session data. The desktop app uses Electron to host the shared Web pages and starts a separate local Host process. The Agent itself does not run inside an ordinary Web page.

iOS can reuse this layered design, but “connect to an existing Harness” and “run Harness independently on the phone” are two different product scopes. The former primarily needs a mobile client and a reliable connection protocol; the latter also requires an iOS execution layer, persistence, and a background-task strategy. Upstream also has an experimental Web Worker Host that could serve as a starting point for local-execution research, but it cannot be treated as a complete desktop runtime.

## 1. Shared Runtime: The Cordis Plugin Tree

A running Harness combines a profile with bundles. `dsh-base` provides model adapters, the Agent loop, tools, persistence, sandboxing, approvals, settings, and related capabilities; `dsh-web-app` adds the GUI Host and browser client. The Desktop profile uses Web’s default bundle composition. The SDK and ACP are separate application interfaces; their ability to drive an Agent does not make them equivalent to the complete GUI protocol.

Source references:

- [Architecture and profiles/bundles](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/docs/architecture.md#L7-L27)
- [Shared base capabilities](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/packages/bundle/base/README.md#L48-L68)

The Agent’s basic execution flow is:

```text
User input enters the inbox
  → Begin a turn
  → Assemble model context and available tools
  → Stream the model response
  → Record the assistant message
  → For tool calls: validate, check permissions, execute, record results
  → Continue the next step with tool results
  → End the turn when no work remains
```

`ReactLoopAgent` drives execution; `tools.execute()` receives the complete batch of tool calls produced by the model, and the executor determines concurrency and cancellation behavior. Model-provider adapters and tool providers are replaceable, so a local iOS implementation would not need to port every desktop tool.

- [Model streaming and tool execution implementation](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/packages/core/agent-loop/src/agent.ts#L479-L603)
- [Tool registration, executors, and the permission pipeline](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/packages/core/tools/README.md#L26-L98)

## 2. Sessions and Model Communication

**The session log is the source of truth.** Model history, recovery, branching, and chat rendering are all derived from append-only Session events. The live assistant stream and committed historical messages must be handled separately; each transient token cannot be treated as a complete persisted message.

First-party Session storage uses one JSONL file per session, with Zstandard compression by default; the current on-disk format in this snapshot is v3. SQLite provides optional session queries and full-text search, rather than primary chat-history storage; the default base composition sets `openAt: never`, so it does not open the SQLite full-text index.

- [The distinction between Session events and live streams](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/docs/architecture.md#L79-L130)
- [JSONL directories, versions, and crash recovery](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/packages/session/session-persistence-jsonl/README.md#L55-L79)
- [Default JSONL and SQLite configuration](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/packages/bundle/base/cordis.patch.yml#L138-L161)

**Network calls from the Host to DeepSeek and the protocol between the UI and Host are separate layers.** In this source snapshot, the official model adapter defaults to `https://api.deepseek.com/anthropic`, sends HTTP requests to `/v1/messages`, and reads SSE; files use `/v1/files`. API keys use `x-api-key`, while account login uses `x-dsh-auth-token`. These are the Host’s upstream model credentials, not the credentials a mobile client uses to authenticate to a Harness Host.

- [Model endpoints, message formats, and authentication](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/packages/llm/llm-deepseek/README.md#L80-L99)
- [HTTP requests and SSE reader implementation](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/packages/llm/llm-deepseek/src/adapter.ts#L142-L169)

## 2.1 Web Client, Protocol, and State Synchronization

Web uses React 18 + TypeScript + Vite 6, with the actual interface assembled through Cordis Client plugins. `apps/web` is the entry point, the main UI lives in `packages/client/*`, application Remote/BFF services live in `packages/api/*`, and server hosting lives in `packages/host/*`. The page requires boot injections from the Host; it cannot be treated as a standalone static React SPA where starting Vite produces the complete product.

The GUI uses **Typert Remote/BFF**, not JSON-RPC 2.0. The SDK and ACP have their own JSON-RPC/stdio integration entry points. An iOS client that needs the existing GUI’s session, tool-approval, and file capabilities should prioritize investigating GUI Remote instead of starting with the SDK or ACP by default.

### External Clients Already Have a Connection Entry Point

The connection flow is as follows; the token is an illustrative placeholder:

```text
GET /connect?token=<host-launch-token>&interactions=answer
  → 302 + Set-Cookie + Location: ./api/remote.mux
  → Send HTTP RPC and establish WebSocket with the same Cookie
  → Open logical streams such as $events and session/follow
```

`/connect` defaults to `interactions=none`; clients that need to receive and answer approval requests should explicitly use `answer`. This authenticates a Host connection and is separate from a DeepSeek account or API key. It currently creates an owner Peer; this review did not find an existing pairing flow that issues fine-grained, restricted tokens to individual iOS apps.

An API Cookie can be bound to only one WebSocket that owns it; a second connection receives 409. Closing that socket deletes the Peer, after which HTTP requests with the old Cookie receive 401 and the client must call `/connect` again. A Host restart also requires reconnection. Browser Cookies and API Cookies use the same name, so a native client should use a separate Cookie store rather than share WebView login state.

The Host checks authority/Origin. Binding to a specific network-interface IP, trusted Hosts, and TLS are deployment settings; the common `--host 0.0.0.0` pattern cannot be copied directly because this upstream version does not support an unspecified bind address. Native handling of 302 redirects, Cookies, WS handshakes, and recovery across foreground/background transitions still needs testing.

- [HTTP/WS, authentication, external connections, and recovery](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/packages/client/connection/README.md#L28-L64)
- [/connect implementation](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/packages/client/connection/src/browser-auth.ts#L307-L347)
- [Socket ownership and Peer removal on disconnect](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/packages/client/connection/src/rpc-host.ts#L129-L172)

### Operations Use HTTP; Live Data Uses WebSocket

| Purpose | Interface/mechanism | iOS implementation focus |
|---|---|---|
| Create a session | `POST /api/session/create` | Read the sessionId actually returned by the Host |
| Send input | `POST /api/session/prompt` | requestId, queue/steer, text/attachments; returns accepted, not the model’s answer |
| Cancel the current task | `POST /api/session/cancel` | Cancellation must be explicit; closing follow does not cancel the turn |
| Follow a session | WS `/api/remote.mux`, logical stream `session/follow` | snapshot → durable event + optional assistant-stream |
| Global state | `session/control` in the same mux | Replace each projection after the baseline |
| Tool approvals | `$events` in the same mux; answer via HTTP `/api/$events/result` | ready/clientId/eventId, cancellation events, pending waterfall replay |
| Upload attachments | `POST /api/session/uploadFileBinary` | Raw byte stream, Session receipt, separate result format |

Example of a regular call (authentication Cookie omitted):

```json
{
  "type": "client-request",
  "rpcId": "rpc-demo",
  "method": "session/create",
  "payload": { "args": { "request": { "cwd": "/work/demo" } } }
}
```

The response uses `type: server-response`, the same `rpcId`, and `result: {ok, value|error}`, so HTTP 200 does not guarantee application-level success. WS uses JSON text frames, with `streamId` identifying a logical stream and frame types open/item/end/cancel/error; each session does not get its own physical socket.

```json
{
  "type": "open",
  "streamId": "follow-demo",
  "endpoint": "session/follow",
  "payload": {
    "args": {
      "request": {
        "address": { "kind": "session", "sessionId": "session-demo" },
        "assistantStream": true
      }
    }
  }
}
```

- [HTTP RPC envelope and multipart response handling](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/packages/client/connection/src/client/rpc.ts#L34-L69)
- [WS mux frame definitions](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/packages/api/gateway/src/stream-protocol.ts#L234-L257)
- [Session creation, input, and cancellation types](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/packages/api/session-controller/src/types.ts#L264-L369)

### Reconnection and Streaming Display Challenges

The first `session/follow` frame is a snapshot containing header, cursor, records, hasMore, and projections, followed by ordered durable events. There are also transient `assistant-stream` start/chunk/end events, ordered by attemptId, revision, and index; the final committed end points to the seq of the persisted message.

iOS should maintain two kinds of state—committed history and the attempt currently being generated—and merge them on completion to avoid duplicating tokens and the final message. After a disconnect, it must reestablish identity and subscriptions and read a new snapshot and activeAttempt baseline; saving a local cursor alone does not mean the server will automatically fill in the gap. Upstream Web already checks for seq gaps and recovers from them. Those semantics are suitable for reuse, but Swift needs its own state implementation.

- [Snapshot, durable event, and assistant attempt definitions](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/packages/api/session-controller/src/types.ts#L450-L583)

### Files and Mobile UI

Raw uploads use `application/octet-stream`, with sessionId/name in the query and an additional mediaType for images; the result is a direct `{ok,value|error}`, without the regular rpcId envelope. The receipt is then included in the prompt. Some file-reading RPCs return multipart/form-data: metadata contains a JSON envelope and bytes placeholders, while separate parts contain binary data. Swift cannot parse every endpoint as JSON/base64.

- [Raw upload implementation](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/packages/client/file-upload/src/http-route.ts#L23-L71)

The existing Web client already has a small-screen sidebar drawer, iPhone/iPad detection, suppression of automatic focus on mobile, and Safari input fixes. This provides a practical basis for WebView reuse, but does not establish that the iOS keyboard, safe areas, file picking, or background recovery have been validated. GUI Remote capabilities are explicitly imported and mounted at build time, with no general runtime capability discovery; combined with the upstream API’s pre-stable status, this makes pinning a compatible Host version advisable for a native implementation.

- [Remote capability set and replay limitations](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/packages/api/remotes/README.md#L73-L79)

## 3. How the Desktop App Works

The desktop package uses Electron + TypeScript, with Vite and electron-builder for building and packaging. Its structure is:

```text
Electron main
  ├─ BrowserWindow + preload → Shared React Web UI
  ├─ Native bridge → File pick/save, clipboard, drag-out, windows, updates
  └─ spawn Electron Node-mode child → Desktop Host
                                      └─ Shared CLI profile runner
                                          └─ dsh-base + dsh-web-app
```

### Startup and Code Reuse

1. The shell first opens the bundled Web loading document.
2. It prepares `$DSH_HOME/profiles/desktop` and the local environment.
3. `DesktopHostProcess.start()` starts a separate Host, using Node IPC for control messages such as boot/readiness/shutdown.
4. The Host calls the shared `runProfile()` with arguments including `--host 127.0.0.1 --port 0`, using a system-assigned port by default.
5. The page waits for `dshDesktopBoot.ready()`, receives injection data and a stream URL, and starts the same `AppWebEntry`.

`BrowserWindow` enables sandboxing/context isolation and disables Node integration. The preload exposes specific native methods; model conversation data still uses the shared Web communication layer. App page assets come from `@deepseek-ai/dsh-web-frontend/dist` and load through `dsh-app://app/`. The Welcome page is a separate, small React UI specific to desktop.

- [Host child process and IPC](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/apps/desktop/src/host-process.ts#L209-L224)
- [Host invocation of the shared profile runner](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/apps/desktop-host/src/index.ts#L22-L48)
- [Desktop startup branch of the same Web entry point](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/apps/web/src/main.ts#L17-L37)
- [Bundled Web assets and managed Host connection](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/apps/desktop/src/main.ts#L762-L821)
- [Specific preload capabilities](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/apps/desktop/src/preload-app.ts#L79-L118)

### Lifecycle Implications for iOS

Closing the main desktop window usually just hides it while the Host keeps working. A full quit checks for tasks, prompts the user, requests an orderly Host shutdown, and terminates the process if necessary. Desktop also bundles local execution payloads such as Node/Python/pnpm; updates keep the shell and runtime versions aligned.

These mechanisms depend on the desktop process model and cannot map directly to unlimited execution after an iOS app enters the background. This source review did not verify an existing desktop product flow for “connect to any remote Host”; the actual desktop startup path always owns and starts a local Host. The shared Web client’s network deployment capabilities and desktop remote-connection management need to be assessed separately.

## 4. Experimental Local Execution in the Browser

`packages/experimental/webworker-runtime` can already load the full plugin tree in a Dedicated Web Worker. It replaces a normal Node Host with a bundled VFS image, module loader, Node API compatibility layer, and postMessage HTTP tunnel.

This provides upstream evidence that part of the shared TypeScript runtime can run outside Node, but its limitations are explicit:

- The VFS is an in-memory filesystem; an optional durable sink extension point exists, but data is temporary when no sink is attached by default. Configuration changes are guaranteed only for the current Worker lifetime. The WebFS directory option is still disabled in this version, so it does not establish that user-file access is complete.
- The shell is implemented by an interpreter and coreutils command table inside the Worker, rather than a full bash; it has no git, network commands, loops, functions, or arbitrary native-program execution.
- pnpm, plugin installation, and native dependency installation are unavailable; PTC Node execution, Office conversion, and some other Agent/provider capabilities are also unavailable.
- `node:net`, `node:sqlite`, `node:worker_threads`, and similar modules are stubs that explicitly raise errors.
- Existing browser startup acceptance testing is based on Chromium. This research found no evidence of WKWebView/WebKit/iOS compatibility and did not validate real model requests.

It is therefore a candidate for a WKWebView local-mode proof of concept, but cannot be treated as a mature iOS port.

- [Worker architecture and limitations](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/packages/experimental/webworker-runtime/README.md#L26-L76)
- [Optional persistence sink](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/packages/experimental/webworker-runtime/src/storage/memory.ts#L189-L230)
- [WebFS directory selection is not yet available](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/packages/experimental/webworker-runtime/src/client/source-chooser.ts#L205-L219)

## 5. Recommended iOS Approaches

| Approach | Execution location | Reusable components | Main new work | Best suited to |
|---|---|---|---|---|
| Native SwiftUI client connected to a Host | Agent/tools on a Mac or server; UI on iOS | Host, tools, Session system, network protocol semantics | Connection/pairing, protocol client, chat-state synchronization, native tool cards, and file handling | Gaining full Harness capabilities and a native mobile experience first |
| WKWebView client connected to a Host | Agent/tools on an external Host; shared Web UI on iOS | Existing React UI and most client state logic | Mobile adaptation, host bridge, authentication/navigation/file permissions | Faster validation of end-to-end functionality and UI plugin compatibility |
| Standalone local app | iOS runs the Agent and a restricted toolset; model inference still calls a cloud API | Selected TypeScript plugins, the experimental Worker approach, or ported domain logic | Execution environment, persistence, native file/network tools, background recovery, and the supported range of plugins | An independent phone product that needs no separate Host |

Subsequent discussion has established the product direction: **install ds-harness-remote on the computer and build a redesigned native iOS client**. SwiftUI is the recommended stack; connectivity reuses the Remote plugin ecosystem, while the UI is designed independently. See [ds-harness-remote Integration Research](ds-harness-remote-ios.md) for the detailed research, protocol differences, and initial design direction. The native-client recommendations below still apply; direct use of the official HTTP/WebSocket interfaces remains a lower-level reference, while the actual client should prioritize Remote’s encrypted tunnel protocol.

The recommended first vertical slice for the native client is: connect to a Host → list/create sessions → send a message → stream text and reasoning → show tool state/approvals → cancel → recover after network loss or backgrounding. Validate file attachments and artifact previews after that core flow. With remote execution, DeepSeek credentials can remain on the Host, while iOS stores its own Host connection credentials.

A standalone iOS runtime needs initial validation of Worker startup and network requests in WKWebView, Session/VFS recovery after restart, mapping between the app’s private directory and user-selected documents, cancellation behavior, and a profile containing only supported tools. Browser-compatible JavaScript does not imply that every native Node package is available.

## 6. Apple Platform Constraints

These constraints inform execution architecture decisions; this research does not constitute a completed App Store compliance assessment.

- [App Review Guidelines 2.5.2, 2.5.4, and 4.7](https://developer.apple.com/app-store/review/guidelines/): App containers, downloaded executable code, and background services are all subject to constraints. Section 4.7 has separate provisions for certain plugins/mini apps, so it cannot simply be read as “all plugins are prohibited” or “arbitrary desktop plugins can be installed.”
- [BGContinuedProcessingTask](https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtask): Starting with iOS 26, certain tasks begun in the foreground can continue processing. They must report progress, can be canceled by the user, and may also be terminated due to resource limits. This does not guarantee a permanent background daemon.
- [URLSessionWebSocketTask](https://developer.apple.com/documentation/foundation/urlsessionwebsockettask): Supports implementing a native Swift WebSocket client; keeping a connection alive does not imply unlimited background execution on iOS, and reliable recovery is still needed when returning to the foreground.

Account login has separate limitations: upstream browser account login currently supports only a local machine or SSH forwarding to loopback, not a non-loopback reverse proxy. Mobile Host pairing and DeepSeek account authorization must be designed separately; an existing iOS OAuth flow cannot be assumed.

- [Current account-login support](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/packages/credentials/deepseek-account-platform/README.md#L43-L66)
- [Known account-login limitations](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/packages/credentials/deepseek-account-platform/README.md#L91-L95)

## 7. Open Source and Product Naming

The source uses the [MIT License](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/LICENSE); code reuse requires retaining the license and copyright notices. Upstream also provides [brand guidelines](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/BRAND_GUIDELINES.md#L5-L10), recommending that community projects use DSH in their names and accurately describe compatibility; `dsh_ios` can continue as the internal project name.

Official resources: [Product website](https://www.deepseek.com/en/harness/) · [Source](https://github.com/deepseek-ai/deepseek-harness) · [Documentation](https://deepseek-harness.github.io/deepseek-harness/).
