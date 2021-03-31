import Foundation

/// An output formatter is used for transforming the result from a
/// jq program into the desired type.
public protocol OutputFormatter {
    /// The type into which the output is transformed.
    associatedtype Format
    /// The output configuration for the processed result.
    var config: JQ.OutputConfiguration { get }
    /// Transforms the result from a jq program into the
    /// desired type.
    func transform(string: String) throws -> Format
}

/// An output formatter which transforms the jq result into `String`.
public struct StringFormatter: OutputFormatter {
    public typealias Format = String
    public let config: JQ.OutputConfiguration

    public func transform(string: String) throws -> String {
        string
    }

    /// Creates a new string formatter with the specified output configuration.
    ///
    /// - parameters:
    ///    - config: Configuration options for formatting
    ///   the output of the jq program.
    public init(config: JQ.OutputConfiguration = .init()) {
        self.config = config
    }
}

/// An output formatter which transforms the jq result into UTF-8 encoded `Data`.
public struct DataFormatter: OutputFormatter {
    public typealias Format = Data
    public let config: JQ.OutputConfiguration

    public func transform(string: String) throws -> Data {
        Data(string.utf8)
    }

    /// Creates a new data formatter with the specified output configuration.
    ///
    /// - parameters:
    ///    - config: Configuration options for formatting
    ///   the output of the jq program.
    public init(config: JQ.OutputConfiguration = .init()) {
        self.config = config
    }
}

/// An output formatter which transforms the jq result into a type conforming
/// to the `Decodable` protocol.
public struct DecodableTypeFormatter<D: Decodable>: OutputFormatter {
    public typealias Format = D
    let decoder: JSONDecoder
    public let config = JQ.OutputConfiguration()

    public func transform(string: String) throws -> D {
        try decoder.decode(D.self, from: Data(string.utf8))
    }

    /// Creates a new decodable type formatter for the type you specify.
    ///
    /// - parameters:
    ///   - type: The `Decodable` type to which the output is decoded.
    ///   - decoder: A `JSONDecoder` used to decode the output.
    public init(decoding type: D.Type, using decoder: JSONDecoder) {
        self.decoder = decoder
    }
}
