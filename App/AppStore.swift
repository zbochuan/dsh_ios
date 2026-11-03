import SwiftUI
import DSHCore

@MainActor @Observable
final class AppStore {
    enum Panel: String, Identifiable {
        case history, computers, settings, demoInfo
        var id: String { rawValue }
    }

    var conversations: [Conversation] = []
    var isDemo = false
    var selectedConversationID: UUID?
    var presentedPanel: Panel?
    private var generationTasks: [UUID: Task<Void, Never>] = [:]

    var selectedConversation: Conversation? {
        conversations.first { $0.id == selectedConversationID }
    }

    var hasDemoHistory: Bool { !conversations.isEmpty }

    func enterDemo() {
        guard !isDemo else { return }
        isDemo = true
        if conversations.isEmpty {
            conversations = DemoContent.conversations()
            newConversation()
        } else if selectedConversation == nil {
            selectedConversationID = conversations.first?.id
        }
        presentedPanel = nil
    }

    func leaveDemo() {
        stopAll()
        isDemo = false
        presentedPanel = nil
        // Keep this launch's history and drafts so returning never discards input.
    }

    func selectConversation(_ id: UUID) {
        guard isDemo, conversations.contains(where: { $0.id == id }) else { return }
        selectedConversationID = id
        if presentedPanel == .history { presentedPanel = nil }
    }

    func newConversation() {
        guard isDemo else { return }
        // Reuse an untouched blank conversation rather than filling history with empty rows.
        if let blank = conversations.first(where: { $0.messages.isEmpty && $0.draft.isEmpty && $0.approval == nil }) {
            selectedConversationID = blank.id
        } else {
            let conversation = Conversation(title: "新对话", workspace: "本地工作区")
            conversations.insert(conversation, at: 0)
            selectedConversationID = conversation.id
        }
        if presentedPanel == .history { presentedPanel = nil }
    }

    func update(_ id: UUID, _ change: (inout Conversation) -> Void) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        change(&conversations[index])
    }

    func send(in id: UUID) {
        guard isDemo, let conversation = conversations.first(where: { $0.id == id }), conversation.phase != .generating, conversation.phase != .awaitingApproval else { return }
        let text = conversation.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        update(id) {
            if $0.messages.isEmpty { $0.title = String(text.prefix(24)) }
            $0.beginDemoReply(to: text)
        }
        let reply = "这是一段预设回复，供你试用对话。\n\n梳理项目时，可以先看 README 里的用途和运行方式，再找程序入口，最后读一个核心流程对应的测试。把不确定的地方记成问题，再逐个验证。\n\n你可以继续输入，或从历史记录切换到另一个对话。"
        generationTasks[id] = Task { [weak self] in
            // Delays simulate streaming only in the explicitly labelled demo.
            for piece in reply.map(String.init) {
                do { try await Task.sleep(for: .milliseconds(22)) } catch { return }
                guard let self, !Task.isCancelled else { return }
                self.update(id) { $0.appendDemoText(piece) }
            }
            self?.update(id) { $0.finishDemoReply() }
            self?.generationTasks[id] = nil
        }
    }

    func stop(_ id: UUID) {
        generationTasks[id]?.cancel()
        generationTasks[id] = nil
        update(id) { $0.interrupt() }
    }

    func stopAll() {
        for task in generationTasks.values { task.cancel() }
        generationTasks.removeAll()
        for index in conversations.indices { conversations[index].interrupt() }
    }

    func resolveApproval(in id: UUID, approvalID: UUID, allow: Bool) {
        guard isDemo else { return }
        update(id) { _ = $0.resolveApproval(id: approvalID, allow: allow) }
    }
}
