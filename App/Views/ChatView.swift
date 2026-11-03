import SwiftUI
import DSHCore

struct ChatView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let conversationID: UUID
    var showsHistoryButton = true
    @State private var approvalToReview: ToolApproval?
    @State private var followingLatest = true
    @State private var returningToLatest = false
    @FocusState private var composerFocused: Bool

    private var conversation: Conversation? { store.conversations.first { $0.id == conversationID } }

    var body: some View {
        if let conversation {
            transcript(conversation)
                .background(DSHTheme.background)
                .navigationTitle(conversation.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if showsHistoryButton {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("历史记录", systemImage: "line.3.horizontal") {
                                composerFocused = false
                                store.presentedPanel = .history
                            }
                            .tint(DSHTheme.ink)
                            .accessibilityIdentifier("conversation.history")
                            .frame(minWidth: 44, minHeight: 44)
                        }
                    }
                    ToolbarItem(placement: .principal) {
                        Button {
                            composerFocused = false
                            store.presentedPanel = .demoInfo
                        } label: {
                            VStack(spacing: 3) {
                                Text(conversation.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(DSHTheme.ink).lineLimit(1)
                                Text("本地演示")
                                    .font(.caption).foregroundStyle(DSHTheme.secondary)
                            }
                            .frame(minHeight: 44)
                        }
                        .accessibilityLabel("\(conversation.title)，本地演示，查看说明")
                        .accessibilityIdentifier("demo.info")
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button("新对话", systemImage: "square.and.pencil") {
                            composerFocused = false
                            store.newConversation()
                        }
                        .tint(DSHTheme.ink)
                        .accessibilityIdentifier("conversation.new")
                        .frame(minWidth: 44, minHeight: 44)
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) { composer(conversation) }
                .sheet(item: $approvalToReview) { approval in
                    ApprovalView(conversationID: conversationID, approval: approval)
                }
        } else {
            ContentUnavailableView("找不到这个对话", systemImage: "bubble.left", description: Text("请从历史记录选择另一个对话。"))
        }
    }

    private func transcript(_ conversation: Conversation) -> some View {
        GeometryReader { viewport in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 28) {
                        if conversation.messages.isEmpty {
                            VStack(spacing: 16) {
                                Text("有什么想聊的？")
                                    .font(.title3.weight(.semibold)).foregroundStyle(DSHTheme.ink)
                                if conversation.draft.isEmpty {
                                    Button {
                                        guard self.conversation?.draft.isEmpty == true else { return }
                                        store.update(conversationID) { $0.draft = "从哪里开始读一个项目？" }
                                        composerFocused = true
                                    } label: {
                                        HStack(spacing: 8) {
                                            Text("从哪里开始读一个项目")
                                            Image(systemName: "arrow.up.left").font(.caption)
                                        }
                                        .font(.subheadline).foregroundStyle(DSHTheme.secondary)
                                        .padding(.horizontal, 14).frame(minHeight: 44)
                                        .background(DSHTheme.surface, in: Capsule())
                                    }
                                    .buttonStyle(PressStyle())
                                    .accessibilityHint("填入消息，编辑后发送")
                                    .accessibilityIdentifier("chat.example")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: max(180, viewport.size.height * 0.68))
                        }
                        ForEach(conversation.messages) { message in MessageView(message: message) }
                        if !conversation.activity.isEmpty {
                            DisclosureGroup {
                                VStack(alignment: .leading, spacing: 16) {
                                    ForEach(conversation.activity) { activity in
                                        HStack(alignment: .top, spacing: 10) {
                                            Image(systemName: activity.state == .completed ? "checkmark" : "xmark")
                                                .font(.caption).foregroundStyle(DSHTheme.secondary)
                                            VStack(alignment: .leading, spacing: 5) {
                                                Text(activity.title).font(.subheadline)
                                                Text(activity.detail).font(.caption.monospaced())
                                                    .foregroundStyle(DSHTheme.secondary).textSelection(.enabled)
                                            }
                                        }
                                    }
                                }.padding(.top, 12)
                            } label: {
                                Label("\(conversation.activity.count) 项活动", systemImage: "checklist")
                                    .font(.subheadline).foregroundStyle(DSHTheme.secondary)
                                    .frame(minHeight: 44)
                            }
                            .tint(DSHTheme.secondary)
                        }
                        if let approval = conversation.approval {
                            Button {
                                composerFocused = false
                                approvalToReview = approval
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "hand.raised")
                                        .font(.body).foregroundStyle(DSHTheme.secondary).padding(.top, 2)
                                    VStack(alignment: .leading, spacing: 7) {
                                        Text("等待确认").font(.subheadline.weight(.semibold))
                                        Text(approval.command).font(.subheadline.monospaced())
                                            .fixedSize(horizontal: false, vertical: true)
                                        Text("\(approval.computer) · \(approval.workspace)")
                                            .font(.caption).foregroundStyle(DSHTheme.secondary)
                                            .lineLimit(2).truncationMode(.middle)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.medium)).foregroundStyle(DSHTheme.secondary)
                                        .padding(.top, 4)
                                }
                                .foregroundStyle(DSHTheme.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(DSHTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(DSHTheme.separator, lineWidth: 0.5))
                            }
                            .buttonStyle(PressStyle(scalesOnPress: false)).accessibilityIdentifier("approval.review")
                        }
                        if conversation.phase == .interrupted {
                            Label("已暂停，可继续发送消息", systemImage: "pause.circle")
                                .font(.caption).foregroundStyle(DSHTheme.secondary)
                                .accessibilityIdentifier("chat.interrupted")
                        }
                        Color.clear.frame(height: 1).id("latest")
                            .background(GeometryReader { geometry in
                                Color.clear.preference(key: TranscriptBottomKey.self, value: geometry.frame(in: .named("transcript")).maxY)
                            })
                    }
                    .frame(maxWidth: DSHTheme.readingWidth)
                    .padding(.horizontal, 22).padding(.top, 24).padding(.bottom, 12)
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

    private func composer(_ conversation: Conversation) -> some View {
        let canSend = !conversation.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && conversation.phase != .awaitingApproval
        return VStack(spacing: 4) {
            if conversation.phase == .awaitingApproval {
                Button("先查看待确认操作") {
                    composerFocused = false
                    approvalToReview = conversation.approval
                }
                .font(.subheadline).foregroundStyle(DSHTheme.action).frame(minHeight: 44)
                .accessibilityIdentifier("approval.composerReview")
            }
            HStack(alignment: .bottom, spacing: 8) {
                TextField("发消息…", text: Binding(
                    get: { self.conversation?.draft ?? "" },
                    set: { value in store.update(conversationID) { $0.draft = value } }
                ), axis: .vertical)
                .font(.body).foregroundStyle(DSHTheme.ink)
                .lineLimit(1...6).focused($composerFocused)
                .padding(.vertical, 12).padding(.leading, 12)
                .accessibilityLabel("消息")
                .accessibilityIdentifier("chat.composer")
                if conversation.phase == .generating {
                    Button { store.stop(conversationID) } label: {
                        Image(systemName: "stop.fill").font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(DSHTheme.background)
                            .frame(width: 36, height: 36).background(DSHTheme.ink, in: Circle())
                            .frame(width: 44, height: 44)
                    }.accessibilityLabel("停止生成").accessibilityIdentifier("chat.stop")
                } else {
                    Button { store.send(in: conversationID) } label: {
                        Image(systemName: "arrow.up").font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(canSend ? Color.white : DSHTheme.secondary)
                            .frame(width: 36, height: 36)
                            .background(canSend ? DSHTheme.blue : DSHTheme.bubble, in: Circle())
                            .frame(width: 44, height: 44)
                    }
                    .disabled(!canSend)
                    .accessibilityLabel("发送消息").accessibilityIdentifier("chat.send")
                }
            }
            .buttonStyle(PressStyle())
            .padding(6)
            .background(DSHTheme.surface, in: RoundedRectangle(cornerRadius: 28))
            .overlay {
                RoundedRectangle(cornerRadius: 28)
                    .strokeBorder(contrast == .increased ? DSHTheme.secondary : DSHTheme.separator, lineWidth: contrast == .increased ? 1.5 : 0.5)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: DSHTheme.readingWidth)
        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 10)
        .frame(maxWidth: .infinity).background(DSHTheme.background)
    }
}

private struct TranscriptBottomKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct MessageView: View {
    let message: ChatMessage
    @State private var copied = false

    var body: some View {
        if message.role == .user {
            HStack {
                Spacer(minLength: 38)
                Text(message.text).font(.body).foregroundStyle(DSHTheme.ink)
                    .lineSpacing(5).textSelection(.enabled)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(DSHTheme.bubble, in: RoundedRectangle(cornerRadius: 20))
                    .accessibilityLabel("你：\(message.text)")
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                if let reasoning = message.reasoning {
                    DisclosureGroup {
                        Text(reasoning).font(.subheadline).lineSpacing(5)
                            .foregroundStyle(DSHTheme.secondary).padding(.vertical, 8)
                            .textSelection(.enabled)
                    } label: {
                        Label("思路", systemImage: "text.alignleft")
                            .font(.subheadline).foregroundStyle(DSHTheme.secondary).frame(minHeight: 44)
                    }
                    .tint(DSHTheme.secondary)
                }
                if message.text.isEmpty && message.isStreaming {
                    ProgressView().controlSize(.small).frame(minHeight: 28)
                        .accessibilityLabel("正在生成演示回复")
                } else {
                    Text(message.text).font(.body).foregroundStyle(DSHTheme.ink)
                        .lineSpacing(6).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel("助手：\(message.text)")
                }
                if !message.isStreaming && !message.text.isEmpty {
                    Button {
                        copyText(message.text)
                        copied = true
                    } label: {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.subheadline).foregroundStyle(DSHTheme.secondary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressStyle())
                    .padding(.leading, -12)
                    .accessibilityLabel(copied ? "已复制" : "复制回复")
                }
            }
        }
    }
}
