# A native iOS client through ds-harness-remote

English | [中文](ds-harness-remote-ios.zh.md)

Date: 2026-11-03. Research target: [liguobao/ds-harness-remote](https://github.com/liguobao/ds-harness-remote), pinned to [`c374397dea2bea0e5a81adc993553be992102bc6`](https://github.com/liguobao/ds-harness-remote/tree/c374397dea2bea0e5a81adc993553be992102bc6), plugin version `0.6.2`.

This is static research. No plugin was installed, service run, external account accessed, or cross-device connection established. The source and protocol support design work; iOS interoperability has not been verified.

## Product direction

The direction is to install ds-harness-remote on the computer and build a redesigned native iOS client. The agent, model connections, project files, and tool execution remain on the computer; iOS handles conversations, task observation, approvals, file viewing, and connection recovery.

SwiftUI is proposed. The existing Android/Expo functionality and protocol are references; iOS navigation, typography, components, and gestures are designed independently. Prioritize continuing a conversation, understanding task activity, and responding to an approval comfortably on a phone.

## 1. What it provides

The project provides a data channel with device identity and encryption.

```text
iOS App
  ├─ HTTPS → Remote Server: login, registration, discovery, refresh
  ├─ WSS → Remote Server: coordination, heartbeat, handshake, relay
  └─ Noise-encrypted channel → Remote plugin on the computer
                              → Harness Typert Remote Gateway
                              → sessions, tools, approvals, workspaces
```

Both Host and Client establish outbound connections to the Server. Network paths can use LAN/P2P/TURN and fall back to WebSocket Relay, so the computer generally needs no public listener or router port forwarding.

This design uses Remote Server device credentials, Control, Noise, and Remote RPC as its outer connection layer, with the Host plugin calling the Harness Gateway. The official Web `/connect` + Cookie + `/api/remote.mux` flow is a lower-level reference.

Sources:

- [Installation, supported clients, and default service](https://github.com/liguobao/ds-harness-remote/blob/c374397dea2bea0e5a81adc993553be992102bc6/README.md#L73-L134)
- [Network planes, connection flow, and fallback](https://github.com/liguobao/ds-harness-remote/blob/c374397dea2bea0e5a81adc993553be992102bc6/docs/network.md#L41-L143)

## 2. Plugin installation and Server deployment

On the computer, install `ds-harness-remote@0.6.2` through the existing Harness Desktop plugin manager and restart. The corresponding CLI command is:

```bash
dsh plugin --profile desktop add -w ds-harness-remote@0.6.2
```

The plugin defaults to the author's hosted `https://dsh.r2049.cn`. The computer and phone must use the same Server and account. Available login methods and registration conditions are determined by that service.

For self-hosting, the upstream repository's `apps/server` provides a single-account service, device registration and credential refresh, device discovery, Control, and Relay, with a Docker image. It does not include the complete hosted Remote Web application, multi-account system, or full WebRTC/TURN coordination. Its `hello.ack` explicitly sends `webrtcEnabled: false` and negotiates only `transport.relay`.

The existing minimal Server is sufficient for developing native iOS, while a configurable Server URL avoids tying the client to the author's service.

- [Desktop plugin installation](https://github.com/liguobao/ds-harness-remote/blob/c374397dea2bea0e5a81adc993553be992102bc6/README.md#L88-L98)
- [Self-hosting scope and Docker](https://github.com/liguobao/ds-harness-remote/blob/c374397dea2bea0e5a81adc993553be992102bc6/apps/server/README.md#L1-L32)
- [Relay-only negotiation in the minimal Server](https://github.com/liguobao/ds-harness-remote/blob/c374397dea2bea0e5a81adc993553be992102bc6/apps/server/src/gateway.ts#L77-L88)

## 3. Existing mobile client and iOS status

The public mobile client lives in `apps/android`, uses React Native / Expo, and directly depends on shared `client-core`, `crypto`, `protocol`, and `webrtc` packages. Its configuration includes an iOS bundle identifier and `expo run:ios`, but identity creation still explicitly uses `platform: android`, and platform-specific code includes an Android foreground service.

The author's [iOS beta issue](https://github.com/liguobao/ds-harness-remote/issues/20) describes an iOS beta. This does not establish that the public repository provides a separate Swift implementation or fully supports our design.

The most useful public client references are device discovery, public-key pinning, token refresh, Host capability probing, session reads/subscriptions, model selection, approvals, and foreground reconnection.

- [Mobile dependencies and iOS launch command](https://github.com/liguobao/ds-harness-remote/blob/c374397dea2bea0e5a81adc993553be992102bc6/apps/android/package.json#L6-L64)
- [iOS configuration](https://github.com/liguobao/ds-harness-remote/blob/c374397dea2bea0e5a81adc993553be992102bc6/apps/android/app.json#L10-L14)
- [Current device identity creation and private-key storage](https://github.com/liguobao/ds-harness-remote/blob/c374397dea2bea0e5a81adc993553be992102bc6/apps/android/src/services/storage.ts#L35-L63)

## 4. Swift integration modules

| Module | Responsibility | Upstream reference |
|---|---|---|
| Server API | Login, register a Client device, refresh tokens, list devices, query Host public keys | `apps/android/src/services/api.ts` |
| Device identity | Generate identity keys locally; store keys/credentials in Keychain; pin remote keys per Server and device | `storage.ts` and encryption documentation |
| Control / Relay transport | hello, connect, heartbeat, transport.selected, relay, separate data attach | `packages/webrtc/src/adaptive-transport.ts` |
| Noise secure channel | IK handshake, bind connection/Host/Client, encryption/decryption, ordered fragmentation | `packages/crypto/src/noise.ts`, `secure-transport.ts` |
| Remote RPC | requestId correlation, timeouts, terminate pending calls on closure, event dispatch | `packages/client-core/src/index.ts` |
| Harness gateway adapter | Capabilities, unary/stream calls, Session state, approvals, large-message transfer | `remote-gateway.ts`, `harness-alpha-client.ts` |
| App state / UI | Session list, messages and tool activity, approvals, navigation, foreground/background recovery | New SwiftUI implementation |

The login/registration endpoints have concrete implementations:

- `POST /api/v1/auth/login`: exchange account credentials for short-lived registration authorization.
- `POST /api/v1/devices/register`: register `role: client`; the new client should use `platform: ios`.
- `POST /api/v1/auth/refresh`: refresh device credentials.
- `GET /api/v1/devices` and `/api/v1/devices/<id>`: discover Hosts and read authorized identity descriptions.
- WSS `/ws/v1/connect`: include the device access token in hello and negotiate the connection.

These Remote Server credentials differ from the DeepSeek model API key. The phone does not need the computer's model credentials.

- [REST client implementation](https://github.com/liguobao/ds-harness-remote/blob/c374397dea2bea0e5a81adc993553be992102bc6/apps/android/src/services/api.ts#L212-L270)
- [Control hello implementation](https://github.com/liguobao/ds-harness-remote/blob/c374397dea2bea0e5a81adc993553be992102bc6/packages/webrtc/src/adaptive-transport.ts#L123-L164)

### Encryption and interoperability

The protocol fixes `Noise_IK_25519_ChaChaPoly_SHA256`. The handshake prologue binds the protocol version, connectionId, Host deviceId, and Client deviceId. The full Noise state machine, nonce ordering, and fragmentation must interoperate.

Use a maintained Noise library or a validated implementation, check the repository's `fixtures/crypto/v1/noise-ik.json` golden vector byte for byte, then connect to a real Host. Swift cryptographic primitives are not a complete Noise IK implementation; dependency selection remains part of the technical validation.

Business messages exceeding 48 KiB use secure fragmentation, with a 4 MiB complete-message limit. Images and large responses also use a separate business transfer mechanism. Serialize sends to preserve Noise counters and fragment order.

- [Noise wrapper and prologue](https://github.com/liguobao/ds-harness-remote/blob/c374397dea2bea0e5a81adc993553be992102bc6/packages/crypto/src/noise.ts#L11-L47)
- [Serialized encrypted sends and reassembly](https://github.com/liguobao/ds-harness-remote/blob/c374397dea2bea0e5a81adc993553be992102bc6/apps/android/src/services/secure-transport.ts#L54-L99)
- [Protocol constants](https://github.com/liguobao/ds-harness-remote/blob/c374397dea2bea0e5a81adc993553be992102bc6/packages/protocol/src/index.ts#L5-L23)
- [Cross-implementation test vector](https://github.com/liguobao/ds-harness-remote/blob/c374397dea2bea0e5a81adc993553be992102bc6/fixtures/crypto/v1/noise-ik.json)

The source implements encryption and identity checks; this research did not audit cryptographic security. Upstream also lists an independent cryptographic review and long-lived connection rekeying as roadmap items.

### Relay first, then WebRTC

The proposed first version implements the supported Relay path with Noise and identity verification, validating the complete remote product while matching the public minimal Server. Add iOS WebRTC DataChannel, ICE, TURN, and direct-path optimization later. Session state and UI should be independent of the transport path.

Relay has two carriers: the older path sends relay frames over the Control socket; `transport.relay.attach` uses a Server-assigned data endpoint and short-lived ticket when supported. Implement the capabilities actually negotiated.

- [Relay send implementation](https://github.com/liguobao/ds-harness-remote/blob/c374397dea2bea0e5a81adc993553be992102bc6/packages/webrtc/src/adaptive-transport.ts#L168-L191)
- [Separate Relay data socket attachment](https://github.com/liguobao/ds-harness-remote/blob/c374397dea2bea0e5a81adc993553be992102bc6/packages/webrtc/src/adaptive-transport.ts#L543-L570)

### Harness calls, streams, and approvals

Probe capabilities with `harness.transport.describe`. Unary calls send `{ endpoint, payload: { args: request } }` through `harness.remote.call`. `args` must be a single plain object; current Hosts reject conversion to positional arrays. The Host exposes an endpoint allowlist.

Open streams through `harness.remote.stream.open`, correlate `harness.remote.frame` and `harness.remote.stream.closed` with `streamId`, and close with `harness.remote.stream.close`. Register subscriptions before the open request to avoid losing the first frame. Connection closure must terminate pending calls and streams.

Approvals use the `$events` subscription, ready/cancel lifecycle, and `$events/result` responses, preserving `clientId` and `eventId`. Allow once maps to `allowed-once`, rejection to `rejected`; obtain fresh valid requests after reconnection.

- [Gateway calls and stream lifecycle](https://github.com/liguobao/ds-harness-remote/blob/c374397dea2bea0e5a81adc993553be992102bc6/packages/plugin/src/remote-typert-gateway.ts#L28-L182)
- [Approval results and event subscription](https://github.com/liguobao/ds-harness-remote/blob/c374397dea2bea0e5a81adc993553be992102bc6/packages/client-core/src/harness-alpha-client.ts#L713-L769)

## 5. Initial iOS interface direction

These are product proposals, not an approved final visual design.

### Navigation and screens

- Sessions are the main entry: recent conversations, active work, and items awaiting a response share a searchable list, with device and project context on each row, avoiding repeated drill-down through devices.
- Devices manages online computers, connection/trust state, and workspaces. If no Host exists, show onboarding; return to conversations once connected.
- Settings handles the account, Server, appearance, and connection options. P2P/TURN/Relay details belong in connection details; chat shows actionable states such as connected, reconnecting, or computer offline.
- Use native navigation pushes and sheets on iPhone and sidebar + detail on iPad. Follow Dynamic Type and system light/dark appearance.

### Chat and tool activity

- Keep the session title at the top, device/workspace as secondary context, and model selection in an expandable menu.
- Prioritize readable message width, paragraphs, and copyable code. Collect tool execution in an expandable activity area showing current actions and results.
- Collapse thinking by default and let the user expand it; new tokens should not animate the entire page layout individually.
- Keep the composer stable against the keyboard, use native sheets for attachments and photos, and retain an explicit stop button during generation.
- Preserve position when the user reads history, offer a return-to-latest action, and avoid forcing the view to the bottom on reconnection.

### Approvals and recovery

- Place pending approvals near the current task. A native sheet shows the actual command/file operation, scope, and allow-once/reject choices. Show other authorization modes only when the Host supports them.
- Remove approvals when their handles are revoked or invalidated by reconnection, so stale buttons cannot remain actionable.
- On foreground return, rebuild transport/Noise and reload the session baseline. Do not automatically replay unconfirmed sends. Drafts may persist, but a network failure does not establish that the Host never received a request.
- Tasks accepted by the Host continue on the computer. iOS does not guarantee a persistent background connection. Live background push needs separate Server/APNs support; the existing Android client also lacks an independent push service.

## 6. First-version scope and verification order

Pin plugin `0.6.2` and a verified Harness baseline for interoperability. Remote currently documents `dsh-v0.2.1-rc.5`; a peer range accepting `0.2.2` prereleases does not demonstrate runtime acceptance of that version. The official master researched earlier is `0.2.2-alpha.2`; the combination needs practical verification.

- [Compatibility baseline and verification boundary](https://github.com/liguobao/ds-harness-remote/blob/c374397dea2bea0e5a81adc993553be992102bc6/docs/compatibility.zh.md#L1-L19)

Proposed implementation order:

1. Define session list, chat, tool activity, and approval screens and produce an interactive prototype.
2. Establish minimal Relay + Noise connectivity, pass the golden vector, then connect to a real Host and read capabilities and workspaces.
3. Complete session creation/resume, text sending, streaming, tool approvals, and stop, including foreground/background and network recovery.
4. Add history pagination, images/files, artifact previews, and large-message transfer verification.
5. Add WebRTC and other optional backends. Prioritize DSH in the first version; Codex/ACP can use the same transport later.

Visible UI plugins need individual evaluation: SwiftUI does not automatically render arbitrary Host React plugins. The first version uses explicit native tool/approval components and a readable generic result view for unsupported tools.

## 7. Research boundaries

Use capability probing and the actual Host Gateway as the current authority. `harness.api.*` ApiProxy has been retired from current Host/mobile main paths; remaining shared types do not justify implementing it as the new client's primary protocol.

Some documentation is stale: the network page describes the Server as a separate repository, while this revision includes minimal `apps/server`. This report cross-checks the current README, Server implementation, and compatibility reference.

The project manifest declares MIT and provides [packages/plugin/LICENSE](https://github.com/liguobao/ds-harness-remote/blob/c374397dea2bea0e5a81adc993553be992102bc6/packages/plugin/LICENSE). Preserve the relevant notices when reusing source.
