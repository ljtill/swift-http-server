import Foundation

/// MIME type handling for common file extensions
///
/// This struct provides utilities for determining MIME types based on file extensions.
/// It supports the most common web file types including HTML, CSS, JavaScript, JSON,
/// and basic image formats.
///
/// The MIME type detection is case-insensitive and defaults to "application/octet-stream"
/// for unknown file extensions.
public struct MimeType {
    private static let mimeTypes: [String: String] = [
        "html": "text/html; charset=utf-8",
        "htm": "text/html; charset=utf-8",
        "css": "text/css",
        "js": "application/javascript",
        "json": "application/json",
        "png": "image/png",
        "jpg": "image/jpeg",
        "jpeg": "image/jpeg",
        "gif": "image/gif",
        "ico": "image/x-icon",
        "svg": "image/svg+xml",
        "txt": "text/plain; charset=utf-8"
    ]
    
    /// Get MIME type for a file path
    /// 
    /// This method extracts the file extension from the provided path and returns
    /// the corresponding MIME type. The extension matching is case-insensitive.
    /// 
    /// - Parameter path: The file path to analyze
    /// - Returns: The MIME type string, defaults to "application/octet-stream" for unknown extensions
    public static func forPath(_ path: String) -> String {
        let url = URL(fileURLWithPath: path)
        let pathExtension = url.pathExtension.lowercased()
        
        return mimeTypes[pathExtension] ?? "application/octet-stream"
    }
    
    /// Get MIME type for a file extension
    /// 
    /// This method returns the MIME type for a given file extension. The extension
    /// should be provided without the leading dot (e.g., "html" not ".html").
    /// 
    /// - Parameter extension: The file extension (without the dot)
    /// - Returns: The MIME type string, defaults to "application/octet-stream" for unknown extensions
    public static func forExtension(_ extension: String) -> String {
        let lowercased = `extension`.lowercased()
        return mimeTypes[lowercased] ?? "application/octet-stream"
    }
    
    /// Check if a file extension is supported
    /// 
    /// This method determines whether a given file extension has a known MIME type
    /// mapping. Useful for filtering or validation operations.
    /// 
    /// - Parameter extension: The file extension (without the dot)
    /// - Returns: True if the extension is supported, false otherwise
    public static func isSupported(_ extension: String) -> Bool {
        let lowercased = `extension`.lowercased()
        return mimeTypes[lowercased] != nil
    }
    
    /// Get all supported file extensions
    /// 
    /// This method returns a sorted array of all file extensions that have
    /// MIME type mappings. Useful for displaying supported formats or validation.
    /// 
    /// - Returns: Array of supported file extensions in alphabetical order
    public static func supportedExtensions() -> [String] {
        return Array(mimeTypes.keys).sorted()
    }
}