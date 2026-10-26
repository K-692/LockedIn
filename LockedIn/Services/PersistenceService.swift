// MARK: - PersistenceService.swift
// Handles all local data storage using JSON serialisation.
// Stores goals and settings generically and atomically.

import Foundation

final class PersistenceService {

    // MARK: - File URLs

    private static let documentsURL: URL = {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LockedIn", isDirectory: true)
    }()

    private static var goalsURL: URL    { documentsURL.appendingPathComponent("goals.json") }
    private static var settingsURL: URL { documentsURL.appendingPathComponent("settings.json") }

    // MARK: - Setup

    static func ensureDirectoryExists() {
        try? FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
    }

    // MARK: - Goals

    static func saveGoals(_ goals: [Goal]) {
        ensureDirectoryExists()
        guard let data = try? JSONEncoder().encode(goals) else { return }
        try? data.write(to: goalsURL, options: .atomic)
    }

    static func loadGoals() -> [Goal] {
        guard let data = try? Data(contentsOf: goalsURL),
              let goals = try? JSONDecoder().decode([Goal].self, from: data) else { return [] }
        return goals
    }

    // MARK: - Settings

    static func saveSettings(_ settings: AppSettings) {
        ensureDirectoryExists()
        guard let data = try? JSONEncoder().encode(settings) else { return }
        try? data.write(to: settingsURL, options: .atomic)
    }

    static func loadSettings() -> AppSettings {
        guard let data = try? Data(contentsOf: settingsURL),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else { return AppSettings() }
        return settings
    }

    // MARK: - Storage Path Info

    static var storagePathDescription: String {
        documentsURL.path
    }

    static var documentsDirectory: URL {
        documentsURL
    }

    // MARK: - Backup & Restore

    /// Exports all app data as a single JSON bundle.
    static func exportBackup() -> Data? {
        let bundle: [String: Any] = [
            "goals":      (try? JSONEncoder().encode(loadGoals())).map { $0.base64EncodedString() } ?? "",
            "settings":   (try? JSONEncoder().encode(loadSettings())).map { $0.base64EncodedString() } ?? "",
            "exportedAt": ISO8601DateFormatter().string(from: Date())
        ]
        return try? JSONSerialization.data(withJSONObject: bundle, options: .prettyPrinted)
    }

    /// Restores app data from a backup bundle exported by exportBackup().
    @discardableResult
    static func importBackup(from data: Data) -> Bool {
        guard let bundle = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }

        if let goalsB64 = bundle["goals"] as? String,
           let goalsData = Data(base64Encoded: goalsB64),
           let goals = try? JSONDecoder().decode([Goal].self, from: goalsData) {
            saveGoals(goals)
        }
        if let settingsB64 = bundle["settings"] as? String,
           let settingsData = Data(base64Encoded: settingsB64),
           let settings = try? JSONDecoder().decode(AppSettings.self, from: settingsData) {
            saveSettings(settings)
        }
        return true
    }
}
