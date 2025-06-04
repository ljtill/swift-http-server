import Foundation
import Logging

/// A log handler that writes log messages to a file
public struct FileLogHandler: LogHandler {
    private let fileHandle: FileHandle
    private let label: String

    public var logLevel: Logger.Level = .info
    public var metadata: Logger.Metadata = [:]

    /// Initialize a file log handler with a file URL
    /// - Parameters:
    ///   - label: The logger label
    ///   - fileURL: The URL of the file to write logs to
    ///   - logLevel: The minimum log level to handle (defaults to .info)
    public init(label: String, fileURL: URL, logLevel: Logger.Level = .info) throws {
        self.label = label
        self.logLevel = logLevel

        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true, attributes: nil)

        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
        }

        self.fileHandle = try FileHandle(forWritingTo: fileURL)
        self.fileHandle.truncateFile(atOffset: 0)
    }

    /// Access metadata values by key
    /// - Parameter metadataKey: The metadata key to access
    /// - Returns: The metadata value for the given key, or nil if not found
    public subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get {
            return self.metadata[metadataKey]
        }
        set {
            self.metadata[metadataKey] = newValue
        }
    }

    /// Log a message with the specified level and metadata
    /// - Parameters:
    ///   - level: The log level for this message
    ///   - message: The message to log
    ///   - metadata: Additional metadata to include with the log entry
    ///   - source: The source identifier for the log entry
    ///   - file: The file name where the log call originated
    ///   - function: The function name where the log call originated
    ///   - line: The line number where the log call originated
    public func log(
        level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?, source: String,
        file: String, function: String, line: UInt
    ) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let levelString = level.rawValue.uppercased()

        var combinedMetadata = self.metadata
        if let metadata = metadata {
            combinedMetadata.merge(metadata) { _, new in new }
        }

        let metadataString = combinedMetadata.isEmpty ? "" : " \(combinedMetadata)"
        let logEntry = "[\(timestamp)] [\(levelString)] [\(label)] \(message)\(metadataString)\n"

        if let data = logEntry.data(using: .utf8) {
            fileHandle.write(data)
        }
    }
}

/// Factory for creating file-based loggers
public struct FileLoggerFactory {
    private let fileURL: URL
    private let logLevel: Logger.Level

    /// Initialize with a file URL and log level
    /// - Parameters:
    ///   - fileURL: The URL of the file to write logs to
    ///   - logLevel: The minimum log level to handle (defaults to .info)
    public init(fileURL: URL, logLevel: Logger.Level = .info) {
        self.fileURL = fileURL
        self.logLevel = logLevel
    }

    /// Create a logger that writes to the configured file
    /// - Parameter label: The logger label
    /// - Returns: A configured logger
    public func makeLogger(label: String) throws -> Logger {
        let handler = try FileLogHandler(label: label, fileURL: fileURL, logLevel: logLevel)
        return Logger(label: label, factory: { _ in handler })
    }
}

/// Convenience methods for setting up file logging
extension Logger {
    /// Create a logger that writes to a file
    /// - Parameters:
    ///   - label: The logger label
    ///   - filePath: The path to the log file
    ///   - logLevel: The minimum log level to handle (defaults to .info)
    /// - Returns: A configured logger
    public static func fileLogger(label: String, filePath: String, logLevel: Logger.Level = .info)
        throws -> Logger
    {
        let fileURL = URL(fileURLWithPath: filePath)
        let factory = FileLoggerFactory(fileURL: fileURL, logLevel: logLevel)
        return try factory.makeLogger(label: label)
    }

    /// Create a logger that writes to a file in the current directory
    /// - Parameters:
    ///   - label: The logger label
    ///   - fileName: The name of the log file (defaults to "app.log")
    ///   - logLevel: The minimum log level to handle (defaults to .info)
    /// - Returns: A configured logger
    public static func fileLogger(
        label: String, fileName: String = "app.log", logLevel: Logger.Level = .info
    ) throws -> Logger {
        let currentDirectory = FileManager.default.currentDirectoryPath
        let filePath = "\(currentDirectory)/\(fileName)"
        return try fileLogger(label: label, filePath: filePath, logLevel: logLevel)
    }
}
