import Foundation

/// Security utilities for path validation and sanitization
///
/// This struct provides essential security functions for web servers that serve static files.
/// It prevents directory traversal attacks and ensures that file paths are safe to access.
///
/// Key security features:
/// - Path sanitization to remove dangerous sequences
/// - Directory traversal attack prevention
/// - Path resolution and validation
/// - Safe path construction within document root
public struct PathSecurity {

    /// Sanitize a request path to prevent directory traversal attacks
    ///
    /// This method properly resolves path components including directory traversal sequences:
    /// - Resolves ".." by removing the previous path component
    /// - Removes "." sequences that are redundant
    /// - Normalizes path separators
    /// - Properly handles paths like "/test/../file.txt" → "/file.txt"
    ///
    /// - Parameter path: The raw request path to sanitize
    /// - Returns: A sanitized and resolved path safe for file system access
    public static func sanitizePath(_ path: String) -> String {
        var components: [String] = []

        for component in path.split(separator: "/") {
            let cleanComponent = String(component).trimmingCharacters(in: .whitespaces)

            if cleanComponent.isEmpty || cleanComponent == "." {
                continue
            }

            if cleanComponent == ".." {
                // Pop the last component if it exists (proper path resolution)
                if !components.isEmpty {
                    components.removeLast()
                }
            } else {
                components.append(cleanComponent)
            }
        }

        return "/" + components.joined(separator: "/")
    }

    /// Resolve a sanitized path to a full file system path
    ///
    /// This method combines the document root with the sanitized request path to create
    /// a full file system path. It ensures the path is properly constructed and normalized.
    ///
    /// - Parameters:
    ///   - path: The sanitized request path
    ///   - documentRoot: The document root directory
    /// - Returns: The resolved full file system path
    public static func resolvePath(_ path: String, documentRoot: String) -> String {
        let cleanDocumentRoot =
            documentRoot.hasSuffix("/") ? String(documentRoot.dropLast()) : documentRoot

        let fullPath = cleanDocumentRoot + path

        return URL(fileURLWithPath: fullPath).standardized.path
    }

    /// Check if a resolved path is safe to access
    ///
    /// This method performs a final security check to ensure the resolved path is still
    /// within the document root after all path resolution. This prevents sophisticated
    /// directory traversal attacks using symlinks or other techniques.
    ///
    /// - Parameters:
    ///   - path: The resolved full file system path
    ///   - documentRoot: The document root directory
    /// - Returns: True if the path is safe to access, false otherwise
    public static func isPathSafe(_ path: String, documentRoot: String) -> Bool {
        let resolvedPath = URL(fileURLWithPath: path).standardized.path
        let resolvedDocumentRoot = URL(fileURLWithPath: documentRoot).standardized.path

        return resolvedPath.hasPrefix(resolvedDocumentRoot + "/")
            || resolvedPath == resolvedDocumentRoot
    }

    /// Perform complete path validation and resolution
    ///
    /// This convenience method combines all security checks into a single operation:
    /// 1. Sanitizes the request path
    /// 2. Resolves it to a full file system path
    /// 3. Validates the result is safe to access
    ///
    /// - Parameters:
    ///   - requestPath: The raw request path from the client
    ///   - documentRoot: The document root directory
    /// - Returns: A tuple containing the sanitized path and resolved path, or nil if unsafe
    public static func validateAndResolvePath(_ requestPath: String, documentRoot: String) -> (
        sanitized: String, resolved: String
    )? {
        let sanitizedPath = sanitizePath(requestPath)

        let resolvedPath = resolvePath(sanitizedPath, documentRoot: documentRoot)

        guard isPathSafe(resolvedPath, documentRoot: documentRoot) else {
            return nil
        }

        return (sanitized: sanitizedPath, resolved: resolvedPath)
    }
}
