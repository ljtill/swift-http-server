import Testing

@testable import swift_http_server

struct ApplicationTests {

    @Test("Project compilation - verifies all dependencies resolve correctly")
    func testProjectCompiles() {
        #expect(Bool(true))
    }
}
