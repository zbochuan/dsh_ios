# DSH iOS

[English](README.md) | 中文

为 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) 重新设计的独立 iOS 客户端，通过 [ds-harness-remote](https://github.com/liguobao/ds-harness-remote) 连接电脑。

电脑负责运行 Agent、模型请求、项目文件与工具；iOS 客户端提供对话、任务动态、审批与文件查看。界面面向 iPhone 和 iPad 设计，建议使用 SwiftUI 实现。

## 项目状态

本仓库目前包含基于源码的研究、双语文档与文档 CI，尚无 iOS 应用，也尚未验证与 Remote Host 的实际连接。首条建议实现的传输路径是带 Noise 加密的 Relay，互通验证后再增加 WebRTC。

## 文档

- [文档索引](docs/README.zh.md)：产品方向、研究与工程参考。
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

本项目独立开发，不声称隶属于 DeepSeek 或 Remote 项目。研究引用固定的上游版本；后续复用源码时需要保留对应的上游许可证声明。本仓库尚未为自己的应用代码选定许可证。
