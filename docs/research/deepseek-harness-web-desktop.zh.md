# DeepSeek Harness Web / Desktop 实现调研

[English](deepseek-harness-web-desktop.md) | 中文

调研日期：2026-11-03。对象为官方仓库 [deepseek-ai/deepseek-harness](https://github.com/deepseek-ai/deepseek-harness)，不是社区桌面封装。源码固定在 [`ce7073d51254c26cd63b22a60835b8f948deb447`](https://github.com/deepseek-ai/deepseek-harness/tree/ce7073d51254c26cd63b22a60835b8f948deb447)，该提交时间为 2026-10-30；根包版本 `0.2.2-alpha.2`，Node 要求 `>=24.9.0`。

本次进行了文档与源码静态阅读，没有安装依赖、构建、运行 Harness、调用模型或做 iOS 真机验证。下文“已实现”指该提交中存在实现；iOS 路线属于基于证据的建议。上游明确处于 developer preview，可能有破坏兼容的变更。

## 结论

Web 和桌面是同一套产品的不同宿主：共享 TypeScript/Cordis Agent 运行时、React Web 客户端、工具系统和会话数据。桌面以 Electron 承载共享 Web 页面，并启动独立的本机 Host 进程。Agent 本身并不运行在普通 Web 页面中。

iOS 可以复用这套分层思路，但“连接现有 Harness”和“手机独立运行 Harness”是两个不同产品范围。前者主要需要移动客户端与可靠的连接协议；后者还需要 iOS 执行层、持久化和后台任务方案。上游另有实验性的 Web Worker Host，可作为本地执行的研究起点，不能直接当作完整桌面运行时。

## 1. 公共运行时：Cordis 插件树

一个运行中的 Harness 由 profile 和 bundle 组合而成。`dsh-base` 提供模型适配、Agent 循环、工具、持久化、沙箱、审批、设置等；`dsh-web-app` 在其上加入 GUI Host 和浏览器客户端。Desktop 的 profile 使用 Web 的默认 bundle 组合。SDK 与 ACP 是另外的应用表面，不能仅因为都能驱动 Agent 就认为它们等同于完整 GUI 协议。

源码入口：

- [架构与 profile/bundle](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/docs/architecture.md#L7-L27)
- [共享基础能力](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/packages/bundle/base/README.md#L48-L68)

Agent 的基本执行流程为：

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

`ReactLoopAgent` 负责驱动；`tools.execute()` 接收模型产生的完整工具调用批次，执行器决定并发与取消。模型提供商适配器和工具提供者可以替换，所以 iOS 本地实现不必把全部桌面工具一起移植。

- [模型流和工具执行的真实实现](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/packages/core/agent-loop/src/agent.ts#L479-L603)
- [工具注册、执行器和权限管线](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/packages/core/tools/README.md#L26-L98)

## 2. 会话与模型通信

**会话日志是事实来源。** 模型历史、恢复、分支和聊天展示都从 append-only Session events 推导。实时 assistant stream 和已提交的历史消息需要分别处理，不能把每个临时 token 当成完整持久化消息。

第一方 Session 存储使用每会话 JSONL，默认 Zstandard 压缩；本次快照的当前磁盘格式为 v3。SQLite 用于可选的会话查询/全文搜索，不是聊天历史的主存储；默认基础组合 `openAt: never`，不会打开 SQLite 全文索引。

- [Session 事件与实时流的区别](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/docs/architecture.md#L79-L130)
- [JSONL 目录、版本和崩溃恢复](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/packages/session/session-persistence-jsonl/README.md#L55-L79)
- [默认 JSONL 与 SQLite 配置](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/packages/bundle/base/cordis.patch.yml#L138-L161)

**Host 到 DeepSeek 的网络调用和 UI 到 Host 的协议是两层。** 本次源码的官方模型适配器默认使用 `https://api.deepseek.com/anthropic`，向 `/v1/messages` 发 HTTP 请求并读取 SSE；文件使用 `/v1/files`。API key 使用 `x-api-key`，账户登录使用 `x-dsh-auth-token`。这些是 Host 的上游模型凭据，不是移动端连接 Harness Host 的鉴权凭据。

- [模型端点、消息格式和鉴权](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/packages/llm/llm-deepseek/README.md#L80-L99)
- [HTTP 请求与 SSE 读取实现](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/packages/llm/llm-deepseek/src/adapter.ts#L142-L169)

## 2.1 Web 客户端、协议与状态同步

Web 使用 React 18 + TypeScript + Vite 6，实际界面通过 Cordis Client 插件装配。`apps/web` 是入口，主要 UI 在 `packages/client/*`，业务 Remote/BFF 在 `packages/api/*`，服务端承载在 `packages/host/*`。页面需要 Host 的 boot injections，不能把它当成独立的静态 React SPA，直接起 Vite 就得到完整产品。

GUI 使用 **Typert Remote/BFF**，不是 JSON-RPC 2.0。SDK/ACP 则有各自的 JSON-RPC/stdio 集成入口。iOS 如果想覆盖现有 GUI 的会话、工具审批与文件功能，应优先研究 GUI Remote，而不是默认从 SDK/ACP 入手。

### 外部客户端已经有连接入口

连接过程如下，token 为说明用占位符：

```text
GET /connect?token=<host-launch-token>&interactions=answer
  → 302 + Set-Cookie + Location: ./api/remote.mux
  → Send HTTP RPC and establish WebSocket with the same Cookie
  → Open logical streams such as $events and session/follow
```

`/connect` 默认 `interactions=none`；需要接收并回答审批时应明确用 `answer`。这是 Host 连接认证，与 DeepSeek 账户/API key 不同。当前创建的是 owner Peer，没有看到为每个 iOS 应用签发细粒度受限 token 的现成配对流程。

一个 API Cookie 只能绑定一条拥有它的 WebSocket；第二条返回 409。该 socket 关闭会删除 Peer，之后旧 Cookie 的 HTTP 请求会收到 401，客户端必须重新 `/connect`。Host 重启后同样需要重新连接。浏览器 Cookie 与 API Cookie 使用相同名称，因此原生端应使用独立 Cookie 存储，不能与 WebView 登录状态混用。

Host 有 authority/Origin 检查。绑定具体网卡 IP、受信 Host 与 TLS 是部署配置；不能直接照搬常见的 `--host 0.0.0.0`，该上游版本不支持 unspecified bind address。原生端的 302、Cookie、WS 握手和前后台恢复仍需实测。

- [HTTP/WS、鉴权、外部连接与恢复说明](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/packages/client/connection/README.md#L28-L64)
- [/connect 实现](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/packages/client/connection/src/browser-auth.ts#L307-L347)
- [socket 所有权和断线后移除 Peer](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/packages/client/connection/src/rpc-host.ts#L129-L172)

### 操作走 HTTP，实时数据走 WebSocket

| 用途 | 接口/机制 | iOS 实现重点 |
|---|---|---|
| 创建会话 | `POST /api/session/create` | 读取 Host 实际返回的 sessionId |
| 发送输入 | `POST /api/session/prompt` | requestId、queue/steer、文本/附件；返回 accepted，不返回模型答案 |
| 取消当前任务 | `POST /api/session/cancel` | 必须显式取消，关闭 follow 不等于取消 turn |
| 追踪会话 | WS `/api/remote.mux` 中 `session/follow` | snapshot → durable event + 可选 assistant-stream |
| 全局状态 | 同一 mux 中 `session/control` | baseline 后替换各 projection |
| 工具审批 | 同一 mux 中 `$events`；HTTP `/api/$events/result` 回答 | ready/clientId/eventId、取消事件、pending waterfall 重放 |
| 上传附件 | `POST /api/session/uploadFileBinary` | 原始 bytes 流、Session receipt、独立结果格式 |

普通调用示例（未包含认证 Cookie）：

```json
{
  "type": "client-request",
  "rpcId": "rpc-demo",
  "method": "session/create",
  "payload": { "args": { "request": { "cwd": "/work/demo" } } }
}
```

响应使用 `type: server-response`、相同 `rpcId` 与 `result: {ok, value|error}`，因此 HTTP 200 不保证业务成功。WS 使用 JSON text frames，`streamId` 标记逻辑流，帧类型为 open/item/end/cancel/error；不是每个会话各开一条物理 socket。

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

- [HTTP RPC envelope 与 multipart 响应分支](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/packages/client/connection/src/client/rpc.ts#L34-L69)
- [WS mux 帧定义](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/packages/api/gateway/src/stream-protocol.ts#L234-L257)
- [会话创建、输入与取消类型](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/packages/api/session-controller/src/types.ts#L264-L369)

### 重连与流式展示的难点

`session/follow` 首帧是 snapshot，包含 header、cursor、records、hasMore、projections，随后发送有序 durable events。另有临时 `assistant-stream` 的 start/chunk/end，以 attemptId、revision、index 排序；最终 committed end 指向正式消息的 seq。

iOS 应保存“已提交历史”和“当前生成中的 attempt”两种状态，在完成时合并，避免 token 和最终消息重复。断线时重新建立身份与订阅，读取新的 snapshot 和 activeAttempt baseline；不能只保存一个本地 cursor 就假设服务端会自动补全。上游 Web 已有 seq gap 检查与恢复，这些语义适合迁移，但 Swift 端需要自己的状态实现。

- [snapshot、durable event 与 assistant attempt 定义](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/packages/api/session-controller/src/types.ts#L450-L583)

### 文件与移动 UI

raw 上传以 `application/octet-stream` 发送，query 带 sessionId/name，图片另带 mediaType；结果是直接 `{ok,value|error}`，不带普通 rpcId envelope。receipt 再加入 prompt。部分文件读取 RPC 返回 multipart/form-data：metadata 中有 JSON envelope 和 bytes placeholder，独立 part 放二进制。Swift 端不能把所有接口都按 JSON/base64 解析。

- [原始上传实现](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/packages/client/file-upload/src/http-route.ts#L23-L71)

现有 Web 已有小屏侧栏 drawer、iPhone/iPad 检测、移动端抑制自动 focus 和 Safari 输入框修复。复用 WebView 有实际基础，但不代表 iOS 的键盘、安全区、文件选择和后台恢复已经验证。GUI Remote 能力由构建时显式导入与挂载，没有通用的运行时能力发现；再加上上游 API 预稳定，原生实现最好固定兼容的 Host 版本。

- [Remote 能力集合与重放限制](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/packages/api/remotes/README.md#L73-L79)

## 3. 桌面版如何实现

桌面包使用 Electron + TypeScript，构建/打包采用 Vite 与 electron-builder。结构是：

```text
Electron main
  ├─ BrowserWindow + preload → Shared React Web UI
  ├─ Native bridge → File pick/save, clipboard, drag-out, windows, updates
  └─ spawn Electron Node-mode child → Desktop Host
                                      └─ Shared CLI profile runner
                                          └─ dsh-base + dsh-web-app
```

### 启动与代码复用

1. 壳先打开打包的 Web loading document。
2. 准备 `$DSH_HOME/profiles/desktop` 和本机环境。
3. `DesktopHostProcess.start()` 启动独立 Host，通过 Node IPC 传 boot/readiness/shutdown 等控制消息。
4. Host 调用共享 `runProfile()`，参数包括 `--host 127.0.0.1 --port 0`，默认使用系统分配的端口。
5. 页面等待 `dshDesktopBoot.ready()`，接收注入信息与 stream URL，启动同一个 `AppWebEntry`。

`BrowserWindow` 开启 sandbox/context isolation，关闭 Node integration。preload 提供定向原生方法；模型对话数据仍走共享 Web 通信层。应用页面资源来自 `@deepseek-ai/dsh-web-frontend/dist`，通过 `dsh-app://app/` 加载。Welcome 页面是桌面另有的一小套 React UI。

- [Host 子进程与 IPC](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/apps/desktop/src/host-process.ts#L209-L224)
- [Host 调用共享 profile runner](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/apps/desktop-host/src/index.ts#L22-L48)
- [同一 Web 入口的桌面启动分支](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/apps/web/src/main.ts#L17-L37)
- [打包 Web 资源与受控 Host 连接](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/apps/desktop/src/main.ts#L762-L821)
- [定向 preload 能力](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/apps/desktop/src/preload-app.ts#L79-L118)

### 生命周期对 iOS 的影响

关闭桌面主窗口通常只是隐藏，Host 继续工作。真正退出会检查任务、提示用户、请求 Host 有序关闭，必要时终止进程。桌面还携带 Node/Python/pnpm 等本机执行载荷；更新时壳和运行时保持版本一致。

这些机制依赖桌面进程模型，不能直接映射为 iOS 退到后台后继续无限运行。桌面源码中没有核实到“连接任意远端 Host”的现成产品流程；实际桌面启动路径始终拥有并启动本机 Host。共享 Web 的网络部署能力与桌面远端连接管理需要分开判断。

## 4. 实验性的浏览器本地运行

`packages/experimental/webworker-runtime` 已能在 Dedicated Web Worker 中加载完整插件树。它用打包的 VFS 镜像、模块加载器、Node API 兼容层和 postMessage HTTP 隧道替代普通 Node Host。

这证明“部分共享 TypeScript 运行时可在非 Node 环境运行”有上游基础，但限制明确：

- VFS 是内存中的文件系统；有可选 durable sink 扩展点，缺省未附 sink 时是临时数据。配置修改只保证当前 Worker 生命周期。WebFS 目录选项在该版本仍 disabled，不能据此宣称用户文件访问已完成。
- Shell 由 Worker 内的解释器和 coreutils 命令表实现，不是完整 bash；没有 git、网络命令、循环、函数和任意原生程序执行。
- pnpm、插件安装、原生依赖安装不可用；PTC Node 执行、Office 转换、部分其他 Agent/provider 能力不可用。
- `node:net`、`node:sqlite`、`node:worker_threads` 等只是会明确报错的 stub。
- 现有浏览器启动验收以 Chromium 为依据，本次没有 WKWebView/WebKit/iOS 兼容证据，也没有真实模型请求验证。

因此可以把它当作 WKWebView 本地模式的技术验证候选，但不能把它当作成熟的 iOS 移植包。

- [Worker 架构与限制](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/packages/experimental/webworker-runtime/README.md#L26-L76)
- [可选持久化 sink](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/packages/experimental/webworker-runtime/src/storage/memory.ts#L189-L230)
- [尚不可用的 WebFS 目录选择](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/packages/experimental/webworker-runtime/src/client/source-chooser.ts#L205-L219)

## 5. iOS 路线建议

| 路线 | 运行位置 | 可复用部分 | 主要新增工作 | 适用目标 |
|---|---|---|---|---|
| SwiftUI 原生连接版 | Agent/工具在 Mac 或服务器；UI 在 iOS | Host、工具、Session 体系、网络协议语义 | 连接/配对、协议客户端、聊天状态同步、原生工具卡和文件流转 | 先获得完整 Harness 能力和原生移动体验 |
| WKWebView 连接版 | Agent/工具在外部 Host；共享 Web UI 在 iOS | 现有 React UI 与大部分客户端状态逻辑 | 移动适配、宿主 bridge、认证/导航/文件权限 | 较快验证端到端功能和 UI 插件兼容 |
| 本地独立版 | iOS 执行 Agent 和受限工具；模型推理仍调用云端 API | 精选 TypeScript 插件、实验性 Worker 思路，或移植后的领域逻辑 | 执行环境、持久化、原生文件/网络工具、后台恢复、插件兼容范围 | 手机无需另一台 Host 的独立产品 |

后续讨论已确定方向：**电脑端安装 ds-harness-remote，iOS 做重新设计的原生客户端**。SwiftUI 为建议技术栈；连接侧复用 Remote 插件生态，UI 独立设计。具体研究、协议差异和第一版设计方向见 [ds-harness-remote 接入调研](ds-harness-remote-ios.zh.md)。下述原生连接版建议继续适用，直连官方 HTTP/WebSocket 的细节作为底层参考，实际客户端优先实现 Remote 的加密隧道协议。

原生连接版首个纵向切片建议覆盖：连接 Host → 列出/创建会话 → 发送消息 → 流式文本与 reasoning → 工具状态/审批 → 取消 → 断网/切后台后恢复。文件附件和产物预览放在同一条核心流程之后验证。远端执行时，DeepSeek 凭据可以留在 Host，iOS 保存自己的 Host 连接凭据。

iOS 独立运行版需先验证：Worker 在 WKWebView 中的启动与网络请求、重启后的 Session/VFS 恢复、App 私有目录与用户选中文档的映射、取消行为，以及只包含受支持工具的 profile。不能把浏览器兼容的 JavaScript 等同于全部 Node 原生包可用。

## 6. Apple 平台约束

这些约束用于判断执行架构，不代表本次已完成 App Store 合规评估。

- [App Review Guidelines 2.5.2、2.5.4 与 4.7](https://developer.apple.com/app-store/review/guidelines/)：App 容器、下载执行代码与后台服务均有约束。4.7 对部分插件/小程序有另外规定，不能简单推导为“所有插件均禁止”或“桌面插件任意安装都可行”。
- [BGContinuedProcessingTask](https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtask)：iOS 26 起可让前台开始的特定任务继续处理，需要进度报告，可被用户取消，也可能因资源限制终止。它不是永久后台 daemon 的保证。
- [URLSessionWebSocketTask](https://developer.apple.com/documentation/foundation/urlsessionwebsockettask)：可实现原生 Swift WebSocket 客户端；连接存活不等于 iOS 后台无限执行，回前台仍需可靠恢复。

账户登录也有单独限制：当前上游浏览器账户登录只支持本机或 SSH 转发到 loopback，不支持非 loopback reverse proxy。移动 Host 配对与 DeepSeek 账户授权必须分别设计，不能直接假定已有 iOS OAuth 流程。

- [当前账户登录支持范围](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/packages/credentials/deepseek-account-platform/README.md#L43-L66)
- [账户登录已知限制](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/packages/credentials/deepseek-account-platform/README.md#L91-L95)

## 7. 开源与产品命名

源码采用 [MIT License](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/LICENSE)，复用代码需保留许可和版权通知。上游另有[品牌使用指引](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/BRAND_GUIDELINES.md#L5-L10)，建议社区项目以 DSH 命名并准确描述兼容关系；当前 `dsh_ios` 可作为内部工程名继续使用。

官方入口：[产品网站](https://www.deepseek.com/en/harness/) · [源码](https://github.com/deepseek-ai/deepseek-harness) · [文档](https://deepseek-harness.github.io/deepseek-harness/)。
