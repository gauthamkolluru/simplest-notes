import Foundation

public enum LocalNoteStoreError: Error, Equatable {
    case writeFailed(underlyingDescription: String)
    case readFailed(underlyingDescription: String)
}

/// Atomic writer seam for tests (simulate mid-write failure / disk full).
public protocol NoteFileWriting {
    func writeAtomically(_ data: Data, to url: URL) throws
}

public struct AtomicFileWriter: NoteFileWriting {
    public init() {}

    public func writeAtomically(_ data: Data, to url: URL) throws {
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let temp = dir.appendingPathComponent(".tmp-\(UUID().uuidString)")
        try data.write(to: temp, options: .atomic)
        if FileManager.default.fileExists(atPath: url.path) {
            _ = try FileManager.default.replaceItemAt(url, withItemAt: temp)
        } else {
            try FileManager.default.moveItem(at: temp, to: url)
        }
    }
}

/// On-device `note.txt` + `sync-state.json` (ADR-0002).
public final class LocalNoteStore {
    public let rootDirectory: URL
    public let writer: any NoteFileWriting
    private let fileManager: FileManager

    public var noteURL: URL { rootDirectory.appendingPathComponent("note.txt") }
    public var syncStateURL: URL { rootDirectory.appendingPathComponent("sync-state.json") }

    public init(
        rootDirectory: URL,
        writer: any NoteFileWriting = AtomicFileWriter(),
        fileManager: FileManager = .default
    ) {
        self.rootDirectory = rootDirectory
        self.writer = writer
        self.fileManager = fileManager
    }

    public func load() throws -> String {
        guard fileManager.fileExists(atPath: noteURL.path) else {
            return ""
        }
        let data: Data
        do {
            data = try Data(contentsOf: noteURL)
        } catch {
            throw LocalNoteStoreError.readFailed(underlyingDescription: String(describing: error))
        }

        if let text = String(data: data, encoding: .utf8) {
            return text
        }

        // T1.09 — never silently drop bytes
        let backupName = "note.corrupt-\(backupTimestamp()).bin"
        let backupURL = rootDirectory.appendingPathComponent(backupName)
        try? data.write(to: backupURL)
        return String(decoding: data, as: UTF8.self)
    }

    public func save(_ text: String) throws {
        do {
            try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
            try writer.writeAtomically(Data(text.utf8), to: noteURL)
        } catch let error as LocalNoteStoreError {
            throw error
        } catch {
            throw LocalNoteStoreError.writeFailed(underlyingDescription: String(describing: error))
        }
    }

    public func loadSyncState() -> SyncState {
        guard fileManager.fileExists(atPath: syncStateURL.path),
              let data = try? Data(contentsOf: syncStateURL)
        else {
            return .defaults
        }
        do {
            return try JSONDecoder().decode(SyncState.self, from: data)
        } catch {
            // Corrupt → defaults + dirty so sync reconciles safely
            var state = SyncState.defaults
            state.dirty = true
            return state
        }
    }

    public func saveSyncState(_ state: SyncState) throws {
        do {
            try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(state)
            try writer.writeAtomically(data, to: syncStateURL)
        } catch {
            throw LocalNoteStoreError.writeFailed(underlyingDescription: String(describing: error))
        }
    }

    private func backupTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}
