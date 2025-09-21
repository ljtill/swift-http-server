import Testing
import Foundation
import NIO
import NIOHTTP1
@testable import HttpServerCore

struct IntegrationTests {
    private func createTestDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)

        try "<h1>Test</h1>".write(to: testDir.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)
        try "test content".write(to: testDir.appendingPathComponent("test.txt"), atomically: true, encoding: .utf8)

        return testDir
    }
    @Test("HttpServer serves files")
    func httpServerServesFiles() async throws {
        let testDir = try createTestDirectory()
        defer { try? FileManager.default.removeItem(at: testDir) }

        let server = HttpServer(documentRoot: testDir.path, host: "127.0.0.1", port: 8080)

        try await server.start()
        defer { Task { await server.stop() } }

        try await Task.sleep(nanoseconds: 100_000_000)

        let url = URL(string: "http://127.0.0.1:8080/test.txt")!
        let (data, response) = try await URLSession(configuration: .default).data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TestError.invalidResponse
        }

        #expect(httpResponse.statusCode == 200)
        #expect(httpResponse.value(forHTTPHeaderField: "Content-Type") == "text/plain; charset=utf-8")

        let content = String(data: data, encoding: .utf8)
        #expect(content?.contains("test content") == true)
    }

    @Test("HttpServer returns 404 for non-existent files")
    func httpServerReturns404() async throws {
        let testDir = try createTestDirectory()
        defer { try? FileManager.default.removeItem(at: testDir) }

        let server = HttpServer(documentRoot: testDir.path, host: "127.0.0.1", port: 3000)

        try await server.start()
        defer { Task { await server.stop() } }

        try await Task.sleep(nanoseconds: 100_000_000)

        let url = URL(string: "http://127.0.0.1:3000/nonexistent.txt")!

        do {
            let (_, response) = try await URLSession(configuration: .default).data(from: url)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TestError.invalidResponse
            }
            #expect(httpResponse.statusCode == 404)
        } catch {
            if let urlError = error as? URLError, urlError.code == .badServerResponse {
                // This is expected for 404 responses
            } else {
                throw error
            }
        }
    }

    @Test("HttpServer serves directory listing when no index.html")
    func httpServerServesDirectoryListing() async throws {
        let testDir = try createTestDirectory()
        defer { try? FileManager.default.removeItem(at: testDir) }

        // Remove index.html to trigger directory listing
        try FileManager.default.removeItem(at: testDir.appendingPathComponent("index.html"))

        let server = HttpServer(documentRoot: testDir.path, host: "127.0.0.1", port: 3001)

        try await server.start()
        defer { Task { await server.stop() } }

        try await Task.sleep(nanoseconds: 100_000_000)

        let url = URL(string: "http://127.0.0.1:3001/")!
        let (data, response) = try await URLSession(configuration: .default).data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TestError.invalidResponse
        }

        #expect(httpResponse.statusCode == 200)
        #expect(httpResponse.value(forHTTPHeaderField: "Content-Type") == "text/html; charset=utf-8")

        let content = String(data: data, encoding: .utf8)
        #expect(content?.contains("Directory listing") == true)
        #expect(content?.contains("test.txt") == true)
        #expect(content?.contains("[FILE]") == true)
    }
}

enum TestError: Error {
    case invalidResponse
}