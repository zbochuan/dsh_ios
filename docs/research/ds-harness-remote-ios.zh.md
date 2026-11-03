# 基于 ds-harness-remote 的原生 iOS 客户端

[English](ds-harness-remote-ios.md) | 中文

日期：2026-11-03。研究对象：[liguobao/ds-harness-remote](https://github.com/liguobao/ds-harness-remote)，固定提交 [`c374397dea2bea0e5a81adc993553be992102bc6`](https://github.com/liguobao/ds-harness-remote/tree/c374397dea2bea0e5a81adc993553be992102bc6)，插件版本 `0.6.2`。

本次为静态研究，没有安装插件、运行服务、登录外部账号或建立跨设备连接。本文确认源码和协议可用于方案设计，不宣称已经验证 iOS 互通。

## 产品方向

采用电脑端安装 ds-harness-remote、iOS 做重新设计的原生客户端的方向。Agent、模型连接、项目文件与工具执行继续在电脑端；iOS 负责对话、任务观察、审批、文件查看和连接恢复。

建议使用 SwiftUI。现有 Android/Expo 的功能与协议可作参考，iOS 导航、排版、组件和手势独立设计。优先让“继续一段对话、知道任务在做什么、回答一次审批”在手机上顺畅完成。

## 1. 它解决了哪些问题

该项目提供带设备身份与加密的数据通道。

```text
iOS App
  ├─ HTTPS → Remote Server: login, registration, discovery, refresh
  ├─ WSS → Remote Server: coordination, heartbeat, handshake, relay
  └─ Noise-encrypted channel → Remote plugin on the computer
                              → Harness Typert Remote Gateway
                              → sessions, tools, approvals, workspaces
```

Host 和 Client 都主动向 Server 建立出站连接。网络路径可使用 LAN/P2P/TURN，失败时回到 WebSocket Relay，因此通常不需要给电脑配置公网监听和路由器端口映射。

本方案的外层使用 Remote Server 的设备凭据、Control、Noise 和 Remote RPC，再由 Host 插件调用 Harness Gateway。官方 Web 的 `/connect` + Cookie + `/api/remote.mux` 流程仅作底层参考。

来源：

- [安装、支持客户端和默认服务](https://github.com/liguobao/ds-harness-remote/blob/c374397dea2bea0e5a81adc993553be992102bc6/README.md#L73-L134)
- [网络平面、连接流程与降级](https://github.com/liguobao/ds-harness-remote/blob/c374397dea2bea0e5a81adc993553be992102bc6/docs/network.md#L41-L143)

## 2. 安装插件与部署 Server

电脑端是在现有 Harness Desktop 的插件管理中安装 `ds-harness-remote@0.6.2`，然后重启。CLI 对应命令：

```bash
dsh plugin --profile desktop add -w ds-harness-remote@0.6.2
```

插件默认使用作者托管的 `https://dsh.r2049.cn`。电脑和手机需要连接同一个 Server，并属于同一账号。作者托管站支持的登录方式与注册条件由该站决定。

如果自部署，上游仓库的 `apps/server` 已提供单账号、设备注册与凭据刷新、设备发现、Control 和 Relay，有 Docker 镜像；它没有开源完整托管 Remote Web、多账号系统和完整 WebRTC/TURN 协调能力。实际 `hello.ack` 明确发送 `webrtcEnabled: false`，只协商 `transport.relay`。

我们可以在现有最小 Server 上开发原生 iOS，同时保留自定义 Server URL，避免把客户端锁在作者的托管服务上。

- [Desktop 插件安装](https://github.com/liguobao/ds-harness-remote/blob/c374397dea2bea0e5a81adc993553be992102bc6/README.md#L88-L98)
- [自部署范围与 Docker](https://github.com/liguobao/ds-harness-remote/blob/c374397dea2bea0e5a81adc993553be992102bc6/apps/server/README.md#L1-L32)
- [最小 Server 的 Relay-only 协商实现](https://github.com/liguobao/ds-harness-remote/blob/c374397dea2bea0e5a81adc993553be992102bc6/apps/server/src/gateway.ts#L77-L88)

## 3. 已有移动端与 iOS 状态

公开移动端位于 `apps/android`，使用 React Native / Expo，直接依赖共享的 `client-core`、`crypto`、`protocol` 和 `webrtc` 包。配置中已有 iOS bundle identifier 和 `expo run:ios`，但身份创建代码仍明确写着 `platform: android`，存在 Android 前台服务等平台实现。

作者的 [iOS 内测 issue](https://github.com/liguobao/ds-harness-remote/issues/20) 说明 iOS 正在内测，不能据此推断公开仓库提供了独立的 Swift 实现或已经完整支持我们的设计。

公开客户端最值得参考的是：设备列表、公钥固定、token refresh、Host capability probing、会话读取/订阅、模型选择、审批和前台重连。

- [移动客户端依赖与 iOS 启动命令](https://github.com/liguobao/ds-harness-remote/blob/c374397dea2bea0e5a81adc993553be992102bc6/apps/android/package.json#L6-L64)
- [iOS 配置](https://github.com/liguobao/ds-harness-remote/blob/c374397dea2bea0e5a81adc993553be992102bc6/apps/android/app.json#L10-L14)
- [当前设备身份创建和私钥存储](https://github.com/liguobao/ds-harness-remote/blob/c374397dea2bea0e5a81adc993553be992102bc6/apps/android/src/services/storage.ts#L35-L63)

## 4. Swift 接入的模块划分

| 模块 | 职责 | 上游参考 |
|---|---|---|
| Server API | 登录、注册 Client device、刷新 token、列出设备、查询 Host 公钥 | `apps/android/src/services/api.ts` |
| Device identity | 本地产生身份密钥；Keychain 保存私钥/凭据；按 Server 与设备固定远端公钥 | `storage.ts` 与加密文档 |
| Control / Relay transport | hello、connect、心跳、transport.selected、relay、独立 data attach | `packages/webrtc/src/adaptive-transport.ts` |
| Noise secure channel | IK 握手、绑定 connection/Host/Client、加解密、有序分片 | `packages/crypto/src/noise.ts`、`secure-transport.ts` |
| Remote RPC | requestId 关联、超时、关闭时结束 pending calls、事件分派 | `packages/client-core/src/index.ts` |
| Harness gateway adapter | capabilities、unary/stream、Session 状态、审批与大消息 transfer | `remote-gateway.ts`、`harness-alpha-client.ts` |
| App state / UI | 会话列表、消息和工具过程、审批、导航、前后台恢复 | 新的 SwiftUI 实现 |

登录/注册入口已有明确实现：

- `POST /api/v1/auth/login`：账号凭据换短期注册授权。
- `POST /api/v1/devices/register`：注册 `role: client`，新客户端应使用 `platform: ios`。
- `POST /api/v1/auth/refresh`：刷新设备凭据。
- `GET /api/v1/devices` 与 `/api/v1/devices/<id>`：发现 Host，读取受授权的身份描述。
- WSS `/ws/v1/connect`：在 hello 中携带设备 access token，协商连接。

这些 Remote Server 凭据与 DeepSeek 模型 API key 是不同的，手机不需要取得电脑上的模型密钥。

- [REST 客户端实际实现](https://github.com/liguobao/ds-harness-remote/blob/c374397dea2bea0e5a81adc993553be992102bc6/apps/android/src/services/api.ts#L212-L270)
- [Control hello 实现](https://github.com/liguobao/ds-harness-remote/blob/c374397dea2bea0e5a81adc993553be992102bc6/packages/webrtc/src/adaptive-transport.ts#L123-L164)

### 加密与互操作

协议固定使用 `Noise_IK_25519_ChaChaPoly_SHA256`。握手 prologue 绑定协议版本、connectionId、Host deviceId 和 Client deviceId，需要完整的 Noise 状态机、nonce 顺序和分片互通。

建议选用维护中的 Noise 库或复用经过验证的实现，通过仓库提供的 `fixtures/crypto/v1/noise-ik.json` golden vector 逐字节校验，再接真实 Host。Swift 的密码基础组件不等于完整的 Noise IK 实现，依赖选型是技术验证中的一项。

业务消息超过 48 KiB 时先做 secure fragmentation，完整消息上限 4 MiB；图片和大响应还会走独立的业务 transfer。发送必须串行，避免 Noise counter 和片段乱序。

- [真实 Noise 封装和 prologue](https://github.com/liguobao/ds-harness-remote/blob/c374397dea2bea0e5a81adc993553be992102bc6/packages/crypto/src/noise.ts#L11-L47)
- [加密发送串行化与重组](https://github.com/liguobao/ds-harness-remote/blob/c374397dea2bea0e5a81adc993553be992102bc6/apps/android/src/services/secure-transport.ts#L54-L99)
- [协议常量](https://github.com/liguobao/ds-harness-remote/blob/c374397dea2bea0e5a81adc993553be992102bc6/packages/protocol/src/index.ts#L5-L23)
- [跨实现测试向量](https://github.com/liguobao/ds-harness-remote/blob/c374397dea2bea0e5a81adc993553be992102bc6/fixtures/crypto/v1/noise-ik.json)

源码体现了加密和身份检查机制，本次没有做密码安全审计；上游也注明独立密码审查与长期连接 rekey 尚在路线图中。

### 先 Relay，再 WebRTC

建议第一版只实现协议支持的 Relay 路径，保留 Noise 和身份校验，先验证完整远程产品，也与公开最小 Server 的能力吻合。之后再增加 iOS WebRTC 的 DataChannel、ICE、TURN 和直连优化；上层会话状态和 UI 不应依赖连接路径。

Relay 有两种承载：旧路径在 Control socket 中发 relay frame；支持 `transport.relay.attach` 时使用 Server 分配的 data endpoint 和短期 ticket。客户端应按实际协商的 capability 实现。

- [Relay 发送实现](https://github.com/liguobao/ds-harness-remote/blob/c374397dea2bea0e5a81adc993553be992102bc6/packages/webrtc/src/adaptive-transport.ts#L168-L191)
- [独立 Relay data socket 绑定](https://github.com/liguobao/ds-harness-remote/blob/c374397dea2bea0e5a81adc993553be992102bc6/packages/webrtc/src/adaptive-transport.ts#L543-L570)

### Harness 调用、流与审批

用 `harness.transport.describe` 探测能力；普通调用通过 `harness.remote.call` 发送 `{ endpoint, payload: { args: request } }`。`args` 必须是单个 plain object，转换成位置参数数组会被当前 Host 拒绝。Host 仅开放允许列表中的 endpoint。

流通过 `harness.remote.stream.open` 建立，以 `streamId` 关联 `harness.remote.frame` 与 `harness.remote.stream.closed`，结束时调用 `harness.remote.stream.close`。订阅需要在 open 请求前注册，防止丢失首帧；连接关闭时必须结束等待中的调用与流。

审批使用 `$events` 订阅、ready/cancel 生命周期及 `$events/result` 响应，保留 `clientId` 与 `eventId`。允许一次对应 `allowed-once`，拒绝对应 `rejected`；重连后要重新取得有效请求。

- [Gateway 调用与流生命周期](https://github.com/liguobao/ds-harness-remote/blob/c374397dea2bea0e5a81adc993553be992102bc6/packages/plugin/src/remote-typert-gateway.ts#L28-L182)
- [审批结果与事件订阅](https://github.com/liguobao/ds-harness-remote/blob/c374397dea2bea0e5a81adc993553be992102bc6/packages/client-core/src/harness-alpha-client.ts#L713-L769)

## 5. iOS 界面重新设计的初稿

这部分是产品建议，尚不是已经确认的最终视觉稿。

### 导航和页面

- 会话作为主入口：最近对话、正在运行、等待回复放在同一个可搜索列表中；每行带设备与项目上下文，无需每次从设备逐层进入。
- 设备管理在线电脑、连接/信任状态与工作区。首次没有 Host 时展示接入说明，接入后回到会话体验。
- 设置处理账号、Server、外观和连接选项。P2P/TURN/Relay 等实现细节放在连接详情；聊天只显示“已连接、重连中、电脑离线”等可行动状态。
- iPhone 用原生 navigation push 和 sheet；iPad 采用 sidebar + detail。布局跟随 Dynamic Type 和系统深浅色。

### 聊天和工具过程

- 顶部保持会话标题，设备/工作区作为次级上下文，模型选择放在可展开菜单。
- 消息正文优先保证阅读宽度、段落和代码可复制性；工具执行收成一条可展开的活动区域，显示当前动作与结果。
- 思考内容默认折叠，用户可展开查看；新 token 不逐个触发整页布局动画。
- 底部输入框稳定贴合键盘，附件与相册从原生 sheet 进入，生成时保留明确的停止按钮。
- 用户向上读历史时保持位置，提供“回到最新”；重新连接不把当前阅读位置强行拉到底部。

### 审批与恢复

- 待审批入口靠近当前任务，点开原生 sheet 后显示具体命令/文件操作、作用范围与“允许一次/拒绝”。若 Host 支持其他授权方式，再按 capability 展示。
- 审批句柄撤销或重连后失效时，UI 同步撤下，不能保留一个仍可点击的旧按钮。
- App 回前台后重建 transport/Noise，并重新读取会话基线；未确认的发送不自动重放。草稿可保留，但网络失败时无法断定 Host 尚未接收。
- Host 已接受的任务继续由电脑执行。iOS 后台本身没有常驻连接保证；实时后台推送需要另行支持 Server/APNs，现有 Android 客户端也未提供独立 push 服务。

## 6. 第一版范围与验证顺序

先固定插件 `0.6.2` 与已验证的 Harness 基线做互通。Remote 当前文档基线是 `dsh-v0.2.1-rc.5`；peer 范围接受 `0.2.2` prerelease 不代表已做该版本的运行验收。此前研究的官方 master 为 `0.2.2-alpha.2`，这两者需要实测对应。

- [兼容基线与验证边界](https://github.com/liguobao/ds-harness-remote/blob/c374397dea2bea0e5a81adc993553be992102bc6/docs/compatibility.zh.md#L1-L19)

建议实现顺序：

1. 定义会话列表、聊天、工具活动与审批四个核心页面，完成可交互原型。
2. 建立最小 Relay + Noise 连接，先过 golden vector，再连真实 Host，读取 capability 和工作区。
3. 打通新建/恢复会话、文本发送、流式输出、工具审批与停止，覆盖前后台和断网恢复。
4. 加入历史分页、图片/文件与产物预览，验证大消息 transfer。
5. 增加 WebRTC 与其他可选 backend。第一版优先 DSH，Codex/ACP 可以沿同一 transport 后续接入。

可见 UI 插件要逐个评估：SwiftUI 不会自动渲染 Host 的任意 React 插件。第一版用明确的原生工具/审批组件，对未适配的工具保留可读的通用结果视图。

## 7. 研究边界

当前应以 capability probing 与真实 Host Gateway 为准。`harness.api.*` ApiProxy 已从当前 Host/移动端主路径退役，不能因共享类型仍存在就实现它作为新客户端主协议。

部分文档有旧描述，例如网络文档称 Server 在独立仓库，而此提交实际包含了最小 `apps/server`。本文以当前 README、Server 实现和兼容说明交叉核实。

项目 manifest 声明 MIT，并在 [packages/plugin/LICENSE](https://github.com/liguobao/ds-harness-remote/blob/c374397dea2bea0e5a81adc993553be992102bc6/packages/plugin/LICENSE) 提供许可证；复用源码需保留相应通知。
