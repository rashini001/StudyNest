import Foundation

struct WidgetSnapshot: Codable {
    var nextSessionSubject: String?
    var nextSessionStart: Date?
    var nextSessionEnd: Date?
    var pendingTaskCount: Int
    var todayStudyMinutes: Int
    var streakDays: Int
}

//Shared container key
struct WidgetDataStore {
    static let appGroupID   = "group.com.studynest.app"
    static let snapshotKey  = "widgetSnapshot"

    static func write(snapshot: WidgetSnapshot) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        if let encoded = try? JSONEncoder().encode(snapshot) {
            defaults.set(encoded, forKey: snapshotKey)
        }
    }

    static func read() -> WidgetSnapshot {
        guard
            let defaults = UserDefaults(suiteName: appGroupID),
            let data = defaults.data(forKey: snapshotKey),
            let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else {
            return WidgetSnapshot(
                nextSessionSubject: nil,
                nextSessionStart: nil,
                nextSessionEnd: nil,
                pendingTaskCount: 0,
                todayStudyMinutes: 0,
                streakDays: 0
            )
        }
        return snapshot
    }
}
