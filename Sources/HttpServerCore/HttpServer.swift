import Foundation
import NIO
import NIOHTTP1
import NIOPosix

/// HTTP server for serving static files using SwiftNIO
/// 
/// This class implements a high-performance HTTP server that serves static files from a specified
/// directory. It uses SwiftNIO for efficient networking and includes features like:
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
    
    /// Initialize the HTTP server with configuration parameters
    /// - Parameters:
    ///   - documentRoot: The root directory to serve files from
    ///   - host: The host address to bind to (defaults to "127.0.0.1")
    ///   - port: The port number to bind to (defaults to 8080)
    public init(documentRoot: String, host: String = "127.0.0.1", port: Int = 8080) {
        self.documentRoot = documentRoot
        self.host = host
        self.port = port
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    }
    
    /// Start the HTTP server and begin accepting connections
    /// 
    /// This method configures and starts the SwiftNIO server with the following setup:
    /// - Creates a ServerBootstrap with the event loop group
    /// - Configures HTTP server pipeline with error handling
    /// - Adds the HttpFileHandler for processing requests
    /// - Binds to the specified host and port
    /// - Logs server startup information
    /// 
    /// - Throws: Server binding errors if the server cannot bind to the specified address/port
    public func start() async throws {
        let bootstrap = ServerBootstrap(group: eventLoopGroup)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).flatMap {
                    channel.pipeline.addHandler(HttpFileHandler(
                        documentRoot: self.documentRoot
                    ))
                }
            }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
        
        _ = try await bootstrap.bind(host: host, port: port).get()
        print("[\(Date())] Server running at http://\(host):\(port)")
    }
    
    /// Stop the HTTP server gracefully
    ///
    /// This method shuts down the server by:
    /// - Gracefully shutting down the event loop group
    /// - Allowing existing connections to complete
    ///
    /// - Returns: Void when the server has been shut down
    public func stop() async -> Void {
        print("[\(Date())] Shutting down HTTP server")
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