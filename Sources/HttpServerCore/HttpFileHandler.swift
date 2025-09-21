import Foundation
import NIO
import NIOHTTP1

/// HTTP channel handler for serving static files
///
/// This class implements a SwiftNIO ChannelInboundHandler that processes HTTP requests
/// and serves static files from a specified document root. It includes comprehensive
/// security measures and logging capabilities.
///
/// Features:
/// - Serves static files with appropriate MIME types
/// - Directory listing when no index.html exists
/// - Security protection against directory traversal attacks
/// - Comprehensive request/response logging
/// - Support for GET requests only
final class HttpFileHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = HTTPServerRequestPart

    typealias OutboundOut = HTTPServerResponsePart

    private let documentRoot: String

    private let fileManager = FileManager.default

    /// Initialize the file handler with document root
    ///
    /// Creates a new HTTP file handler for serving static files from the specified
    /// document root directory.
    ///
    /// - Parameters:
    ///   - documentRoot: The root directory to serve files from
    init(documentRoot: String) {
        self.documentRoot = documentRoot
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
    /// 1. Validates the request method (only GET is supported)
    /// 2. Sanitizes the request path to prevent directory traversal
    /// 3. Resolves the full file path
    /// 4. Validates path safety
    /// 5. Serves the requested file or directory
    ///
    /// - Parameters:
    ///   - context: The channel handler context
    ///   - request: The HTTP request head containing method, URI, and headers
    private func handleRequest(context: ChannelHandlerContext, request: HTTPRequestHead) {
        let path = request.uri
        print("[\(Date())] Received \(request.method.rawValue) request for: \(path)")

        guard request.method == .GET else {
            sendResponse(context: context, status: .methodNotAllowed, body: "Method not allowed")
            return
        }

        // Use PathSecurity utility for safe path validation and resolution
        guard let pathInfo = PathSecurity.validateAndResolvePath(path, documentRoot: documentRoot)
        else {
            print("[\(Date())] WARNING: Path traversal attempt blocked: \(path)")
            sendResponse(context: context, status: .forbidden, body: "Forbidden")
            return
        }

        serveFile(context: context, path: pathInfo.resolved, requestPath: pathInfo.sanitized)
    }

    /// Serve a file or directory at the specified path
    ///
    /// This method determines whether the path points to a file or directory:
    /// - For files: serves the file directly
    /// - For directories: looks for index.html, serves it if found, otherwise generates directory listing
    ///
    /// - Parameters:
    ///   - context: The channel handler context
    ///   - path: The full file system path
    ///   - requestPath: The original request path for directory listing
    private func serveFile(context: ChannelHandlerContext, path: String, requestPath: String) {
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
            print("[\(Date())] File not found: \(path)")
            sendResponse(context: context, status: .notFound, body: "Not Found")
            return
        }

        if isDirectory.boolValue {
            let indexPath = URL(fileURLWithPath: path).appendingPathComponent("index.html").path
            if fileManager.fileExists(atPath: indexPath) {
                serveStaticFile(context: context, path: indexPath)
            } else {
                serveDirectoryListing(context: context, path: path, requestPath: requestPath)
            }
        } else {
            serveStaticFile(context: context, path: path)
        }
    }

    /// Serve a static file with appropriate headers and content
    ///
    /// This method:
    /// 1. Reads the file content
    /// 2. Determines the MIME type
    /// 3. Sets appropriate HTTP headers
    /// 4. Sends the file content as HTTP response
    /// 5. Logs the operation
    ///
    /// - Parameters:
    ///   - context: The channel handler context
    ///   - path: The full file system path to serve
    private func serveStaticFile(context: ChannelHandlerContext, path: String) {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let mimeType = MimeType.forPath(path)

            print("[\(Date())] Serving file: \(path) (\(data.count) bytes, \(mimeType))")

            var headers = HTTPHeaders()
            headers.add(name: "Content-Type", value: mimeType)
            headers.add(name: "Content-Length", value: String(data.count))

            let head = HTTPResponseHead(version: .http1_1, status: .ok, headers: headers)
            context.write(wrapOutboundOut(.head(head)), promise: nil)

            let buffer = context.channel.allocator.buffer(bytes: data)
            context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
            context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)

        } catch {
            print("[\(Date())] ERROR serving file \(path): \(error.localizedDescription)")
            sendResponse(
                context: context, status: .internalServerError, body: "Internal Server Error")
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
    ///   - path: The full directory path
    ///   - requestPath: The original request path for URL generation
    private func serveDirectoryListing(
        context: ChannelHandlerContext, path: String, requestPath: String
    ) {
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: path)
            let sortedContents = contents.sorted()

            let html = DirectoryListing.generateHTML(
                contents: sortedContents, requestPath: requestPath)

            print("[\(Date())] Serving directory listing: \(path) (\(contents.count) items)")

            var headers = HTTPHeaders()
            headers.add(name: "Content-Type", value: "text/html; charset=utf-8")
            headers.add(name: "Content-Length", value: String(html.utf8.count))

            let head = HTTPResponseHead(version: .http1_1, status: .ok, headers: headers)
            context.write(wrapOutboundOut(.head(head)), promise: nil)

            let buffer = context.channel.allocator.buffer(string: html)
            context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
            context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)

        } catch {
            print("[\(Date())] ERROR listing directory \(path): \(error.localizedDescription)")
            sendResponse(
                context: context, status: .internalServerError, body: "Internal Server Error")
        }
    }

    /// Send a simple HTTP response with plain text body
    ///
    /// This method is used for error responses and simple text responses.
    /// It sets appropriate headers and sends the response.
    ///
    /// - Parameters:
    ///   - context: The channel handler context
    ///   - status: The HTTP status code
    ///   - body: The response body as plain text
    private func sendResponse(
        context: ChannelHandlerContext, status: HTTPResponseStatus, body: String
    ) {
        var headers = HTTPHeaders()
        headers.add(name: "Content-Type", value: "text/plain; charset=utf-8")
        headers.add(name: "Content-Length", value: String(body.utf8.count))

        let head = HTTPResponseHead(version: .http1_1, status: status, headers: headers)
        context.write(wrapOutboundOut(.head(head)), promise: nil)

        let buffer = context.channel.allocator.buffer(string: body)
        context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
    }
}
