import SwiftUI
import DSHCore

struct SessionsView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(AppStore.self) private var store

    var body: some View {
        if horizontalSizeClass == .regular {
            NavigationSplitView {
                ConversationHistoryView(isSheet: false)
            } detail: {
                conversationContent(showHistory: false)
            }
            .navigationSplitViewStyle(.balanced)
        } else {
            NavigationStack {
                conversationContent(showHistory: true)
            }
        }
    }

    @ViewBuilder
    private func conversationContent(showHistory: Bool) -> some View {
        if store.isDemo, let conversation = store.selectedConversation {
            ChatView(conversationID: conversation.id, showsHistoryButton: showHistory)
                .id(conversation.id)
        } else {
            ConversationEntryView(showsHistoryButton: showHistory)
        }
    }
}

struct ConversationHistoryView: View {
    @Environment(AppStore.self) private var store
    @State private var search = ""
    let isSheet: Bool

    private var filtered: [Conversation] {
        store.conversations.filter {
            search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.workspace.localizedCaseInsensitiveContains(search)
        }.sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        List {
            if store.isDemo {
                Section("本地对话") {
                    if filtered.isEmpty {
                        Text(search.isEmpty ? "还没有对话" : "没有找到相关对话")
                            .font(.subheadline).foregroundStyle(DSHTheme.secondary)
                            .listRowSeparator(.hidden)
                    }
                    ForEach(filtered) { conversation in
                        Button { store.selectConversation(conversation.id) } label: {
                            SessionRow(conversation: conversation, isSelected: store.selectedConversationID == conversation.id)
                        }
                        .listRowBackground(store.selectedConversationID == conversation.id ? DSHTheme.surface : DSHTheme.background)
                        .listRowSeparator(.hidden)
                        .accessibilityIdentifier("history.conversation.\(conversation.title)")
                    }
                }
            } else {
                Section {
                    Button(store.hasDemoHistory ? "继续本地演示" : "试用本地对话") { store.enterDemo() }
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("history.demo")
                } footer: {
                    Text(store.hasDemoHistory ? "本次打开的对话和草稿已保留。" : "演示使用预设内容，不执行电脑上的操作。")
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .searchable(text: $search, prompt: "搜索对话或工作区")
        .navigationTitle("历史记录")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isSheet {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { store.presentedPanel = nil }
                }
            }
            if store.isDemo {
                ToolbarItem(placement: .primaryAction) {
                    Button("新对话", systemImage: "square.and.pencil") { store.newConversation() }
                        .tint(DSHTheme.ink)
                        .accessibilityIdentifier("history.new")
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                Divider().padding(.bottom, 8)
                if isSheet {
                    NavigationLink { DevicesView() } label: {
                        historyDestination("电脑", symbol: "desktopcomputer")
                    }.accessibilityIdentifier("history.computers")
                    NavigationLink { SettingsView() } label: {
                        historyDestination("设置", symbol: "gearshape")
                    }.accessibilityIdentifier("history.settings")
                } else {
                    Button { store.presentedPanel = .computers } label: {
                        historyDestination("电脑", symbol: "desktopcomputer")
                    }.accessibilityIdentifier("history.computers")
                    Button { store.presentedPanel = .settings } label: {
                        historyDestination("设置", symbol: "gearshape")
                    }.accessibilityIdentifier("history.settings")
                }
            }
            .buttonStyle(PressStyle(scalesOnPress: false))
            .padding(.horizontal, 20).padding(.bottom, 8)
            .background(DSHTheme.background)
        }
        .tint(DSHTheme.action)
        .background(DSHTheme.background)
    }

    private func historyDestination(_ title: String, symbol: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.body).frame(width: 22)
            Text(title).font(.body)
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(DSHTheme.secondary)
        }
        .foregroundStyle(DSHTheme.ink)
        .frame(minHeight: 48).contentShape(Rectangle())
    }
}

private struct SessionRow: View {
    let conversation: Conversation
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(conversation.title)
                    .font(.body.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(DSHTheme.ink).lineLimit(2)
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark").font(.caption.weight(.semibold))
                        .foregroundStyle(DSHTheme.action).accessibilityHidden(true)
                }
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    context
                    Spacer(minLength: 4)
                    status
                }
                VStack(alignment: .leading, spacing: 5) {
                    context
                    status
                }
            }
            .font(.caption).foregroundStyle(DSHTheme.secondary)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var context: some View {
        Text(conversation.draft.isEmpty ? conversation.workspace : "草稿：\(conversation.draft)")
            .lineLimit(1).truncationMode(.tail)
    }

    @ViewBuilder
    private var status: some View {
        if conversation.phase == .awaitingApproval {
            Label("待确认", systemImage: "hand.raised").fixedSize()
        } else {
            Text(conversation.updatedAt, style: .time).fixedSize()
        }
    }
}

private struct ConversationEntryView: View {
    @Environment(AppStore.self) private var store
    @Environment(ConnectionStore.self) private var connection
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let showsHistoryButton: Bool

    var body: some View {
        GeometryReader { viewport in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    VStack(alignment: .leading, spacing: 28) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("从一个对话开始")
                                .font(.title3.weight(.semibold)).foregroundStyle(DSHTheme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("entry.title")
                            Text("演示使用预设回复；远程对话暂未开放。")
                                .font(.subheadline).foregroundStyle(DSHTheme.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        VStack(spacing: 0) {
                            Button { store.enterDemo() } label: {
                                entryAction(store.hasDemoHistory ? "继续本地演示" : "试用本地对话", symbol: "bubble.left", primary: true)
                            }
                            .accessibilityIdentifier("demo.enter")
                            Divider()
                            Button { store.presentedPanel = .computers } label: {
                                entryAction(connection.isSignedIn ? "查看我的电脑" : "登录并发现电脑", symbol: "desktopcomputer", primary: false)
                            }
                            .accessibilityIdentifier("entry.computers")
                        }
                        .buttonStyle(PressStyle(scalesOnPress: false))
                    }
                    .frame(maxWidth: 340)
                    Spacer(minLength: 0)
                    Color.clear.frame(height: dynamicTypeSize.isAccessibilitySize ? 0 : 100)
                }
                .padding(.horizontal, 30).padding(.vertical, 24)
                .frame(maxWidth: .infinity)
                .frame(minHeight: viewport.size.height)
            }
        }
        .background(DSHTheme.background)
        .navigationTitle("DSH")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsHistoryButton {
                ToolbarItem(placement: .topBarLeading) {
                    Button("历史记录", systemImage: "line.3.horizontal") { store.presentedPanel = .history }
                        .tint(DSHTheme.ink)
                        .accessibilityIdentifier("conversation.history")
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
        }
    }

    private func entryAction(_ title: String, symbol: String, primary: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 20)).frame(width: 24)
                .accessibilityHidden(true)
            Text(title).fontWeight(primary ? .medium : .regular)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .accessibilityHidden(true)
        }
        .font(.body).foregroundStyle(primary ? DSHTheme.action : DSHTheme.ink)
        .padding(.vertical, 16).frame(minHeight: 56)
        .contentShape(Rectangle())
    }
}

struct DemoInfoView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        Form {
            Section {
                Text("回复来自本机预设内容。审批只记录你的选择，不会调用模型或执行命令。")
                Text("对话和草稿在本次打开期间保留，包括退出演示或登录账号后；关闭 App 后不保存。")
            }
            Section {
                Button("查看电脑") { store.presentedPanel = .computers }
                Button("退出演示，保留草稿") { store.leaveDemo() }
                    .accessibilityIdentifier("demo.leave")
            }
        }
        .tint(DSHTheme.action)
        .navigationTitle("本地演示")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("完成") { store.presentedPanel = nil }
            }
        }
    }
}
