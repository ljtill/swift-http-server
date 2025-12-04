import AsyncHTTPClient
import Foundation
import NIOCore
import Testing

@testable import HttpServerCore

struct IntegrationTests {
    /// Create a temporary test directory with sample files for integration testing
    ///
    /// Creates a unique temporary directory containing:
    /// - index.html: Basic HTML file for testing
    /// - test.txt: Plain text file for testing
    ///
    /// - Returns: URL to the temporary test directory
    private func createTestDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)

        try "<h1>Test</h1>".write(
            to: testDir.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)
        try "test content".write(
            to: testDir.appendingPathComponent("test.txt"), atomically: true, encoding: .utf8)

        return testDir
    }

    @Test("HttpServer serves files")
    func httpServerServesFiles() async throws {
        let testDir = try createTestDirectory()
        defer { try? FileManager.default.removeItem(at: testDir) }

        let logger = try Logger(logFilePath: nil, silent: true)
        let port = Int.random(in: 49152...65535)
        let server = HttpServer(
            documentRoot: testDir.path,
            host: "127.0.0.1",
            port: port,
            indexFile: "index.html",
            logger: logger
        )

        try await server.start()

        let request = HTTPClientRequest(url: "http://127.0.0.1:\(port)")
        let response = try await HTTPClient.shared.execute(request, timeout: .seconds(30))

        #expect(response.status.code == 200)
        #expect(response.headers["content-type"].contains("text/html; charset=utf-8"))

        let body = try await response.body.collect(upTo: 1024 * 1024)
        let content = body.getString(at: body.readerIndex, length: body.readableBytes)

        #expect(content?.contains("<h1>Test</h1>") == true)

        await server.stop()
    }

    @Test("HttpServer serves directory listing when no index.html")
    func httpServerServesDirectoryListing() async throws {
        let testDir = try createTestDirectory()
        defer { try? FileManager.default.removeItem(at: testDir) }

        try FileManager.default.removeItem(at: testDir.appendingPathComponent("index.html"))

        let logger = try Logger(logFilePath: nil, silent: true)
        let port = Int.random(in: 49152...65535)
        let server = HttpServer(
            documentRoot: testDir.path,
            host: "127.0.0.1",
            port: port,
            indexFile: "index.html",
            logger: logger
        )

        try await server.start()

        let request = HTTPClientRequest(url: "http://127.0.0.1:\(port)")
        let response = try await HTTPClient.shared.execute(request, timeout: .seconds(30))

        #expect(response.status.code == 200)
        #expect(response.headers["content-type"].contains("text/html; charset=utf-8"))

        let body = try await response.body.collect(upTo: 1024 * 1024)
        let content = body.getString(at: body.readerIndex, length: body.readableBytes)

        #expect(content?.contains("Directory listing") == true)
        #expect(content?.contains("test.txt") == true)
        #expect(content?.contains("[FILE]") == true)

        await server.stop()
    }

    @Test("HttpServer returns 404 for non-existent files")
    func httpServerReturns404() async throws {
        let testDir = try createTestDirectory()
        defer { try? FileManager.default.removeItem(at: testDir) }

        let logger = try Logger(logFilePath: nil, silent: true)
        let port = Int.random(in: 49152...65535)
        let server = HttpServer(
            documentRoot: testDir.path,
            host: "127.0.0.1",
            port: port,
            indexFile: "index.html",
            logger: logger
        )

        try await server.start()

        let request = HTTPClientRequest(url: "http://127.0.0.1:\(port)/nonexistent.txt")
        let response = try await HTTPClient.shared.execute(request, timeout: .seconds(30))

        #expect(response.status.code == 404)

        await server.stop()
    }

    @Test("HttpServer rejects POST method")
    func httpServerRejectsPOSTMethod() async throws {
        let testDir = try createTestDirectory()
        defer { try? FileManager.default.removeItem(at: testDir) }

        let logger = try Logger(logFilePath: nil, silent: true)
        let port = Int.random(in: 49152...65535)
        let server = HttpServer(
            documentRoot: testDir.path,
            host: "127.0.0.1",
            port: port,
            indexFile: "index.html",
            logger: logger
        )

        try await server.start()

        var request = HTTPClientRequest(url: "http://127.0.0.1:\(port)")
        request.method = .POST
        request.body = .bytes(ByteBuffer(string: "test data"))

        let response = try await HTTPClient.shared.execute(request, timeout: .seconds(30))

        #expect(response.status.code == 405)

        await server.stop()
    }

    @Test("HttpServer rejects PUT method")
    func httpServerRejectsPUTMethod() async throws {
        let testDir = try createTestDirectory()
        defer { try? FileManager.default.removeItem(at: testDir) }

        let logger = try Logger(logFilePath: nil, silent: true)
        let port = Int.random(in: 49152...65535)
        let server = HttpServer(
            documentRoot: testDir.path,
            host: "127.0.0.1",
            port: port,
            indexFile: "index.html",
            logger: logger
        )

        try await server.start()

        var request = HTTPClientRequest(url: "http://127.0.0.1:\(port)/test.txt")
        request.method = .PUT
        request.body = .bytes(ByteBuffer(string: "new content"))

        let response = try await HTTPClient.shared.execute(request, timeout: .seconds(30))

        #expect(response.status.code == 405)

        await server.stop()
    }

    @Test("HttpServer supports HEAD request")
    func httpServerSupportsHEADRequest() async throws {
        let testDir = try createTestDirectory()
        defer { try? FileManager.default.removeItem(at: testDir) }

        let logger = try Logger(logFilePath: nil, silent: true)
        let port = Int.random(in: 49152...65535)
        let server = HttpServer(
            documentRoot: testDir.path,
            host: "127.0.0.1",
            port: port,
            indexFile: "index.html",
            logger: logger
        )

        try await server.start()

        var request = HTTPClientRequest(url: "http://127.0.0.1:\(port)")
        request.method = .HEAD

        let response = try await HTTPClient.shared.execute(request, timeout: .seconds(30))

        #expect(response.status.code == 200)
        #expect(response.headers["content-type"].contains("text/html; charset=utf-8"))
        #expect(response.headers["content-length"].first != nil)

        // HEAD should not include response body
        let body = try await response.body.collect(upTo: 1024 * 1024)
        #expect(body.readableBytes == 0)

        await server.stop()
    }

    @Test("HttpServer serves custom index file")
    func httpServerServesCustomIndexFile() async throws {
        let testDir = try createTestDirectory()
        defer { try? FileManager.default.removeItem(at: testDir) }

        try FileManager.default.removeItem(at: testDir.appendingPathComponent("index.html"))
        try "<h1>Custom Home</h1>".write(
            to: testDir.appendingPathComponent("home.html"),
            atomically: true,
            encoding: .utf8
        )

        let logger = try Logger(logFilePath: nil, silent: true)
        let port = Int.random(in: 49152...65535)
        let server = HttpServer(
            documentRoot: testDir.path,
            host: "127.0.0.1",
            port: port,
            indexFile: "home.html",
            logger: logger
        )

        try await server.start()

        let request = HTTPClientRequest(url: "http://127.0.0.1:\(port)")
        let response = try await HTTPClient.shared.execute(request, timeout: .seconds(30))

        #expect(response.status.code == 200)
        #expect(response.headers["content-type"].contains("text/html; charset=utf-8"))

        let body = try await response.body.collect(upTo: 1024 * 1024)
        let content = body.getString(at: body.readerIndex, length: body.readableBytes)

        #expect(content?.contains("<h1>Custom Home</h1>") == true)

        await server.stop()
    }

    @Test("HttpServer shows directory listing when custom index file not found")
    func httpServerFallsBackToDirectoryListing() async throws {
        let testDir = try createTestDirectory()
        defer { try? FileManager.default.removeItem(at: testDir) }

        try FileManager.default.removeItem(at: testDir.appendingPathComponent("index.html"))

        let logger = try Logger(logFilePath: nil, silent: true)
        let port = Int.random(in: 49152...65535)
        let server = HttpServer(
            documentRoot: testDir.path,
            host: "127.0.0.1",
            port: port,
            indexFile: "custom.html",
            logger: logger
        )

        try await server.start()

        let request = HTTPClientRequest(url: "http://127.0.0.1:\(port)")
        let response = try await HTTPClient.shared.execute(request, timeout: .seconds(30))

        #expect(response.status.code == 200)
        #expect(response.headers["content-type"].contains("text/html; charset=utf-8"))

        let body = try await response.body.collect(upTo: 1024 * 1024)
        let content = body.getString(at: body.readerIndex, length: body.readableBytes)

        // Should show directory listing, not error
        #expect(content?.contains("Directory listing") == true)
        #expect(content?.contains("test.txt") == true)

        await server.stop()
    }

    @Test("HttpServer handles index file names with valid special characters")
    func httpServerHandlesSpecialCharacterIndexFile() async throws {
        let testDir = try createTestDirectory()
        defer { try? FileManager.default.removeItem(at: testDir) }

        let customIndexName = "main_index-v2.html"
        try "<h1>Special Chars</h1>".write(
            to: testDir.appendingPathComponent(customIndexName),
            atomically: true,
            encoding: .utf8
        )

        let logger = try Logger(logFilePath: nil, silent: true)
        let port = Int.random(in: 49152...65535)
        let server = HttpServer(
            documentRoot: testDir.path,
            host: "127.0.0.1",
            port: port,
            indexFile: customIndexName,
            logger: logger
        )

        try await server.start()

        let request = HTTPClientRequest(url: "http://127.0.0.1:\(port)")
        let response = try await HTTPClient.shared.execute(request, timeout: .seconds(30))

        #expect(response.status.code == 200)

        let body = try await response.body.collect(upTo: 1024 * 1024)
        let content = body.getString(at: body.readerIndex, length: body.readableBytes)

        #expect(content?.contains("<h1>Special Chars</h1>") == true)

        await server.stop()
    }

    @Test("HttpServer ignores query strings in URLs")
    func httpServerIgnoresQueryStrings() async throws {
        let testDir = try createTestDirectory()
        defer { try? FileManager.default.removeItem(at: testDir) }

        let logger = try Logger(logFilePath: nil, silent: true)
        let port = Int.random(in: 49152...65535)
        let server = HttpServer(
            documentRoot: testDir.path,
            host: "127.0.0.1",
            port: port,
            indexFile: "index.html",
            logger: logger
        )

        try await server.start()

        // Test with query string - should serve index.html
        let request = HTTPClientRequest(url: "http://127.0.0.1:\(port)/?version=1&cache=false")
        let response = try await HTTPClient.shared.execute(request, timeout: .seconds(30))

        #expect(response.status.code == 200)
        #expect(response.headers["content-type"].contains("text/html; charset=utf-8"))

        let body = try await response.body.collect(upTo: 1024 * 1024)
        let content = body.getString(at: body.readerIndex, length: body.readableBytes)

        #expect(content?.contains("<h1>Test</h1>") == true)

        await server.stop()
    }

    @Test("HttpServer includes CORS headers on file responses")
    func httpServerIncludesCorsHeadersOnFiles() async throws {
        let testDir = try createTestDirectory()
        defer { try? FileManager.default.removeItem(at: testDir) }

        let logger = try Logger(logFilePath: nil, silent: true)
        let port = Int.random(in: 49152...65535)
        let server = HttpServer(
            documentRoot: testDir.path,
            host: "127.0.0.1",
            port: port,
            indexFile: "index.html",
            logger: logger
        )

        try await server.start()

        let request = HTTPClientRequest(url: "http://127.0.0.1:\(port)/test.txt")
        let response = try await HTTPClient.shared.execute(request, timeout: .seconds(30))

        #expect(response.status.code == 200)

        // Verify CORS headers
        #expect(response.headers["access-control-allow-origin"].contains("*"))
        #expect(response.headers["access-control-allow-methods"].contains("GET, HEAD, OPTIONS"))
        #expect(response.headers["access-control-allow-headers"].contains("*"))
        #expect(response.headers["access-control-max-age"].contains("86400"))

        await server.stop()
    }

    @Test("HttpServer includes CORS headers on directory listings")
    func httpServerIncludesCorsHeadersOnDirectoryListing() async throws {
        let testDir = try createTestDirectory()
        defer { try? FileManager.default.removeItem(at: testDir) }

        // Remove index.html to trigger directory listing
        try FileManager.default.removeItem(at: testDir.appendingPathComponent("index.html"))

        let logger = try Logger(logFilePath: nil, silent: true)
        let port = Int.random(in: 49152...65535)
        let server = HttpServer(
            documentRoot: testDir.path,
            host: "127.0.0.1",
            port: port,
            indexFile: "index.html",
            logger: logger
        )

        try await server.start()

        let request = HTTPClientRequest(url: "http://127.0.0.1:\(port)")
        let response = try await HTTPClient.shared.execute(request, timeout: .seconds(30))

        #expect(response.status.code == 200)

        // Verify CORS headers on directory listing
        #expect(response.headers["access-control-allow-origin"].contains("*"))
        #expect(response.headers["access-control-allow-methods"].contains("GET, HEAD, OPTIONS"))
        #expect(response.headers["access-control-allow-headers"].contains("*"))
        #expect(response.headers["access-control-max-age"].contains("86400"))

        await server.stop()
    }

    @Test("HttpServer includes CORS headers on error responses")
    func httpServerIncludesCorsHeadersOnErrors() async throws {
        let testDir = try createTestDirectory()
        defer { try? FileManager.default.removeItem(at: testDir) }

        let logger = try Logger(logFilePath: nil, silent: true)
        let port = Int.random(in: 49152...65535)
        let server = HttpServer(
            documentRoot: testDir.path,
            host: "127.0.0.1",
            port: port,
            indexFile: "index.html",
            logger: logger
        )

        try await server.start()

        // Test 404 error
        let notFoundRequest = HTTPClientRequest(url: "http://127.0.0.1:\(port)/nonexistent.txt")
        let notFoundResponse = try await HTTPClient.shared.execute(notFoundRequest, timeout: .seconds(30))

        #expect(notFoundResponse.status.code == 404)
        #expect(notFoundResponse.headers["access-control-allow-origin"].contains("*"))
        #expect(notFoundResponse.headers["access-control-allow-methods"].contains("GET, HEAD, OPTIONS"))
        #expect(notFoundResponse.headers["access-control-allow-headers"].contains("*"))
        #expect(notFoundResponse.headers["access-control-max-age"].contains("86400"))

        // Test 405 error (method not allowed)
        var methodNotAllowedRequest = HTTPClientRequest(url: "http://127.0.0.1:\(port)")
        methodNotAllowedRequest.method = .POST
        methodNotAllowedRequest.body = .bytes(ByteBuffer(string: "test"))

        let methodNotAllowedResponse = try await HTTPClient.shared.execute(
            methodNotAllowedRequest, timeout: .seconds(30))

        #expect(methodNotAllowedResponse.status.code == 405)
        #expect(methodNotAllowedResponse.headers["access-control-allow-origin"].contains("*"))
        #expect(methodNotAllowedResponse.headers["access-control-allow-methods"].contains("GET, HEAD, OPTIONS"))
        #expect(methodNotAllowedResponse.headers["access-control-allow-headers"].contains("*"))
        #expect(methodNotAllowedResponse.headers["access-control-max-age"].contains("86400"))

        await server.stop()
    }

    @Test("HttpServer handles OPTIONS preflight requests")
    func httpServerHandlesOptionsRequest() async throws {
        let testDir = try createTestDirectory()
        defer { try? FileManager.default.removeItem(at: testDir) }

        let logger = try Logger(logFilePath: nil, silent: true)
        let port = Int.random(in: 49152...65535)
        let server = HttpServer(
            documentRoot: testDir.path,
            host: "127.0.0.1",
            port: port,
            indexFile: "index.html",
            logger: logger
        )

        try await server.start()

        var request = HTTPClientRequest(url: "http://127.0.0.1:\(port)")
        request.method = .OPTIONS

        let response = try await HTTPClient.shared.execute(request, timeout: .seconds(30))

        // OPTIONS should return 204 No Content
        #expect(response.status.code == 204)

        // Verify CORS headers
        #expect(response.headers["access-control-allow-origin"].contains("*"))
        #expect(response.headers["access-control-allow-methods"].contains("GET, HEAD, OPTIONS"))
        #expect(response.headers["access-control-allow-headers"].contains("*"))
        #expect(response.headers["access-control-max-age"].contains("86400"))

        // OPTIONS should not include response body
        let body = try await response.body.collect(upTo: 1024 * 1024)
        #expect(body.readableBytes == 0)

        await server.stop()
    }

    @Test("HttpServer handles OPTIONS for specific resources")
    func httpServerHandlesOptionsForSpecificResource() async throws {
        let testDir = try createTestDirectory()
        defer { try? FileManager.default.removeItem(at: testDir) }

        let logger = try Logger(logFilePath: nil, silent: true)
        let port = Int.random(in: 49152...65535)
        let server = HttpServer(
            documentRoot: testDir.path,
            host: "127.0.0.1",
            port: port,
            indexFile: "index.html",
            logger: logger
        )

        try await server.start()

        var request = HTTPClientRequest(url: "http://127.0.0.1:\(port)/test.txt")
        request.method = .OPTIONS

        let response = try await HTTPClient.shared.execute(request, timeout: .seconds(30))

        // OPTIONS should return 204 No Content
        #expect(response.status.code == 204)

        // Verify CORS headers
        #expect(response.headers["access-control-allow-origin"].contains("*"))
        #expect(response.headers["access-control-allow-methods"].contains("GET, HEAD, OPTIONS"))
        #expect(response.headers["access-control-allow-headers"].contains("*"))
        #expect(response.headers["access-control-max-age"].contains("86400"))

        // OPTIONS should not include response body
        let body = try await response.body.collect(upTo: 1024 * 1024)
        #expect(body.readableBytes == 0)

        await server.stop()
    }
}
