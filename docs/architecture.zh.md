# 应用架构

[English](architecture.md) | 中文

## 当前实现

DSH 是独立的 Swift 6 / SwiftUI 客户端，最低支持 iOS 17。紧凑布局使用任务列表导航栈和左侧抽屉；常规布局把抽屉作为分栏侧栏，与任务详情并列。电脑、设置和连接电脑在弹层中打开。仓库中的 [Xcode 工程](../DSH.xcodeproj/project.pbxproj)构建应用及 UI 测试；本地 [DSHCore package](../Packages/DSHCore/Package.swift)负责可独立测试的状态与协议代码，不需要第三方 Swift package 依赖。

| 领域 | 已实现行为 | 验证边界 |
|---|---|---|
| 原生界面 | 按电脑分组并带等待队列的任务列表、可搜索抽屉、带可折叠动态及改动和终端卡片的任务详情、任务内审批弹层、配对入口与设置 | 任务、回复与审批是本地示例。源码实现不代表已经通过原生视觉或无障碍验收。 |
| 会话状态 | 预设文本增量、停止、按会话保存草稿、本次运行内退出后继续、审批仅处理一次及退到后台时失效 | 仅为内存演示状态，尚无真实 Harness 会话状态处理或持久历史。 |
| Remote Server | HTTPS 登录、iOS 设备注册、凭据刷新、Host 发现与身份描述接口 | 已有请求格式测试，未使用服务账号或真实 Host。 |
| 凭据 | X25519 设备身份与设备 token 按标准化 Server 来源保存在不参与同步、仅限本机的钥匙串中 | 密码与注册 token 仅临时使用；钥匙串存储和连接恢复仍需真机验证。 |
| 加密 | Noise IK 发起端与有序安全分片 | 黄金向量及本地响应端测试；不代表独立密码学审计或真实 Host 互通。 |
| 远程会话 | 尚未接入界面 | Control/Relay 传输、Host 公钥信任、RPC、会话流及真实审批仍待实现。 |

示例任务从首屏或配对页面打开；已完成的示例任务中说明一次：其内容是预设的，不会连接电脑。审批结果描述本地选择。电脑发现页说明发现设备不代表建立安全会话，且不提供可用的远程任务操作。不收集模型 API key；只有用户填写 Server 并提交登录后，才会发送 Remote 账号信息。正式 REST 会话拒绝重定向，不使用 Cookie 或缓存，仅接受 HTTPS 来源地址。UserDefaults 保存已提交的 Server 地址、外观、通知和新任务默认值偏好及需要重新登录的恢复标记，密码与设备 token 不会写入其中。

## 源码职责

- [AppStore](../App/AppStore.swift)负责载入示例任务、选择、抽屉与弹层状态、首页草稿、按任务保存的草稿以及模拟进度。新任务优先复用未编辑的空白任务；分叉、重命名、归档和删除只作用于本地任务。进入后台会取消模拟进度并使示例审批失效，不会发送 Host 命令。
- [ConnectionStore](../App/ConnectionStore.swift)协调显式登录、钥匙串恢复、凭据刷新、设备发现与本地退出登录。表单编辑独立于已提交的 Server 地址。凭据操作串行执行；设备授权被拒绝时清除登录状态，设备发现的网络失败则保留已成功的认证。注册前账号登录失败会保留现有设备凭据及登录状态；这一行为已通过源码审阅，未使用真实账号验证。恢复流程可以恢复已提交 Server 的登录状态，但 `accountName` 仅在显式登录时设置，既不持久化也不重新加载，因此应用重新启动并恢复凭据后不会显示账号名称行。设备 token 与身份密钥仍保存在钥匙串中。token 替换结果不确定时要求重新登录。恢复操作包括重试恢复、本地退出登录，以及仅针对无法读取的身份、经确认后执行的移除。退出登录清除本地 token，不撤销 Server 上的设备。
- [Conversation](../Packages/DSHCore/Sources/DSHCore/Conversation.swift)负责任务的消息、动态、附件、阶段与结果、权限模式、模型、草稿与待处理审批；[TaskBoard](../Packages/DSHCore/Sources/DSHCore/TaskBoard.swift)推导等待队列、按电脑分组、项目分组与搜索。审批详情展示电脑、完整工作区、命令与 Agent 说明。关闭详情保留有效请求；处理时核对请求标识及等待阶段，仅消费一次并追加本地结果。审批失效时保留草稿并补充说明。
- [RemoteServerAPI](../Packages/DSHCore/Sources/DSHCore/RemoteServerAPI.swift)实现固定版本的 Server 消息结构。[DeviceIdentity](../Packages/DSHCore/Sources/DSHCore/DeviceIdentity.swift)与 [CredentialStore](../Packages/DSHCore/Sources/DSHCore/CredentialStore.swift)隔离身份与持久化逻辑。
- [NoiseIK](../Packages/DSHCore/Sources/DSHCore/NoiseIK.swift)与 [SecureChannel](../Packages/DSHCore/Sources/DSHCore/SecureChannel.swift)独立于网络 I/O 实现发起端与分帧。后续传输层必须串行执行完整的加密与发送操作，包括全部分片；仅靠 actor 隔离不能保证后续 socket 发送的顺序。

## 界面与设计

[移动端产品设计](product-design.zh.md)维护 Claude/ChatGPT 官方截图证据、修订后的交互方向及验收要求。实现移除了宣传式大标题与功能卡片，助手正文直接呈现在阅读区域，用户消息使用中性气泡，并保留一个输入框。首版界面使用简体中文，以系统字体、语义文字尺寸、至少 44 点的主要操作目标及原生导航和弹层为基础。实际点击区域、完整 Dynamic Type 布局、VoiceOver 及交互质量仍需原生审阅。[开发文档](development.zh.md)分别记录已完成的模拟器断言与真机启动，以及这些待完成检查。

[DSHTheme](../App/Design/DSHTheme.swift)将官方 [Harness 设计 token](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/packages/client/ui-theme/src/styles/design-platform.css)映射到不透明的中性表面，蓝色用于可用操作和选择状态。基础蓝在浅色外观下为 `#4176E6`，深色外观下为 `#5686FE`；文字操作使用单独调整对比度的色值。阅读列最大宽度为 680 点。外观跟随系统，也可手动指定。[上游品牌指引](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/BRAND_GUIDELINES.md)为独立使用 DSH 命名提供依据。

按下时立即将不透明度改为 `0.72`，小型控件同时缩放至 `0.97`；松开时使用响应参数 `0.3`、阻尼系数 `1` 的弹簧恢复。最小点击区域保持不动，位于视觉变换之外。较宽的行仅改变不透明度。开启“减弱动态效果”时移除缩放与动画，保留即时不透明度反馈。主动回到最新使用响应参数 `0.35`、阻尼系数 `1` 的弹簧，开启“减弱动态效果”时立即定位。这些是源码参数，不是实测的物理交互质量。

消息支持选择与复制。输入框固定在安全区内，思路与活动默认折叠，新增文本不为整个布局添加动画。浏览历史时可离开最新位置，并显示回到最新的操作；主动返回动画期间暂停流式文本的自动滚动。滚动与弹层手势保留原生行为。富文本 Markdown、代码语法高亮、附件与文件预览尚未实现。

## 下一步接入边界

连接[调研](research/ds-harness-remote-ios.zh.md)记录的固定 Remote 版本，协商能力，建立 Control/Relay 传输，核验并固定 Host 公钥，再完成 Noise 握手，之后才能发送 RPC。不得改用明文 RPC 或模型 API 请求替代这一通道。实现 `harness.transport.describe` 及单次调用与流式 gateway，确保先注册订阅再打开流，并具备明确超时、待处理调用终止与审批失效处理。

真实会话必须区分持久历史与即时助手生成，重连后替换基线，且不得自动重放结果未知的修改操作。已接受的工作继续在电脑执行；关闭 iOS 或退到后台不代表请求取消任务。在声明支持该路径之前，必须记录真实 Host 版本、流结束、停止、审批、transfer 与重连的验证证据。[开发文档](development.zh.md)负责构建与发布验证。
