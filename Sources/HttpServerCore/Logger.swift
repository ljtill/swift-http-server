import Foundation

/// Thread-safe file and console logger for the HTTP server
///
/// This class provides centralized logging with dual output designed for local development.
/// Console output shows only startup/shutdown messages and errors without timestamps for clean
/// output, while file output logs everything including requests, file operations, warnings,
/// and errors with ISO8601 timestamps. The logger truncates existing log files on initialization
/// to provide a fresh log for each server session. This logger uses a serial DispatchQueue to
/// ensure thread-safe access across SwiftNIO's multi-threaded event loop group.
///
/// Key features:
/// - Queue-based concurrency for thread-safe logging
/// - Dual output with different formatting (console vs file)
/// - Log level filtering (info/error to console, all to file)
/// - ISO8601 timestamps in file logs
/// - Automatic log file truncation on initialization
public final class Logger: Sendable {

    /// Log level enumeration
    ///
    /// Defines the severity level of log messages for filtering and formatting.
    public enum Level: Sendable {
        case info       // Informational messages (console + file)
        case warning    // Warning messages (file only)
        case error      // Error messages (console + file)
        case debug      // Debug/trace messages (file only)
    }

    private let fileHandle: FileHandle?
    private let logFilePath: String?
    private let queue: DispatchQueue
    private let silent: Bool

    /// Initialize the logger with optional file output
    ///
    /// This method creates or truncates the log file and prepares it for writing.
    /// If the log file already exists, it will be removed and recreated to ensure
    /// a fresh log for each server session.
    ///
    /// - Parameters:
    ///   - logFilePath: Path to log file, or nil for console-only logging
    ///   - silent: If true, disables all logging output (default: false)
    /// - Throws: File creation or opening errors
    public init(logFilePath: String?, silent: Bool = false) throws {
        self.logFilePath = logFilePath
        self.silent = silent
        self.queue = DispatchQueue(label: "com.httpserver.logger", qos: .utility)

        if let path = logFilePath {
            // Remove existing log file to ensure fresh log
            if FileManager.default.fileExists(atPath: path) {
                try FileManager.default.removeItem(atPath: path)
            }

            // Create new log file
            guard FileManager.default.createFile(atPath: path, contents: nil, attributes: nil) else {
                throw NSError(
                    domain: "Logger",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to create log file at '\(path)'"]
                )
            }

            // Open file handle for writing
            guard let handle = FileHandle(forWritingAtPath: path) else {
                throw NSError(
                    domain: "Logger",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to open log file at '\(path)'"]
                )
            }

            self.fileHandle = handle

            // Write header to log file
            let formatter = ISO8601DateFormatter()
            let timestamp = formatter.string(from: Date())
            let header = "=== HTTP Server Log Started at \(timestamp) ===\n"
            if let data = header.data(using: .utf8) {
                try? handle.write(contentsOf: data)
            }
        } else {
            self.fileHandle = nil
        }
    }

    /// Log a message with specified level
    ///
    /// This method handles dual output based on log level:
    /// - Info and Error: Console (without timestamp) + File (with timestamp)
    /// - Warning and Debug: File only (with timestamp)
    ///
    /// When silent mode is enabled, all logging output is suppressed.
    ///
    /// - Parameters:
    ///   - level: The log level
    ///   - message: The message to log
    public func log(_ level: Level, _ message: String) {
        // Skip all logging if silent mode is enabled
        if silent {
            return
        }

        queue.async { [weak self] in
            guard let self = self else { return }

            // Console output: only info and error levels, without timestamps
            if self.shouldLogToConsole(level) {
                let consoleMessage = self.formatConsoleMessage(level: level, message: message)
                print(consoleMessage)
            }

            // File output: everything with timestamps
            if let handle = self.fileHandle {
                let fileMessage = self.formatFileMessage(level: level, message: message)
                if let data = (fileMessage + "\n").data(using: .utf8) {
                    try? handle.write(contentsOf: data)
                }
            }
        }
    }

    /// Log an informational message
    ///
    /// Info messages appear on both console and file.
    ///
    /// - Parameter message: The message to log
    public func info(_ message: String) {
        log(.info, message)
    }

    /// Log a warning message
    ///
    /// Warning messages appear in file only (not on console).
    ///
    /// - Parameter message: The message to log
    public func warning(_ message: String) {
        log(.warning, message)
    }

    /// Log an error message
    ///
    /// Error messages appear on both console and file with ERROR prefix.
    ///
    /// - Parameter message: The message to log
    public func error(_ message: String) {
        log(.error, message)
    }

    /// Log a debug message
    ///
    /// Debug messages appear in file only (not on console).
    ///
    /// - Parameter message: The message to log
    public func debug(_ message: String) {
        log(.debug, message)
    }

    /// Close the log file handle
    ///
    /// This method should be called during server shutdown to properly close
    /// the log file. Failures are silently ignored as this is best-effort cleanup.
    public func close() {
        queue.sync {
            try? fileHandle?.close()
        }
    }

    /// Format a console message without timestamp
    ///
    /// - Parameters:
    ///   - level: The log level
    ///   - message: The message to format
    /// - Returns: Formatted console message
    private func formatConsoleMessage(level: Level, message: String) -> String {
        let prefix = levelPrefix(level)
        return "\(prefix)\(message)"
    }

    /// Format a file message with ISO8601 timestamp
    ///
    /// - Parameters:
    ///   - level: The log level
    ///   - message: The message to format
    /// - Returns: Formatted file message with timestamp
    private func formatFileMessage(level: Level, message: String) -> String {
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: Date())
        let prefix = levelPrefix(level)
        return "[\(timestamp)] \(prefix)\(message)"
    }

    /// Get the prefix string for a log level
    ///
    /// - Parameter level: The log level
    /// - Returns: Prefix string (empty for info/debug, "ERROR: " or "WARNING: " for others)
    private func levelPrefix(_ level: Level) -> String {
        switch level {
        case .info, .debug:
            return ""
        case .warning:
            return "WARNING: "
        case .error:
            return "ERROR: "
        }
    }

    /// Determine if a log level should appear on console
    ///
    /// - Parameter level: The log level to check
    /// - Returns: true if the level should be logged to console
    private func shouldLogToConsole(_ level: Level) -> Bool {
        switch level {
        case .info, .error:
            return true
        case .warning, .debug:
            return false
        }
    }

    deinit {
        // Best-effort cleanup
        try? fileHandle?.close()
    }
}
