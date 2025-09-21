import Foundation
import NIO
import NIOHTTP1

/// HTTP channel handler for serving static files
///
/// This class implements a SwiftNIO ChannelInboundHandler that processes HTTP requests
/// and serves static files from a specified document root. It includes comprehensive
/// security measures and logging capabilities. This class conforms to @unchecked Sendable
/// because all stored properties are immutable, FileManager.default is thread-safe, and
/// each handler instance is confined to a single NIO event loop for its lifetime.
///
/// Key features:
/// - Serves static files with appropriate MIME types
/// - Directory listing when no index.html exists
/// - Security protection against directory traversal attacks
/// - Comprehensive request/response logging
/// - Support for GET, HEAD, and OPTIONS requests
/// - CORS headers for local development (permissive configuration)
final class HttpFileHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = HTTPServerRequestPart

    typealias OutboundOut = HTTPServerResponsePart

    private let documentRoot: String

    private let indexFile: String

    private let fileManager = FileManager.default

    private let logger: Logger

    /// Initialize the file handler with document root, index file, and logger
    ///
    /// Creates a new HTTP file handler for serving static files from the specified
    /// document root directory.
    ///
    /// - Parameters:
    ///   - documentRoot: The root directory to serve files from
    ///   - indexFile: The index file name to serve for directories
    ///   - logger: The logger instance for request logging
    init(documentRoot: String, indexFile: String, logger: Logger) {
        self.documentRoot = documentRoot
        self.indexFile = indexFile
        self.logger = logger
    }

    /// Add CORS headers to an HTTP response for local development
    ///
    /// This method adds permissive CORS headers suitable for local development:
    /// - Allows all origins (*)
    /// - Allows GET, HEAD, and OPTIONS methods
    /// - Allows all request headers
    /// - Caches preflight responses for 24 hours
    ///
    /// - Parameter headers: The HTTPHeaders object to modify (mutating)
    private static func addCorsHeaders(to headers: inout HTTPHeaders) {
        headers.add(name: "Access-Control-Allow-Origin", value: "*")
        headers.add(name: "Access-Control-Allow-Methods", value: "GET, HEAD, OPTIONS")
        headers.add(name: "Access-Control-Allow-Headers", value: "*")
        headers.add(name: "Access-Control-Max-Age", value: "86400")
    }

    /// Handle incoming channel data (HTTP request parts)
    ///
    /// This method processes different parts of HTTP requests. Only the request head
    /// is processed for file serving, while body and end parts are ignored.
    ///
    /// - Parameters:
    ///   - context: The channel handler context
    ///   - data: The incoming data wrapped in NIOAny
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let requestPart = unwrapInboundIn(data)

        switch requestPart {
        case .head(let request):
            handleRequest(context: context, request: request)
        case .body, .end:
            break
        }
    }

    /// Handle an HTTP request by processing the request head
    ///
    /// This method performs the following operations:
    /// 1. Validates the request method (GET and HEAD are supported)
    /// 2. Strips query strings from the URI
    /// 3. Sanitizes the request path to prevent directory traversal
    /// 4. Resolves the full file path
    /// 5. Validates path safety
    /// 6. Serves the requested file or directory
    ///
    /// - Parameters:
    ///   - context: The channel handler context
    ///   - request: The HTTP request head containing method, URI, and headers
    private func handleRequest(context: ChannelHandlerContext, request: HTTPRequestHead) {
        // Strip query string from URI (e.g., "/index.html?version=1" becomes "/index.html")
        let path = request.uri.split(separator: "?", maxSplits: 1).first.map(String.init) ?? "/"
        logger.debug("Received \(request.method.rawValue) request for: \(path)")

        // Handle OPTIONS preflight requests for CORS
        if request.method == .OPTIONS {
            handleOptionsRequest(context: context)
            return
        }

        guard request.method == .GET || request.method == .HEAD else {
            sendResponse(context: context, method: request.method, status: .methodNotAllowed, body: "Method not allowed")
            return
        }

        // Use PathSecurity utility for safe path validation and resolution
        guard let pathInfo = PathSecurity.validateAndResolvePath(path, documentRoot: documentRoot)
        else {
            logger.warning("Path traversal attempt blocked: \(path)")
            sendResponse(context: context, method: request.method, status: .forbidden, body: "Forbidden")
            return
        }

        serveFile(context: context, method: request.method, path: pathInfo.resolved, requestPath: pathInfo.sanitized)
    }

    /// Handle OPTIONS preflight requests for CORS
    ///
    /// This method responds to CORS preflight requests with appropriate headers
    /// and a 204 No Content status. OPTIONS requests are used by browsers to
    /// determine if cross-origin requests are allowed.
    ///
    /// - Parameter context: The channel handler context
    private func handleOptionsRequest(context: ChannelHandlerContext) {
        logger.debug("Received OPTIONS request (CORS preflight)")

        var headers = HTTPHeaders()
        Self.addCorsHeaders(to: &headers)

        let head = HTTPResponseHead(version: .http1_1, status: .noContent, headers: headers)
        context.write(wrapOutboundOut(.head(head)), promise: nil)
        context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
    }

    /// Serve a file or directory at the specified path
    ///
    /// This method determines whether the path points to a file or directory:
    /// - For files: serves the file directly
    /// - For directories: looks for the configured index file, serves it if found, otherwise generates directory listing
    ///
    /// - Parameters:
    ///   - context: The channel handler context
    ///   - method: The HTTP request method (GET or HEAD)
    ///   - path: The full file system path
    ///   - requestPath: The original request path for directory listing
    private func serveFile(context: ChannelHandlerContext, method: HTTPMethod, path: String, requestPath: String) {
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
            logger.debug("File not found: \(path)")
            sendResponse(context: context, method: method, status: .notFound, body: "Not Found")
            return
        }

        if isDirectory.boolValue {
            let indexPath = URL(fileURLWithPath: path).appendingPathComponent(indexFile).path
            if fileManager.fileExists(atPath: indexPath) {
                serveStaticFile(context: context, method: method, path: indexPath)
            } else {
                serveDirectoryListing(context: context, method: method, path: path, requestPath: requestPath)
            }
        } else {
            serveStaticFile(context: context, method: method, path: path)
        }
    }

    /// Serve a static file with appropriate headers and content
    ///
    /// This method:
    /// 1. Reads the file content (metadata only for HEAD requests)
    /// 2. Determines the MIME type
    /// 3. Sets appropriate HTTP headers
    /// 4. Sends the file content as HTTP response (headers only for HEAD requests)
    /// 5. Logs the operation
    ///
    /// - Parameters:
    ///   - context: The channel handler context
    ///   - method: The HTTP request method (GET or HEAD)
    ///   - path: The full file system path to serve
    private func serveStaticFile(context: ChannelHandlerContext, method: HTTPMethod, path: String) {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let mimeType = MimeType.forPath(path)

            logger.debug("Serving file: \(path) (\(data.count) bytes, \(mimeType))")

            var headers = HTTPHeaders()
            headers.add(name: "Content-Type", value: mimeType)
            headers.add(name: "Content-Length", value: String(data.count))
            Self.addCorsHeaders(to: &headers)

            let head = HTTPResponseHead(version: .http1_1, status: .ok, headers: headers)
            context.write(wrapOutboundOut(.head(head)), promise: nil)

            // For HEAD requests, only send headers without body
            if method == .GET {
                let buffer = context.channel.allocator.buffer(bytes: data)
                context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
            }
            context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)

        } catch {
            logger.error("Failed to serve file \(path): \(error.localizedDescription)")
            sendResponse(
                context: context, method: method, status: .internalServerError, body: "Internal Server Error")
        }
    }

    /// Serve a directory listing as HTML
    ///
    /// This method generates an HTML directory listing when no index.html is found:
    /// 1. Lists directory contents
    /// 2. Generates HTML with proper styling
    /// 3. Includes navigation links
    /// 4. Logs the operation
    ///
    /// - Parameters:
    ///   - context: The channel handler context
    ///   - method: The HTTP request method (GET or HEAD)
    ///   - path: The full directory path
    ///   - requestPath: The original request path for URL generation
    private func serveDirectoryListing(
        context: ChannelHandlerContext, method: HTTPMethod, path: String, requestPath: String
    ) {
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: path)

            // Check each item and append "/" to directories for proper [DIR]/[FILE] detection
            let processedContents = contents.map { item -> String in
                let itemPath = URL(fileURLWithPath: path).appendingPathComponent(item).path
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: itemPath, isDirectory: &isDirectory),
                   isDirectory.boolValue {
                    return item + "/"
                }
                return item
            }
            let sortedContents = processedContents.sorted()

            let html = DirectoryListing.generateHTML(
                contents: sortedContents, requestPath: requestPath)

            logger.debug("Serving directory listing: \(path) (\(contents.count) items)")

            var headers = HTTPHeaders()
            headers.add(name: "Content-Type", value: "text/html; charset=utf-8")
            headers.add(name: "Content-Length", value: String(html.utf8.count))
            Self.addCorsHeaders(to: &headers)

            let head = HTTPResponseHead(version: .http1_1, status: .ok, headers: headers)
            context.write(wrapOutboundOut(.head(head)), promise: nil)

            // For HEAD requests, only send headers without body
            if method == .GET {
                let buffer = context.channel.allocator.buffer(string: html)
                context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
            }
            context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)

        } catch {
            logger.error("Failed to list directory \(path): \(error.localizedDescription)")
            sendResponse(
                context: context, method: method, status: .internalServerError, body: "Internal Server Error")
        }
    }

    /// Send a simple HTTP response with plain text body
    ///
    /// This method is used for error responses and simple text responses.
    /// It sets appropriate headers and sends the response.
    ///
    /// - Parameters:
    ///   - context: The channel handler context
    ///   - method: The HTTP request method (GET or HEAD)
    ///   - status: The HTTP status code
    ///   - body: The response body as plain text
    private func sendResponse(
        context: ChannelHandlerContext, method: HTTPMethod, status: HTTPResponseStatus, body: String
    ) {
        var headers = HTTPHeaders()
        headers.add(name: "Content-Type", value: "text/plain; charset=utf-8")
        headers.add(name: "Content-Length", value: String(body.utf8.count))
        Self.addCorsHeaders(to: &headers)

        let head = HTTPResponseHead(version: .http1_1, status: status, headers: headers)
        context.write(wrapOutboundOut(.head(head)), promise: nil)

        // For HEAD requests, only send headers without body
        if method == .GET {
            let buffer = context.channel.allocator.buffer(string: body)
            context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        }
        context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
    }
}
