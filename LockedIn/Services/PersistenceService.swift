// MARK: - PersistenceService.swift
// Local JSON storage for goals and settings.
// - Writes are atomic and performed on a background serial queue (UI never blocks on disk).
// - Unreadable files are quarantined instead of being silently overwritten, so data is never lost.
// - Backups are validated before anything on disk is replaced.

import Foundation
import os

final class PersistenceService {

    private static let log = Logger(subsystem: "com.lockedin.app", category: "persistence")
    private static let ioQueue = DispatchQueue(label: "com.lockedin.app.persistence", qos: .utility)

    // MARK: - File URLs

    private static let documentsURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("LockedIn", isDirectory: true)
    }()

    private static var goalsURL: URL    { documentsURL.appendingPathComponent("goals.json") }
    private static var settingsURL: URL { documentsURL.appendingPathComponent("settings.json") }

    private static func makeEncoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }

    // MARK: - Setup

    static func ensureDirectoryExists() {
        do {
            try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        } catch {
            log.error("Could not create data directory: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Generic IO

    private static func write(_ data: Data, to url: URL) {
        ioQueue.async {
            ensureDirectoryExists()
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                log.error("Failed writing \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private static func load<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            quarantine(url, reason: error)
            return nil
        }
    }

    /// Moves an unreadable file aside (e.g. goals.corrupt-1700000000.json) so the next save
    /// does not destroy data the user may still want to recover.
    private static func quarantine(_ url: URL, reason: Error) {
        let stamp = Int(Date().timeIntervalSince1970)
        let dest = url.deletingPathExtension()
            .appendingPathExtension("corrupt-\(stamp)")
            .appendingPathExtension("json")
        do {
            try FileManager.default.moveItem(at: url, to: dest)
            log.error("Quarantined unreadable \(url.lastPathComponent, privacy: .public) → \(dest.lastPathComponent, privacy: .public): \(reason.localizedDescription, privacy: .public)")
        } catch {
            log.error("Could not quarantine \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Blocks until all queued writes have hit disk. Call before the app terminates.
    static func flush() {
        ioQueue.sync {}
    }

    // MARK: - Goals

    static func saveGoals(_ goals: [Goal]) {
        guard let data = try? makeEncoder().encode(goals) else { return }
        write(data, to: goalsURL)
    }

    static func loadGoals() -> [Goal] {
        load([Goal].self, from: goalsURL) ?? []
    }

    // MARK: - Settings

    static func saveSettings(_ settings: AppSettings) {
        guard let data = try? makeEncoder().encode(settings) else { return }
        write(data, to: settingsURL)
    }

    static func loadSettings() -> AppSettings {
        load(AppSettings.self, from: settingsURL) ?? AppSettings()
    }

    // MARK: - Storage Path Info

    static var storagePathDescription: String {
        (documentsURL.path as NSString).abbreviatingWithTildeInPath
    }

    static var documentsDirectory: URL {
        ensureDirectoryExists()
        return documentsURL
    }

    // MARK: - Backup & Restore

    struct BackupContents {
        let goals: [Goal]
        let settings: AppSettings?
    }

    enum BackupError: LocalizedError {
        case unreadable
        case invalidFormat

        var errorDescription: String? {
            switch self {
            case .unreadable:    return "The backup file could not be read."
            case .invalidFormat: return "This file is not a valid LockedIn backup."
            }
        }
    }

    /// Exports the given in-memory state as a single JSON bundle.
    static func exportBackup(goals: [Goal], settings: AppSettings) -> Data? {
        let encoder = makeEncoder()
        guard let goalsData = try? encoder.encode(goals),
              let settingsData = try? encoder.encode(settings) else { return nil }
        let bundle: [String: Any] = [
            "format":     "lockedin-backup",
            "version":    1,
            "goals":      goalsData.base64EncodedString(),
            "settings":   settingsData.base64EncodedString(),
            "exportedAt": ISO8601DateFormatter().string(from: Date())
        ]
        return try? JSONSerialization.data(withJSONObject: bundle, options: [.prettyPrinted, .sortedKeys])
    }

    /// Parses and validates a backup without touching anything on disk.
    static func parseBackup(_ data: Data) throws -> BackupContents {
        guard let bundle = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BackupError.unreadable
        }
        guard let goalsB64 = bundle["goals"] as? String,
              let goalsData = Data(base64Encoded: goalsB64),
              let goals = try? JSONDecoder().decode([Goal].self, from: goalsData) else {
            throw BackupError.invalidFormat
        }
        var settings: AppSettings?
        if let settingsB64 = bundle["settings"] as? String,
           let settingsData = Data(base64Encoded: settingsB64) {
            settings = try? JSONDecoder().decode(AppSettings.self, from: settingsData)
        }
        return BackupContents(goals: goals, settings: settings)
    }
}
