import Foundation

/// Utility for generating directory listing HTML
/// 
/// This struct provides functionality to generate HTML directory listings for web servers.
/// It creates formatted HTML pages with navigation links and file listings when serving
/// directory contents to clients.
/// 
/// The generated HTML includes:
/// - Proper HTML5 structure with responsive design
/// - Navigation links for parent directories
/// - File and directory entries with appropriate styling
/// - Clean, accessible interface
public struct DirectoryListing {
    
    /// Generate simple HTML directory listing
    ///
    /// This method creates a basic HTML page showing the contents of a directory.
    /// It includes simple navigation and file listings without complex styling.
    ///
    /// - Parameters:
    ///   - contents: Array of file and directory names to display
    ///   - requestPath: The original request path for generating proper URLs
    /// - Returns: Basic HTML string ready for serving
    public static func generateHTML(contents: [String], requestPath: String) -> String {
        let title = requestPath == "/" ? "Directory listing for /" : "Directory listing for \(requestPath)"
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

        // Add navigation if not at root
        if requestPath != "/" {
            html += "<p><a href=\"\(parentPath)\">← Parent Directory</a></p>"
        }

        // Add file listing
        html += "<ul>"

        for item in contents {
            let itemPath = constructItemPath(requestPath: requestPath, item: item)
            let displayName = item.hasSuffix("/") ? String(item.dropLast()) : item
            let prefix = item.hasSuffix("/") ? "[DIR] " : "[FILE] "

            html += "<li><a href=\"\(itemPath)\">\(prefix)\(displayName)</a></li>"
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