import XCTest
import SwiftJQ

final class JQTests: XCTestCase {
    func testInitSucceedsForValidProgram() throws {
        XCTAssertEqual(try JQ(program: "").program, "")
        XCTAssertEqual(try JQ(program: ".").program, ".")
        XCTAssertEqual(try JQ(program: "map(first)").program, "map(first)")
        XCTAssertEqual(try JQ(program: "debug").program, "debug")
        XCTAssertEqual(try JQ(program: "input").program, "input")
        XCTAssertEqual(try JQ(program: "inputs").program, "inputs")
    }

    func testInitFailsForInvalidProgram() throws {
        assertCompileError(
            try JQ(program: "unknown_func"),
            errorMessages: [
                "jq: error: unknown_func/0 is not defined at <top-level>, line 1:\nunknown_func",
                "jq: 1 compile error"
            ])
        assertCompileError(
            try JQ(program: #"include "some_lib.jq"; ."#),
            errorMessages: [
                "jq: error: module not found: some_lib.jq\n",
                "jq: 1 compile error"
            ])
    }

    func assertCompileError<T>(
        _ expression: @autoclosure () throws -> T,
        errorMessages: [String],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try expression(), file: file, line: line) { error in
            guard case JQ.InitializationError.compile(let info) = error else {
                XCTFail("Incorrect error thrown: \(error)", file: file, line: line)
                return
            }

            XCTAssertEqual(info.errorMessages, errorMessages, file: file, line: line)
        }
    }
}
