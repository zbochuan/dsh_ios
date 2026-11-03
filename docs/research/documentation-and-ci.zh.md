# 上游文档与 CI/CD 约定调研

[English](documentation-and-ci.md) | 中文

研究日期：2026-11-03。来源固定为 DeepSeek Harness 提交 [`ce7073d51254c26cd63b22a60835b8f948deb447`](https://github.com/deepseek-ai/deepseek-harness/tree/ce7073d51254c26cd63b22a60835b8f948deb447)。本次静态阅读文档与工作流定义，没有执行上游构建或发布。

## 文档归属

上游[文档规范](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/docs/AGENTS.md)为每个事实指定唯一归属：根指令保存简短常规规则，架构文档描绘运行时，子系统参考定义契约，包 README 描述包行为，教程承载操作步骤，Agent Notes 记录决策与理由。当前参考描述当前行为，历史证据进入专门记录；正文每段一个物理行，仓库内使用相对链接。

本仓库以更小的目录采用这一原则。研究保存在 `docs/research/`，工程规则归开发和双语参考，重要决策后续保存在 `docs/decisions/`。应用建立前不创建空的子系统或包文档；研究保留为特定版本的证据，不作为 iOS 客户端已经可用的证明。

## 中英文配对

上游[双语约定](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/docs/i18n/README.md)赋予两种语言同等效力。每组由同目录 `name.md`、`name.zh.md` 和 `name.i18n.yaml` 组成；自动检查语言切换、对应结构与链接目标、精确代码块，以及分章节记录的哈希。语义准确性仍由审阅负责。

[本仓库约定](../i18n/README.zh.md)采用三文件配对、同等效力、术语表、同次变更更新和显式确认记录。简化的 Python 标准库检查器使用本地记录格式，对完整章节计算哈希，而上游只对特定正文块计算。它按已说明的 Markdown 子集独立实现，不引入上游 TypeScript 工具，也不声称覆盖范围完全相同。

## CI 验证

上游[拉取请求 CI](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/.github/workflows/ci.yml)拆分静态分析、覆盖率、lint 与构建产物使用任务；采用锁定依赖安装、默认只读权限、关闭 checkout 凭据持久化，并取消被新提交替代的运行。[开发指南](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/docs/development.md)衔接本地命令与完整 CI 检查，文档同步属于必需工程检查。

本仓库采用本地与 CI 共用命令及独立验证任务。文档在 Ubuntu 上运行，不依赖 Node；有 Xcode 工程与共享 scheme 后，再在 macOS 上构建模拟器版本。协议互通需要注明版本的隔离 Host。上游企业 runner 和 Node monorepo 构建依赖图不适用于本仓库。

## 构建与发布

上游[发布预演](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/.github/workflows/release.yml)在拉取请求和主开发分支上、不使用发布凭据地构建和验证 npm 包。独立的[手动发布工作流](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/.github/workflows/release-publish.yml)在发布前核对所选版本与包；它也提供显式跳过 tag 检查的选项，因此不能把“仅 tag 发布”概括为所有上游流程的绝对规则。

上游 [macOS 打包](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/.github/workflows/macos-package.yml)手动选择源码 ref 与 test/production 配置，随后检查配置、签名安装包并保留产物和诊断。独立的[文档部署](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/.github/workflows/docs-pages.yml)从经验证的发布 tag 手动运行，使用 GitHub Pages 环境；普通拉取请求 CI 仍构建站点。

iOS 采用先验证构建再发布、产物可追溯、独立手动发布工作流与受保护签名环境的原则。不复制 Electron 安装包、npm 发布或上游站点部署。TestFlight 建议流程与缺少的前提由[开发与 CI/CD](../development.zh.md)维护，目前尚无启用的签名工作流。
