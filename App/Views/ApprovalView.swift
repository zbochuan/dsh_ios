import SwiftUI
import DSHCore

struct ApprovalView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let conversationID: UUID
    let approval: ToolApproval

    private var isValid: Bool {
        guard store.isDemo, let conversation = store.conversations.first(where: { $0.id == conversationID }) else { return false }
        return conversation.phase == .awaitingApproval && conversation.approval?.id == approval.id
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text(isValid ? approval.explanation : "请求已失效，不能再记录授权。关闭后可继续对话。")
                        .font(.body).lineSpacing(6).foregroundStyle(DSHTheme.ink)
                    VStack(alignment: .leading, spacing: 18) {
                        detail("电脑") { Text(approval.computer) }
                        detail("工作区") {
                            Text(approval.workspace).font(.subheadline.monospaced())
                                .textSelection(.enabled)
                        }
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 12) {
                        Text("命令").font(.subheadline).foregroundStyle(DSHTheme.secondary)
                        Text(approval.command)
                            .font(.body.monospaced()).lineSpacing(5).textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(16)
                            .background(DSHTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                            .accessibilityIdentifier("approval.command")
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("影响范围").font(.subheadline).foregroundStyle(DSHTheme.secondary)
                        Text(approval.scope).font(.subheadline).lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .foregroundStyle(DSHTheme.ink)
                .frame(maxWidth: DSHTheme.readingWidth, alignment: .leading)
                .padding(24).frame(maxWidth: .infinity)
            }
            .background(DSHTheme.background)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 6) {
                    Text(isValid ? "本地演示，只记录选择，不执行命令。" : "请求已失效，没有记录授权。")
                        .font(.caption).foregroundStyle(DSHTheme.secondary)
                        .multilineTextAlignment(.center).padding(.bottom, 10)
                    Button {
                        store.resolveApproval(in: conversationID, approvalID: approval.id, allow: true)
                        dismiss()
                    } label: {
                        Text("仅允许一次").font(.body.weight(.semibold))
                            .foregroundStyle(DSHTheme.background)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(DSHTheme.action, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(!isValid).opacity(isValid ? 1 : 0.4)
                    .accessibilityIdentifier("approval.allow")
                    Button("拒绝这次操作", role: .destructive) {
                        store.resolveApproval(in: conversationID, approvalID: approval.id, allow: false)
                        dismiss()
                    }
                    .font(.body).frame(maxWidth: .infinity, minHeight: 48).disabled(!isValid)
                    .accessibilityIdentifier("approval.reject")
                }
                .buttonStyle(PressStyle())
                .frame(maxWidth: DSHTheme.readingWidth)
                .padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 8)
                .frame(maxWidth: .infinity).background(DSHTheme.background)
            }
            .navigationTitle("确认操作")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                        .foregroundStyle(DSHTheme.action)
                        .accessibilityIdentifier("approval.close")
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func detail<Content: View>(_ title: String, @ViewBuilder value: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(DSHTheme.secondary)
            value().font(.body).fixedSize(horizontal: false, vertical: true)
        }
    }
}
