import SwiftUI
import DSHCore

struct DevicesView: View {
    @Environment(ConnectionStore.self) private var connection
    @State private var showingLogin = false

    var body: some View {
        List {
            if connection.isSignedIn {
                Section {
                    LabeledContent("服务", value: connection.committedServerAddress)
                        .font(.subheadline)
                } footer: {
                    Text("在线状态来自 Remote 服务。")
                }
                Section("我的电脑") {
                    if connection.isBusy {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("正在获取电脑列表…").foregroundStyle(.secondary)
                        }.padding(.vertical, 12)
                    } else if let error = connection.errorMessage {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("未能获取电脑列表", systemImage: "exclamationmark.circle")
                            Text(error).font(.subheadline).foregroundStyle(.secondary)
                            Button("重试") { Task { await connection.refreshDevices() } }
                                .frame(minHeight: 44)
                                .accessibilityIdentifier("devices.retry")
                        }.padding(.vertical, 8)
                    } else if connection.devices.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("还没有发现电脑")
                            Text("在电脑上启用 ds-harness-remote，并登录同一个服务和账号。")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }.padding(.vertical, 8)
                    } else {
                        ForEach(connection.devices) { device in
                            NavigationLink { DeviceDetailView(device: device) } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: "desktopcomputer").foregroundStyle(.secondary)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(device.name).font(.body.weight(.medium))
                                        Text(device.platform).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(device.online ? "在线" : "离线")
                                        .font(.caption).foregroundStyle(.secondary)
                                }.padding(.vertical, 8)
                            }
                        }
                    }
                }
            } else {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("登录后查看你的电脑").font(.body.weight(.semibold))
                        Text("使用电脑上的 Remote 服务和账号登录，查看电脑是否在线。")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Button("登录并发现电脑") { showingLogin = true }
                            .frame(minHeight: 44)
                            .accessibilityIdentifier("devices.login")
                            .disabled(connection.isBusy)
                    }.padding(.vertical, 8)
                    if connection.isBusy { ProgressView("正在恢复登录…") }
                }
                ConnectionRecoverySection()
            }
            Section {
                DisclosureGroup("电脑端准备") {
                    Text("安装 ds-harness-remote 0.6.2，重启 Harness 后登录 Remote。这里需要填写相同的服务地址。")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Link("查看安装说明", destination: URL(string: "https://github.com/liguobao/ds-harness-remote")!)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(DSHTheme.surface)
        .tint(DSHTheme.action)
        .navigationTitle("电脑")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if connection.isSignedIn {
                ToolbarItem(placement: .primaryAction) {
                    Button("刷新", systemImage: "arrow.clockwise") { Task { await connection.refreshDevices() } }
                        .disabled(connection.isBusy).frame(minWidth: 44, minHeight: 44)
                }
            }
        }
        .refreshable { if connection.isSignedIn { await connection.refreshDevices() } }
        .task { await connection.restore() }
        .sheet(isPresented: $showingLogin) { ConnectionView() }
    }
}

private struct DeviceDetailView: View {
    let device: RemoteDevice

    var body: some View {
        Form {
            Section("设备") {
                LabeledContent("名称", value: device.name)
                LabeledContent("平台", value: device.platform)
                LabeledContent("服务端状态", value: device.online ? "在线" : "离线")
                if let version = device.harnessVersion { LabeledContent("Harness", value: version) }
                if let version = device.clientVersion { LabeledContent("Remote", value: version) }
            }
            Section("任务") {
                Text("在线状态来自 Remote 服务；尚未核验这台电脑的身份，也未建立加密会话，所以这里还不会显示它的任务。")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .navigationTitle(device.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
