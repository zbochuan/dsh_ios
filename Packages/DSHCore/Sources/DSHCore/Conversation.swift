import Foundation

/// A task the agent works on for one computer and project. Chat is one interaction inside it.
public struct Conversation: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var computer: String
    public var project: String
    public var workspace: String
    public var messages: [ChatMessage]
    public var activity: [ToolActivity]
    public var approval: ToolApproval?
    public var phase: Phase
    public var outcome: Outcome?
    public var permissionMode: PermissionMode
    public var model: String
    public var currentStep: String?
    public var summary: String?
    public var draft: String
    public var isArchived: Bool
    public var startedAt: Date
    public var updatedAt: Date

    public enum Phase: String, Sendable {
        case ready, generating, awaitingApproval, interrupted
    }

    public enum Outcome: String, Sendable {
        case succeeded, failed
    }

    public init(id: UUID = UUID(), title: String, computer: String, project: String, workspace: String = "", messages: [ChatMessage] = [], activity: [ToolActivity] = [], approval: ToolApproval? = nil, phase: Phase = .ready, outcome: Outcome? = nil, permissionMode: PermissionMode = .ask, model: String = ModelChoice.followComputer, currentStep: String? = nil, summary: String? = nil, draft: String = "", isArchived: Bool = false, startedAt: Date = .now, updatedAt: Date = .now) {
        self.id = id
        self.title = title
        self.computer = computer
        self.project = project
        self.workspace = workspace
        self.messages = messages
        self.activity = activity
        self.approval = approval
        self.phase = phase
        self.outcome = outcome
        self.permissionMode = permissionMode
        self.model = model
        self.currentStep = currentStep
        self.summary = summary
        self.draft = draft
        self.isArchived = isArchived
        self.startedAt = startedAt
        self.updatedAt = updatedAt
    }

    public var status: TaskStatus {
        switch phase {
        case .awaitingApproval where approval != nil: return .needsYou
        case .generating: return .running
        case .interrupted: return .stopped
        default:
            if outcome == .failed { return .failed }
            return messages.isEmpty ? .new : .done
        }
    }

    /// One line describing what the task did last, for list rows.
    public var latestActivity: String {
        if status == .running, let currentStep { return currentStep }
        let draft = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !draft.isEmpty { return "草稿：\(draft)" }
        if status == .needsYou, let approval { return "等你确认：\(approval.command)" }
        if let summary { return summary }
        let last = messages.last { !$0.text.isEmpty }?.text ?? ""
        return last.split(whereSeparator: \.isNewline).first.map(String.init) ?? "还没有开始"
    }

    public var isBusy: Bool { phase == .generating || phase == .awaitingApproval }

    public mutating func beginDemoReply(to text: String) {
        guard !isBusy else { return }
        messages.append(ChatMessage(role: .user, text: text))
        messages.append(ChatMessage(role: .assistant, text: "", isStreaming: true))
        phase = .generating
        outcome = nil
        summary = nil
        currentStep = "正在规划…"
        draft = ""
        startedAt = .now
        updatedAt = .now
    }

    public mutating func setDemoStep(_ step: String, activity: ToolActivity? = nil) {
        guard phase == .generating, let index = messages.indices.last, messages[index].isStreaming else { return }
        currentStep = step
        if let activity { messages[index].activity.append(activity) }
    }

    public mutating func appendDemoText(_ text: String) {
        guard phase == .generating, let index = messages.indices.last, messages[index].isStreaming else { return }
        messages[index].text += text
    }

    public mutating func attachDemo(_ attachment: MessageAttachment) {
        guard phase == .generating, let index = messages.indices.last, messages[index].isStreaming else { return }
        messages[index].attachments.append(attachment)
    }

    public mutating func finishDemoReply(summary: String? = nil) {
        guard phase == .generating else { return }
        if let index = messages.indices.last { messages[index].isStreaming = false }
        phase = .ready
        outcome = .succeeded
        currentStep = nil
        self.summary = summary
        updatedAt = .now
    }

    public mutating func interrupt() {
        if let index = messages.indices.last { messages[index].isStreaming = false }
        if approval != nil {
            messages.append(ChatMessage(role: .assistant, text: "待确认操作已失效，没有记录授权。你可以继续发送消息。"))
        }
        approval = nil
        currentStep = nil
        if isBusy { phase = .interrupted }
    }

    @discardableResult
    public mutating func resolveApproval(id: UUID, allow: Bool, note: String? = nil) -> Bool {
        guard let approval, approval.id == id, phase == .awaitingApproval else { return false }
        self.approval = nil
        phase = .ready
        updatedAt = .now
        let note = allow ? "" : (note ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        activity.append(ToolActivity(kind: .command, title: allow ? "本地记录：允许一次" : "本地记录：已拒绝", detail: approval.command, state: allow ? .completed : .declined))
        let result: String
        if allow {
            result = "已记录「仅允许一次」。没有执行命令。"
        } else if note.isEmpty {
            result = "已记录「拒绝这次操作」。没有执行命令。"
        } else {
            result = "已记录「拒绝这次操作」，并附上说明：\(note)。没有执行命令。"
        }
        messages.append(ChatMessage(role: .assistant, text: result))
        return true
    }

    /// Removes an assistant reply and the prompt that produced it, returning the prompt to send again.
    public mutating func prepareRetry(of messageID: UUID) -> String? {
        guard !isBusy,
              let index = messages.firstIndex(where: { $0.id == messageID }),
              messages[index].role == .assistant,
              let promptIndex = messages[..<index].lastIndex(where: { $0.role == .user }) else { return nil }
        let prompt = messages[promptIndex].text
        messages.removeSubrange(promptIndex...)
        return prompt
    }

    /// A new task holding this conversation up to and including `messageID`.
    public func forked(at messageID: UUID) -> Conversation? {
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else { return nil }
        var copied = Array(messages[...index])
        for position in copied.indices {
            copied[position] = ChatMessage(role: copied[position].role, text: copied[position].text, reasoning: copied[position].reasoning, activity: copied[position].activity, attachments: copied[position].attachments)
        }
        return Conversation(title: "\(title) · 分叉", computer: computer, project: project, workspace: workspace, messages: copied, permissionMode: permissionMode, model: model)
    }
}

public enum TaskStatus: String, Sendable {
    case new, running, needsYou, done, failed, stopped
}

public enum PermissionMode: String, CaseIterable, Identifiable, Sendable {
    // There is deliberately no "bypass all approvals" mode on the phone.
    case ask, autoEdit, plan

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .ask: "每次询问"
        case .autoEdit: "自动改文件"
        case .plan: "计划模式"
        }
    }

    public var detail: String {
        switch self {
        case .ask: "读文件以外的操作都先问你"
        case .autoEdit: "改文件不再询问，运行命令仍要确认"
        case .plan: "只读代码并给出计划，不做改动"
        }
    }
}

public enum ModelChoice {
    public static let followComputer = "跟随电脑"
    public static let all = [followComputer, "DeepSeek V3", "DeepSeek R1"]
}

public struct ChatMessage: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var role: Role
    public var text: String
    public var reasoning: String?
    public var activity: [ToolActivity]
    public var attachments: [MessageAttachment]
    public var isStreaming: Bool
    public enum Role: String, Sendable { case user, assistant }

    public init(id: UUID = UUID(), role: Role, text: String, reasoning: String? = nil, activity: [ToolActivity] = [], attachments: [MessageAttachment] = [], isStreaming: Bool = false) {
        self.id = id
        self.role = role
        self.text = text
        self.reasoning = reasoning
        self.activity = activity
        self.attachments = attachments
        self.isStreaming = isStreaming
    }
}

public struct ToolActivity: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var kind: Kind
    public var title: String
    public var detail: String
    public var state: State
    public enum Kind: String, Sendable { case read, edit, command, other }
    public enum State: Sendable { case completed, declined }

    public init(id: UUID = UUID(), kind: Kind = .other, title: String, detail: String, state: State = .completed) {
        self.id = id
        self.kind = kind
        self.title = title
        self.detail = detail
        self.state = state
    }

    /// "读了 3 个文件 · 改了 2 个 · 运行 1 条命令"
    public static func summary(of activity: [ToolActivity]) -> String {
        func count(_ kind: Kind) -> Int { activity.filter { $0.kind == kind }.count }
        let reads = count(.read), edits = count(.edit), commands = count(.command), others = count(.other)
        var parts: [String] = []
        if reads > 0 { parts.append("读了 \(reads) 个文件") }
        if edits > 0 { parts.append(reads > 0 ? "改了 \(edits) 个" : "改了 \(edits) 个文件") }
        if commands > 0 { parts.append("运行 \(commands) 条命令") }
        if others > 0 { parts.append("\(others) 项其他操作") }
        return parts.joined(separator: " · ")
    }
}

public enum MessageAttachment: Identifiable, Equatable, Sendable {
    case diff(DiffAttachment)
    case terminal(TerminalOutput)

    public var id: UUID {
        switch self {
        case .diff(let diff): diff.id
        case .terminal(let output): output.id
        }
    }
}

public struct DiffAttachment: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var fileName: String
    public var additions: Int
    public var deletions: Int
    public var lines: [DiffLine]
    public var changedFiles: Int

    public init(id: UUID = UUID(), fileName: String, additions: Int, deletions: Int, lines: [DiffLine], changedFiles: Int = 1) {
        self.id = id
        self.fileName = fileName
        self.additions = additions
        self.deletions = deletions
        self.lines = lines
        self.changedFiles = changedFiles
    }
}

public struct DiffLine: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var kind: Kind
    public var text: String
    public enum Kind: String, Sendable { case added, removed, context }

    public init(id: UUID = UUID(), _ kind: Kind, _ text: String) {
        self.id = id
        self.kind = kind
        self.text = text
    }
}

public struct TerminalOutput: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var command: String
    public var output: String
    public var exitCode: Int32

    public init(id: UUID = UUID(), command: String, output: String, exitCode: Int32 = 0) {
        self.id = id
        self.command = command
        self.output = output
        self.exitCode = exitCode
    }
}

public struct ToolApproval: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let command: String
    public let workspace: String
    public let explanation: String
    public let computer: String
    public let requestedAt: Date

    public init(id: UUID = UUID(), title: String = "运行命令", command: String, workspace: String, explanation: String, computer: String, requestedAt: Date = .now) {
        self.id = id
        self.title = title
        self.command = command
        self.workspace = workspace
        self.explanation = explanation
        self.computer = computer
        self.requestedAt = requestedAt
    }
}
