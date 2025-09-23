import Testing
import Foundation

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
}