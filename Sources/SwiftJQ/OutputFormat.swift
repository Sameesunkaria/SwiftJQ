import Foundation

public protocol OutputFormat {
    associatedtype Format
    var config: JQ.OutputConfiguration { get }
    func transform(string: String) throws -> Format
}

public struct StringFormat: OutputFormat {
    public typealias Format = String
    public let config: JQ.OutputConfiguration

    public func transform(string: String) throws -> String {
        string
    }

    public init(config: JQ.OutputConfiguration = .init()) {
        self.config = config
    }
}

public struct DataFormat: OutputFormat {
    public typealias Format = Data
    public let config: JQ.OutputConfiguration

    public func transform(string: String) throws -> Data {
        Data(string.utf8)
    }

    public init(config: JQ.OutputConfiguration = .init()) {
        self.config = config
    }
}

public struct DecodableTypeFormat<D: Decodable>: OutputFormat {
    public typealias Format = D
    let decoder: JSONDecoder
    public let config = JQ.OutputConfiguration()

    public func transform(string: String) throws -> D {
        try decoder.decode(D.self, from: Data(string.utf8))
    }

    public init(_ type: D.Type, using decoder: JSONDecoder) {
        self.decoder = decoder
    }
}
