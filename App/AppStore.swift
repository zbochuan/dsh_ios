import SwiftUI
import DSHCore

@MainActor @Observable
final class AppStore {
    enum Panel: String, Identifiable {
        case computers, settings, pairing
        var id: String { rawValue }
    }

    var conversations: [Conversation] = []
    /// True once the example tasks are open. Nothing in them runs on a computer.
    var isDemo = false
    var selectedConversationID: UUID?
    var presentedPanel: Panel?
    var isDrawerOpen = false
    /// A task whose approval sheet should open as soon as its detail appears.
    var approvalToOpen: UUID?
    var homeDraft = ""
    var newTaskComputer = DemoContent.computers[0].name
    var newTaskProject = DemoContent.projects[DemoContent.computers[0].name]?.first ?? ""
    var newTaskPermission: PermissionMode = .ask
    private var generationTasks: [UUID: Task<Void, Never>] = [:]

    var selectedConversation: Conversation? {
        conversations.first { $0.id == selectedConversationID }
    }

    var computers: [ComputerSummary] { isDemo ? DemoContent.computers : [] }

    var onlineComputers: [ComputerSummary] { computers.filter(\.isOnline) }

    func projects(on computer: String) -> [String] { DemoContent.projects[computer] ?? [] }

    func board(search: String = "") -> TaskBoard {
        TaskBoard(conversations: conversations, computers: computers, search: search)
    }

    /// Opens the example tasks, optionally showing one of them.
    func enterDemo(showing title: String? = nil) {
        if !isDemo {
            isDemo = true
            if conversations.isEmpty {
                conversations = DemoContent.conversations()
                newTaskPermission = defaultPermission
                if let running = conversations.first(where: { $0.phase == .generating }) {
                    playExampleRun(running.id)
                }
            }
        }
        presentedPanel = nil
        isDrawerOpen = false
        if let title, let task = conversations.first(where: { $0.title == title }) {
            selectConversation(task.id)
        }
    }

    func selectConversation(_ id: UUID?) {
        guard let id else {
            selectedConversationID = nil
            isDrawerOpen = false
            return
        }
        guard isDemo, conversations.contains(where: { $0.id == id }) else { return }
        selectedConversationID = id
        isDrawerOpen = false
    }

    func reviewApproval(in id: UUID) {
        approvalToOpen = id
        selectConversation(id)
    }

    func newConversation() {
        guard isDemo else { return }
        // Reuse an untouched blank task rather than filling the list with empty rows.
        if let blank = conversations.first(where: { $0.messages.isEmpty && $0.draft.isEmpty && $0.approval == nil && !$0.isArchived }) {
            selectedConversationID = blank.id
        } else {
            let task = Conversation(title: "新任务", computer: newTaskComputer, project: newTaskProject, workspace: "~/code/\(newTaskProject)", permissionMode: newTaskPermission, model: defaultModel)
            conversations.insert(task, at: 0)
            selectedConversationID = task.id
        }
        isDrawerOpen = false
    }

    /// Starts a task from the home composer.
    func startTask() {
        let text = homeDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isDemo, !text.isEmpty else { return }
        let task = Conversation(title: String(text.prefix(24)), computer: newTaskComputer, project: newTaskProject, workspace: "~/code/\(newTaskProject)", permissionMode: newTaskPermission, model: defaultModel)
        conversations.insert(task, at: 0)
        homeDraft = ""
        selectedConversationID = task.id
        begin(text, in: task.id)
    }

    func update(_ id: UUID, _ change: (inout Conversation) -> Void) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        change(&conversations[index])
    }

    func send(in id: UUID) {
        guard isDemo, let conversation = conversations.first(where: { $0.id == id }), !conversation.isBusy else { return }
        let text = conversation.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        update(id) { if $0.messages.isEmpty { $0.title = String(text.prefix(24)) } }
        begin(text, in: id)
    }

    func retry(_ messageID: UUID, in id: UUID) {
        guard isDemo else { return }
        var prompt: String?
        update(id) { prompt = $0.prepareRetry(of: messageID) }
        if let prompt { begin(prompt, in: id) }
    }

    func fork(_ messageID: UUID, in id: UUID) {
        guard isDemo, let source = conversations.first(where: { $0.id == id }),
              let fork = source.forked(at: messageID),
              let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations.insert(fork, at: index)
        selectedConversationID = fork.id
    }

    func rename(_ id: UUID, to title: String) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        update(id) { $0.title = title }
    }

    func archive(_ id: UUID) {
        stop(id)
        update(id) { $0.isArchived = true }
        if selectedConversationID == id { selectedConversationID = nil }
    }

    func delete(_ id: UUID) {
        generationTasks[id]?.cancel()
        generationTasks[id] = nil
        conversations.removeAll { $0.id == id }
        if selectedConversationID == id { selectedConversationID = nil }
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

    func resolveApproval(in id: UUID, approvalID: UUID, allow: Bool, note: String? = nil) {
        guard isDemo else { return }
        update(id) { _ = $0.resolveApproval(id: approvalID, allow: allow, note: note) }
    }

    private var defaultPermission: PermissionMode {
        PermissionMode(rawValue: UserDefaults.standard.string(forKey: "defaults.permissionMode") ?? "") ?? .ask
    }

    private var defaultModel: String {
        UserDefaults.standard.string(forKey: "defaults.model") ?? ModelChoice.followComputer
    }

    private func begin(_ text: String, in id: UUID) {
        update(id) { $0.beginDemoReply(to: text) }
        let reply = "在真实任务里，Agent 会在你的电脑上读文件、改代码、运行命令，每一步都会显示在这里。\n\n需要确认的操作会先停下来，出现在首页的「等你确认」里。你可以随时补充指令或点「停止」。"
        generationTasks[id] = Task { [weak self] in
            // Delays pace the example only; no request leaves the phone.
            for step in ["正在规划…", "正在整理回复…"] {
                do { try await Task.sleep(for: .milliseconds(700)) } catch { return }
                guard let self, !Task.isCancelled else { return }
                self.update(id) { $0.setDemoStep(step) }
            }
            for piece in reply.map(String.init) {
                do { try await Task.sleep(for: .milliseconds(22)) } catch { return }
                guard let self, !Task.isCancelled else { return }
                self.update(id) { $0.appendDemoText(piece) }
            }
            self?.update(id) { $0.finishDemoReply(summary: "已回复") }
            self?.generationTasks[id] = nil
        }
    }

    /// Plays the scripted progress of the running example task.
    private func playExampleRun(_ id: UUID) {
        let reply = "设置页已拆成四组。`SettingsView` 里的演示开关已删除，通知开关移到新的「通知」组。"
        generationTasks[id] = Task { [weak self] in
            let steps: [(String, ToolActivity)] = [
                ("正在修改 SettingsView.swift…", ToolActivity(kind: .edit, title: "修改文件", detail: "App/Views/SettingsView.swift")),
                ("正在修改 AppStore.swift…", ToolActivity(kind: .edit, title: "修改文件", detail: "App/AppStore.swift")),
                ("正在运行 swift test…", ToolActivity(kind: .command, title: "运行命令", detail: "swift test")),
            ]
            for (step, activity) in steps {
                do { try await Task.sleep(for: .seconds(15)) } catch { return }
                guard let self, !Task.isCancelled else { return }
                self.update(id) { $0.setDemoStep(step, activity: activity) }
            }
            do { try await Task.sleep(for: .seconds(10)) } catch { return }
            for piece in reply.map(String.init) {
                do { try await Task.sleep(for: .milliseconds(30)) } catch { return }
                guard let self, !Task.isCancelled else { return }
                self.update(id) { $0.appendDemoText(piece) }
            }
            self?.update(id) {
                $0.attachDemo(.diff(DiffAttachment(fileName: "SettingsView.swift", additions: 42, deletions: 18, lines: [
                    DiffLine(.removed, "Section(\"本地演示\") {"),
                    DiffLine(.added, "Section(\"通知\") {"),
                    DiffLine(.added, "    Toggle(\"需要我确认时\", isOn: $ask)"),
                ], changedFiles: 2)))
                $0.attachDemo(.terminal(TerminalOutput(command: "swift test", output: "Executed 48 tests, with 0 failures")))
                $0.finishDemoReply(summary: "改了 2 个文件，测试通过")
            }
            self?.generationTasks[id] = nil
        }
    }
}
