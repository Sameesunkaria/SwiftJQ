import Cjq
import Foundation

/// An object that let's you run a jq program over an input.
///
/// You can use the `JQ` class to execute a jq program over an
/// input string.
///
/// The example below shows a simple jq program for obtaining the list of
/// fruits with a price greater than `1.0`. An instance of the `JQ` class is
/// initialized with the `jq` program. Then, the `fruitsJSON` is processed
/// with the `rawString` output configuration to get the raw names of the
/// fruits instead of a quoted JSON string. The output is an array of fruit names.
///
/// ```
/// let expensiveFruitsFilter =
///     try JQ(program: ".[] | select(.price > 1) | .name")
///
/// let fruitsJSON = """
/// [
///   {
///     "name": "apple",
///     "price": 1.2
///   },
///   {
///     "name": "banana",
///     "price": 0.5
///   },
///   {
///     "name": "avocado",
///     "price": 2.5
///   }
/// ]
/// """
///
/// let expensiveFruits = try expensiveFruitsFilter.all(
///     for: fruitsJSON,
///     format: StringFormat(config: .init(rawString: true)))
///
/// print(expensiveFruits) // Prints ["apple", "avocado"]
/// ```
///
/// - NOTE: A `JQ` instance can only process one input at a time.
/// Attempting to processing multiple inputs in parallel may lead to the caller
/// having to wait while another input finishes processing. If you need to
/// process multiple inputs in parallel, please create a new instance of the
/// `JQ` object for each thread.
final public class JQ {
    /// The jq program stored within the instance of this class.
    public let program: String

    private var jqState: OpaquePointer?
    private let unfairLock = UnfairLock()
    private let debugHandler = DebugHandler()

    /// Creates a new `JQ` instance with the specified jq program.
    ///
    /// An instance may be used to process multiple inputs, using the same
    /// program. The initializer throws a `JQ.InitializationError` if the
    /// program fails to compile.
    ///
    /// - parameters:
    ///   - program: A jq program used to process all inputs to the instance
    ///   of this class.
    ///   - libraryPaths: Array of file system URLs the jq program uses to
    ///   search for libraries.
    public init(
        program: String,
        libraryPaths: [URL] = []
    ) throws {
        self.program = program
        // Initializing a new jq state.
        jqState = jq_init()
        guard jqState != nil else {
            // Initializing a jq state can only fail if the memory
            // allocation fails.
            throw InitializationError.alloc
        }

        let errorHandler = CompilationErrorHandler()

        // Passing an unretained reference of error handler. The error
        // handler is retained in memory by the scope of the initializer.
        jq_set_error_cb(
            jqState,
            errorHandler.callback,
            errorHandler.rawPointer)

        // Setting library search paths. An empty array of paths must be
        // set if no libraryPaths are passed in, not doing so causes the
        // program to raise an assertion.
        let jvLibraryPaths = libraryPaths
            .map(\.standardizedFileURL.relativePath)
            .map { jv_string($0) }
            .reduce(jv_array(), jv_array_append)
        jq_set_attr(jqState, jv_string("JQ_LIBRARY_PATH"), jvLibraryPaths)

        // Compile the jq program.
        let compiled = jq_compile(jqState, program)
        guard compiled != 0 else {
            jq_teardown(&jqState)
            throw InitializationError.compile(
                .init(errorMessages: errorHandler.errorMessages))
        }

        // Resetting to the default error callback as a fail safe measure,
        // however it should not be required as a compilation error should
        // not be reported after the program has successfully compiled.
        // The default error handler prints error messages to the console.
        jq_set_error_cb(jqState, nil, nil)
        // Setting the debug handler. The handler is retained in memory by
        // the instance of this class.
        jq_set_debug_cb(jqState, debugHandler.callback, debugHandler.rawPointer)
        // The input function is not supported.
        jq_set_input_cb(jqState, nil, nil)
    }

    deinit {
        // We must clean up the jq_state during
        // deinit to free up memory.
        jq_teardown(&jqState)
    }

    /// Returns the first value emitted while processing the JSON input, formatted
    /// into the specified output format. Returns `nil` if no value is emitted.
    ///
    /// The input `json` must be a valid JSON. Processing an input may yield
    /// zero, one or many results. Only the first result is processed, transformed into
    /// the specified format and returned. If the input is not a valid JSON or the jq
    /// programs does not finish successfully a `JQ.ProcessingError` will be
    /// thrown. If transformation into the output format fails, the transformation error
    /// is rethrown.
    ///
    /// - NOTE: A `JQ` instance can only process one input at a time.
    /// Attempting to processing multiple inputs in parallel may lead to the caller
    /// having to wait while another input finishes processing. If you need to
    /// process multiple inputs in parallel, please create a new instance of the
    /// `JQ` object for each thread.
    ///
    /// - parameters:
    ///   - json: A string containing JSON to be processed using the jq
    ///   `program` stored within `self`.
    ///   - format: An output format to which the results are transformed.
    public func first<T: OutputFormat>(for json: String, format: T) throws -> T.Format? {
        do {
            return try one(for: json, format: format)
        } catch ProcessingError.noResultEmitted {
            return nil
        }
    }

    /// Returns the first value emitted while processing the JSON input, formatted
    /// into the specified output format. Throws if no value is emitted.
    ///
    /// The input `json` must be a valid JSON. Processing an input may yield
    /// zero, one or many results. Only the first result is processed, transformed into
    /// the specified format and returned. If the input is not a valid JSON or the
    /// program does not emit any value for the given input or the jq programs does
    /// not finish successfully a `JQ.ProcessingError` will be thrown. If
    /// transformation into the output format fails, the transformation error is rethrown.
    ///
    /// - NOTE: A `JQ` instance can only process one input at a time.
    /// Attempting to processing multiple inputs in parallel may lead to the caller
    /// having to wait while another input finishes processing. If you need to
    /// process multiple inputs in parallel, please create a new instance of the
    /// `JQ` object for each thread.
    ///
    /// - parameters:
    ///   - json: A string containing JSON to be processed using the jq
    ///   `program` stored within `self`.
    ///   - format: An output format to which the results are transformed.
    public func one<T: OutputFormat>(for json: String, format: T) throws -> T.Format {
        let stringResult = try processOne(for: json, outputConfiguration: format.config)
        return try format.transform(string: stringResult)
    }

    /// Returns all values emitted while processing the JSON input, formatted
    /// into the specified output format.
    ///
    /// The input `json` must be a valid JSON. Processing an input may yield
    /// zero, one or many results. The results are accumulated into an array,
    /// transformed into the specified format and returned. If the input is not a valid
    /// JSON or the jq programs does not finish successfully a
    /// `JQ.ProcessingError` will be thrown. If transformation into the output
    /// format fails, the transformation error is rethrown.
    ///
    /// - NOTE: A `JQ` instance can only process one input at a time.
    /// Attempting to processing multiple inputs in parallel may lead to the caller
    /// having to wait while another input finishes processing. If you need to
    /// process multiple inputs in parallel, please create a new instance of the
    /// `JQ` object for each thread.
    ///
    /// - parameters:
    ///   - json: A string containing JSON to be processed using the jq
    ///   `program` stored within `self`.
    ///   - format: An output format to which the results are transformed.
    public func all<T: OutputFormat>(for json: String, format: T) throws -> [T.Format] {
        let stringResults = try processAll(for: json, outputConfiguration: format.config)
        return try stringResults.map(format.transform)
    }

    /// Returns the first value emitted while processing the JSON input, formatted
    /// into the specified output format. Returns `nil` if no value is emitted.
    ///
    /// The input `jsonData` must hold a valid JSON encoded as UTF-8.
    /// Processing an input may yield zero, one or many results. Only the first result
    /// is processed, transformed into the specified format and returned. If the input
    /// is not a valid JSON or the jq programs does not finish successfully a
    /// `JQ.ProcessingError` will be thrown. If transformation into the output
    /// format fails, the transformation error is rethrown.
    ///
    /// - NOTE: A `JQ` instance can only process one input at a time.
    /// Attempting to processing multiple inputs in parallel may lead to the caller
    /// having to wait while another input finishes processing. If you need to
    /// process multiple inputs in parallel, please create a new instance of the
    /// `JQ` object for each thread.
    ///
    /// - parameters:
    ///   - jsonData: Data containing JSON encoded as UTF-8 to be
    ///   processed using the jq `program` stored within `self`.
    ///   - format: An output format to which the results are transformed.
    public func first<T: OutputFormat>(for jsonData: Data, format: T) throws -> T.Format? {
        try first(for: String(decoding: jsonData, as: UTF8.self), format: format)
    }

    /// Returns the first value emitted while processing the JSON input, formatted
    /// into the specified output format. Throws if no value is emitted.
    ///
    /// The input `jsonData` must hold a valid JSON encoded as UTF-8.
    /// Processing an input may yield zero, one or many results. Only the first result
    /// is processed, transformed into the specified format and returned. If the input
    /// is not a valid JSON or the program does not emit any value for the given
    /// input or the jq programs does not finish successfully a
    /// `JQ.ProcessingError` will be thrown. If transformation into the output
    /// format fails, the transformation error is rethrown.
    ///
    /// - NOTE: A `JQ` instance can only process one input at a time.
    /// Attempting to processing multiple inputs in parallel may lead to the caller
    /// having to wait while another input finishes processing. If you need to
    /// process multiple inputs in parallel, please create a new instance of the
    /// `JQ` object for each thread.
    ///
    /// - parameters:
    ///   - jsonData: Data containing JSON encoded as UTF-8 to be
    ///   processed using the jq `program` stored within `self`.
    ///   - format: An output format to which the results are transformed.
    public func one<T: OutputFormat>(for jsonData: Data, format: T) throws -> T.Format {
        try one(for: String(decoding: jsonData, as: UTF8.self), format: format)
    }

    /// Returns all values emitted while processing the JSON input, formatted
    /// into the specified output format.
    ///
    /// The input `jsonData` must hold a valid JSON encoded as UTF-8.
    /// Processing an input may yield zero, one or many results. The results are
    /// accumulated into an array, transformed into the specified format and
    /// returned. If the input is not a valid JSON or the jq programs does not
    /// finish successfully a `JQ.ProcessingError` will be thrown. If
    /// transformation into the output format fails, the transformation error
    /// is rethrown.
    ///
    /// - NOTE: A `JQ` instance can only process one input at a time.
    /// Attempting to processing multiple inputs in parallel may lead to the caller
    /// having to wait while another input finishes processing. If you need to
    /// process multiple inputs in parallel, please create a new instance of the
    /// `JQ` object for each thread.
    ///
    /// - parameters:
    ///   - jsonData: Data containing JSON encoded as UTF-8 to be
    ///   processed using the jq `program` stored within `self`.
    ///   - format: An output format to which the results are transformed.
    public func all<T: OutputFormat>(for jsonData: Data, format: T) throws -> [T.Format] {
        try all(for: String(decoding: jsonData, as: UTF8.self), format: format)
    }

    /// Returns the first value emitted while processing the JSON input, as
    /// a `String`. Returns `nil` if no value is emitted.
    ///
    /// The input `json` must be a valid JSON. Processing an input may yield
    /// zero, one or many results. Only the first result is processed and returned.
    /// If the input is not a valid JSON or the jq programs does not finish
    /// successfully a `JQ.ProcessingError` will be thrown.
    ///
    /// - NOTE: A `JQ` instance can only process one input at a time.
    /// Attempting to processing multiple inputs in parallel may lead to the caller
    /// having to wait while another input finishes processing. If you need to
    /// process multiple inputs in parallel, please create a new instance of the
    /// `JQ` object for each thread.
    ///
    /// - parameters:
    ///   - json: A string containing JSON to be processed using the jq
    ///   `program` stored within `self`.
    @inlinable
    public func first(for json: String) throws -> String? {
        try first(for: json, format: StringFormat())
    }

    /// Returns the first value emitted while processing the JSON input, as
    /// a `String`. Throws if no value is emitted.
    ///
    /// The input `json` must be a valid JSON. Processing an input may yield
    /// zero, one or many results. Only the first result is processed and returned.
    /// If the input is not a valid JSON or the program does not emit any value
    /// for the given input or the jq programs does not finish successfully
    /// a `JQ.ProcessingError` will be thrown.
    ///
    /// - NOTE: A `JQ` instance can only process one input at a time.
    /// Attempting to processing multiple inputs in parallel may lead to the caller
    /// having to wait while another input finishes processing. If you need to
    /// process multiple inputs in parallel, please create a new instance of the
    /// `JQ` object for each thread.
    ///
    /// - parameters:
    ///   - json: A string containing JSON to be processed using the jq
    ///   `program` stored within `self`.
    @inlinable
    public func one(for json: String) throws -> String {
        try one(for: json, format: StringFormat())
    }

    /// Returns all values emitted while processing the JSON input, as an
    /// array of `String`.
    ///
    /// The input `json` must be a valid JSON. Processing an input may yield
    /// zero, one or many results. The results are accumulated into an array
    /// and returned. If the input is not a valid JSON or the jq programs does
    /// not finish successfully a `JQ.ProcessingError` will be thrown.
    ///
    /// - NOTE: A `JQ` instance can only process one input at a time.
    /// Attempting to processing multiple inputs in parallel may lead to the caller
    /// having to wait while another input finishes processing. If you need to
    /// process multiple inputs in parallel, please create a new instance of the
    /// `JQ` object for each thread.
    ///
    /// - parameters:
    ///   - json: A string containing JSON to be processed using the jq
    ///   `program` stored within `self`.
    @inlinable
    public func all(for json: String) throws -> [String] {
        try all(for: json, format: StringFormat())
    }

    /// Returns the first value emitted while processing the JSON input,
    /// as `Data`. Returns `nil` if no value is emitted.
    ///
    /// The input `jsonData` must hold a valid JSON encoded as UTF-8.
    /// Processing an input may yield zero, one or many results. Only the first result
    /// is processed and returned. If the input is not a valid JSON or the jq programs
    /// does not finish successfully a `JQ.ProcessingError` will be thrown.
    ///
    /// - NOTE: A `JQ` instance can only process one input at a time.
    /// Attempting to processing multiple inputs in parallel may lead to the caller
    /// having to wait while another input finishes processing. If you need to
    /// process multiple inputs in parallel, please create a new instance of the
    /// `JQ` object for each thread.
    ///
    /// - parameters:
    ///   - jsonData: Data containing JSON encoded as UTF-8 to be
    ///   processed using the jq `program` stored within `self`.
    @inlinable
    public func first(for jsonData: Data) throws -> Data? {
        try first(for: jsonData, format: DataFormat())
    }

    /// Returns the first value emitted while processing the JSON input,
    /// as `Data`. Throws if no value is emitted.
    ///
    /// The input `jsonData` must hold a valid JSON encoded as UTF-8.
    /// Processing an input may yield zero, one or many results. Only the first result
    /// is processed and returned. If the input is not a valid JSON or the program does
    /// not emit any value for the given input or the jq programs does not finish
    /// successfully a `JQ.ProcessingError` will be thrown. If transformation into
    /// the output format fails, the transformation error is rethrown.
    ///
    /// - NOTE: A `JQ` instance can only process one input at a time.
    /// Attempting to processing multiple inputs in parallel may lead to the caller
    /// having to wait while another input finishes processing. If you need to
    /// process multiple inputs in parallel, please create a new instance of the
    /// `JQ` object for each thread.
    ///
    /// - parameters:
    ///   - jsonData: Data containing JSON encoded as UTF-8 to be
    ///   processed using the jq `program` stored within `self`.
    @inlinable
    public func one(for jsonData: Data) throws -> Data {
        try one(for: jsonData, format: DataFormat())
    }

    /// Returns all values emitted while processing the JSON input, as an
    /// array of `Data`.
    ///
    /// The input `jsonData` must hold a valid JSON encoded as UTF-8.
    /// Processing an input may yield zero, one or many results. The results are
    /// accumulated into an array and returned. If the input is not a valid JSON
    /// or the jq programs does not finish successfully a `JQ.ProcessingError`
    /// will be thrown.
    ///
    /// - NOTE: A `JQ` instance can only process one input at a time.
    /// Attempting to processing multiple inputs in parallel may lead to the caller
    /// having to wait while another input finishes processing. If you need to
    /// process multiple inputs in parallel, please create a new instance of the
    /// `JQ` object for each thread.
    ///
    /// - parameters:
    ///   - jsonData: Data containing JSON encoded as UTF-8 to be
    ///   processed using the jq `program` stored within `self`.
    @inlinable
    public func all(for jsonData: Data) throws -> [Data] {
        try all(for: jsonData, format: DataFormat())
    }
}

// MARK: - Private Result Processing
extension JQ {
    private enum ProcessingResult {
        case value(jv)
        case finished
        case halt
        case haltError(message: ProcessingError.ErrorMessage?, exitCode: Int)
        case exception(message: ProcessingError.ErrorMessage)
    }

    private func startProcessing(
        _ json: String,
        outputConfiguration: OutputConfiguration = .init()
    ) throws {
        // Parse the input string and throw if parsing fails.
        let parsedInput = jv_parse(json)
        guard jv_is_valid(parsedInput) != 0 else {
            let message = errorMessage(from: jv_invalid_get_msg(parsedInput))
            throw ProcessingError.parse(message)
        }

        // Point of synchronization. Each Swift JQ object is backed by a
        // single jq_state struct therefore, only one input can be
        // processed at a time.
        unfairLock.lock()

        // No jq flags are supported yet.
        let jqFlags: Int32 = .zero
        // Start processing input.
        jq_start(jqState, parsedInput, jqFlags)
    }

    private func next() -> ProcessingResult {
        let result = jq_next(jqState)

        if jv_is_valid(result) != 0 {
            return .value(result)
        } else {
            if jq_halted(jqState) != 0 {
                // jq program invoked halt or halt_error.
                return handleHalt()
            } else if jv_invalid_has_msg(jv_copy(result)) != 0 {
                // Processing failed due to an uncaught exception.
                let message = errorMessage(from: jv_invalid_get_msg(jv_copy(result)))
                return .exception(message: message)
            } else {
                return .finished
            }
        }
    }

    private func finishProcessing() {
        // Free up the memory allocated for the input.
        jq_start(jqState, jv_null(), 0)
        unfairLock.unlock()
    }

    private func processOne(
        for json: String,
        outputConfiguration: OutputConfiguration
    ) throws -> String {
        try startProcessing(json)
        defer { finishProcessing() }

        let value = next()
        switch value {
        case .value(let jvValue):
            return generateOutputString(
                for: jvValue,
                outputConfiguration: outputConfiguration)
        case .finished, .halt:
            throw ProcessingError.noResultEmitted
        case .haltError(let message, let exitCode):
            throw ProcessingError.halt(
                .init(
                    errorMessage: message,
                    partialResult: [],
                    exitCode: exitCode))
        case .exception(let message):
            throw ProcessingError.exception(message)
        }
    }

    private func processAll(
        for json: String,
        outputConfiguration: OutputConfiguration
    ) throws -> [String] {
        try startProcessing(json)
        defer { finishProcessing() }
        var processedValues = [String]()

        var currentValue = next()
        while case .value(let jvValue) = currentValue {
            processedValues.append(
                generateOutputString(
                    for: jvValue,
                    outputConfiguration: outputConfiguration))
            currentValue = next()
        }

        switch currentValue {
        case .value:
            break // Should not occur
        case .finished, .halt:
            break // Return normally
        case .haltError(let message, let exitCode):
            throw ProcessingError.halt(
                .init(
                    errorMessage: message,
                    partialResult: processedValues,
                    exitCode: exitCode))
        case .exception(let message):
            throw ProcessingError.exception(message)
        }

        return processedValues
    }
}

// MARK: - Private Helpers
extension JQ {
    private func generateOutputString(
        for value: jv,
        outputConfiguration: OutputConfiguration
    ) -> String {
        if outputConfiguration.rawString, jv_get_kind(value) == JV_KIND_STRING {
            let outputString = String(cString: jv_string_value(value))
            jv_free(value)
            return outputString
        } else {
            let stringResult = jv_dump_string(value, outputConfiguration.jvPrintFlags)
            let outputString = String(cString: jv_string_value(stringResult))
            jv_free(stringResult)
            return outputString
        }
    }

    private func handleHalt() -> ProcessingResult {
        // From the jq_state we aren't able to distinguish between the
        // invocation of halt and halt_error. To overcome this, we define
        // that the program halts normally if halted without an error
        // message and an exit code of 0. In all other cases we will
        // halt with an error.

        let exitCode = jq_get_exit_code(jqState)
        defer { jv_free(exitCode) }

        // If the exitCode is not valid, we assume that halt was invoked.
        guard jv_is_valid(exitCode) != 0 else { return .halt }

        // Default exit code for halt_error.
        var exitCodeValue = 5
        if (jv_get_kind(exitCode) == JV_KIND_NUMBER) {
            exitCodeValue = Int(jv_number_value(exitCode))
        }

        let message = haltMessage(from: jq_get_error_message(jqState))
        // The program halts normally if halted without an error message
        // and an exit code of 0.
        if message == nil, exitCodeValue == .zero {
            return .halt
        } else {
            return .haltError(message: message, exitCode: exitCodeValue)
        }
    }

    private func errorMessage(from value: jv) -> ProcessingError.ErrorMessage {
        defer { jv_free(value) }
        // If an error message is of kind string we store the raw string
        // otherwise, the string representation of the value is used.
        if jv_get_kind(value) == JV_KIND_STRING {
            return ProcessingError.ErrorMessage(
                message: String(cString: jv_string_value(value)),
                isString: true)
        } else {
            let messageString = jv_dump_string(jv_copy(value), 0)
            defer { jv_free(messageString) }
            return ProcessingError.ErrorMessage(
                message: String(cString: jv_string_value(messageString)),
                isString: false)
        }
    }

    private func haltMessage(from value: jv) -> ProcessingError.ErrorMessage? {
        defer { jv_free(value) }
        // If a halt is executed with an invalid message or null,
        // we treat it as a halt without a message.
        if jv_is_valid(value) == 0 || jv_get_kind(value) == JV_KIND_NULL {
            return nil
        } else {
            return errorMessage(from: value)
        }
    }
}
