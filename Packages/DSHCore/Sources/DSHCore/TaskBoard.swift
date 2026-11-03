import Foundation

public struct ComputerSummary: Identifiable, Hashable, Sendable {
    public var name: String
    public var isOnline: Bool
    public var id: String { name }

    public init(name: String, isOnline: Bool) {
        self.name = name
        self.isOnline = isOnline
    }
}

/// Groups tasks for the home screen and the drawer.
public struct TaskBoard: Equatable, Sendable {
    public struct ComputerSection: Identifiable, Equatable, Sendable {
        public var computer: ComputerSummary
        public var tasks: [Conversation]
        public var id: String { computer.id }
    }

    public struct ProjectGroup: Identifiable, Equatable, Sendable {
        public var computer: String
        public var project: String
        public var tasks: [Conversation]
        public var id: String { "\(computer) · \(project)" }
    }

    /// Tasks waiting on the user, oldest request first so nothing waits forever.
    public let pending: [Conversation]
    /// Every known computer, each with its tasks that are not waiting on the user.
    public let sections: [ComputerSection]
    /// Every visible task grouped by computer and project, for the drawer.
    public let projects: [ProjectGroup]

    public init(conversations: [Conversation], computers: [ComputerSummary], search: String = "") {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let visible = conversations
            .filter { !$0.isArchived }
            .filter { task in
                query.isEmpty || [task.title, task.project, task.computer].contains { $0.localizedCaseInsensitiveContains(query) }
            }
            .sorted { $0.updatedAt > $1.updatedAt }

        pending = visible
            .filter { $0.status == .needsYou }
            .sorted { ($0.approval?.requestedAt ?? $0.updatedAt) < ($1.approval?.requestedAt ?? $1.updatedAt) }

        var known = computers
        for task in visible where !known.contains(where: { $0.name == task.computer }) {
            // A task can outlive its computer's listing; never hide it.
            known.append(ComputerSummary(name: task.computer, isOnline: false))
        }
        sections = known.map { computer in
            ComputerSection(computer: computer, tasks: visible.filter { $0.computer == computer.name && $0.status != .needsYou })
        }

        var groups: [ProjectGroup] = []
        for task in visible {
            if let index = groups.firstIndex(where: { $0.computer == task.computer && $0.project == task.project }) {
                groups[index].tasks.append(task)
            } else {
                groups.append(ProjectGroup(computer: task.computer, project: task.project, tasks: [task]))
            }
        }
        projects = groups
    }
}

public enum TaskTime {
    /// "刚开始", "6 分钟", "1 小时 5 分钟"
    public static func elapsed(from start: Date, to end: Date = .now) -> String {
        let minutes = max(0, Int(end.timeIntervalSince(start) / 60))
        if minutes < 1 { return "刚开始" }
        if minutes < 60 { return "\(minutes) 分钟" }
        let hours = minutes / 60, rest = minutes % 60
        return rest == 0 ? "\(hours) 小时" : "\(hours) 小时 \(rest) 分钟"
    }

    /// "刚刚", "2 分钟前", "3 小时前", "昨天", "3 天前"
    public static func ago(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        let minutes = max(0, Int(now.timeIntervalSince(date) / 60))
        if minutes < 1 { return "刚刚" }
        if minutes < 60 { return "\(minutes) 分钟前" }
        if calendar.isDate(date, inSameDayAs: now) { return "\(minutes / 60) 小时前" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) { return "昨天" }
        let days = max(2, calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 2)
        return "\(days) 天前"
    }
}
