import ArgumentParser
import Foundation
import HttpServerCore

/// The main entry point for the HTTP server command-line application
///
/// This struct implements the ArgumentParser protocol to provide a command-line interface
/// for the HTTP server. It handles argument parsing, server configuration, and lifecycle management.
@main
struct HttpCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "http-server",
        abstract: "A high-performance HTTP server for serving static files",
        version: "1.0.0"
    )

    @Argument(help: "Directory path to serve files from")
    var directory: String

    @Option(name: [.short, .long], help: "Port to run the server on")
    var port: Int = 8080

    @Option(name: [.short, .long], help: "Host to bind the server to")
    var host: String = "127.0.0.1"

    /// Executes the HTTP server command asynchronously
    ///
    /// This method performs the following operations:
    /// 1. Validates the specified directory exists and is accessible
    /// 2. Creates and configures the HTTP server
    /// 3. Sets up signal handling for graceful shutdown
    /// 4. Starts the server and keeps it running
    ///
    /// - Throws: ValidationError if directory doesn't exist or isn't a directory
    /// - Throws: Server startup errors from HttpServer.start()
    mutating func run() async throws {
        print(
            "[\(Date())] Starting HTTP server - directory: \(directory), host: \(host), port: \(port)"
        )

        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: directory, isDirectory: &isDirectory) else {
            print("[\(Date())] ERROR: Directory does not exist: \(directory)")
            throw ValidationError("Directory '\(directory)' does not exist")
        }

        guard isDirectory.boolValue else {
            print("[\(Date())] ERROR: Path is not a directory: \(directory)")
            throw ValidationError("Path '\(directory)' is not a directory")
        }

        let server = HttpServer(
            documentRoot: directory,
            host: host,
            port: port
        )

        let signalSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        signalSource.setEventHandler { [server] in
            print("[\(Date())] Received SIGINT, shutting down server")
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
