import SwiftUI

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(ConnectionStore.self) private var connection
    @AppStorage("appearance") private var appearance = "system"
    @State private var confirmingSignOut = false
    @State private var showingLogin = false

    var body: some View {
        Form {
            Section("外观") {
                Picker("显示模式", selection: $appearance) {
                    Text("跟随系统").tag("system")
                    Text("浅色").tag("light")
                    Text("深色").tag("dark")
                }
            }
            Section("Remote 账号") {
                if connection.isSignedIn {
                    if !connection.accountName.isEmpty { LabeledContent("账号", value: connection.accountName) }
                    LabeledContent("服务", value: connection.committedServerAddress)
                    NavigationLink("查看电脑") { DevicesView() }
                } else {
                    Button("登录 Remote") { showingLogin = true }.disabled(connection.isBusy)
                }
                if connection.canSignOut {
                    Button("退出登录", role: .destructive) { confirmingSignOut = true }
                }
            }
            ConnectionRecoverySection()
            Section {
                if store.isDemo {
                    Button("退出演示，保留草稿") { store.leaveDemo() }
                        .accessibilityIdentifier("settings.leaveDemo")
                } else {
                    Button(store.hasDemoHistory ? "继续本地演示" : "试用本地对话") { store.enterDemo() }
                }
            } header: { Text("本地演示") } footer: {
                Text("回复使用预设内容，不执行命令。对话与草稿在本次打开期间保留，关闭 App 后不保存。")
            }
            Section("关于 DSH") {
                LabeledContent("版本", value: "0.1.0 · 开发预览")
                Text("为 DeepSeek Harness 设计的独立客户端，不隶属于 DeepSeek。")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text("模型凭据和项目文件留在电脑。Remote 设备凭据保存在本机钥匙串。")
                    .font(.subheadline).foregroundStyle(.secondary)
                Link("项目源码与进展", destination: URL(string: "https://github.com/zbochuan/dsh_ios")!)
            }
        }
        .scrollContentBackground(.hidden)
        .background(DSHTheme.surface)
        .tint(DSHTheme.action)
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .task { await connection.restore() }
        .sheet(isPresented: $showingLogin) { ConnectionView() }
        .confirmationDialog("退出 Remote 账号？", isPresented: $confirmingSignOut, titleVisibility: .visible) {
            Button("退出登录", role: .destructive) { Task { await connection.signOut() } }
        } message: {
            Text("这会删除本机登录凭据并保留设备身份；不会撤销服务端凭据。本地对话与草稿不受影响。")
        }
    }
}
