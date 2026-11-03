import SwiftUI
import DSHCore

/// Task detail: the conversation with the agent, its activity and its pending request.
struct ChatView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let conversationID: UUID
    @State private var approvalToReview: ToolApproval?
    @State private var followingLatest = true
    @State private var returningToLatest = false
    @State private var renaming = false
    @State private var renameText = ""
    @State private var confirmingDelete = false
    @FocusState private var composerFocused: Bool

    private var conversation: Conversation? { store.conversations.first { $0.id == conversationID } }

    var body: some View {
        if let conversation {
            transcript(conversation)
                .background(DSHTheme.background)
                .navigationTitle(conversation.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        VStack(spacing: 1) {
                            Text(conversation.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(DSHTheme.ink).lineLimit(1)
                            Text(TaskText.context(conversation))
                                .font(.caption).foregroundStyle(DSHTheme.secondary).lineLimit(1)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("task.title")
                    }
                    ToolbarItem(placement: .primaryAction) { moreMenu(conversation) }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) { composer(conversation) }
                .sheet(item: $approvalToReview) { approval in
                    ApprovalView(conversationID: conversationID, approval: approval)
                }
                .alert("重命名任务", isPresented: $renaming) {
                    TextField("任务名称", text: $renameText)
                    Button("保存") { store.rename(conversationID, to: renameText) }
                    Button("取消", role: .cancel) {}
                }
                .confirmationDialog("删除这个任务？", isPresented: $confirmingDelete, titleVisibility: .visible) {
                    Button("删除", role: .destructive) { store.delete(conversationID) }
                } message: {
                    Text("会从手机上移除这个任务和它的草稿。")
                }
                .onAppear {
                    if store.approvalToOpen == conversationID {
                        store.approvalToOpen = nil
                        approvalToReview = conversation.approval
                    }
                }
        } else {
            ContentUnavailableView("找不到这个任务", systemImage: "list.bullet", description: Text("请从任务列表选择另一个任务。"))
        }
    }

    private func moreMenu(_ conversation: Conversation) -> some View {
        Menu {
            Button("新任务", systemImage: "square.and.pencil") {
                composerFocused = false
                store.newConversation()
            }
            .accessibilityIdentifier("conversation.new")
            Button("重命名", systemImage: "pencil") {
                renameText = conversation.title
                renaming = true
            }
            Button("归档", systemImage: "archivebox") { store.archive(conversationID) }
            Button("删除", systemImage: "trash", role: .destructive) { confirmingDelete = true }
        } label: {
            Image(systemName: "ellipsis").font(.body.weight(.medium))
                .foregroundStyle(DSHTheme.ink)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel("更多")
        .accessibilityIdentifier("task.more")
    }

    private func transcript(_ conversation: Conversation) -> some View {
        GeometryReader { viewport in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 22) {
                        if conversation.messages.isEmpty {
                            emptyState(conversation, height: viewport.size.height)
                        }
                        let lastAssistant = conversation.messages.last { $0.role == .assistant }?.id
                        ForEach(conversation.messages) { message in
                            MessageView(
                                message: message,
                                canRetry: message.id == lastAssistant && !conversation.isBusy,
                                retry: { store.retry(message.id, in: conversationID) },
                                fork: { store.fork(message.id, in: conversationID) }
                            )
                        }
                        if !conversation.activity.isEmpty {
                            ActivitySummary(activity: conversation.activity, title: "\(conversation.activity.count) 条确认记录")
                        }
                        if let approval = conversation.approval {
                            approvalCard(conversation, approval)
                        }
                        if conversation.phase == .interrupted {
                            Label("已停止，可继续发送消息", systemImage: "pause.circle")
                                .font(.caption).foregroundStyle(DSHTheme.secondary)
                                .accessibilityIdentifier("chat.interrupted")
                        }
                        Color.clear.frame(height: 1).id("latest")
                            .background(GeometryReader { geometry in
                                Color.clear.preference(key: TranscriptBottomKey.self, value: geometry.frame(in: .named("transcript")).maxY)
                            })
                    }
                    .frame(maxWidth: DSHTheme.readingWidth)
                    .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 12)
                    .frame(maxWidth: .infinity)
                }
                .coordinateSpace(name: "transcript")
                .scrollDismissesKeyboard(.interactively)
                .onPreferenceChange(TranscriptBottomKey.self) { bottom in
                    followingLatest = bottom <= viewport.size.height + 80
                }
                .onAppear { proxy.scrollTo("latest", anchor: .bottom) }
                .onChange(of: conversation.messages.last?.text) { _, _ in
                    // Incoming text must not replace a user-initiated scroll animation.
                    if followingLatest && !returningToLatest { proxy.scrollTo("latest", anchor: .bottom) }
                }
                .onChange(of: conversation.messages.last?.attachments.count) { _, _ in
                    if followingLatest && !returningToLatest { proxy.scrollTo("latest", anchor: .bottom) }
                }
                .onChange(of: conversation.phase) { _, phase in
                    if phase == .generating { followingLatest = true; proxy.scrollTo("latest", anchor: .bottom) }
                }
                .overlay(alignment: .bottomTrailing) {
                    if !followingLatest && !returningToLatest {
                        Button {
                            followingLatest = true
                            if reduceMotion {
                                proxy.scrollTo("latest", anchor: .bottom)
                            } else {
                                returningToLatest = true
                                withAnimation(.spring(response: 0.35, dampingFraction: 1), completionCriteria: .removed) {
                                    proxy.scrollTo("latest", anchor: .bottom)
                                } completion: {
                                    returningToLatest = false
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.down")
                                .font(.body.weight(.medium)).foregroundStyle(DSHTheme.ink)
                                .frame(width: 44, height: 44)
                                .background(DSHTheme.background, in: Circle())
                                .overlay(Circle().strokeBorder(DSHTheme.separator, lineWidth: 1))
                        }
                        .buttonStyle(PressStyle()).accessibilityLabel("回到最新")
                        .accessibilityIdentifier("chat.latest")
                        .padding(16)
                    }
                }
            }
        }
    }

    private func emptyState(_ conversation: Conversation, height: CGFloat) -> some View {
        VStack(spacing: 14) {
            Text("要 Agent 做点什么？")
                .font(.title3.weight(.semibold)).foregroundStyle(DSHTheme.ink)
            Text("在 \(TaskText.context(conversation)) 上运行")
                .font(.subheadline).foregroundStyle(DSHTheme.secondary)
            if conversation.draft.isEmpty {
                Button {
                    guard self.conversation?.draft.isEmpty == true else { return }
                    store.update(conversationID) { $0.draft = "看看这个项目的测试覆盖了哪些流程" }
                    composerFocused = true
                } label: {
                    HStack(spacing: 8) {
                        Text("看看测试覆盖了哪些流程")
                        Image(systemName: "arrow.up.left").font(.caption)
                    }
                    .font(.subheadline).foregroundStyle(DSHTheme.secondary)
                    .padding(.horizontal, 14).frame(minHeight: 44)
                    .background(DSHTheme.surface, in: Capsule())
                }
                .buttonStyle(PressStyle())
                .accessibilityHint("填入指令，编辑后发送")
                .accessibilityIdentifier("chat.example")
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: max(180, height * 0.62))
    }

    private func approvalCard(_ conversation: Conversation, _ approval: ToolApproval) -> some View {
        Button {
            composerFocused = false
            approvalToReview = approval
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    StatusDot(kind: .needsYou)
                    Text("需要你确认 · \(approval.title)")
                }
                .font(.footnote.weight(.semibold)).foregroundStyle(DSHTheme.amberText)
                Text(approval.command).font(.subheadline.monospaced()).foregroundStyle(DSHTheme.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text("查看并确认").font(.subheadline.weight(.semibold)).foregroundStyle(DSHTheme.action)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(DSHTheme.amberCard, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(DSHTheme.amberBorder, lineWidth: 1))
        }
        .buttonStyle(PressStyle(scalesOnPress: false))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("需要你确认：\(approval.title)，\(approval.command)")
        .accessibilityHint("查看并确认")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("approval.review")
    }

    @ViewBuilder
    private func statusLine(_ conversation: Conversation) -> some View {
        if conversation.phase == .generating {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small).tint(DSHTheme.blue)
                Text(conversation.currentStep ?? "正在处理…")
                    .font(.footnote).foregroundStyle(DSHTheme.blue)
                    .lineLimit(1).truncationMode(.middle)
                    .accessibilityIdentifier("chat.step")
                Spacer(minLength: 8)
                Button { store.stop(conversationID) } label: {
                    Text("停止").font(.footnote.weight(.medium)).foregroundStyle(DSHTheme.ink)
                        .padding(.horizontal, 12).frame(minHeight: 28)
                        .background(DSHTheme.bubble, in: Capsule())
                }
                .buttonStyle(PressStyle())
                .accessibilityLabel("停止任务")
                .accessibilityIdentifier("chat.stop")
            }
            .padding(.horizontal, 6)
            .accessibilityElement(children: .contain)
        } else if conversation.phase == .awaitingApproval, let approval = conversation.approval {
            HStack(spacing: 8) {
                StatusDot(kind: .needsYou)
                Text("等你确认：\(approval.title)")
                    .font(.footnote).foregroundStyle(DSHTheme.amberText).lineLimit(1)
                Spacer(minLength: 8)
                Button("查看并确认") {
                    composerFocused = false
                    approvalToReview = approval
                }
                .font(.footnote.weight(.semibold)).foregroundStyle(DSHTheme.action)
                .frame(minHeight: 44)
                .accessibilityIdentifier("approval.composerReview")
            }
            .padding(.horizontal, 6)
        }
    }

    private func composer(_ conversation: Conversation) -> some View {
        let canSend = !conversation.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !conversation.isBusy
        let modelBinding = Binding(get: { self.conversation?.model ?? ModelChoice.followComputer }, set: { value in store.update(conversationID) { $0.model = value } })
        let permissionBinding = Binding(get: { self.conversation?.permissionMode ?? .ask }, set: { value in store.update(conversationID) { $0.permissionMode = value } })
        return VStack(alignment: .leading, spacing: 6) {
            statusLine(conversation)
            VStack(alignment: .leading, spacing: 0) {
                TextField(conversation.messages.isEmpty ? "让 Agent 做点什么…" : "追加指令…", text: Binding(
                    get: { self.conversation?.draft ?? "" },
                    set: { value in store.update(conversationID) { $0.draft = value } }
                ), axis: .vertical)
                .font(.body).foregroundStyle(DSHTheme.ink)
                .lineLimit(1...6).focused($composerFocused)
                .padding(.horizontal, 10).padding(.top, 10).padding(.bottom, 4)
                .accessibilityLabel("指令")
                .accessibilityIdentifier("chat.composer")
                HStack(spacing: 0) {
                    AttachMenu()
                    Menu {
                        Picker("模型", selection: modelBinding) {
                            ForEach(ModelChoice.all, id: \.self) { Text($0).tag($0) }
                        }
                    } label: { menuLabel(conversation.model) }
                    .accessibilityLabel("模型：\(conversation.model)")
                    .accessibilityIdentifier("chat.model")
                    Menu {
                        PermissionPicker(selection: permissionBinding)
                    } label: { menuLabel(conversation.permissionMode.title) }
                    .accessibilityLabel("权限模式：\(conversation.permissionMode.title)")
                    .accessibilityIdentifier("chat.permission")
                    Spacer(minLength: 0)
                    DictationButton { composerFocused = true }
                    Button { store.send(in: conversationID) } label: { SendGlyph(enabled: canSend) }
                        .disabled(!canSend)
                        .accessibilityLabel("发送")
                        .accessibilityIdentifier("chat.send")
                }
                .buttonStyle(PressStyle())
            }
            .padding(4)
            .background(DSHTheme.surface, in: RoundedRectangle(cornerRadius: 22))
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(contrast == .increased ? DSHTheme.secondary : DSHTheme.separator, lineWidth: contrast == .increased ? 1.5 : 1)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: DSHTheme.readingWidth)
        .padding(.horizontal, 12).padding(.top, 6).padding(.bottom, 10)
        .frame(maxWidth: .infinity).background(DSHTheme.background)
    }

    private func menuLabel(_ title: String) -> some View {
        HStack(spacing: 3) {
            Text(title).lineLimit(1)
            Image(systemName: "chevron.down").font(.caption2.weight(.semibold)).accessibilityHidden(true)
        }
        .font(.footnote).foregroundStyle(DSHTheme.ink)
        .padding(.horizontal, 6)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}

private struct TranscriptBottomKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct MessageView: View {
    let message: ChatMessage
    let canRetry: Bool
    let retry: () -> Void
    let fork: () -> Void
    @State private var copied = false
    @State private var diffToShow: DiffAttachment?

    var body: some View {
        if message.role == .user {
            HStack {
                Spacer(minLength: 48)
                Text(message.text).font(.body).foregroundStyle(DSHTheme.ink)
                    .lineSpacing(4).textSelection(.enabled)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(DSHTheme.bubble, in: RoundedRectangle(cornerRadius: 20))
                    .accessibilityLabel("你：\(message.text)")
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                if let reasoning = message.reasoning {
                    DisclosureGroup {
                        Text(reasoning).font(.subheadline).lineSpacing(5)
                            .foregroundStyle(DSHTheme.secondary).padding(.vertical, 6)
                            .textSelection(.enabled)
                    } label: {
                        Label("思路", systemImage: "text.alignleft")
                            .font(.subheadline).foregroundStyle(DSHTheme.secondary).frame(minHeight: 44)
                    }
                    .tint(DSHTheme.secondary)
                }
                if !message.activity.isEmpty {
                    ActivitySummary(activity: message.activity, title: ToolActivity.summary(of: message.activity))
                }
                if message.text.isEmpty && message.isStreaming {
                    EmptyView()
                } else {
                    Text(markdown(message.text)).font(.body).foregroundStyle(DSHTheme.ink)
                        .lineSpacing(5).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel("助手：\(message.text)")
                }
                ForEach(message.attachments) { attachment in
                    switch attachment {
                    case .diff(let diff): DiffCard(diff: diff) { diffToShow = diff }
                    case .terminal(let output): TerminalCard(output: output)
                    }
                }
                if !message.isStreaming && !message.text.isEmpty {
                    HStack(spacing: 0) {
                        action(copied ? "已复制" : "复制", symbol: copied ? "checkmark" : "doc.on.doc", id: "message.copy") {
                            copyText(message.text)
                            copied = true
                        }
                        if canRetry {
                            action("重试", symbol: "arrow.clockwise", id: "message.retry", perform: retry)
                        }
                        action("从这里分叉", symbol: "arrow.triangle.branch", id: "message.fork", perform: fork)
                    }
                    .padding(.leading, -12).padding(.top, -6)
                }
            }
            .sheet(item: $diffToShow) { diff in
                DiffDetailView(diff: diff, edits: message.activity.filter { $0.kind == .edit })
            }
        }
    }

    private func action(_ label: String, symbol: String, id: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Image(systemName: symbol)
                .font(.subheadline).foregroundStyle(DSHTheme.secondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }
}

/// One line such as "读了 3 个文件 · 改了 2 个 · 运行 1 条命令" that expands into the steps.
private struct ActivitySummary: View {
    let activity: [ToolActivity]
    let title: String
    @State private var expanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 1)) { expanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                        .accessibilityHidden(true)
                    Text(title).multilineTextAlignment(.leading)
                }
                .font(.subheadline).foregroundStyle(DSHTheme.secondary)
                .frame(minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(expanded ? "已展开" : "已收起")
            .accessibilityIdentifier("message.activity")
            if expanded {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(activity) { item in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Image(systemName: symbol(item))
                                .font(.caption).foregroundStyle(DSHTheme.secondary)
                                .frame(width: 16)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title).font(.footnote).foregroundStyle(DSHTheme.ink)
                                Text(item.detail).font(.caption.monospaced())
                                    .foregroundStyle(DSHTheme.secondary).textSelection(.enabled)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.leading, 4)
            }
        }
    }

    private func symbol(_ item: ToolActivity) -> String {
        if item.state == .declined { return "xmark" }
        switch item.kind {
        case .read: return "doc.text"
        case .edit: return "pencil"
        case .command: return "terminal"
        case .other: return "checkmark"
        }
    }
}

private struct DiffCard: View {
    let diff: DiffAttachment
    let showAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(diff.fileName).font(.footnote.monospaced()).foregroundStyle(DSHTheme.ink)
                Spacer()
                Text("+\(diff.additions)").foregroundStyle(DSHTheme.greenText)
                Text("−\(diff.deletions)").foregroundStyle(DSHTheme.red)
            }
            .font(.caption)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(DSHTheme.diffHeader)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(diff.fileName)，增加 \(diff.additions) 行，删除 \(diff.deletions) 行")
            DiffLines(lines: diff.lines)
            Divider()
            Button(action: showAll) {
                Text(diff.changedFiles > 1 ? "查看全部改动（\(diff.changedFiles) 个文件）" : "查看全部改动")
                    .font(.footnote).foregroundStyle(DSHTheme.action)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .padding(.horizontal, 14)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("diff.showAll")
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(DSHTheme.separator, lineWidth: 1))
    }
}

private struct DiffLines: View {
    let lines: [DiffLine]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(lines) { line in
                Text("\(prefix(line.kind)) \(line.text)")
                    .font(.caption.monospaced())
                    .foregroundStyle(foreground(line.kind))
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14).padding(.vertical, 2)
                    .background(background(line.kind))
                    .accessibilityLabel("\(spoken(line.kind))：\(line.text)")
            }
        }
        .textSelection(.enabled)
    }

    private func prefix(_ kind: DiffLine.Kind) -> String { kind == .added ? "+" : kind == .removed ? "−" : " " }
    private func spoken(_ kind: DiffLine.Kind) -> String { kind == .added ? "新增" : kind == .removed ? "删除" : "未改" }
    private func foreground(_ kind: DiffLine.Kind) -> Color { kind == .added ? DSHTheme.diffAddedText : kind == .removed ? DSHTheme.diffRemovedText : DSHTheme.ink }
    private func background(_ kind: DiffLine.Kind) -> Color { kind == .added ? DSHTheme.diffAdded : kind == .removed ? DSHTheme.diffRemoved : .clear }
}

private struct TerminalCard: View {
    let output: TerminalOutput

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("$ \(output.command)").foregroundStyle(DSHTheme.terminalMuted)
            Text(output.output).foregroundStyle(DSHTheme.terminalText)
            if output.exitCode != 0 {
                Text("退出码 \(output.exitCode)").foregroundStyle(DSHTheme.diffRemovedText)
            }
        }
        .font(.caption.monospaced())
        .lineSpacing(3)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(DSHTheme.terminal, in: RoundedRectangle(cornerRadius: 14))
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("终端输出：\(output.command)，\(output.output)\(output.exitCode == 0 ? "" : "，退出码 \(output.exitCode)")")
    }
}

private struct DiffDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let diff: DiffAttachment
    let edits: [ToolActivity]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DiffLines(lines: diff.lines)
                        .listRowInsets(EdgeInsets())
                } header: {
                    Text("\(diff.fileName) · +\(diff.additions) −\(diff.deletions)").font(.footnote.monospaced())
                } footer: {
                    Text("手机上显示改动摘要；完整差异保存在电脑上的工作区。")
                }
                if !edits.isEmpty {
                    Section("改动的文件") {
                        ForEach(edits) { edit in
                            Text(edit.detail).font(.footnote.monospaced()).textSelection(.enabled)
                        }
                    }
                }
            }
            .navigationTitle("全部改动")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
