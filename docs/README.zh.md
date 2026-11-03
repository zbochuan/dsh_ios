# 文档

[English](README.md) | 中文

## 产品与研究

产品是为运行 Harness 和 ds-harness-remote 的电脑重新设计的 iOS 客户端。Agent 执行与项目文件由电脑负责。SwiftUI 应用提供以对话为中心的本地演示，以及 Server 登录和设备发现；Relay 接入与 Host 互通仍待完成。[应用架构](architecture.zh.md)维护当前行为与验证边界。

- [移动端产品设计](product-design.zh.md)维护当前以对话为中心的方向、Claude/ChatGPT 官方参考证据及交互验收要求。
- [Remote 客户端调研](research/ds-harness-remote-ios.zh.md)维护客户端职责建议、协议映射与兼容性证据，早期界面建议作为历史背景保留。
- [Web 与桌面版调研](research/deepseek-harness-web-desktop.zh.md)记录所引版本的官方运行时和客户端实现。
- [文档与 CI/CD 调研](research/documentation-and-ci.zh.md)记录上游工程约定及其在本仓库中的适配方式。

## 工程参考

- [应用架构](architecture.zh.md)维护已实现行为、源码职责与接入边界。
- [开发与 CI/CD](development.zh.md)维护本地验证、现有构建工作流及发布要求。
- [双语文档](i18n/README.zh.md)维护配对、同步和审阅规则。
- [术语表](i18n/terminology.md)定义共用的中英文术语。

## 存放规则

`docs/research/` 保存特定版本的证据与建议；做出重要决策时，在 `docs/decisions/` 中记录背景、取舍和验证要求。架构参考随应用变更同步更新，其他文档链接到对应参考，避免把研究报告变成另一份实现手册。每篇面向读者的文档都有英文页、中文页和同目录同步记录。
