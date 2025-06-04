import ArgumentParser
import Logging

@main
struct HttpServer: ParsableCommand {
    @Flag(name: [.short, .long], help: "Enable debug logging")
    var debug = false

    mutating func run() throws {
        let logLevel: Logger.Level = debug ? .debug : .info
        let logger = try Logger.fileLogger(
            label: "com.ljtill.httpserver",
            fileName: "app.log",
            logLevel: logLevel
        )

        print("HTTP Server starting...")
        logger.info("Starting HTTP server...")
        logger.debug("Server is running in debug mode")

        // TODO: Implement server logic
    }
}
