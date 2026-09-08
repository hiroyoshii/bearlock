import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

public enum LockRepositoryError: Error {
    case corruptState(URL)
}

/// A stable sidecar file protects atomic replacements of the JSON file. All readers and
/// writers participate, and each instance also serializes access to its codecs.
public final class JSONFileLockRepository: LockRepository, @unchecked Sendable {
    private let fileURL: URL
    private let mutex = NSRecursiveLock()
    private var accessDepth = 0

    public init(fileURL: URL) { self.fileURL = fileURL }

    public func withExclusiveAccess<T>(_ body: () throws -> T) throws -> T {
        mutex.lock()
        defer { mutex.unlock() }
        if accessDepth > 0 { return try body() }
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let fd = open(fileURL.appendingPathExtension("lock").path, O_CREAT | O_RDWR, mode_t(0o600))
        guard fd >= 0 else { throw posixError() }
        defer { close(fd) }
        while flock(fd, LOCK_EX) != 0 {
            if errno != EINTR { throw posixError() }
        }
        accessDepth += 1
        defer {
            accessDepth -= 1
            _ = flock(fd, LOCK_UN)
        }
        return try body()
    }

    public func load() throws -> LockState {
        try withExclusiveAccess {
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
    }

    public func save(_ state: LockState) throws {
        try withExclusiveAccess {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .custom { date, encoder in
                var container = encoder.singleValueContainer()
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                try container.encode(formatter.string(from: date))
            }
            let data = try encoder.encode(state)
            #if os(iOS)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            #else
            try data.write(to: fileURL, options: .atomic)
            #endif
        }
    }

    private func posixError() -> POSIXError {
        POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }
}
