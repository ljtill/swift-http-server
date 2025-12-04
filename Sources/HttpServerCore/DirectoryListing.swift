import Foundation

/// Utility for generating directory listing HTML
///
/// This struct provides functionality to generate HTML directory listings for web servers.
/// It creates formatted HTML pages with navigation links and file listings when serving
/// directory contents to clients.
///
/// Key features:
/// - Proper HTML5 structure with responsive design
/// - Navigation links for parent directories
/// - File and directory entries with appropriate styling
/// - Clean, accessible interface
public struct DirectoryListing {

    /// Escape HTML special characters to prevent XSS attacks
    ///
    /// This method sanitizes user-controlled content by escaping HTML special characters
    /// that could be used for cross-site scripting attacks.
    ///
    /// - Parameter text: The text to escape
    /// - Returns: HTML-safe escaped text
    private static func escapeHTML(_ text: String) -> String {
        var escaped = text
        escaped = escaped.replacingOccurrences(of: "&", with: "&amp;")
        escaped = escaped.replacingOccurrences(of: "<", with: "&lt;")
        escaped = escaped.replacingOccurrences(of: ">", with: "&gt;")
        escaped = escaped.replacingOccurrences(of: "\"", with: "&quot;")
        escaped = escaped.replacingOccurrences(of: "'", with: "&#39;")
        return escaped
    }

    /// URL encode a path for safe use in href attributes
    ///
    /// This method encodes special characters in URLs to ensure proper link functionality
    /// and prevent injection attacks in href attributes.
    ///
    /// - Parameter path: The path to encode
    /// - Returns: URL-encoded path safe for use in href attributes
    private static func encodeURL(_ path: String) -> String {
        // URL encode the path, allowing forward slashes for proper path structure
        return path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
    }

    /// Generate simple HTML directory listing
    ///
    /// This method creates a basic HTML page showing the contents of a directory.
    /// It includes simple navigation and file listings without complex styling.
    ///
    /// All user-controlled content (file names, paths) is properly escaped to prevent
    /// XSS (Cross-Site Scripting) attacks.
    ///
    /// - Parameters:
    ///   - contents: Array of file and directory names to display
    ///   - requestPath: The original request path for generating proper URLs
    /// - Returns: Basic HTML string ready for serving
    public static func generateHTML(contents: [String], requestPath: String) -> String {
        let escapedRequestPath = escapeHTML(requestPath)
        let title =
            requestPath == "/"
            ? "Directory listing for /" : "Directory listing for \(escapedRequestPath)"
        let parentPath = requestPath == "/" ? "" : getParentPath(requestPath)

        var html = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="UTF-8">
                <title>\(title)</title>
            </head>
            <body>
                <h1>\(title)</h1>
            """

        if requestPath != "/" {
            let encodedParentPath = encodeURL(parentPath)
            html += "<p><a href=\"\(encodedParentPath)\">← Parent Directory</a></p>"
        }

        html += "<ul>"

        for item in contents {
            let itemPath = constructItemPath(requestPath: requestPath, item: item)
            let encodedItemPath = encodeURL(itemPath)
            let displayName = item.hasSuffix("/") ? String(item.dropLast()) : item
            let escapedDisplayName = escapeHTML(displayName)
            let prefix = item.hasSuffix("/") ? "[DIR] " : "[FILE] "

            html +=
                "<li><a href=\"\(encodedItemPath)\">\(prefix)\(escapedDisplayName)</a></li>"
        }

        html += """
                    </ul>
                </body>
            </html>
            """

        return html
    }

    /// Get parent directory path for navigation
    ///
    /// This method constructs the parent directory path for navigation links.
    /// It handles proper URL construction and edge cases.
    ///
    /// - Parameter requestPath: The current request path
    /// - Returns: The parent directory path
    private static func getParentPath(_ requestPath: String) -> String {
        let components = requestPath.split(separator: "/").map(String.init)
        if components.count <= 1 {
            return "/"
        }
        let parentComponents = components.dropLast()
        return parentComponents.isEmpty ? "/" : "/" + parentComponents.joined(separator: "/")
    }

    /// Construct item path for links
    ///
    /// This method builds the proper URL path for file and directory links
    /// in the directory listing.
    ///
    /// - Parameters:
    ///   - requestPath: The current request path
    ///   - item: The file or directory name
    /// - Returns: The constructed path for the item
    private static func constructItemPath(requestPath: String, item: String) -> String {
        let basePath = requestPath.hasSuffix("/") ? requestPath : requestPath + "/"
        return basePath + item
    }
}
