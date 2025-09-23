# Swift HTTP Server

A command-line HTTP server for serving static files, built with Swift and SwiftNIO.

## Features

- Serves static files from any directory
- Automatic MIME type detection for common file types
- Directory listing when no index.html exists
- Security protection against directory traversal attacks
- Graceful shutdown on SIGINT
- Simple console logging with timestamps

## Installation

```bash
git clone https://github.com/ljtill/swift-http-server.git
cd swift-http-server
swift build -c release
```

## Usage

```bash
# Serve files from current directory on port 8080
swift run HttpServer .

# Custom directory and port
swift run HttpServer /path/to/directory --port 3000

# Custom host and port
swift run HttpServer /path/to/directory --host 0.0.0.0 --port 8080
```

## Development

```bash
# Run tests
swift test

# Build for release
swift build -c release
```