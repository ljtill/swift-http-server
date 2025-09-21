import Foundation
import Testing

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
        #expect(MimeType.forPath("/file.HTML") == "text/html; charset=utf-8")  // case insensitive
    }

    @Test("PathSecurity sanitizes dangerous paths")
    func pathSecurity() {
        #expect(PathSecurity.sanitizePath("/../../etc/passwd") == "/etc/passwd")
        #expect(PathSecurity.sanitizePath("/./test/../file.txt") == "/file.txt")
        #expect(PathSecurity.sanitizePath("/normal/path/file.txt") == "/normal/path/file.txt")

        let root = "/var/www/html"
        #expect(
            PathSecurity.resolvePath("/index.html", documentRoot: root)
                == "/var/www/html/index.html")
        #expect(PathSecurity.isPathSafe("/var/www/html/file.txt", documentRoot: root) == true)
        #expect(PathSecurity.isPathSafe("/etc/passwd", documentRoot: root) == false)
    }

    @Test("PathSecurity prevents directory traversal attacks")
    func pathSecurityDirectoryTraversal() {
        let root = "/var/www/html"

        let result1 = PathSecurity.validateAndResolvePath("/../../etc/passwd", documentRoot: root)
        #expect(result1 != nil)
        #expect(result1?.sanitized == "/etc/passwd")
        #expect(result1?.resolved == "/var/www/html/etc/passwd")
        #expect(PathSecurity.isPathSafe(result1!.resolved, documentRoot: root) == true)

        let result2 = PathSecurity.validateAndResolvePath(
            "/../../../etc/passwd", documentRoot: root)
        #expect(result2 != nil)
        #expect(result2?.sanitized == "/etc/passwd")
        #expect(result2?.resolved == "/var/www/html/etc/passwd")

        let result3 = PathSecurity.validateAndResolvePath("/index.html", documentRoot: root)
        #expect(result3 != nil)
        #expect(result3?.sanitized == "/index.html")
        #expect(result3?.resolved == "/var/www/html/index.html")
    }

    @Test("DirectoryListing generates HTML")
    func directoryListing() {
        let contents = ["file.txt", "folder/"]
        let html = DirectoryListing.generateHTML(contents: contents, requestPath: "/test")

        #expect(html.contains("<!DOCTYPE html>"))
        #expect(html.contains("Directory listing for /test"))
        #expect(html.contains("file.txt"))
        #expect(html.contains("folder"))
        #expect(html.contains("[FILE]"))  // File prefix
        #expect(html.contains("[DIR]"))  // Directory prefix
    }

    @Test("DirectoryListing escapes HTML to prevent XSS")
    func directoryListingXSSPrevention() {
        let maliciousContents = [
            "<script>alert('XSS')</script>.txt",
            "file<img src=x onerror=alert(1)>.html",
            "test&copy;.txt",
        ]
        let html = DirectoryListing.generateHTML(
            contents: maliciousContents, requestPath: "/test")

        #expect(html.contains("&lt;script&gt;alert(&#39;XSS&#39;)&lt;/script&gt;.txt"))
        #expect(html.contains("&lt;img src=x onerror=alert(1)&gt;.html"))
        #expect(html.contains("&amp;copy;"))

        #expect(!html.contains("<script>alert"))
        #expect(!html.contains("<img src=x"))

        let maliciousPath = "/test<script>alert('path')</script>"
        let htmlWithMaliciousPath = DirectoryListing.generateHTML(
            contents: ["file.txt"], requestPath: maliciousPath)

        #expect(
            htmlWithMaliciousPath.contains(
                "&lt;script&gt;alert(&#39;path&#39;)&lt;/script&gt;"))
        #expect(!htmlWithMaliciousPath.contains("<script>alert('path')"))
    }

    @Test("MimeType handles edge cases")
    func mimeTypeEdgeCases() {
        #expect(MimeType.forPath("") == "application/octet-stream")
        #expect(MimeType.forPath("/file") == "application/octet-stream")
        #expect(MimeType.forPath("/file.tar.gz") == "application/octet-stream")
        #expect(MimeType.forPath("/file.") == "application/octet-stream")
        #expect(MimeType.forPath("file.txt") == "text/plain; charset=utf-8")  // no leading slash
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
