import SwiftUI
import DSHCore

struct ConnectionView: View {
    @Environment(ConnectionStore.self) private var connection
    @Environment(\.dismiss) private var dismiss
    @State private var serverAddress = ""
    @State private var email = ""
    @State private var password = ""
    private var validServer: Bool { (try? RemoteServerURL(serverAddress)) != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("填写电脑正在使用的 Remote 服务和账号。")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Section {
                    TextField("https://remote.example.com", text: $serverAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never).keyboardType(.URL)
                        .accessibilityLabel("Remote 服务地址")
                        .accessibilityIdentifier("connection.server")
                    if !serverAddress.isEmpty && !validServer {
                        Text("请输入 HTTPS 服务根地址，例如 https://remote.example.com")
                            .font(.caption).foregroundStyle(.red)
                    }
                } header: { Text("Remote 服务") } footer: {
                    Text("可在电脑的 Remote 插件设置中查看。登录会向这个地址发送账号信息。")
                }
                Section {
                    TextField("邮箱或账号", text: $email)
                        .textContentType(.username).autocorrectionDisabled()
                        .textInputAutocapitalization(.never).keyboardType(.emailAddress)
                        .accessibilityIdentifier("connection.account")
                    SecureField("密码", text: $password).textContentType(.password)
                        .accessibilityIdentifier("connection.password")
                } header: { Text("账号") } footer: {
                    Text("登录密码不保存。无需填写模型 API key。")
                }
                ConnectionRecoverySection()
                Section {
                    Button {
                        Task {
                            let success = await connection.login(serverAddress: serverAddress, email: email, password: password)
                            password = ""
                            if success { dismiss() }
                        }
                    } label: {
                        HStack {
                            if connection.isBusy { ProgressView() }
                            Text(connection.isBusy ? "正在登录…" : "登录并发现电脑").fontWeight(.medium)
                        }.frame(minHeight: 44)
                    }
                    .disabled(connection.isBusy || !validServer || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)
                    .accessibilityIdentifier("connection.login")
                } footer: {
                    Text("登录后可查看电脑状态；远程对话暂未开放。你的本地对话与草稿会保留。")
                }
            }
            .scrollContentBackground(.hidden)
            .background(DSHTheme.surface)
            .tint(DSHTheme.action)
            .navigationTitle("登录 Remote")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { password = ""; dismiss() }.disabled(connection.isBusy)
                }
            }
            .disabled(connection.isBusy)
            .interactiveDismissDisabled(connection.isBusy)
        }
        .onAppear { serverAddress = connection.committedServerAddress }
        .onDisappear { password = "" }
    }
}

struct ConnectionRecoverySection: View {
    @Environment(ConnectionStore.self) private var connection
    @State private var confirmingIdentityRemoval = false

    var body: some View {
        if let error = connection.errorMessage {
            Section {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(.subheadline).foregroundStyle(.red)
                if connection.canRetryRestore {
                    Button("重试恢复登录") { Task { await connection.retryRestore() } }
                        .frame(minHeight: 44)
                }
                if connection.canForgetSavedIdentity {
                    Button("移除无法读取的本机身份", role: .destructive) { confirmingIdentityRemoval = true }
                        .frame(minHeight: 44)
                }
            }
            .confirmationDialog("移除该服务的本机身份？", isPresented: $confirmingIdentityRemoval, titleVisibility: .visible) {
                Button("移除并重新登录", role: .destructive) {
                    Task { await connection.forgetSavedIdentity() }
                }
            } message: {
                Text("将移除 \(connection.savedIdentityServerAddress ?? "该服务") 对应的本机身份与登录凭据。重新登录会注册新身份；服务端旧记录不会自动撤销。")
            }
        }
    }
}
