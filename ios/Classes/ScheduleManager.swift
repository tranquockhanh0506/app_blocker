import Foundation

@available(iOS 15.0, *)
class ScheduleManager: NSObject {
    private let userDefaultsKey = "app_blocker_schedules"

    // MARK: - Public API

    func addSchedule(data: [String: Any]) {
        var schedules = loadSchedules()

        // Ensure the schedule has an id
        guard let id = data["id"] as? String else { return }

        // Remove any existing schedule with the same id
        schedules.removeAll { ($0["id"] as? String) == id }

        schedules.append(data)
        saveSchedules(schedules)
    }

    func updateSchedule(data: [String: Any]) {
        var schedules = loadSchedules()

        guard let id = data["id"] as? String else { return }

        if let index = schedules.firstIndex(where: { ($0["id"] as? String) == id }) {
            schedules[index] = data
        } else {
            schedules.append(data)
        }

        saveSchedules(schedules)
    }

    func removeSchedule(id: String) {
        var schedules = loadSchedules()
        schedules.removeAll { ($0["id"] as? String) == id }
        saveSchedules(schedules)
    }

    func getSchedules() -> [[String: Any]] {
        return loadSchedules()
    }

    func enableSchedule(id: String) {
        var schedules = loadSchedules()

        if let index = schedules.firstIndex(where: { ($0["id"] as? String) == id }) {
            var schedule = schedules[index]
            schedule["enabled"] = true
            schedules[index] = schedule
            saveSchedules(schedules)
        }
    }

    func disableSchedule(id: String) {
        var schedules = loadSchedules()

        if let index = schedules.firstIndex(where: { ($0["id"] as? String) == id }) {
            var schedule = schedules[index]
            schedule["enabled"] = false
            schedules[index] = schedule
            saveSchedules(schedules)
        }
    }

    // MARK: - Persistence

    private func loadSchedules() -> [[String: Any]] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return []
        }

        do {
            let decoded = try JSONSerialization.jsonObject(with: data, options: [])
            return decoded as? [[String: Any]] ?? []
        } catch {
            return []
        }
    }

    private func saveSchedules(_ schedules: [[String: Any]]) {
        do {
            let data = try JSONSerialization.data(withJSONObject: schedules, options: [])
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            // Silently fail - data could not be serialized
        }
    }
}
