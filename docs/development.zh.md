# 开发与 CI/CD

[English](development.md) | 中文

## 本地文档检查

在仓库根目录使用 Python 3.11 或更新版本。检查器不依赖第三方包：

```bash
python3 -I scripts/check_docs.py
```

更新并审阅两种语言后，为指定文档刷新同步记录，再运行一次完整检查：

```bash
python3 -I scripts/check_docs.py --record README.md docs/development.md
```

修改检查器时，还需运行其失败场景测试：

```bash
python3 -I scripts/test_check_docs.py
```

[双语约定](i18n/README.zh.md)定义检查器覆盖的内容及仍需审阅的部分。目前尚无 Xcode 工程、应用构建命令或发布自动化。

## 现有 CI

[文档 CI](../.github/workflows/docs.yml)在拉取请求、推送到 `main` 和手动触发时运行，在 Ubuntu 上使用 Python 3.13 检查完整 Markdown 文档库。仓库只读权限、关闭 checkout 凭据持久化、按 ref 取消过期运行，使验证流程独立于发布。

本地与 CI 使用同一个脚本。仅修改文档不分配 macOS runner。工作流通过只能证明文档符合已说明的检查，不能证明 iOS 构建或 Host 互通。将此检查设为合并必需项属于仓库设置，本次尚未配置。

## iOS CI 接入计划

随实际 iOS 工程加入以下流程，使每个命令都能在真实 target 上运行。这些是接入要求，目前还不是可运行的工作流。

| 阶段 | 触发与运行环境 | 必需证据 |
|---|---|---|
| 文档 | 拉取请求与 `main`；Ubuntu | 完整双语配对、结构、哈希与本地文件链接检查。 |
| 模拟器构建与测试 | 拉取请求与 `main` 中的应用变更；托管 macOS | 明确 Xcode 版本、提交共享 scheme、指定模拟器与 runtime、无签名构建及相关单元/UI 测试。 |
| Remote 互通 | 协议变更或手动触发；隔离的测试 Host | 记录 Harness、插件与 Server 版本；验证 Noise 向量、会话流、审批生命周期、transfer 和重连行为。 |
| 发布预演 | 选定的发布版本；托管 macOS | 核对版本和构建号，具备签名后预演 archive/export，保留校验和、源码版本与诊断信息。 |
| TestFlight 上传 | 从版本 tag 手动触发；受保护的发布环境 | 在选定版本重跑必要验证，使用对应签名产物，上传 App Store Connect，并保留可追溯运行记录。 |

模拟器测试应覆盖有意义的行为：流结束时的消息状态、过期审批、断线后结果未知的修改操作，以及导航和无障碍路径。使用 stub 的协议测试不能替代真实 Host 测试。拉取请求任务不使用外部凭据，自动化测试也不依赖用户日常运行的 Harness。

引入 Swift package 依赖时提交 `Package.resolved`，CI 固定 Xcode 工具链，本地与工作流使用相同的仓库内命令。诊断测试失败时保留 `.xcresult`。验证后记录所选 scheme、最低系统版本、模拟器与 Host 兼容版本。

## 发布要求

具备应用 target 后，建立独立的手动发布工作流。`ios-v0.1.0` 这样的版本 tag 必须与应用的 marketing version 一致，build number 必须合法且尚未在 App Store Connect 使用。构建和验证选定的准确版本，保留产物身份与源码版本，确保重试上传预期构建，不悄悄重建其他版本。

TestFlight 需要 Apple Developer 团队、bundle identifier、签名证书与 profile 或经认可的签名服务、App Store Connect 认证，以及配置好的受保护发布环境。目前尚未提供或配置这些信息。本次仓库初始化不包含部署凭据、Apple 账号变更、上传、GitHub Pages 部署或 App Store 提审。

[上游文档与发布调研](research/documentation-and-ci.zh.md)说明了这样拆分流程的依据。iOS 工程建立后即可加入模拟器验证，具备具体签名配置后再接入发布。
