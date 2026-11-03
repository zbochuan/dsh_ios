import SwiftUI
import DSHCore

/// iPhone: a task stack with a left drawer. iPad: the drawer is the split-view sidebar.
struct RootLayout: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(AppStore.self) private var store

    var body: some View {
        if horizontalSizeClass == .regular {
            NavigationSplitView {
                DrawerView(isSidebar: true)
                    .navigationSplitViewColumnWidth(min: 280, ideal: 314)
            } detail: {
                NavigationStack {
                    if let id = store.selectedConversationID {
                        ChatView(conversationID: id).id(id)
                    } else {
                        HomeView(showsMenuButton: false)
                    }
                }
            }
            .navigationSplitViewStyle(.balanced)
        } else {
            PhoneShell()
        }
    }
}

private struct PhoneShell: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let selection = Binding<UUID?>(
            get: { store.selectedConversationID },
            set: { store.selectConversation($0) }
        )
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                NavigationStack {
                    HomeView(showsMenuButton: true)
                        .navigationDestination(item: selection) { id in
                            ChatView(conversationID: id).id(id)
                        }
                }
                .accessibilityHidden(store.isDrawerOpen)
                .overlay(alignment: .leading) {
                    // Edge swipe opens the drawer from the home screen; task pages keep the back swipe.
                    if store.selectedConversationID == nil && !store.isDrawerOpen {
                        Color.clear.frame(width: 18).contentShape(Rectangle())
                            .gesture(DragGesture(minimumDistance: 16).onEnded { value in
                                if value.translation.width > 50 { store.isDrawerOpen = true }
                            })
                            .accessibilityHidden(true)
                    }
                }

                if store.isDrawerOpen {
                    Color.black.opacity(0.32)
                        .ignoresSafeArea()
                        .onTapGesture { store.isDrawerOpen = false }
                        .accessibilityHidden(true)
                        .transition(.opacity)
                    DrawerView(isSidebar: false)
                        .frame(width: min(314, geometry.size.width * 0.84))
                        .background(DSHTheme.surface.ignoresSafeArea())
                        .gesture(DragGesture(minimumDistance: 16).onEnded { value in
                            if value.translation.width < -50 { store.isDrawerOpen = false }
                        })
                        .accessibilityAction(.escape) { store.isDrawerOpen = false }
                        .transition(reduceMotion ? .opacity : .move(edge: .leading))
                }
            }
            .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 1), value: store.isDrawerOpen)
        }
    }
}

struct HomeView: View {
    @Environment(AppStore.self) private var store
    @Environment(ConnectionStore.self) private var connection
    let showsMenuButton: Bool

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if store.isDemo {
                        board(store.board(), now: context.date)
                    } else {
                        onboarding(now: context.date)
                    }
                }
                .frame(maxWidth: DSHTheme.readingWidth, alignment: .leading)
                .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 24)
                .frame(maxWidth: .infinity)
            }
        }
        .background(DSHTheme.background)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if store.isDemo { HomeComposer() }
        }
        .navigationTitle("任务")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsMenuButton {
                ToolbarItem(placement: .topBarLeading) {
                    Button("打开侧边栏", systemImage: "line.3.horizontal") { store.isDrawerOpen = true }
                        .tint(DSHTheme.ink)
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityIdentifier("home.menu")
                }
            }
            if store.isDemo {
                ToolbarItem(placement: .primaryAction) {
                    Button("新任务", systemImage: "square.and.pencil") { store.newConversation() }
                        .tint(DSHTheme.ink)
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityIdentifier("home.new")
                }
            }
        }
    }

    @ViewBuilder
    private func board(_ board: TaskBoard, now: Date) -> some View {
        if !board.pending.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    StatusDot(kind: .needsYou)
                    Text("等你确认 · \(board.pending.count)")
                }
                .font(.footnote.weight(.semibold)).foregroundStyle(DSHTheme.amberText)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("home.pendingHeader")
                ForEach(board.pending) { task in PendingCard(task: task, now: now) }
            }
        }
        ForEach(board.sections) { section in
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    HStack(spacing: 6) {
                        StatusDot(kind: section.computer.isOnline ? .online : .offline)
                        Text("\(section.computer.name) · \(section.computer.isOnline ? "在线" : "离线")")
                    }
                    .font(.footnote.weight(.semibold)).foregroundStyle(DSHTheme.secondary)
                    Spacer()
                    if !section.tasks.isEmpty {
                        Text("\(section.tasks.count) 个任务").font(.caption).foregroundStyle(DSHTheme.secondary)
                    }
                }
                .padding(.bottom, 4)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
                if !section.computer.isOnline {
                    Text("电脑唤醒后会自动重连，任务不会丢失。")
                        .font(.footnote).foregroundStyle(DSHTheme.secondary)
                        .padding(.vertical, 8)
                }
                ForEach(section.tasks) { task in
                    Button { store.selectConversation(task.id) } label: { TaskRow(task: task, now: now) }
                        .buttonStyle(PressStyle(scalesOnPress: false))
                        .accessibilityIdentifier("task.row.\(task.title)")
                    if task.id != section.tasks.last?.id { Divider() }
                }
            }
        }
        if !connection.isSignedIn {
            Button { store.presentedPanel = .pairing } label: {
                Label("连接你的电脑", systemImage: "desktopcomputer")
                    .font(.subheadline).foregroundStyle(DSHTheme.action)
                    .frame(minHeight: 44)
            }
            .accessibilityIdentifier("home.connect")
        }
    }

    @ViewBuilder
    private func onboarding(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("在手机上看着电脑里的 Agent 干活")
                .font(.title3.weight(.semibold)).foregroundStyle(DSHTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("home.title")
            Text("连接后，这里会列出每台电脑上的任务；需要你确认的操作会排在最上面。")
                .font(.subheadline).foregroundStyle(DSHTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 12)

        Button { store.presentedPanel = .pairing } label: {
            HStack(spacing: 12) {
                Image(systemName: "qrcode.viewfinder").font(.title3).frame(width: 28).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("连接电脑").font(.body.weight(.semibold))
                    Text("代码、文件和模型密钥留在电脑上").font(.footnote).foregroundStyle(DSHTheme.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(DSHTheme.secondary).accessibilityHidden(true)
            }
            .foregroundStyle(DSHTheme.ink)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DSHTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(PressStyle(scalesOnPress: false))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.connect")

        if connection.isSignedIn {
            signedInComputers
        }

        if let example = DemoContent.conversations(now: now).first(where: { $0.title == DemoContent.exampleTitle }) {
            VStack(alignment: .leading, spacing: 4) {
                Text("示例").font(.footnote.weight(.semibold)).foregroundStyle(DSHTheme.secondary)
                    .accessibilityAddTraits(.isHeader)
                Button { store.enterDemo(showing: example.title) } label: { TaskRow(task: example, now: now) }
                    .buttonStyle(PressStyle(scalesOnPress: false))
                    .accessibilityIdentifier("home.example")
            }
        }
    }

    @ViewBuilder
    private var signedInComputers: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(connection.devices) { device in
                HStack(spacing: 6) {
                    StatusDot(kind: device.online ? .online : .offline)
                    Text("\(device.name) · \(device.online ? "在线" : "离线")")
                }
                .font(.footnote.weight(.semibold)).foregroundStyle(DSHTheme.secondary)
                .accessibilityElement(children: .combine)
            }
            Text(connection.devices.isEmpty ? "还没有发现电脑。在电脑上启用 ds-harness-remote，并登录同一个账号。" : "电脑上的任务会在安全会话接入后列在这里。")
                .font(.footnote).foregroundStyle(DSHTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct PendingCard: View {
    @Environment(AppStore.self) private var store
    let task: Conversation
    let now: Date

    var body: some View {
        if let approval = task.approval {
            Button { store.reviewApproval(in: task.id) } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(task.title).font(.body.weight(.semibold)).foregroundStyle(DSHTheme.ink)
                        Spacer(minLength: 8)
                        Text(TaskTime.ago(approval.requestedAt, now: now)).font(.caption).foregroundStyle(DSHTheme.secondary)
                    }
                    Text(approval.command)
                        .font(.footnote.monospaced()).foregroundStyle(DSHTheme.ink)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(DSHTheme.background, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(DSHTheme.amberBorder, lineWidth: 0.5))
                    ViewThatFits(in: .horizontal) {
                        HStack {
                            Text(TaskText.context(task)).font(.caption).foregroundStyle(DSHTheme.secondary)
                            Spacer()
                            Text("查看并确认").font(.subheadline.weight(.semibold)).foregroundStyle(DSHTheme.action)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text(TaskText.context(task)).font(.caption).foregroundStyle(DSHTheme.secondary)
                            Text("查看并确认").font(.subheadline.weight(.semibold)).foregroundStyle(DSHTheme.action)
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(DSHTheme.amberCard, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(DSHTheme.amberBorder, lineWidth: 1))
            }
            .buttonStyle(PressStyle(scalesOnPress: false))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("等你确认：\(task.title)，\(approval.command)，\(TaskText.context(task))")
            .accessibilityHint("查看并确认")
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("home.pending.\(task.title)")
        }
    }
}

private struct HomeComposer: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorSchemeContrast) private var contrast
    @FocusState private var focused: Bool

    var body: some View {
        @Bindable var store = store
        let canSend = !store.homeDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Menu {
                        Picker("电脑", selection: $store.newTaskComputer) {
                            ForEach(store.onlineComputers) { Text($0.name).tag($0.name) }
                        }
                    } label: { chip(store.newTaskComputer) }
                    .accessibilityLabel("电脑：\(store.newTaskComputer)")
                    .accessibilityIdentifier("home.chip.computer")
                    Menu {
                        Picker("项目", selection: $store.newTaskProject) {
                            ForEach(store.projects(on: store.newTaskComputer), id: \.self) { Text($0).tag($0) }
                        }
                    } label: { chip(store.newTaskProject) }
                    .accessibilityLabel("项目：\(store.newTaskProject)")
                    .accessibilityIdentifier("home.chip.project")
                    Menu {
                        PermissionPicker(selection: $store.newTaskPermission)
                    } label: { chip(store.newTaskPermission.title) }
                    .accessibilityLabel("权限模式：\(store.newTaskPermission.title)")
                    .accessibilityIdentifier("home.chip.permission")
                }
                .padding(.horizontal, 4)
            }
            .onChange(of: store.newTaskComputer) { _, computer in
                if let first = store.projects(on: computer).first { store.newTaskProject = first }
            }

            HStack(alignment: .bottom, spacing: 4) {
                AttachMenu()
                TextField("让 Agent 做点什么…", text: $store.homeDraft, axis: .vertical)
                    .font(.body).foregroundStyle(DSHTheme.ink)
                    .lineLimit(1...4).focused($focused)
                    .padding(.vertical, 12)
                    .accessibilityLabel("新任务")
                    .accessibilityIdentifier("home.composer")
                if canSend {
                    Button { focused = false; store.startTask() } label: { SendGlyph(enabled: true) }
                        .accessibilityLabel("开始任务").accessibilityIdentifier("home.send")
                } else {
                    DictationButton { focused = true }
                }
            }
            .buttonStyle(PressStyle())
            .padding(4)
            .background(DSHTheme.surface, in: RoundedRectangle(cornerRadius: 26))
            .overlay {
                RoundedRectangle(cornerRadius: 26)
                    .strokeBorder(contrast == .increased ? DSHTheme.secondary : DSHTheme.separator, lineWidth: contrast == .increased ? 1.5 : 1)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: DSHTheme.readingWidth)
        .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 10)
        .frame(maxWidth: .infinity)
        .background(DSHTheme.background)
    }

    private func chip(_ title: String) -> some View {
        Text(title)
            .font(.caption).foregroundStyle(DSHTheme.ink)
            .padding(.horizontal, 10)
            .frame(minHeight: 28)
            .background(DSHTheme.bubble, in: Capsule())
            .frame(minHeight: 44)
            .contentShape(Rectangle())
    }
}

struct PermissionPicker: View {
    @Binding var selection: PermissionMode

    var body: some View {
        Picker("权限模式", selection: $selection) {
            ForEach(PermissionMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
    }
}

struct AttachMenu: View {
    var body: some View {
        // TODO: Attach photos and files once the Host session can receive them.
        Menu {
            Button("照片", systemImage: "photo") {}.disabled(true)
            Button("文件", systemImage: "doc") {}.disabled(true)
        } label: {
            Image(systemName: "plus").font(.system(size: 18, weight: .medium))
                .foregroundStyle(DSHTheme.ink)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel("添加照片或文件")
        .accessibilityIdentifier("composer.attach")
    }
}

struct DictationButton: View {
    let focus: () -> Void

    var body: some View {
        // TODO: Start speech recognition directly; for now this focuses the field so the keyboard's dictation key is one tap away.
        Button(action: focus) {
            Image(systemName: "mic").font(.system(size: 18, weight: .medium))
                .foregroundStyle(DSHTheme.ink)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel("听写")
        .accessibilityHint("聚焦输入框，可使用键盘上的听写")
        .accessibilityIdentifier("composer.dictation")
    }
}

struct SendGlyph: View {
    let enabled: Bool

    var body: some View {
        Image(systemName: "arrow.up").font(.system(size: 17, weight: .semibold))
            .foregroundStyle(enabled ? DSHTheme.background : DSHTheme.secondary)
            .frame(width: 34, height: 34)
            .background(enabled ? DSHTheme.ink : DSHTheme.bubble, in: Circle())
            .frame(width: 44, height: 44)
    }
}
