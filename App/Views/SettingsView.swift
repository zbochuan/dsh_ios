import SwiftUI
import DSHCore

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(ConnectionStore.self) private var connection
    @AppStorage("appearance") private var appearance = "system"
    // TODO: Deliver these through push notifications and a Live Activity once the computer can send events.
    @AppStorage("notify.approval") private var notifyApproval = true
    @AppStorage("notify.finished") private var notifyFinished = true
    @AppStorage("notify.liveActivity") private var liveActivity = false
    @AppStorage("defaults.permissionMode") private var defaultPermission = PermissionMode.ask.rawValue
    @AppStorage("defaults.model") private var defaultModel = ModelChoice.followComputer

    var body: some View {
        Form {
            Section("电脑") {
                if store.isDemo {
                    ForEach(store.computers, id: \.name) { computer in
                        computerRow(computer.name, online: computer.isOnline, detail: "示例")
                    }
                }
                ForEach(connection.devices) { device in
                    computerRow(device.name, online: device.online, detail: device.platform)
                }
                if connection.isSignedIn || !connection.devices.isEmpty {
                    NavigationLink("查看全部电脑") { DevicesView() }
                }
                Button {
                    store.presentedPanel = .pairing
                } label: {
                    Label("连接新电脑", systemImage: "plus")
                }
                .accessibilityIdentifier("settings.pair")
            }
            Section {
                Toggle("需要我确认时", isOn: $notifyApproval)
                    .accessibilityIdentifier("settings.notify.approval")
                Toggle("任务完成或失败", isOn: $notifyFinished)
                    .accessibilityIdentifier("settings.notify.finished")
                Toggle("锁屏实时活动", isOn: $liveActivity)
                    .accessibilityIdentifier("settings.notify.liveActivity")
            } header: { Text("通知") } footer: {
                Text("连接电脑后，按这些选项提醒你。")
            }
            Section {
                Picker("权限模式", selection: Binding(
                    get: { PermissionMode(rawValue: defaultPermission) ?? .ask },
                    set: { defaultPermission = $0.rawValue; store.newTaskPermission = $0 }
                )) {
                    ForEach(PermissionMode.allCases) { mode in Text(mode.title).tag(mode) }
                }
                .accessibilityIdentifier("settings.permission")
                Picker("模型", selection: $defaultModel) {
                    ForEach(ModelChoice.all, id: \.self) { Text($0).tag($0) }
                }
                .accessibilityIdentifier("settings.model")
            } header: { Text("新任务默认") } footer: {
                Text("手机上不提供“跳过所有确认”。")
            }
            Section("通用") {
                Picker("外观", selection: $appearance) {
                    Text("跟随系统").tag("system")
                    Text("浅色").tag("light")
                    Text("深色").tag("dark")
                }
                NavigationLink {
                    AccountView()
                } label: {
                    LabeledContent("账号", value: connection.isSignedIn ? (connection.accountName.isEmpty ? "已登录" : connection.accountName) : "未登录")
                }
                .accessibilityIdentifier("settings.account")
                NavigationLink("关于") { AboutView() }
            }
        }
        .scrollContentBackground(.hidden)
        .background(DSHTheme.surface)
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .task { await connection.restore() }
    }

    private func computerRow(_ name: String, online: Bool, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "desktopcomputer").foregroundStyle(DSHTheme.secondary).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                Text(detail).font(.caption).foregroundStyle(DSHTheme.secondary)
            }
            Spacer()
            StatusDot(kind: online ? .online : .offline)
            Text(online ? "在线" : "离线").font(.subheadline).foregroundStyle(DSHTheme.secondary)
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }
}

private struct AccountView: View {
    @Environment(ConnectionStore.self) private var connection
    @State private var confirmingSignOut = false
    @State private var showingLogin = false

    var body: some View {
        Form {
            Section("Remote 账号") {
                if connection.isSignedIn {
                    if !connection.accountName.isEmpty { LabeledContent("账号", value: connection.accountName) }
                    LabeledContent("服务", value: connection.committedServerAddress)
                } else {
                    Button("登录 Remote") { showingLogin = true }
                        .disabled(connection.isBusy)
                        .accessibilityIdentifier("settings.login")
                }
                if connection.canSignOut {
                    Button("退出登录", role: .destructive) { confirmingSignOut = true }
                }
            }
            ConnectionRecoverySection()
        }
        .scrollContentBackground(.hidden)
        .background(DSHTheme.surface)
        .navigationTitle("账号")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingLogin) { ConnectionView() }
        .confirmationDialog("退出 Remote 账号？", isPresented: $confirmingSignOut, titleVisibility: .visible) {
            Button("退出登录", role: .destructive) { Task { await connection.signOut() } }
        } message: {
            Text("这会删除本机登录凭据并保留设备身份；不会撤销服务端凭据。任务与草稿不受影响。")
        }
    }
}

private struct AboutView: View {
    var body: some View {
        Form {
            Section {
                LabeledContent("版本", value: "0.1.0 · 开发预览")
                Text("为 DeepSeek Harness 设计的独立客户端，不隶属于 DeepSeek。")
                    .font(.subheadline).foregroundStyle(DSHTheme.secondary)
                Text("代码、文件和模型凭据留在电脑。Remote 设备凭据保存在本机钥匙串。")
                    .font(.subheadline).foregroundStyle(DSHTheme.secondary)
                Link("项目源码与进展", destination: URL(string: "https://github.com/zbochuan/dsh_ios")!)
            }
        }
        .scrollContentBackground(.hidden)
        .background(DSHTheme.surface)
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
    }
}
