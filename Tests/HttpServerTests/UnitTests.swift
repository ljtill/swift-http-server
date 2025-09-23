import Testing
import Foundation
@testable import HttpServerCore

struct UnitTests {
    
    @Test("MimeType returns correct types")
    func mimeTypes() {
        #expect(MimeType.forPath("/file.html") == "text/html; charset=utf-8")
        #expect(MimeType.forPath("/file.css") == "text/css")
        #expect(MimeType.forPath("/file.js") == "application/javascript")
        #expect(MimeType.forPath("/file.json") == "application/json")
        #expect(MimeType.forPath("/file.png") == "image/png")
        #expect(MimeType.forPath("/file.unknown") == "application/octet-stream")
        #expect(MimeType.forPath("/file.HTML") == "text/html; charset=utf-8") // case insensitive
    }

    @Test("PathSecurity sanitizes dangerous paths")
    func pathSecurity() {
        #expect(PathSecurity.sanitizePath("/../../etc/passwd") == "/etc/passwd")
        #expect(PathSecurity.sanitizePath("/./test/../file.txt") == "/test/file.txt")
        #expect(PathSecurity.sanitizePath("/normal/path/file.txt") == "/normal/path/file.txt")

        let root = "/var/www/html"
        #expect(PathSecurity.resolvePath("/index.html", documentRoot: root) == "/var/www/html/index.html")
        #expect(PathSecurity.isPathSafe("/var/www/html/file.txt", documentRoot: root) == true)
        #expect(PathSecurity.isPathSafe("/etc/passwd", documentRoot: root) == false)
    }

    @Test("DirectoryListing generates HTML")
    func directoryListing() {
        let contents = ["file.txt", "folder/"]
        let html = DirectoryListing.generateHTML(contents: contents, requestPath: "/test")

        #expect(html.contains("<!DOCTYPE html>"))
        #expect(html.contains("Directory listing for /test"))
        #expect(html.contains("file.txt"))
        #expect(html.contains("folder"))
        #expect(html.contains("[FILE]")) // File prefix
        #expect(html.contains("[DIR]")) // Directory prefix
    }

    @Test("MimeType handles edge cases")
    func mimeTypeEdgeCases() {
        #expect(MimeType.forPath("") == "application/octet-stream")
        #expect(MimeType.forPath("/file") == "application/octet-stream")
        #expect(MimeType.forPath("/file.tar.gz") == "application/octet-stream")
        #expect(MimeType.forPath("/file.") == "application/octet-stream")
        #expect(MimeType.forPath("file.txt") == "text/plain; charset=utf-8") // no leading slash
    }

    @Test("PathSecurity handles edge cases")
    func pathSecurityEdgeCases() {
        #expect(PathSecurity.sanitizePath("") == "/")
        #expect(PathSecurity.sanitizePath("/") == "/")
        #expect(PathSecurity.sanitizePath("/path/") == "/path")
        #expect(PathSecurity.sanitizePath("   /test/   ") == "/test")

        let root = "/var/www"
        #expect(PathSecurity.isPathSafe("/var/www", documentRoot: root) == true)
        #expect(PathSecurity.isPathSafe("/var/www/", documentRoot: root) == true)
    }
}