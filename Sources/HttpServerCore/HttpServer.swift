import Foundation
import NIO
import NIOHTTP1
import NIOPosix

/// HTTP server for serving static files using SwiftNIO
///
/// This class implements a local HTTP server that serves static files from a specified
/// directory. It uses SwiftNIO for efficient networking and proper concurrency handling.
///
/// This class uses @unchecked Sendable because:
/// - The mutable serverChannel property is only accessed from async methods (start/stop)
/// - These methods are designed to be called sequentially, not concurrently
/// - SwiftNIO's Channel type is thread-safe for the operations we perform
/// - The lifecycle (start -> stop) ensures proper synchronization
///
/// Key features:
/// - Security protection against directory traversal attacks
/// - Automatic MIME type detection
/// - Directory listing when no index.html exists
/// - Structured logging of all requests and responses
/// - Graceful shutdown handling
public final class HttpServer: @unchecked Sendable {
    private let eventLoopGroup: EventLoopGroup

    private let documentRoot: String

    private let host: String

    private let port: Int

    private let indexFile: String

    private let logger: Logger

    /// The server channel for the bound socket
    ///
    /// This channel is set when the server starts and is used to properly close
    /// the server socket before shutting down the event loop group.
    private var serverChannel: Channel?

    /// Initialize the HTTP server with configuration parameters
    /// - Parameters:
    ///   - documentRoot: The root directory to serve files from
    ///   - host: The host address to bind to (defaults to "127.0.0.1")
    ///   - port: The port number to bind to (defaults to 3000)
    ///   - indexFile: The index file name to serve for directories (defaults to "index.html")
    ///   - logger: The logger instance for server logging
    public init(documentRoot: String, host: String, port: Int, indexFile: String, logger: Logger) {
        self.documentRoot = documentRoot
        self.host = host
        self.port = port
        self.indexFile = indexFile
        self.logger = logger
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    }

    /// Start the HTTP server and begin accepting connections
    ///
    /// This method configures and starts the SwiftNIO server with the following setup:
    /// - Creates a ServerBootstrap with the event loop group
    /// - Configures HTTP server pipeline with error handling
    /// - Adds the HttpFileHandler for processing requests
    /// - Binds to the specified host and port
    /// - Stores the server channel for proper shutdown
    /// - Logs server startup information
    ///
    /// - Throws: Server binding errors if the server cannot bind to the specified address/port
    public func start() async throws {
        let bootstrap = ServerBootstrap(group: eventLoopGroup)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).flatMap {
                    channel.pipeline.addHandler(
                        HttpFileHandler(
                            documentRoot: self.documentRoot,
                            indexFile: self.indexFile,
                            logger: self.logger
                        ))
                }
            }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)

        serverChannel = try await bootstrap.bind(host: host, port: port).get()
        logger.info("Server running at http://\(host):\(port)")
    }

    /// Stop the HTTP server gracefully
    ///
    /// This method shuts down the server by:
    /// - Logging the shutdown
    /// - Closing the server channel to stop accepting new connections
    /// - Closing the logger
    /// - Gracefully shutting down the event loop group
    /// - Allowing existing connections to complete
    ///
    /// - Returns: Void when the server has been shut down
    public func stop() async {
        logger.info("Shutting down HTTP server")

        // Close the server channel to stop accepting new connections
        if let channel = serverChannel {
            try? await channel.close()
        }

        logger.close()
        try? await eventLoopGroup.shutdownGracefully()
    }

    /// Deinitializer ensures proper cleanup of resources
    ///
    /// This method synchronously shuts down the event loop group if it hasn't been
    /// shut down already. This is a safety measure to prevent resource leaks.
    deinit {
        try? eventLoopGroup.syncShutdownGracefully()
    }
}
