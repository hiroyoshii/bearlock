import Foundation

public enum LockRepositoryError: Error {
    case corruptState(URL)
}

/// The app is the sole writer. Extensions only read the atomically replaced snapshot, so
/// readers always observe either the previous complete state or the next complete state.
public final class JSONFileLockRepository: LockRepository, @unchecked Sendable {
    private let fileURL: URL

    public init(fileURL: URL) { self.fileURL = fileURL }

    public func load() throws -> LockState {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return LockState()
        }
        // I/O errors propagate unchanged. Never turn inaccessible data into an empty state.
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: value) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: value) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO8601 date")
            }
            return date
        }
        do {
            return try decoder.decode(LockState.self, from: data)
        } catch is DecodingError {
            // Keep the original in place: subsequent reads must not silently unlock or
            // overwrite it. Preserve one diagnostic copy until the original is repaired.
            let backup = fileURL.deletingPathExtension().appendingPathExtension("corrupt.json")
            if !FileManager.default.fileExists(atPath: backup.path) {
                try? data.write(to: backup, options: .atomic)
            }
            throw LockRepositoryError.corruptState(fileURL)
        }
    }

    public func save(_ state: LockState) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            try container.encode(formatter.string(from: date))
        }
        let data = try encoder.encode(state)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        #if os(iOS)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: fileURL, options: .atomic)
        #endif
    }
}
