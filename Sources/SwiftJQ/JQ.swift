import Cjq

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
/// let expensiveFruits = try expensiveFruitsFilter.process(
///     fruitsJSON,
///     outputConfiguration: .init(rawString: true))
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
    public init(program: String) throws {
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

        // Setting library search paths. Not doing so raises an assertion
        // if an include statement is present in the program.
        jq_set_attr(jqState, jv_string("JQ_LIBRARY_PATH"), jv_array())

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

    /// Process JSON input using the jq `program` stored within `self`.
    ///
    /// The `inputJSON` must be a string containing a valid JSON.
    /// Processing an input may yield zero, one or many results. The returned
    /// array accumulates all the results emitted by the jq for the provided
    /// `inputJSON`. If the input is not a valid JSON or the jq programs does
    /// not finish successfully a `JQ.ProcessingError` will be thrown.
    ///
    /// Optionally, a `JQ.OutputConfiguration` may be provided. The output
    /// configuration defines how the final output should be formatted.
    ///
    /// - NOTE: A `JQ` instance can only process one input at a time.
    /// Attempting to processing multiple inputs in parallel may lead to the caller
    /// having to wait while another input finishes processing. If you need to
    /// process multiple inputs in parallel, please create a new instance of the
    /// `JQ` object for each thread.
    ///
    /// - parameters:
    ///   - inputJSON: A string containing JSON which will be processed
    ///   using the jq `program` stored within `self`.
    ///   - outputConfiguration: Configuration options for formatting
    ///   the output of the jq program.
    public func process(
        _ inputJSON: String,
        outputConfiguration: OutputConfiguration = .init()
    ) throws -> [String] {
        // Parse the input string and throw if parsing fails.
        let parsedInput = jv_parse(inputJSON)
        guard jv_is_valid(parsedInput) != 0 else {
            let message = errorMessage(from: jv_invalid_get_msg(parsedInput))
            throw ProcessingError.parse(message)
        }

        // Point of synchronization. Each Swift JQ object is backed by a
        // single jq_state struct therefore, only one input can be
        // processed at a time.
        unfairLock.lock()
        defer { unfairLock.unlock() }

        // No jq flags are supported yet.
        let jqFlags: Int32 = .zero
        // Start processing input.
        jq_start(jqState, parsedInput, jqFlags)

        // Start processing the input. The outputs are accumulated into
        // the output array, until jq_next returns an invalid value.
        var output = [String]()
        var result = jq_next(jqState)
        defer { jv_free(result) }

        while jv_is_valid(result) != 0 {
            output.append(
                generateOutputString(
                    for: result,
                    outputConfiguration: outputConfiguration))
            result = jq_next(jqState)
        }

        if jq_halted(jqState) != 0 {
            // jq program invoked halt or halt_error.
            return try handleHalt(partialResult: output)
        } else if jv_invalid_has_msg(jv_copy(result)) != 0 {
            // Processing failed due to an uncaught exception.
            let message = errorMessage(from: jv_invalid_get_msg(jv_copy(result)))
            throw ProcessingError.exception(message)
        }

        // Successfully finished processing.
        return output
    }
}

// MARK: - Private Helpers
extension JQ {
    private func generateOutputString(
        for value: jv,
        outputConfiguration: OutputConfiguration
    ) -> String {
        if outputConfiguration.rawString, jv_get_kind(value) == JV_KIND_STRING {
            defer { jv_free(value) }
            return String(cString: jv_string_value(value))
        } else {
            let stringResult = jv_dump_string(value, outputConfiguration.jvPrintFlags)
            jv_free(stringResult)
            return String(cString: jv_string_value(stringResult))
        }
    }

    private func handleHalt(partialResult: [String]) throws -> [String] {
        // As we are using the error throwing semantics of Swift, we need a
        // clear distinction between a normal return scenario and throwing
        // an error. Generally, a halt should return normally, and a
        // halt_error should throw an error. However, here we aren't able to
        // make a distinction between the invocation of the two halt
        // functions. To overcome this, we define that the program returns
        // normally if halted without an error message and an exit code
        // of 0. In all other cases we will throw.

        let exitCode = jq_get_exit_code(jqState)
        defer { jv_free(exitCode) }

        // If the exitCode is not valid, we assume that halt was invoked
        // and return immediately.
        guard jv_is_valid(exitCode) != 0 else { return partialResult }

        // Default exit code for halt_error.
        var exitCodeValue = 5
        if (jv_get_kind(exitCode) == JV_KIND_NUMBER) {
            exitCodeValue = Int(jv_number_value(exitCode))
        }

        let message = haltMessage(from: jq_get_error_message(jqState))
        // The program returns normally if halted without an error message
        // and an exit code of 0.
        if message == nil, exitCodeValue == .zero {
            return partialResult
        } else {
            throw ProcessingError.halt(
                .init(
                    errorMessage: message,
                    partialResult: partialResult,
                    exitCode: exitCodeValue))
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
