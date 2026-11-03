import Foundation

public struct Conversation: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var workspace: String
    public var messages: [ChatMessage]
    public var activity: [ToolActivity]
    public var approval: ToolApproval?
    public var phase: Phase
    public var draft: String
    public var updatedAt: Date

    public enum Phase: String, Sendable {
        case ready, generating, awaitingApproval, interrupted
    }

    public init(id: UUID = UUID(), title: String, workspace: String, messages: [ChatMessage] = [], activity: [ToolActivity] = [], approval: ToolApproval? = nil, phase: Phase = .ready, draft: String = "", updatedAt: Date = .now) {
        self.id = id
        self.title = title
        self.workspace = workspace
        self.messages = messages
        self.activity = activity
        self.approval = approval
        self.phase = phase
        self.draft = draft
        self.updatedAt = updatedAt
    }

    public mutating func beginDemoReply(to text: String) {
        guard phase != .generating, phase != .awaitingApproval else { return }
        messages.append(ChatMessage(role: .user, text: text))
        messages.append(ChatMessage(role: .assistant, text: "", isStreaming: true))
        phase = .generating
        draft = ""
        updatedAt = .now
    }

    public mutating func appendDemoText(_ text: String) {
        guard phase == .generating, let index = messages.indices.last, messages[index].isStreaming else { return }
        messages[index].text += text
    }

    public mutating func finishDemoReply() {
        guard phase == .generating else { return }
        if let index = messages.indices.last { messages[index].isStreaming = false }
        phase = .ready
    }

    public mutating func interrupt() {
        if let index = messages.indices.last { messages[index].isStreaming = false }
        if approval != nil {
            messages.append(ChatMessage(role: .assistant, text: "待确认操作已失效，没有记录授权。你可以继续发送消息。"))
        }
        approval = nil
        if phase == .generating || phase == .awaitingApproval { phase = .interrupted }
    }

    @discardableResult
    public mutating func resolveApproval(id: UUID, allow: Bool) -> Bool {
        guard let approval, approval.id == id, phase == .awaitingApproval else { return false }
        self.approval = nil
        phase = .ready
        updatedAt = .now
        activity.append(ToolActivity(title: allow ? "本地记录：允许一次" : "本地记录：已拒绝", detail: approval.command, state: allow ? .completed : .declined))
        messages.append(ChatMessage(role: .assistant, text: allow ? "已记录「仅允许一次」。没有执行命令。" : "已记录「拒绝这次操作」。没有执行命令。"))
        return true
    }
}

public struct ChatMessage: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var role: Role
    public var text: String
    public var reasoning: String?
    public var isStreaming: Bool
    public enum Role: String, Sendable { case user, assistant }

    public init(id: UUID = UUID(), role: Role, text: String, reasoning: String? = nil, isStreaming: Bool = false) {
        self.id = id
        self.role = role
        self.text = text
        self.reasoning = reasoning
        self.isStreaming = isStreaming
    }
}

public struct ToolActivity: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var detail: String
    public var state: State
    public enum State: Sendable { case completed, declined }

    public init(id: UUID = UUID(), title: String, detail: String, state: State = .completed) {
        self.id = id
        self.title = title
        self.detail = detail
        self.state = state
    }
}

public struct ToolApproval: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let command: String
    public let workspace: String
    public let explanation: String
    public let computer: String
    public let scope: String

    public init(id: UUID = UUID(), command: String, workspace: String, explanation: String, computer: String = "示例电脑", scope: String = "范围未提供") {
        self.id = id
        self.command = command
        self.workspace = workspace
        self.explanation = explanation
        self.computer = computer
        self.scope = scope
    }
}

public enum DemoContent {
    public static func conversations() -> [Conversation] {
        [
            Conversation(title: "阅读一个 Swift 项目", workspace: "示例 / notes", messages: [
                ChatMessage(role: .user, text: "拿到一个 Swift 项目，先看哪些文件？"),
                ChatMessage(role: .assistant, text: "先看 README，了解项目用途与运行方式。\n\n接着找 App 或 main 入口，顺着一个具体操作往下读，例如保存一条笔记。遇到的数据类型和依赖可以边读边记，不必一开始就读完整个项目。\n\n最后看这条流程的测试，确认正常结果和失败情况。", reasoning: "沿着一条实际流程阅读，比逐个目录浏览更容易建立上下文。")
            ]),
            Conversation(title: "检查登录流程", workspace: "示例 / app", messages: [ChatMessage(role: .user, text: "确认登录测试前，需要看哪些信息？"), ChatMessage(role: .assistant, text: "下面是一条待确认操作的示例。打开后可以查看电脑、工作区、命令与影响范围，再选择允许一次或拒绝。")], approval: ToolApproval(command: "swift test", workspace: "~/Projects/app", explanation: "运行项目测试，检查登录状态与错误处理。", computer: "示例 Mac", scope: "测试代码可读写当前工作区，也可能访问网络；实际影响取决于测试内容。"), phase: .awaitingApproval),
            Conversation(title: "整理阅读笔记", workspace: "示例 / notes", messages: [ChatMessage(role: .user, text: "怎样记录读代码时的问题？"), ChatMessage(role: .assistant, text: "每条笔记留三个部分：正在看的流程、已经确认的行为、还需要验证的问题。附上文件和函数名，下一次就能从同一个位置继续。")])
        ]
    }
}
