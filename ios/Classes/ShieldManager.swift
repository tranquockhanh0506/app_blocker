import Foundation
import ManagedSettings
import FamilyControls

@available(iOS 15.0, *)
class ShieldManager: NSObject {
    private let store = ManagedSettingsStore()
    private let userDefaultsKey = "app_blocker_token_mappings"
    private let blockedAllKey = "app_blocker_blocked_all"

    // In-memory tracking of blocked tokens
    private var blockedApplicationTokens: Set<ApplicationToken> = []
    private var blockedCategoryTokens: Set<ActivityCategoryToken> = []

    // Map of identifier strings to serialized token data
    // Since ApplicationToken is opaque, we store identifier -> token association
    private var identifierToAppTokenData: [String: Data] = [:]
    private var identifierToCategoryTokenData: [String: Data] = [:]

    override init() {
        super.init()
        loadTokenMappings()
    }

    // MARK: - Public API

    func blockApps(identifiers: [String]) {
        // Load existing tokens from storage
        var appTokens = blockedApplicationTokens
        var catTokens = blockedCategoryTokens

        // Try to restore tokens for known identifiers
        for identifier in identifiers {
            if let data = identifierToAppTokenData[identifier],
               let token = try? JSONDecoder().decode(ApplicationToken.self, from: data) {
                appTokens.insert(token)
            }
            if let data = identifierToCategoryTokenData[identifier],
               let token = try? JSONDecoder().decode(ActivityCategoryToken.self, from: data) {
                catTokens.insert(token)
            }
        }

        blockedApplicationTokens = appTokens
        blockedCategoryTokens = catTokens

        applyShield()
        saveBlockedState()
    }

    func blockWithSelection(selection: FamilyActivitySelection) {
        blockedApplicationTokens = selection.applicationTokens
        blockedCategoryTokens = selection.categoryTokens

        // Store token mappings for persistence
        storeTokensFromSelection(selection: selection)
        applyShield()
        saveBlockedState()
    }

    func blockAll() {
        store.shield.applicationCategories = .all()
        UserDefaults.standard.set(true, forKey: blockedAllKey)
    }

    func unblockApps(identifiers: [String]) {
        for identifier in identifiers {
            if let data = identifierToAppTokenData[identifier],
               let token = try? JSONDecoder().decode(ApplicationToken.self, from: data) {
                blockedApplicationTokens.remove(token)
            }
            if let data = identifierToCategoryTokenData[identifier],
               let token = try? JSONDecoder().decode(ActivityCategoryToken.self, from: data) {
                blockedCategoryTokens.remove(token)
            }
        }

        applyShield()
        saveBlockedState()
    }

    func unblockAll() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        blockedApplicationTokens = []
        blockedCategoryTokens = []
        UserDefaults.standard.set(false, forKey: blockedAllKey)
        saveBlockedState()
    }

    func getBlockedApps() -> [String] {
        let isBlockedAll = UserDefaults.standard.bool(forKey: blockedAllKey)
        if isBlockedAll {
            return ["__all__"]
        }

        // Return all identifiers that have active tokens
        var result: [String] = []
        for (identifier, data) in identifierToAppTokenData {
            if let token = try? JSONDecoder().decode(ApplicationToken.self, from: data),
               blockedApplicationTokens.contains(token) {
                result.append(identifier)
            }
        }
        for (identifier, data) in identifierToCategoryTokenData {
            if let token = try? JSONDecoder().decode(ActivityCategoryToken.self, from: data),
               blockedCategoryTokens.contains(token) {
                if !result.contains(identifier) {
                    result.append(identifier)
                }
            }
        }
        return result
    }

    // MARK: - Token Selection Storage

    func storeTokensFromSelection(selection: FamilyActivitySelection) {
        let encoder = JSONEncoder()

        // Store application tokens with generated identifiers
        var appIndex = 0
        for token in selection.applicationTokens {
            let identifier = "app_token_\(appIndex)"
            if let data = try? encoder.encode(token) {
                identifierToAppTokenData[identifier] = data
            }
            appIndex += 1
        }

        // Store category tokens with generated identifiers
        var catIndex = 0
        for token in selection.categoryTokens {
            let identifier = "cat_token_\(catIndex)"
            if let data = try? encoder.encode(token) {
                identifierToCategoryTokenData[identifier] = data
            }
            catIndex += 1
        }

        saveTokenMappings()
    }

    func getSelectionInfo() -> [[String: Any]] {
        var result: [[String: Any]] = []

        // Return info about blocked app tokens
        var appIndex = 0
        for _ in blockedApplicationTokens {
            let identifier = "app_token_\(appIndex)"
            result.append([
                "packageName": identifier,
                "appName": "App \(appIndex)",
                "isSystemApp": false,
            ])
            appIndex += 1
        }

        // Return info about blocked category tokens
        var catIndex = 0
        for _ in blockedCategoryTokens {
            let identifier = "cat_token_\(catIndex)"
            result.append([
                "packageName": identifier,
                "appName": "Category \(catIndex)",
                "isSystemApp": false,
            ])
            catIndex += 1
        }

        return result
    }

    // MARK: - Private Helpers

    private func applyShield() {
        store.shield.applications = blockedApplicationTokens.isEmpty ? nil : blockedApplicationTokens
        if blockedCategoryTokens.isEmpty {
            store.shield.applicationCategories = nil
        } else {
            store.shield.applicationCategories = .specific(blockedCategoryTokens)
        }
    }

    private func saveBlockedState() {
        saveTokenMappings()
    }

    private func saveTokenMappings() {
        let encoder = JSONEncoder()

        // Convert Data values to Base64 strings for UserDefaults compatibility
        var appMappings: [String: String] = [:]
        for (key, data) in identifierToAppTokenData {
            appMappings[key] = data.base64EncodedString()
        }

        var catMappings: [String: String] = [:]
        for (key, data) in identifierToCategoryTokenData {
            catMappings[key] = data.base64EncodedString()
        }

        // Store blocked token identifiers
        let blockedAppIds: [String] = blockedApplicationTokens.compactMap { token in
            if let data = try? encoder.encode(token) {
                return data.base64EncodedString()
            }
            return nil
        }

        let blockedCatIds: [String] = blockedCategoryTokens.compactMap { token in
            if let data = try? encoder.encode(token) {
                return data.base64EncodedString()
            }
            return nil
        }

        let storage: [String: Any] = [
            "appMappings": appMappings,
            "catMappings": catMappings,
            "blockedAppTokens": blockedAppIds,
            "blockedCatTokens": blockedCatIds,
        ]

        UserDefaults.standard.set(storage, forKey: userDefaultsKey)
    }

    private func loadTokenMappings() {
        guard let storage = UserDefaults.standard.dictionary(forKey: userDefaultsKey) else {
            return
        }

        let decoder = JSONDecoder()

        // Restore identifier-to-token mappings
        if let appMappings = storage["appMappings"] as? [String: String] {
            for (key, base64) in appMappings {
                if let data = Data(base64Encoded: base64) {
                    identifierToAppTokenData[key] = data
                }
            }
        }

        if let catMappings = storage["catMappings"] as? [String: String] {
            for (key, base64) in catMappings {
                if let data = Data(base64Encoded: base64) {
                    identifierToCategoryTokenData[key] = data
                }
            }
        }

        // Restore blocked token sets
        if let blockedAppIds = storage["blockedAppTokens"] as? [String] {
            for base64 in blockedAppIds {
                if let data = Data(base64Encoded: base64),
                   let token = try? decoder.decode(ApplicationToken.self, from: data) {
                    blockedApplicationTokens.insert(token)
                }
            }
        }

        if let blockedCatIds = storage["blockedCatTokens"] as? [String] {
            for base64 in blockedCatIds {
                if let data = Data(base64Encoded: base64),
                   let token = try? decoder.decode(ActivityCategoryToken.self, from: data) {
                    blockedCategoryTokens.insert(token)
                }
            }
        }
    }
}
