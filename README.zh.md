# DSH iOS

[English](README.md) | 中文

为 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) 重新设计的独立 iOS 客户端，通过 [ds-harness-remote](https://github.com/liguobao/ds-harness-remote) 连接电脑。

电脑负责运行 Agent、模型请求、项目文件与工具。Swift 6 / SwiftUI 界面面向 iOS 17 及以上的 iPhone 和 iPad，以对话、历史记录和一个输入框为中心，提供回复、任务动态与审批的本地演示。Remote Server 登录和电脑发现独立实现，远程对话仍未开放。

## 项目状态

仓库现已包含 Xcode 应用、共享 scheme、可测试的 Swift 核心、UI 测试，以及文档、构建和发布预演工作流。打开 `DSH.xcodeproj` 并选择 `DSH` scheme。[应用架构](docs/architecture.zh.md)记录已实现行为与后续接入工作；[开发文档](docs/development.zh.md)记录验证与命令。Noise 加密已有独立实现，Control/Relay 和实际 Harness 会话尚未接通，不声称已完成真实 Host 互通。

## 文档

- [文档索引](docs/README.zh.md)：产品方向、研究与工程参考。
- [移动端产品设计](docs/product-design.zh.md)：Claude 与 ChatGPT 官方截图参考、交互决策及原生验收要求。
- [Remote 客户端调研](docs/research/ds-harness-remote-ios.zh.md)：部署、协议、iOS 交互建议与兼容边界。
- [Web 与桌面版调研](docs/research/deepseek-harness-web-desktop.zh.md)：上游运行时、持久化与客户端架构。
- [开发与 CI/CD](docs/development.zh.md)：本地检查、现有 CI 与计划中的 iOS 发布流程。
- [双语文档约定](docs/i18n/README.zh.md)：文件配对、术语与同步记录。

## 参与开发

阅读 [CONTRIBUTING.md](CONTRIBUTING.zh.md)，在仓库根目录运行与 CI 相同的文档检查：

```bash
python3 -I scripts/check_docs.py
```

## 上游项目

本项目独立开发，不声称隶属于 DeepSeek 或 Remote 项目。研究引用固定的上游版本；上游测试向量与协议改写的声明保存在[第三方声明](THIRD_PARTY_NOTICES.txt)中。本仓库尚未为自己的应用代码选定许可证。
