import Foundation
import Testing
@testable import DSHCore

@Test func statusFollowsPhaseApprovalAndOutcome() {
    var task = Conversation(title: "T", computer: "Mac", project: "p")
    #expect(task.status == .new)
    task.beginDemoReply(to: "go")
    #expect(task.status == .running)
    #expect(task.currentStep != nil)
    task.finishDemoReply(summary: "done")
    #expect(task.status == .done)
    #expect(task.currentStep == nil)
    #expect(task.summary == "done")
    task.outcome = .failed
    #expect(task.status == .failed)
    task.beginDemoReply(to: "again")
    task.interrupt()
    #expect(task.status == .stopped)
    // An awaiting phase without a request is not shown as needing the user.
    task.phase = .awaitingApproval
    #expect(task.status != .needsYou)
}

@Test func latestActivityPrefersStepThenDraftThenSummary() {
    var task = DemoContent.conversations()[0]
    #expect(task.latestActivity == "正在修改 SettingsView.swift…")
    task.interrupt()
    task.draft = "  next  "
    #expect(task.latestActivity == "草稿：next")
    task.draft = ""
    task.summary = "改了 2 个文件"
    #expect(task.latestActivity == "改了 2 个文件")
    task.summary = nil
    task.messages = [ChatMessage(role: .assistant, text: "first line\nsecond")]
    #expect(task.latestActivity == "first line")
}

@Test func demoStepsAndAttachmentsOnlyApplyWhileStreaming() {
    var task = Conversation(title: "T", computer: "Mac", project: "p")
    task.setDemoStep("ignored", activity: ToolActivity(kind: .read, title: "r", detail: "a"))
    #expect(task.currentStep == nil)
    task.beginDemoReply(to: "go")
    task.setDemoStep("读取", activity: ToolActivity(kind: .read, title: "r", detail: "a"))
    task.attachDemo(.terminal(TerminalOutput(command: "ls", output: "a")))
    #expect(task.currentStep == "读取")
    #expect(task.messages.last?.activity.count == 1)
    #expect(task.messages.last?.attachments.count == 1)
    task.interrupt()
    task.attachDemo(.terminal(TerminalOutput(command: "late", output: "")))
    #expect(task.messages.last?.attachments.count == 1)
    #expect(task.currentStep == nil)
}

@Test func activitySummaryCountsByKind() {
    func make(_ kind: ToolActivity.Kind) -> ToolActivity { ToolActivity(kind: kind, title: "", detail: "") }
    #expect(ToolActivity.summary(of: [make(.read), make(.read), make(.read), make(.edit), make(.edit), make(.command)]) == "读了 3 个文件 · 改了 2 个 · 运行 1 条命令")
    #expect(ToolActivity.summary(of: [make(.edit)]) == "改了 1 个文件")
    #expect(ToolActivity.summary(of: [make(.command), make(.other)]) == "运行 1 条命令 · 1 项其他操作")
    #expect(ToolActivity.summary(of: []) == "")
}

@Test func retryRemovesReplyAndReturnsPrompt() {
    var task = DemoContent.conversations()[3]
    let reply = task.messages[1]
    let fromUser = task.prepareRetry(of: task.messages[0].id)
    #expect(fromUser == nil, "Only assistant replies can be retried.")
    let prompt = task.prepareRetry(of: reply.id)
    #expect(prompt == "把依赖升级到最新的小版本。")
    #expect(task.messages.isEmpty)

    var busy = DemoContent.conversations()[1]
    let blocked = busy.prepareRetry(of: busy.messages[1].id)
    #expect(blocked == nil, "A task waiting on approval cannot retry.")
    #expect(busy.messages.count == 2)
}

@Test func forkCopiesHistoryUpToMessageWithoutPendingState() throws {
    var source = DemoContent.conversations()[1]
    source.draft = "unsent"
    let fork = try #require(source.forked(at: source.messages[0].id))
    #expect(fork.id != source.id)
    #expect(fork.title == "修复登录超时 · 分叉")
    #expect(fork.messages.map(\.text) == [source.messages[0].text])
    #expect(fork.messages[0].id != source.messages[0].id)
    #expect(fork.approval == nil)
    #expect(fork.phase == .ready)
    #expect(fork.draft.isEmpty)
    #expect(fork.computer == source.computer && fork.project == source.project)
    #expect(source.forked(at: UUID()) == nil)
}

@Test func phoneOffersNoBypassPermission() {
    #expect(PermissionMode.allCases.map(\.title) == ["每次询问", "自动改文件", "计划模式"])
    #expect(PermissionMode(rawValue: "bypass") == nil)
}

@Test func boardPinsPendingAndGroupsByComputer() {
    let tasks = DemoContent.conversations()
    let board = TaskBoard(conversations: tasks, computers: DemoContent.computers)
    #expect(board.pending.map(\.title) == ["修复登录超时"])
    #expect(board.sections.map(\.computer.name) == ["Mac mini", "MacBook Pro"])
    #expect(board.sections[0].tasks.map(\.title) == ["重构设置页", "加暗色模式", "升级依赖"])
    #expect(board.sections[1].computer.isOnline == false)
    #expect(board.sections[1].tasks.map(\.title) == ["写周报脚本"])
    #expect(board.projects.map(\.id) == ["Mac mini · dsh_ios", "Mac mini · harness-api", "MacBook Pro · blog"])
    #expect(board.projects[1].tasks.map(\.title) == ["修复登录超时", "升级依赖"])
}

@Test func boardHidesArchivedFiltersSearchAndKeepsUnknownComputers() {
    var tasks = DemoContent.conversations()
    tasks[0].isArchived = true
    tasks.append(Conversation(title: "孤立任务", computer: "Linux box", project: "x"))
    let board = TaskBoard(conversations: tasks, computers: DemoContent.computers)
    #expect(!board.sections[0].tasks.contains { $0.title == "重构设置页" })
    #expect(board.sections.last?.computer == ComputerSummary(name: "Linux box", isOnline: false))

    let searched = TaskBoard(conversations: tasks, computers: DemoContent.computers, search: "harness")
    #expect(searched.projects.map(\.id) == ["Mac mini · harness-api"])
    #expect(searched.pending.count == 1)
}

@Test func pendingOrderedByOldestRequest() {
    let now = Date()
    func waiting(_ title: String, minutes: Double) -> Conversation {
        Conversation(title: title, computer: "Mac", project: "p", approval: ToolApproval(command: "c", workspace: "w", explanation: "e", computer: "Mac", requestedAt: now.addingTimeInterval(-minutes * 60)), phase: .awaitingApproval, updatedAt: now)
    }
    let board = TaskBoard(conversations: [waiting("new", minutes: 1), waiting("old", minutes: 10)], computers: [])
    #expect(board.pending.map(\.title) == ["old", "new"])
}

@Test func timeFormatting() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
    #expect(TaskTime.elapsed(from: now.addingTimeInterval(-20), to: now) == "刚开始")
    #expect(TaskTime.elapsed(from: now.addingTimeInterval(-6 * 60), to: now) == "6 分钟")
    #expect(TaskTime.elapsed(from: now.addingTimeInterval(-65 * 60), to: now) == "1 小时 5 分钟")
    #expect(TaskTime.elapsed(from: now.addingTimeInterval(-120 * 60), to: now) == "2 小时")
    #expect(TaskTime.ago(now.addingTimeInterval(-10), now: now, calendar: calendar) == "刚刚")
    #expect(TaskTime.ago(now.addingTimeInterval(-2 * 60), now: now, calendar: calendar) == "2 分钟前")
    let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now)!
    #expect(TaskTime.ago(noon.addingTimeInterval(-3 * 3600), now: noon, calendar: calendar) == "3 小时前")
    #expect(TaskTime.ago(noon.addingTimeInterval(-24 * 3600), now: noon, calendar: calendar) == "昨天")
    #expect(TaskTime.ago(noon.addingTimeInterval(-3 * 24 * 3600), now: noon, calendar: calendar) == "3 天前")
}
