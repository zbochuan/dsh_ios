import SwiftUI
import DSHCore

enum TaskText {
    static func status(_ task: Conversation, now: Date = .now) -> String {
        switch task.status {
        case .running: "运行中 · \(TaskTime.elapsed(from: task.startedAt, to: now))"
        case .needsYou: "等你确认 · \(TaskTime.ago(task.approval?.requestedAt ?? task.updatedAt, now: now))"
        case .done: "已完成 · \(time(task.updatedAt, now: now))"
        case .failed: "失败 · \(time(task.updatedAt, now: now))"
        case .stopped: "已停止"
        case .new: "新任务"
        }
    }

    static func context(_ task: Conversation) -> String { "\(task.computer) · \(task.project)" }

    static func color(_ status: TaskStatus) -> Color {
        switch status {
        case .running: DSHTheme.blue
        case .needsYou: DSHTheme.amberText
        case .failed: DSHTheme.red
        default: DSHTheme.secondary
        }
    }

    /// Today shows the clock time; older tasks show a relative day.
    private static func time(_ date: Date, now: Date) -> String {
        Calendar.current.isDate(date, inSameDayAs: now) ? date.formatted(date: .omitted, time: .shortened) : TaskTime.ago(date, now: now)
    }
}

struct StatusIcon: View {
    let status: TaskStatus
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var spinning = false

    var body: some View {
        ZStack {
            Circle().fill(background)
            switch status {
            case .running:
                Circle().trim(from: 0, to: 0.72)
                    .stroke(DSHTheme.blue, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                    .frame(width: 14, height: 14)
                    .rotationEffect(.degrees(spinning ? 360 : 0))
                    .onAppear {
                        guard !reduceMotion else { return }
                        withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) { spinning = true }
                    }
            default:
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(foreground)
            }
        }
        .frame(width: 32, height: 32)
        .accessibilityHidden(true)
    }

    private var symbol: String {
        switch status {
        case .done: "checkmark"
        case .failed: "exclamationmark"
        case .needsYou: "hand.raised.fill"
        case .stopped: "pause.fill"
        default: "pencil"
        }
    }

    private var foreground: Color {
        switch status {
        case .done: DSHTheme.greenText
        case .failed: DSHTheme.red
        case .needsYou: DSHTheme.amber
        default: DSHTheme.secondary
        }
    }

    private var background: Color {
        switch status {
        case .running: DSHTheme.blueTint
        case .failed: DSHTheme.redTint
        case .needsYou: DSHTheme.amberCard
        default: DSHTheme.neutralTint
        }
    }
}

struct StatusDot: View {
    enum Kind { case online, offline, running, needsYou }
    let kind: Kind

    var body: some View {
        Group {
            switch kind {
            case .online: Circle().fill(DSHTheme.green)
            case .offline: Circle().strokeBorder(DSHTheme.secondary, lineWidth: 1.5)
            case .running: Circle().fill(DSHTheme.blue)
            case .needsYou: Circle().fill(DSHTheme.amber)
            }
        }
        .frame(width: 8, height: 8)
        .accessibilityHidden(true)
    }
}

struct TaskRow: View {
    let task: Conversation
    var now: Date = .now
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            StatusIcon(status: task.status)
            VStack(alignment: .leading, spacing: 3) {
                let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 3)) : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
                layout {
                    Text(task.title)
                        .font(.subheadline.weight(.semibold)).foregroundStyle(DSHTheme.ink)
                        .lineLimit(2)
                    if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
                    Text(TaskText.status(task, now: now))
                        .font(.caption).foregroundStyle(TaskText.color(task.status))
                        .fixedSize(horizontal: !dynamicTypeSize.isAccessibilitySize, vertical: false)
                }
                Text("\(task.project) · \(task.latestActivity)")
                    .font(.footnote).foregroundStyle(DSHTheme.secondary)
                    .lineLimit(1).truncationMode(.tail)
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(task.title)，\(TaskText.status(task, now: now))，\(task.project) · \(task.latestActivity)")
    }
}

/// Prompt text with inline Markdown: bold, italics, links and code spans.
func markdown(_ text: String) -> AttributedString {
    var attributed = (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
    let codeRanges = attributed.runs.compactMap { run in
        run.inlinePresentationIntent?.contains(.code) == true ? run.range : nil
    }
    for range in codeRanges {
        attributed[range].font = .system(.subheadline, design: .monospaced)
        attributed[range].backgroundColor = DSHTheme.bubble
    }
    return attributed
}
