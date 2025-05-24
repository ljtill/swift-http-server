---
applyTo: '**'
---

## Technology Stack
- **Language:** Swift 6
- **Platform:** Linux
- **Application Type:** Command-line HTTP server
- **Dependencies:** Primarily Apple-built packages

## Code Style & Requirements
- Follow Swift API Design Guidelines
- Use Swift's modern concurrency model (async/await)
- Ensure Linux compatibility for all code
- Write non-blocking, performant network code
- Include appropriate error handling with descriptive messages
- Prefer value types when appropriate
- Use strong typing; avoid force unwrapping
- Include documentation comments for public-facing APIs

## HTTP Server Requirements
- Code should support standard HTTP methods
- Implement efficient static file serving capabilities
- Support configurable port binding
- Consider memory efficiency for long-running processes
- Include proper request logging
- Implement graceful shutdown handling

## CLI Implementation
- Use ArgumentParser for command-line argument handling
- Support standard Unix signal handling
- Provide clear, concise terminal output
- Follow Unix command-line conventions

## Testing Considerations
- All code should be testable
- Support for Linux-compatible test cases
- Consider async testing patterns for network code

## Swift-Specific Guidelines
- Use `Foundation` and other Apple frameworks appropriately
- Follow Swift 6-specific patterns and idioms
- Leverage Swift's strong type system
- Use Swift-NIO patterns for networking where appropriate

## Security Considerations
- Validate all user inputs
- Prevent path traversal attacks
- Implement proper HTTP headers
- Handle errors without exposing sensitive information

## Performance
- Consider resource usage for server operations
- Implement appropriate caching mechanisms
- Use Swift's performance features effectively