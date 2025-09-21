import Foundation
import Testing

struct EndToEndTests {

    @Test("CLI shows help when no arguments provided")
    func cliShowsHelp() async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "./.build/debug/HttpServer")
        process.arguments = []

        let pipe = Pipe()
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        #expect(process.terminationStatus != 0)

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        #expect(output.contains("directory") || output.contains("USAGE"))
    }

    @Test("CLI rejects non-existent directory")
    func cliRejectsNonExistentDirectory() async throws {
        let nonExistentPath = "/tmp/httpserver-nonexistent-\(UUID().uuidString)"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "./.build/debug/HttpServer")
        process.arguments = [nonExistentPath]

        let pipe = Pipe()
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        #expect(process.terminationStatus != 0)

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        #expect(
            output.contains("directory") || output.contains("not found")
                || output.contains("does not exist"))
    }

    @Test("CLI rejects file instead of directory")
    func cliRejectsFileInsteadOfDirectory() async throws {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-file-\(UUID().uuidString)")
        try "test".write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "./.build/debug/HttpServer")
        process.arguments = [tempFile.path]

        let pipe = Pipe()
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        #expect(process.terminationStatus != 0)

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        #expect(output.contains("directory") || output.contains("not a directory"))
    }
}
