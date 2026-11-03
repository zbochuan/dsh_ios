import Foundation

/// In-memory example tasks shown before a computer is paired. Nothing here runs on a computer.
public enum DemoContent {
    public static let computers = [
        ComputerSummary(name: "Mac mini", isOnline: true),
        ComputerSummary(name: "MacBook Pro", isOnline: false),
    ]

    /// Projects offered for new example tasks, per computer.
    public static let projects = ["Mac mini": ["dsh_ios", "harness-api"], "MacBook Pro": ["blog"]]

    /// The title of the task that explains the example, shown before pairing.
    public static let exampleTitle = "加暗色模式"

    public static func conversations(now: Date = .now) -> [Conversation] {
        func ago(minutes: Double) -> Date { now.addingTimeInterval(-minutes * 60) }
        return [
            Conversation(
                title: "重构设置页", computer: "Mac mini", project: "dsh_ios", workspace: "~/code/dsh_ios",
                messages: [
                    ChatMessage(role: .user, text: "把设置页按“电脑、通知、权限、外观”重新分组，删掉演示相关的选项。"),
                    ChatMessage(role: .assistant, text: "", activity: [
                        ToolActivity(kind: .read, title: "读取文件", detail: "App/Views/SettingsView.swift"),
                        ToolActivity(kind: .read, title: "读取文件", detail: "App/AppStore.swift"),
                    ], isStreaming: true),
                ],
                phase: .generating, permissionMode: .autoEdit, currentStep: "正在修改 SettingsView.swift…",
                startedAt: ago(minutes: 6), updatedAt: ago(minutes: 0.5)
            ),
            Conversation(
                title: "修复登录超时", computer: "Mac mini", project: "harness-api", workspace: "~/code/harness-api",
                messages: [
                    ChatMessage(role: .user, text: "登录偶尔超时，帮我查一下原因并修好。"),
                    ChatMessage(role: .assistant, text: "超时来自 `session.ts` 的重试逻辑：token 刷新失败后没有退避，连续请求占满了连接池。\n\n我已经改成指数退避，接下来想跑一遍单元测试确认没有回归。", activity: [
                        ToolActivity(kind: .read, title: "读取文件", detail: "src/session.ts"),
                        ToolActivity(kind: .read, title: "读取文件", detail: "src/client.ts"),
                        ToolActivity(kind: .edit, title: "修改文件", detail: "src/session.ts"),
                    ]),
                ],
                approval: ToolApproval(
                    title: "运行测试命令", command: "npm run test -- --watch=false", workspace: "~/code/harness-api",
                    explanation: "修改了 session.ts 的超时逻辑，需要跑一遍单元测试确认没有回归。只读运行，不写文件。",
                    computer: "Mac mini", requestedAt: ago(minutes: 2)
                ),
                phase: .awaitingApproval, startedAt: ago(minutes: 9), updatedAt: ago(minutes: 2)
            ),
            Conversation(
                title: exampleTitle, computer: "Mac mini", project: "dsh_ios", workspace: "~/code/dsh_ios",
                messages: [
                    ChatMessage(role: .user, text: "给 App 加上暗色模式，颜色都放进 DSHTheme。"),
                    ChatMessage(
                        role: .assistant,
                        text: "暗色模式已经加好。颜色集中在 `DSHTheme`，每个颜色都有浅色和深色两个值，正文对比度不低于 **4.5:1**。\n\n这是一个示例任务：内容是预设的，不会连接电脑或执行命令。连接电脑后，这里会显示 Agent 的真实进展。",
                        reasoning: "先找出所有硬编码颜色，再统一换成主题色，最后跑测试确认没有改坏布局。",
                        activity: [
                            ToolActivity(kind: .read, title: "读取文件", detail: "App/Design/DSHTheme.swift"),
                            ToolActivity(kind: .read, title: "读取文件", detail: "App/Views/ChatView.swift"),
                            ToolActivity(kind: .read, title: "读取文件", detail: "App/Views/SettingsView.swift"),
                            ToolActivity(kind: .edit, title: "修改文件", detail: "App/Design/DSHTheme.swift"),
                            ToolActivity(kind: .edit, title: "修改文件", detail: "App/Views/ChatView.swift"),
                            ToolActivity(kind: .edit, title: "修改文件", detail: "App/Views/SettingsView.swift"),
                            ToolActivity(kind: .edit, title: "修改文件", detail: "App/DSHApp.swift"),
                            ToolActivity(kind: .command, title: "运行命令", detail: "swift test"),
                        ],
                        attachments: [
                            .diff(DiffAttachment(fileName: "DSHTheme.swift", additions: 42, deletions: 18, lines: [
                                DiffLine(.removed, "static let ink = Color(white: 0.12)"),
                                DiffLine(.added, "static let ink = adaptive(light: 0x1B1C1F, dark: 0xF4F4F5)"),
                                DiffLine(.added, "static let surface = adaptive(light: 0xF4F5F7, dark: 0x202022)"),
                            ], changedFiles: 4)),
                            .terminal(TerminalOutput(command: "swift test", output: "Executed 48 tests, with 0 failures")),
                        ]
                    ),
                ],
                outcome: .succeeded, summary: "改了 4 个文件，测试通过",
                startedAt: ago(minutes: 200), updatedAt: ago(minutes: 180)
            ),
            Conversation(
                title: "升级依赖", computer: "Mac mini", project: "harness-api", workspace: "~/code/harness-api",
                messages: [
                    ChatMessage(role: .user, text: "把依赖升级到最新的小版本。"),
                    ChatMessage(role: .assistant, text: "升级后有 2 个测试失败，都和 `undici` 新版本的超时默认值有关。我先停在这里，没有提交改动。", activity: [
                        ToolActivity(kind: .edit, title: "修改文件", detail: "package.json"),
                        ToolActivity(kind: .command, title: "运行命令", detail: "npm test"),
                    ], attachments: [
                        .terminal(TerminalOutput(command: "npm test", output: "Tests: 2 failed, 61 passed, 63 total", exitCode: 1)),
                    ]),
                ],
                outcome: .failed, summary: "2 个测试未通过",
                startedAt: ago(minutes: 26 * 60 + 20), updatedAt: ago(minutes: 26 * 60)
            ),
            Conversation(
                title: "写周报脚本", computer: "MacBook Pro", project: "blog", workspace: "~/blog",
                messages: [
                    ChatMessage(role: .user, text: "写个脚本，把本周的 git 提交整理成周报。"),
                    ChatMessage(role: .assistant, text: "脚本在 `scripts/weekly.py`，运行后会在 `drafts/` 下生成本周的周报。"),
                ],
                outcome: .succeeded, summary: "生成了 weekly.py",
                startedAt: ago(minutes: 3 * 24 * 60 + 30), updatedAt: ago(minutes: 3 * 24 * 60)
            ),
        ]
    }
}
