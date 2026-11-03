# 参与开发

[English](CONTRIBUTING.md) | 中文

产品方向是重新设计界面的 iOS 客户端，连接运行 Harness 与 ds-harness-remote 的电脑。修改这一边界前，先阅读[文档索引](docs/README.zh.md)。

## 文档变更

每个事实只在一个归属文档中维护，其他位置通过链接引用。研究记录固定上游版本的证据；当前行为归架构或开发参考。做出重要决策时，在 `docs/decisions/` 中记录理由与验证要求。

按照[双语约定](docs/i18n/README.zh.md)与[术语表](docs/i18n/terminology.md)，在同一次变更中更新两种语言。正文每段使用一个物理行，仓库文件使用相对链接，两种语言的代码示例保持一致。

确认两种语言语义一致后，仅为改动过的文档配对更新记录：

```bash
python3 -I scripts/check_docs.py --record README.md docs/development.md
```

交付变更前运行完整检查：

```bash
python3 -I scripts/check_docs.py
```

检查覆盖配对完整性、结构、同步记录、本地链接和基本 Markdown 格式，无法判断译文语义，也无法证明远程协议互通。

## 应用变更

按照[开发与 CI/CD](docs/development.zh.md)中的命令检查仓库内的 Xcode 应用与 Swift package。[应用架构](docs/architecture.zh.md)维护实现边界。连接状态和协议处理应独立于 SwiftUI 视图，协议变更需通过上游测试向量及注明版本的 Host 验证。

界面决策与官方参考证据归[移动端产品设计](docs/product-design.zh.md)。保留按会话存放的草稿、会话内审批以及简短的本地演示说明，仅为已支持的操作增加控件。分别说明原生源码变更、模拟器检查、真机运行与视觉及无障碍审阅；截图和编译通过本身不能证明交互质量。

## 审阅与发布

说明最终行为、相关检查及尚未验证的边界。凭据、签名文件和生成的构建产物不得进入 Git。拉取请求检查不使用部署凭据；具备应用与签名配置后，签名发布使用独立工作流和受保护环境。
