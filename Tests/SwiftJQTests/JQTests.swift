import SwiftJQ
import XCTest

final class JQTests: XCTestCase {
    let resourcesURL = Bundle.module.resourceURL!

    // MARK: - Init tests
    func testInitSucceedsForValidProgram() throws {
        XCTAssertEqual(try JQ(program: "").program, "")
        XCTAssertEqual(try JQ(program: ".").program, ".")
        XCTAssertEqual(try JQ(program: "map(first)").program, "map(first)")
        XCTAssertEqual(try JQ(program: "debug").program, "debug")
        XCTAssertEqual(try JQ(program: "input").program, "input")
        XCTAssertEqual(try JQ(program: "inputs").program, "inputs")
        XCTAssertEqual(try JQ(program: "inputs").program, "inputs")
        XCTAssertEqual(
            try JQ(
                program: #"include "test_lib"; test_func"#,
                libraryPaths: [resourcesURL]).program,
            #"include "test_lib"; test_func"#)
    }

    func testInitFailsForInvalidProgram() throws {
        assertCompileError(
            try JQ(program: "unknown_func"),
            errorMessages: [
                "jq: error: unknown_func/0 is not defined at <top-level>, line 1:\nunknown_func",
                "jq: 1 compile error"
            ])
        assertCompileError(
            try JQ(program: #"include "some_lib"; ."#),
            errorMessages: [
                "jq: error: module not found: some_lib\n",
                "jq: 1 compile error"
            ])
    }

    // MARK: - String input processing tests

    func testFirstString() throws {
        let jq = try JQ(program: ".[]")
        let stringFormatter = StringFormatter()
        let decoder = JSONDecoder()
        let intFormatter = DecodableTypeFormatter(decoding: Int.self, using: decoder)

        XCTAssertEqual(try jq.first(for: "[1,2,3,4]", formatter: stringFormatter), "1")
        XCTAssertEqual(try jq.first(for: "[1,2,3,4]", formatter: intFormatter), 1)
        XCTAssertEqual(try jq.first(for: "[]", formatter: stringFormatter), nil)
        XCTAssertEqual(try jq.first(for: "[]", formatter: intFormatter), nil)

        XCTAssertEqual(try jq.first(for: "[1,2,3,4]"), "1")
        XCTAssertEqual(try jq.first(for: "[]"), nil)
    }

    func testOneString() throws {
        let jq = try JQ(program: ".[]")
        let stringFormatter = StringFormatter()
        let decoder = JSONDecoder()
        let intFormatter = DecodableTypeFormatter(decoding: Int.self, using: decoder)

        XCTAssertEqual(try jq.one(for: "[1,2,3,4]", formatter: stringFormatter), "1")
        XCTAssertEqual(try jq.one(for: "[1,2,3,4]", formatter: intFormatter), 1)
        XCTAssertThrowsError(try jq.one(for: "[]", formatter: stringFormatter)) { error in
            guard case JQ.ProcessingError.noResultEmitted = error else {
                XCTFail("Incorrect error thrown: \(error)")
                return
            }
        }
        XCTAssertThrowsError(try jq.one(for: "[]", formatter: intFormatter)) { error in
            guard case JQ.ProcessingError.noResultEmitted = error else {
                XCTFail("Incorrect error thrown: \(error)")
                return
            }
        }

        XCTAssertEqual(try jq.one(for: "[1,2,3,4]"), "1")
        XCTAssertThrowsError(try jq.one(for: "[]")) { error in
            guard case JQ.ProcessingError.noResultEmitted = error else {
                XCTFail("Incorrect error thrown: \(error)")
                return
            }
        }
    }

    func testAllString() throws {
        let jq = try JQ(program: ".[]")
        let stringFormatter = StringFormatter()
        let decoder = JSONDecoder()
        let intFormatter = DecodableTypeFormatter(decoding: Int.self, using: decoder)

        XCTAssertEqual(try jq.all(for: "[1,2,3,4]", formatter: stringFormatter), ["1", "2", "3", "4"])
        XCTAssertEqual(try jq.all(for: "[1,2,3,4]", formatter: intFormatter), [1, 2, 3, 4])
        XCTAssertEqual(try jq.all(for: "[]", formatter: stringFormatter), [])
        XCTAssertEqual(try jq.all(for: "[]", formatter: intFormatter), [])

        XCTAssertEqual(try jq.all(for: "[1,2,3,4]"), ["1", "2", "3", "4"])
        XCTAssertEqual(try jq.all(for: "[]"), [])
    }

    // MARK: - Data input processing tests

    func testFirstData() throws {
        let jq = try JQ(program: ".[]")
        let stringFormatter = StringFormatter()
        let decoder = JSONDecoder()
        let intFormatter = DecodableTypeFormatter(decoding: Int.self, using: decoder)

        XCTAssertEqual(try jq.first(for: Data("[1,2,3,4]".utf8), formatter: stringFormatter), "1")
        XCTAssertEqual(try jq.first(for: Data("[1,2,3,4]".utf8), formatter: intFormatter), 1)
        XCTAssertEqual(try jq.first(for: Data("[]".utf8), formatter: stringFormatter), nil)
        XCTAssertEqual(try jq.first(for: Data("[]".utf8), formatter: intFormatter), nil)

        XCTAssertEqual(try jq.first(for: Data("[1,2,3,4]".utf8)), Data("1".utf8))
        XCTAssertEqual(try jq.first(for: Data("[]".utf8)), nil)
    }

    func testOneData() throws {
        let jq = try JQ(program: ".[]")
        let stringFormatter = StringFormatter()
        let decoder = JSONDecoder()
        let intFormatter = DecodableTypeFormatter(decoding: Int.self, using: decoder)

        XCTAssertEqual(try jq.one(for: Data("[1,2,3,4]".utf8), formatter: stringFormatter), "1")
        XCTAssertEqual(try jq.one(for: Data("[1,2,3,4]".utf8), formatter: intFormatter), 1)
        XCTAssertThrowsError(try jq.one(for: Data("[]".utf8), formatter: stringFormatter)) { error in
            guard case JQ.ProcessingError.noResultEmitted = error else {
                XCTFail("Incorrect error thrown: \(error)")
                return
            }
        }
        XCTAssertThrowsError(try jq.one(for: Data("[]".utf8), formatter: intFormatter)) { error in
            guard case JQ.ProcessingError.noResultEmitted = error else {
                XCTFail("Incorrect error thrown: \(error)")
                return
            }
        }

        XCTAssertEqual(try jq.one(for: Data("[1,2,3,4]".utf8)), Data("1".utf8))
        XCTAssertThrowsError(try jq.one(for: Data("[]".utf8))) { error in
            guard case JQ.ProcessingError.noResultEmitted = error else {
                XCTFail("Incorrect error thrown: \(error)")
                return
            }
        }
    }

    func testAllData() throws {
        let jq = try JQ(program: ".[]")
        let stringFormatter = StringFormatter()
        let decoder = JSONDecoder()
        let intFormatter = DecodableTypeFormatter(decoding: Int.self, using: decoder)

        XCTAssertEqual(try jq.all(for: Data("[1,2,3,4]".utf8), formatter: stringFormatter), ["1", "2", "3", "4"])
        XCTAssertEqual(try jq.all(for: Data("[1,2,3,4]".utf8), formatter: intFormatter), [1, 2, 3, 4])
        XCTAssertEqual(try jq.all(for: Data("[]".utf8), formatter: stringFormatter), [])
        XCTAssertEqual(try jq.all(for: Data("[]".utf8), formatter: intFormatter), [])

        XCTAssertEqual(try jq.all(for: Data("[1,2,3,4]".utf8)), ["1", "2", "3", "4"].map { Data($0.utf8) })
        XCTAssertEqual(try jq.all(for: Data("[]".utf8)), [])
    }

    // MARK: - jq implemented functionality tests

    func testProcessingSucceedsForValidInputAndProgram() throws {
        XCTAssertEqual(try JQ(program: ".").all(for: "{}"), ["{}"])
        XCTAssertEqual(try JQ(program: ".").all(for: "[]"), ["[]"])
        XCTAssertEqual(try JQ(program: "debug").all(for: "[]"), ["[]"])
        XCTAssertEqual(try JQ(program: "inputs").all(for: "[]"), [])
        XCTAssertEqual(try JQ(program: "input_filename").all(for: "[]"), ["null"])
        XCTAssertEqual(try JQ(program: "try input catch null").all(for: "[]"), ["null"])
        XCTAssertEqual(
            try JQ(
                program: #"include "test_lib"; test_func"#,
                libraryPaths: [resourcesURL]).all(for: "{}"),
            [#""It works!""#])
    }

    func testProcessingFailsForInvalidInput() throws {
        assertParseError(
            try JQ(program: ".").all(for: "Not valid JSON"),
            message: "Invalid numeric literal at line 1, column 4 (while parsing 'Not valid JSON')")
        assertParseError(
            try JQ(program: ".").all(for: "{}\n{}\n{}"),
            message: "Unexpected extra JSON values (while parsing '{}\n{}\n{}')")
    }

    func testProcessingFailsForUncaughtExceptions() throws {
        assertExceptionError(
            try JQ(program: "first").all(for: "{}"),
            message: "Cannot index object with number")

        // The jq input function is currently not supported
        // and should throw an exception
        assertExceptionError(
            try JQ(program: "input").all(for: "{}"),
            message: "break")

        // The input_line_number function is not supported
        // and throws an exception when called.
        assertExceptionError(
            try JQ(program: "input_line_number").all(for: "{}"),
            message: "Unknown input line number")
    }

    func testProcessingHalts() throws {
        // A halt should cause the processing to stop early.
        XCTAssertEqual(
            try JQ(program: ".[] | if .%3 == 0 then halt else . end")
                .all(for: "[1, 2, 3, 4, 5]"),
            ["1", "2"])

        assertHaltError(
            try JQ(program: ".[] | if .%3 == 0 then halt_error else . end")
                .all(for: "[1, 2, 3, 4, 5]"),
            message: "3",
            exitCode: 5, // Default exit code for halt_error
            partialResult: ["1", "2"])

        assertHaltError(
            try JQ(program: ".[] | if .%3 == 0 then halt_error(0) else . end")
                .all(for: "[1, 2, 3, 4, 5]"),
            message: "3",
            exitCode: 0,
            partialResult: ["1", "2"])

        assertHaltError(
            try JQ(program: ".[] | if .%3 == 0 then null | halt_error else . end")
                .all(for: "[1, 2, 3, 4, 5]"),
            message: nil,
            exitCode: 5,
            partialResult: ["1", "2"])

        // A program halted with no message an exit code 0
        // should not throw.
        XCTAssertEqual(
            try JQ(program: ".[] | if .%3 == 0 then null | halt_error(0) else . end")
                .all(for: "[1, 2, 3, 4, 5]"),
            ["1", "2"])
    }

    func testOutputConfigurations() throws {
        XCTAssertEqual(
            try JQ(program: ".").all(for: #"{"c":10,"b":5,"a":7}"#),
            [#"{"c":10,"b":5,"a":7}"#])

        XCTAssertEqual(
            try JQ(program: ".").all(for: #""test""#),
            [#""test""#])

        XCTAssertEqual(
            try JQ(program: ".").all(
                for: #"{"c":10,"b":5,"a":7}"#,
                formatter: StringFormatter(config: .init(sortedKeys: true))),
            [#"{"a":7,"b":5,"c":10}"#])

        XCTAssertEqual(
            try JQ(program: ".").all(
                for: #""test""#,
                formatter: StringFormatter(config: .init(rawString: true))),
            ["test"])

        XCTAssertEqual(
            try JQ(program: ".").all(
                for: #"{"c":10,"b":5,"a":7}"#,
                formatter: StringFormatter(config: .init(pretty: true))),
            [
                """
                {
                    "c": 10,
                    "b": 5,
                    "a": 7
                }
                """
            ])

        XCTAssertEqual(
            try JQ(program: ".").all(
                for: #"{"c":10,"b":5,"a":7}"#,
                formatter: StringFormatter(config: .init(pretty: true, indent: .spaces(2)))),
            [
                """
                {
                  "c": 10,
                  "b": 5,
                  "a": 7
                }
                """
            ])

        XCTAssertEqual(
            try JQ(program: ".").all(
                for: #"{"c":10,"b":5,"a":7}"#,
                formatter: StringFormatter(config: .init(pretty: true, indent: .tabs))),
            [
                """
                {
                \t"c": 10,
                \t"b": 5,
                \t"a": 7
                }
                """
            ])

        XCTAssertEqual(
            try JQ(program: ".[]").all(
                for: #"[{"c":10,"b":5,"a":7}, "test"]"#,
                formatter: StringFormatter(
                    config: .init(
                        sortedKeys: true,
                        rawString: true,
                        pretty: true,
                        indent: .spaces(2)))),
            [
                """
                {
                  "a": 7,
                  "b": 5,
                  "c": 10
                }
                """,
                "test"
            ])
    }

    func testAttemptingToProcessInParallel() throws {
        let jq = try JQ(program: ".")
        DispatchQueue.concurrentPerform(iterations: 10) { index in
            XCTAssertEqual(try? jq.one(for: String(index)), String(index))
        }
    }
}

// MARK: - Helpers

extension JQTests {
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

    func assertParseError<T>(
        _ expression: @autoclosure () throws -> T,
        message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try expression(), file: file, line: line) { error in
            guard case JQ.ProcessingError.parse(let info) = error else {
                XCTFail("Incorrect error thrown: \(error)", file: file, line: line)
                return
            }

            XCTAssertEqual(info.message, message, file: file, line: line)
        }
    }

    func assertExceptionError<T>(
        _ expression: @autoclosure () throws -> T,
        message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try expression(), file: file, line: line) { error in
            guard case JQ.ProcessingError.exception(let info) = error else {
                XCTFail("Incorrect error thrown: \(error)", file: file, line: line)
                return
            }

            XCTAssertEqual(info.message, message, file: file, line: line)
        }
    }

    func assertHaltError<T>(
        _ expression: @autoclosure () throws -> T,
        message: String?,
        exitCode: Int,
        partialResult: [String],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try expression(), file: file, line: line) { error in
            guard case JQ.ProcessingError.halt(let info) = error else {
                XCTFail("Incorrect error thrown: \(error)", file: file, line: line)
                return
            }

            XCTAssertEqual(info.errorMessage?.message, message, file: file, line: line)
            XCTAssertEqual(info.exitCode, exitCode, file: file, line: line)
            XCTAssertEqual(info.partialResult, partialResult, file: file, line: line)
        }
    }
}
