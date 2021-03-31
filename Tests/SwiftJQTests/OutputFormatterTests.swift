import SwiftJQ
import XCTest

final class OutputFormatterTests: XCTestCase {
    func testStringFormatter() throws {
        let outputConfig = JQ.OutputConfiguration(sortedKeys: true, pretty: true)
        let formatter = StringFormatter(config: outputConfig)
        XCTAssertEqual(try formatter.transform(string: "123"), "123")
        XCTAssertEqual(formatter.config, outputConfig)
    }

    func testDataFormatter() throws {
        let outputConfig = JQ.OutputConfiguration(sortedKeys: true, pretty: true)
        let formatter = DataFormatter(config: outputConfig)
        XCTAssertEqual(try formatter.transform(string: "123"), Data("123".utf8))
        XCTAssertEqual(formatter.config, outputConfig)
    }

    func testDecodableTypeFormatter() throws {
        let formatter = DecodableTypeFormatter(decoding: Int.self, using: JSONDecoder())
        XCTAssertEqual(try formatter.transform(string: "123"), 123)
        XCTAssertEqual(formatter.config, .init())
    }
}
