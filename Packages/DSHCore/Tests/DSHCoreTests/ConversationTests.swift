import Testing
@testable import DSHCore

@Test func streamingCompletesWithoutDuplicatingMessage() {
    var conversation = Conversation(title: "Test", computer: "Mac", project: "demo")
    conversation.beginDemoReply(to: "hello")
    conversation.appendDemoText("Hello")
    conversation.appendDemoText(" world")
    conversation.finishDemoReply()
    conversation.finishDemoReply()
    #expect(conversation.messages.count == 2)
    #expect(conversation.messages.last?.text == "Hello world")
    #expect(conversation.messages.last?.isStreaming == false)
    #expect(conversation.phase == .ready)
}

@Test func interruptionInvalidatesApprovalAndStopsLateChunks() {
    var conversation = DemoContent.conversations()[1]
    let approvalID = conversation.approval!.id
    conversation.draft = "Keep my next question"
    conversation.interrupt()
    let accepted = conversation.resolveApproval(id: approvalID, allow: true)
    #expect(!accepted)
    #expect(conversation.approval == nil)
    #expect(conversation.phase == .interrupted)
    #expect(conversation.draft == "Keep my next question")
    #expect(conversation.messages.last?.text.contains("已失效") == true)
    let messageCount = conversation.messages.count
    conversation.interrupt()
    #expect(conversation.messages.count == messageCount)

    conversation.beginDemoReply(to: "hello")
    conversation.appendDemoText("partial")
    conversation.interrupt()
    conversation.appendDemoText("late")
    #expect(conversation.messages.last?.text == "partial")
}

@Test func approvalCanOnlyBeResolvedOnce() {
    var conversation = DemoContent.conversations()[1]
    let id = conversation.approval!.id
    conversation.draft = "Next question"
    let first = conversation.resolveApproval(id: id, allow: false)
    let second = conversation.resolveApproval(id: id, allow: true)
    #expect(first)
    #expect(!second)
    #expect(conversation.activity.count == 1)
    #expect(conversation.activity.first?.state == .declined)
    #expect(conversation.messages.last?.text == "已记录「拒绝这次操作」。没有执行命令。")
    #expect(conversation.draft == "Next question")
    #expect(conversation.phase == .ready)
}

@Test func approvalMustMatchCurrentRequestAndPhase() {
    var conversation = DemoContent.conversations()[1]
    let current = conversation.approval!.id
    let unrelated = ToolApproval(command: "other", workspace: "/other", explanation: "Other request", computer: "Mac")
    let acceptedUnrelated = conversation.resolveApproval(id: unrelated.id, allow: true)
    #expect(!acceptedUnrelated)
    #expect(conversation.approval?.id == current)
    conversation.phase = .interrupted
    let acceptedInterrupted = conversation.resolveApproval(id: current, allow: true)
    #expect(!acceptedInterrupted)
    #expect(conversation.activity.isEmpty)
}

@Test func allowingDemoApprovalRecordsChoiceWithoutClaimingExecution() {
    var conversation = DemoContent.conversations()[1]
    let approval = conversation.approval!
    #expect(conversation.status == .needsYou)
    #expect(approval.computer == "Mac mini")
    #expect(approval.workspace == "~/code/harness-api")
    #expect(approval.command == "npm run test -- --watch=false")
    let accepted = conversation.resolveApproval(id: approval.id, allow: true)
    #expect(accepted)
    #expect(conversation.approval == nil)
    #expect(conversation.status == .done)
    #expect(conversation.activity.last?.title == "本地记录：允许一次")
    #expect(conversation.messages.last?.text == "已记录「仅允许一次」。没有执行命令。")
}

@Test func rejectingWithNoteKeepsNoteAndConsumesOnce() {
    var conversation = DemoContent.conversations()[1]
    let id = conversation.approval!.id
    let first = conversation.resolveApproval(id: id, allow: false, note: "  先别跑全部测试  ")
    let second = conversation.resolveApproval(id: id, allow: false, note: "again")
    #expect(first)
    #expect(!second)
    #expect(conversation.messages.last?.text == "已记录「拒绝这次操作」，并附上说明：先别跑全部测试。没有执行命令。")
    #expect(conversation.activity.count == 1)
}

@Test func allowingIgnoresNote() {
    var conversation = DemoContent.conversations()[1]
    conversation.resolveApproval(id: conversation.approval!.id, allow: true, note: "ignored")
    #expect(conversation.messages.last?.text == "已记录「仅允许一次」。没有执行命令。")
}
