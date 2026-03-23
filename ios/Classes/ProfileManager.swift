import Foundation

@available(iOS 15.0, *)
class ProfileManager: NSObject {
    private let userDefaultsKey = "app_blocker_profiles"
    private let activeProfileKey = "app_blocker_active_profile_id"
    private weak var shieldManager: ShieldManager?

    init(shieldManager: ShieldManager) {
        self.shieldManager = shieldManager
        super.init()
    }

    // MARK: - Public API

    func createProfile(data: [String: Any]) {
        var profiles = loadProfiles()

        guard let id = data["id"] as? String else { return }

        // Remove any existing profile with the same id
        profiles.removeAll { ($0["id"] as? String) == id }

        // Ensure new profiles start inactive unless explicitly set
        var profileData = data
        if profileData["isActive"] == nil {
            profileData["isActive"] = false
        }

        profiles.append(profileData)
        saveProfiles(profiles)
    }

    func updateProfile(data: [String: Any]) {
        var profiles = loadProfiles()

        guard let id = data["id"] as? String else { return }

        if let index = profiles.firstIndex(where: { ($0["id"] as? String) == id }) {
            profiles[index] = data
        } else {
            profiles.append(data)
        }

        saveProfiles(profiles)
    }

    func deleteProfile(id: String) {
        var profiles = loadProfiles()

        // If the deleted profile is active, deactivate it first
        let activeId = UserDefaults.standard.string(forKey: activeProfileKey)
        if activeId == id {
            shieldManager?.unblockAll()
            UserDefaults.standard.removeObject(forKey: activeProfileKey)
        }

        profiles.removeAll { ($0["id"] as? String) == id }
        saveProfiles(profiles)
    }

    func getProfiles() -> [[String: Any]] {
        let profiles = loadProfiles()
        let activeId = UserDefaults.standard.string(forKey: activeProfileKey)

        // Mark the active profile
        return profiles.map { profile in
            var p = profile
            let profileId = p["id"] as? String
            p["isActive"] = (profileId == activeId)
            return p
        }
    }

    /// Activates a profile by blocking its apps. Returns true if the profile was found.
    @discardableResult
    func activateProfile(id: String) -> Bool {
        let profiles = loadProfiles()

        guard let profile = profiles.first(where: { ($0["id"] as? String) == id }) else {
            return false
        }

        // Deactivate any currently active profile first
        let currentActiveId = UserDefaults.standard.string(forKey: activeProfileKey)
        if let currentId = currentActiveId, currentId != id {
            deactivateProfile(id: currentId)
        }

        // Block the apps in this profile
        if let appIdentifiers = profile["appIdentifiers"] as? [String] {
            shieldManager?.blockApps(identifiers: appIdentifiers)
        }

        // Mark as active
        UserDefaults.standard.set(id, forKey: activeProfileKey)
        return true
    }

    func deactivateProfile(id: String) {
        let activeId = UserDefaults.standard.string(forKey: activeProfileKey)

        guard activeId == id else { return }

        // Unblock all apps
        shieldManager?.unblockAll()

        // Clear active profile
        UserDefaults.standard.removeObject(forKey: activeProfileKey)
    }

    func getActiveProfile() -> [String: Any]? {
        guard let activeId = UserDefaults.standard.string(forKey: activeProfileKey) else {
            return nil
        }

        let profiles = loadProfiles()

        guard var profile = profiles.first(where: { ($0["id"] as? String) == activeId }) else {
            // Active profile no longer exists, clean up
            UserDefaults.standard.removeObject(forKey: activeProfileKey)
            return nil
        }

        profile["isActive"] = true
        return profile
    }

    // MARK: - Persistence

    private func loadProfiles() -> [[String: Any]] {
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

    private func saveProfiles(_ profiles: [[String: Any]]) {
        do {
            let data = try JSONSerialization.data(withJSONObject: profiles, options: [])
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            // Silently fail - data could not be serialized
        }
    }
}
