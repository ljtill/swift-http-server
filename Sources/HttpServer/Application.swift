import ArgumentParser
import Foundation
import HttpServerCore

/// The main entry point for the HTTP server command-line application
///
/// This struct implements the ArgumentParser protocol to provide a command-line interface
/// for the HTTP server. It handles argument parsing, validates input parameters, configures
/// the server with the specified options, and manages the server lifecycle including graceful
/// shutdown on SIGINT signals.
///
/// Key features:
/// - Directory path validation and verification
/// - Configurable host, port, and index file options
/// - Logger initialization with file output
/// - Graceful shutdown handling on Ctrl+C
/// - Comprehensive error reporting
@main
struct HttpCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "http-server",
        abstract: "A local HTTP server for serving static files",
        version: "1.0.0"
    )

    @Argument(help: "Directory path to serve files from")
    var directory: String

    @Option(name: [.short, .long], help: "Port to run the server on")
    var port: Int = 3000

    @Option(name: [.short, .long], help: "Host to bind the server to")
    var host: String = "127.0.0.1"

    @Option(name: [.long], help: "Path to log file (default: app.log in current directory)")
    var logFile: String = "app.log"

    @Option(name: [.long], help: "Index file name to serve for directories (default: index.html)")
    var indexFile: String = "index.html"

    /// Executes the HTTP server command asynchronously
    ///
    /// This method performs the following operations:
    /// 1. Initializes the logger with specified log file
    /// 2. Validates the specified directory exists and is accessible
    /// 3. Creates and configures the HTTP server
    /// 4. Sets up signal handling for graceful shutdown
    /// 5. Starts the server and keeps it running
    ///
    /// - Throws: ValidationError if directory doesn't exist or isn't a directory, or logger fails
    /// - Throws: Server startup errors from HttpServer.start()
    mutating func run() async throws {
        let logger: Logger
        do {
            logger = try Logger(logFilePath: logFile)
        } catch {
            print("ERROR: Failed to initialize logger: \(error.localizedDescription)")
            throw ValidationError("Failed to initialize logger at '\(logFile)'")
        }

        logger.debug(
            "Starting HTTP server - directory: \(directory), host: \(host), port: \(port), indexFile: \(indexFile)"
        )

        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: directory, isDirectory: &isDirectory) else {
            logger.error("Directory does not exist: \(directory)")
            throw ValidationError("Directory '\(directory)' does not exist")
        }

        guard isDirectory.boolValue else {
            logger.error("Path is not a directory: \(directory)")
            throw ValidationError("Path '\(directory)' is not a directory")
        }

        let server = HttpServer(
            documentRoot: directory,
            host: host,
            port: port,
            indexFile: indexFile,
            logger: logger
        )

        // Set up graceful shutdown on SIGINT (Ctrl+C)
        // SIG_IGN prevents default termination, allowing custom handler to run
        let signalSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        signalSource.setEventHandler { [server] in
            Task { @MainActor in
                _ = await server.stop()
                Foundation.exit(0)
            }
        }
        signalSource.resume()
        signal(SIGINT, SIG_IGN)

        try await server.start()

        try await Task.sleep(nanoseconds: .max)
    }
}
