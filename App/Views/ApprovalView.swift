import SwiftUI
import DSHCore

/// The single place where a pending request is allowed or rejected.
struct ApprovalView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let conversationID: UUID
    let approval: ToolApproval
    @State private var explaining = false
    @State private var note = ""
    @FocusState private var noteFocused: Bool

    private var conversation: Conversation? { store.conversations.first { $0.id == conversationID } }

    /// A request stays answerable only while its task is still waiting on this exact request.
    private var isValid: Bool {
        guard store.isDemo, let conversation else { return false }
        return conversation.phase == .awaitingApproval && conversation.approval?.id == approval.id
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(approval.title)
                            .font(.title2.weight(.semibold)).foregroundStyle(DSHTheme.ink)
                            .accessibilityAddTraits(.isHeader)
                        Text("\(conversation?.title ?? "任务")在等你 · \(TaskTime.ago(approval.requestedAt))")
                            .font(.subheadline).foregroundStyle(DSHTheme.secondary)
                    }
                    Text("$ \(approval.command)")
                        .font(.body.monospaced()).lineSpacing(5)
                        .foregroundStyle(DSHTheme.terminalText)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(16)
                        .background(DSHTheme.terminal, in: RoundedRectangle(cornerRadius: 14))
                        .environment(\.colorScheme, .dark)
                        .accessibilityLabel("命令：\(approval.command)")
                        .accessibilityIdentifier("approval.command")
                    VStack(spacing: 0) {
                        detail("电脑", approval.computer)
                        Divider()
                        detail("工作区", approval.workspace, mono: true)
                        Divider()
                        detail("Agent 说明", approval.explanation)
                    }
                    .padding(.horizontal, 14)
                    .background(DSHTheme.surface, in: RoundedRectangle(cornerRadius: 14))
                    if !isValid {
                        Label("请求已失效，不能再记录授权。关闭后可继续这个任务。", systemImage: "clock.badge.xmark")
                            .font(.subheadline).foregroundStyle(DSHTheme.secondary)
                            .accessibilityIdentifier("approval.stale")
                    }
                }
                .frame(maxWidth: DSHTheme.readingWidth, alignment: .leading)
                .padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 24)
                .frame(maxWidth: .infinity)
            }
            .background(DSHTheme.background)
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom, spacing: 0) { actions }
            .navigationTitle("需要你确认")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                        .accessibilityIdentifier("approval.close")
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var actions: some View {
        VStack(spacing: 8) {
            if explaining {
                TextField("告诉 Agent 为什么拒绝，或换一种做法", text: $note, axis: .vertical)
                    .lineLimit(2...5).focused($noteFocused)
                    .padding(12)
                    .background(DSHTheme.surface, in: RoundedRectangle(cornerRadius: 14))
                    .accessibilityIdentifier("approval.note")
                Button {
                    resolve(allow: false, note: note)
                } label: {
                    Text("拒绝并发送说明").font(.body.weight(.semibold))
                        .foregroundStyle(DSHTheme.background)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(DSHTheme.ink, in: RoundedRectangle(cornerRadius: 16))
                }
                .disabled(!isValid || note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(isValid && !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 1 : 0.4)
                .accessibilityIdentifier("approval.sendNote")
                Button("取消") { explaining = false; note = "" }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(DSHTheme.secondary)
            } else {
                Button {
                    resolve(allow: true)
                } label: {
                    Text("允许这一次").font(.body.weight(.semibold))
                        .foregroundStyle(DSHTheme.background)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(DSHTheme.ink, in: RoundedRectangle(cornerRadius: 16))
                }
                .disabled(!isValid).opacity(isValid ? 1 : 0.4)
                .accessibilityIdentifier("approval.allow")
                HStack(spacing: 8) {
                    Button { resolve(allow: false) } label: {
                        Text("拒绝").secondaryButton()
                    }
                    .disabled(!isValid)
                    .accessibilityIdentifier("approval.reject")
                    Button {
                        explaining = true
                        noteFocused = true
                    } label: {
                        Text("拒绝并说明…").secondaryButton()
                    }
                    .disabled(!isValid)
                    .accessibilityIdentifier("approval.explain")
                }
                .opacity(isValid ? 1 : 0.4)
            }
            HStack(spacing: 4) {
                Text("本任务权限：\(conversation?.permissionMode.title ?? PermissionMode.ask.title)")
                Menu("更改") {
                    PermissionPicker(selection: Binding(
                        get: { conversation?.permissionMode ?? .ask },
                        set: { value in store.update(conversationID) { $0.permissionMode = value } }
                    ))
                }
                .frame(minHeight: 44)
                .accessibilityLabel("更改本任务权限")
                .accessibilityIdentifier("approval.permission")
            }
            .font(.footnote).foregroundStyle(DSHTheme.secondary)
        }
        .buttonStyle(PressStyle())
        .frame(maxWidth: DSHTheme.readingWidth)
        .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 4)
        .frame(maxWidth: .infinity).background(DSHTheme.background)
    }

    private func resolve(allow: Bool, note: String? = nil) {
        guard isValid else { return }
        store.resolveApproval(in: conversationID, approvalID: approval.id, allow: allow, note: note)
        dismiss()
    }

    private func detail(_ title: String, _ value: String, mono: Bool = false) -> some View {
        let layout = AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))
        return layout {
            Text(title).font(.subheadline).foregroundStyle(DSHTheme.secondary)
                .frame(width: 76, alignment: .leading)
            Text(value).font(mono ? .subheadline.monospaced() : .subheadline)
                .foregroundStyle(DSHTheme.ink).textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

private extension Text {
    func secondaryButton() -> some View {
        font(.body).foregroundStyle(DSHTheme.ink)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(DSHTheme.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}
