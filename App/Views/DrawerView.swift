import SwiftUI
import DSHCore

/// The task index: a left drawer on iPhone and the sidebar on iPad.
struct DrawerView: View {
    @Environment(AppStore.self) private var store
    @Environment(ConnectionStore.self) private var connection
    let isSidebar: Bool
    @State private var search = ""
    @State private var renaming: Conversation?
    @State private var renameText = ""
    @State private var deleting: Conversation?

    private var computerCount: Int { store.isDemo ? store.computers.count : connection.devices.count }

    var body: some View {
        let board = store.board(search: search)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(DSHTheme.secondary).accessibilityHidden(true)
                TextField("搜索任务", text: $search)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("drawer.search")
            }
            .font(.body)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(DSHTheme.bubble, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16).padding(.top, isSidebar ? 8 : 16).padding(.bottom, 8)

            Button { store.selectConversation(nil) } label: {
                Label("全部任务", systemImage: "list.bullet")
                    .font(.body.weight(.semibold)).foregroundStyle(DSHTheme.ink)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .padding(.horizontal, 20)
                    .background(isSidebar && store.selectedConversationID == nil ? DSHTheme.bubble : .clear)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle(scalesOnPress: false))
            .accessibilityAddTraits(store.selectedConversationID == nil ? .isSelected : [])
            .accessibilityIdentifier("drawer.all")

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if store.isDemo {
                        ForEach(board.projects) { group in
                            VStack(alignment: .leading, spacing: 0) {
                                Text(group.id)
                                    .font(.caption.weight(.semibold)).foregroundStyle(DSHTheme.secondary)
                                    .padding(.horizontal, 20).padding(.bottom, 4)
                                    .accessibilityAddTraits(.isHeader)
                                ForEach(group.tasks) { task in row(task) }
                            }
                        }
                        if board.projects.isEmpty {
                            Text(search.isEmpty ? "还没有任务" : "没有找到相关任务")
                                .font(.subheadline).foregroundStyle(DSHTheme.secondary)
                                .padding(.horizontal, 20)
                        } else {
                            Text("长按任务：重命名、归档、删除")
                                .font(.caption).foregroundStyle(DSHTheme.secondary)
                                .padding(.horizontal, 20)
                        }
                    } else {
                        Text("连接电脑后，任务会按电脑和项目列在这里。")
                            .font(.subheadline).foregroundStyle(DSHTheme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 20)
                    }
                }
                .padding(.top, 10).padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.immediately)

            Divider()
            VStack(alignment: .leading, spacing: 0) {
                Button { store.isDrawerOpen = false; store.presentedPanel = .computers } label: {
                    footerRow { Image(systemName: "desktopcomputer").font(.body).frame(width: 28) } text: { Text("电脑 · \(computerCount) 台") }
                }
                .accessibilityIdentifier("drawer.computers")
                Button { store.isDrawerOpen = false; store.presentedPanel = .settings } label: {
                    footerRow {
                        Text(String(connection.accountName.first ?? "我"))
                            .font(.footnote.weight(.semibold)).foregroundStyle(DSHTheme.background)
                            .frame(width: 28, height: 28).background(DSHTheme.ink, in: Circle())
                    } text: { Text(connection.accountName.isEmpty ? "设置" : connection.accountName) }
                }
                .accessibilityLabel(connection.accountName.isEmpty ? "设置" : "\(connection.accountName)，账号与设置")
                .accessibilityIdentifier("drawer.settings")
            }
            .buttonStyle(PressStyle(scalesOnPress: false))
            .padding(.horizontal, 20).padding(.vertical, 8)
        }
        .background(DSHTheme.surface)
        .toolbar(isSidebar ? .automatic : .hidden, for: .navigationBar)
        .navigationTitle("任务")
        .alert("重命名任务", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("任务名称", text: $renameText)
                .accessibilityIdentifier("drawer.renameField")
            Button("保存") {
                if let renaming { store.rename(renaming.id, to: renameText) }
                renaming = nil
            }
            Button("取消", role: .cancel) { renaming = nil }
        }
        .confirmationDialog("删除这个任务？", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible, presenting: deleting) { task in
            Button("删除", role: .destructive) { store.delete(task.id) }
        } message: { _ in
            Text("会从手机上移除这个任务和它的草稿。")
        }
    }

    private func row(_ task: Conversation) -> some View {
        let selected = store.selectedConversationID == task.id
        return Button { store.selectConversation(task.id) } label: {
            HStack(spacing: 10) {
                Text(task.title)
                    .font(.subheadline.weight(selected ? .semibold : .regular))
                    .foregroundStyle(DSHTheme.ink)
                    .lineLimit(1)
                Spacer(minLength: 4)
                switch task.status {
                case .running: StatusDot(kind: .running)
                case .needsYou: StatusDot(kind: .needsYou)
                default: EmptyView()
                }
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(selected ? DSHTheme.bubble : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(scalesOnPress: false))
        .contextMenu {
            Button("重命名", systemImage: "pencil") { renameText = task.title; renaming = task }
            Button("归档", systemImage: "archivebox") { store.archive(task.id) }
            Button("删除", systemImage: "trash", role: .destructive) { deleting = task }
        }
        .accessibilityLabel(rowLabel(task))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("drawer.task.\(task.title)")
    }

    private func rowLabel(_ task: Conversation) -> String {
        switch task.status {
        case .running: "\(task.title)，运行中"
        case .needsYou: "\(task.title)，等你确认"
        default: task.title
        }
    }

    private func footerRow<Icon: View, Title: View>(@ViewBuilder icon: () -> Icon, @ViewBuilder text: () -> Title) -> some View {
        HStack(spacing: 12) {
            icon().accessibilityHidden(true)
            text().font(.subheadline)
            Spacer()
        }
        .foregroundStyle(DSHTheme.ink)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
    }
}
