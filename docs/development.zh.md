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

[双语约定](i18n/README.zh.md)定义检查器覆盖的内容及仍需审阅的部分。

## 应用开发

打开 `DSH.xcodeproj`，选择共享 `DSH` scheme 和 iPhone 或 iPad 模拟器。最低部署版本为 iOS 17.0，源码使用 Swift 6。bundle identifier `app.dsh.ios` 是开发占位值。工程不保存签名团队或设备标识；真机测试的签名通过本机构建设置传入，不得进入 Git。在首屏打开示例任务即可载入本地示例任务，其中包含待处理审批。Server 登录和设备发现需要明确填写 HTTPS Remote Server 及其账号，不使用 DeepSeek 模型密钥。

在 macOS 上独立运行核心测试：

```bash
swift test --package-path Packages/DSHCore
```

Xcode 工程无需第三方生成器。增删 Swift 源文件后，重新生成确定性的文件引用：

```bash
python3 -I scripts/generate_xcode_project.py
```

安装 Xcode 26.2 和 iOS 26.2 的 iPhone 17 Pro 运行时后，执行与 CI 相同的核心及模拟器检查：

```bash
bash scripts/check_ios.sh
```

使用其他已安装模拟器时，可覆盖 `DSH_SIMULATOR_DESTINATION`，例如 `platform=iOS Simulator,name=iPhone 18 Pro,OS=27.2`。未指定 `arch` 时，脚本追加本机原生架构，并设置 `ONLY_ACTIVE_ARCH=YES`；明确指定的目标架构会保留。这可避免目标选择不明确时在 Apple silicon 上选中 x86_64。无签名编译不需要可启动的模拟器运行时：

```bash
xcodebuild -project DSH.xcodeproj -scheme DSH -destination 'generic/platform=iOS Simulator' -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
```

应用图标是[生成器](../scripts/generate_app_icon.swift)栅格化的原创矢量几何图形，其 PNG 属于源资源，不是构建产物。当前没有外部 Swift package 依赖，因此尚不需要 `Package.resolved`。构建目录、测试结果与签名材料均由 Git 忽略。

## 现有 CI

[文档 CI](../.github/workflows/docs.yml)在拉取请求、推送到 `main` 和手动触发时运行，在 Ubuntu 上使用 Python 3.13 检查完整 Markdown 文档库。仓库只读权限、关闭 checkout 凭据持久化、按 ref 取消过期运行，使验证流程独立于发布。

[iOS CI](../.github/workflows/ios.yml)针对应用变更及手动触发在 `macos-15` 上运行，明确选择 Xcode 26.2 和 iPhone 17 Pro / iOS 26.2。它调用 [check_ios.sh](../scripts/check_ios.sh)，检查工程引用、核心测试及无签名模拟器 UI 测试，结果包保留七天。仅修改文档不分配 macOS runner。这些工作流已加入仓库，但在推送并执行前，不声称已有 GitHub 运行结果。

核心测试覆盖 Server 请求结构、无效响应、重定向拒绝、身份与凭据生命周期、Noise 向量与篡改、安全分片、演示流完成时不重复消息、中断后迟到片段，以及失效或已处理审批。任务控制台 UI 测试覆盖连接与示例入口、配对、空白输入、发送与停止后继续、从首页发起任务、新建任务及取消登录时的草稿保留、审批关闭与允许、拒绝或拒绝并说明、首页等待卡片、后台失效、不含跳过选项的权限菜单、分叉、抽屉搜索，以及最大字号下的主要操作，并附加浅色、深色和无障碍截图。测试仅在自身进程中覆盖连接默认值，且不提交登录凭据。stub 与本地密码学测试不能替代真实 Host 测试。任何任务均不使用用户日常的 Harness 安装或部署凭据。

## 验证记录

2026-11-03，本地使用 Xcode 27.2 验证了基于 `c66f94d95eaacb9ca64850a51ff1f55c2fe61565` 的未提交对话界面改版。这标识的是基线提交，不是被测变更的已提交快照。模拟器目标为 iPhone 18 Pro / iOS 27.2，使用 `arm64` 和 `ONLY_ACTIVE_ARCH=YES`。这些结果不代表已在 CI 配置的 Xcode 26.2 运行时执行。

| 检查 | 结果与范围 | 本地证据 |
|---|---|---|
| 任务控制台改版 | 2026-11-03，`check_ios.sh` 在同样的 Xcode 27.2 / iPhone 18 Pro / iOS 27.2 目标上针对提交 `9874ecf` 成功退出：43 项核心测试及全部 15 项 UI 测试通过，无失败或跳过。首页、任务详情、深色审批与深色配对截图已完成视觉检查。本次修订未检查 iPad 布局、VoiceOver 顺序和真机。 | `build/task-console-validation.log`、`build/Tests-1793686209.xcresult`、`build/screenshots/` |
| 核心与模拟器 UI | `check_ios.sh` 成功退出：30 项核心测试及全部八项 UI 测试通过，无失败或跳过。这确认了最终大字号布局修正前的改版基线。 | `build/redesign-validation.log`、`build/Tests-1793677716.xcresult`，以及由 `build/redesign-ui-attachments/manifest.json` 索引的七张截图附件 |
| 修正后的最大字号布局 | 截图审阅发现入口文字截断及发送图标过大；修正后，最大字号测试与发送、停止及继续测试均通过，耗时 48.092 秒。新截图已完成视觉检查，确认入口标签完整、发送图标未超出范围。 | `build/redesign-accessibility-validation.log`、`build/RedesignAccessibility-1793678863.xcresult`、`build/redesign-accessibility-attachments/` |
| 签名真机构建与启动 | 交付的 Debug 构建包含布局及登录错误修正，构建成功；`app.dsh.ios` 已在 iPhone 14 Pro / iOS 26.6.1 上安装并启动。前一版已修正布局的入口截图已完成视觉检查；最终登录错误修正不改变 UI。账号登录失败后保留现有会话的行为已通过源码审阅与编译，未使用真实服务测试。 | `build/delivery-device-build.log`、`build/dsh-iphone-final.png` |
| 真机 UI 自动化 | 测试执行前，runner 初始化失败：“Timed out while enabling automation mode.”。没有通过真机点击、发送或停止测试。 | `build/redesign-device-smoke.log`、`build/RedesignDeviceSmoke.xcresult` |
| 本地无签名 Release archive | `xcodebuild archive` 在最终布局修正及后续登录错误审阅之前成功。应用不依赖 AppIntents，因此跳过其元数据提取。这是本地归档，不代表 GitHub 工作流执行、签名 IPA 导出或上传。 | `build/redesign-archive.log`、`build/RedesignRehearsal.xcarchive`、`build/RedesignArchive.xcresult` |

工程引用一致性、版本验证、shell 语法及 property-list 检查也已通过。早期验证发现了 x86_64 模拟器链接失败；当前脚本选择原生架构，并通过了上述完整运行。更早的签名版本也在建立系统信任、解锁设备后，于 iPhone 14 Pro / iOS 26.6.1 成功启动。此处及共享工程均不记录签名身份或设备标识。`build/` 下的证据仅保留在本地，并由 Git 忽略；新克隆不包含这些日志、结果包、截图或归档。

已通过的模拟器运行仍存在自动化问题：导航期间，XCTest 因未收到“App animations complete”通知而多次等待约 60 秒。历史切换、新建对话和退出演示的草稿测试耗时 689.835 秒，完整 UI 测试耗时 887.466 秒。这些是受自动化等待影响的测试运行时长，不是实测的应用动画延迟；通知缺失的原因尚未解决。

[可交互 HTML 评审页](../design/product-review.html)另行完成了浏览器检查：示例建议的显示及草稿保护、流式完成和 Stop 后 textarea 节点身份、焦点、选择范围及中文草稿保留，以及审批仅处理一次均通过。合成的 `compositionstart`/`compositionend` 事件可禁用和重新启用发送。375 像素视口未出现横向溢出，iPad HTML 布局已完成视觉检查。这些只验证浏览器行为；合成输入组合事件不能验证用户实际使用中文输入法的体验。静态主题色计算中，已检查的正文、次要文字及操作文字色对的对比度至少为 4.5:1，发送图标至少为 3:1，但不代表完整的原生对比度验收。

真机钥匙串与连接恢复、启动以外的真机交互、原生小屏 iPhone 和 iPad 布局、真实键盘及输入法行为、完整 Dynamic Type 布局、VoiceOver 与 Reduce Motion 仍未验证。这些检查应使用[产品验收要求](product-design.zh.md)。浏览器布局、合成事件、静态对比度计算及通过的 UI 断言不能证明完整的原生可用性或无障碍验收。

协议源码基线为 ds-harness-remote `c374397dea2bea0e5a81adc993553be992102bc6` / 插件 `0.6.2`。本应用尚未运行任何 Harness、插件与 Server 的组合。[应用架构](architecture.zh.md)维护已实现行为与尚待完成的加密会话接入。

## 发布预演与发布

[发布预演](../.github/workflows/release-rehearsal.yml)需要手动从 `ios-v<marketing-version>` 触发。[check_release.py](../scripts/check_release.py)核对两种构建配置与所选 tag。工作流重跑文档及核心验证，创建无签名设备 archive，并保留 ZIP、SHA-256 校验和、源码版本和诊断信息十四天。它不导出可安装的签名 IPA，不上传 TestFlight，也不能检查构建号是否已在 App Store Connect 使用。

TestFlight 仍未配置，需要 Apple Developer 团队、最终 bundle identifier、签名证书与 profile 或经认可的签名服务、App Store Connect 认证，以及受保护的发布环境。后续上传必须在所选版本 tag 重跑必需验证，并使用对应的签名产物。本次实现不包含部署凭据、Apple 账号变更、上传、GitHub Pages 部署或 App Store 提审。

[上游文档与发布调研](research/documentation-and-ci.zh.md)说明了拆分流程的依据。Remote 互通验证独立维护：发布前先记录版本，并实测会话流、审批生命周期、transfer、停止及重连，才能声明支持。
