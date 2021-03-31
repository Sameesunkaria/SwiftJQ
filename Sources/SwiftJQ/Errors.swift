extension JQ {
    /// An error that occurs during the initialization of a `JQ` object instance.
    public enum InitializationError: Error, CustomStringConvertible {
        /// Information about the errors encountered while compiling a jq program.
        public struct Compile: CustomStringConvertible {
            /// A textual representation of this instance.
            public var description: String {
                "Error compiling the jq program.\n"
                    + errorMessages.joined(separator: "\n")
            }

            /// Error messages returned while attempting to compile the jq program.
            public let errorMessages: [String]
        }

        /// An indication that `JQ` object instance wasn't able to fully initialize
        /// due to an allocation failure.
        case alloc
        /// An indication that the jq program failed to compile.
        case compile(Compile)

        /// A textual representation of this instance.
        public var description: String {
            switch self {
            case .alloc: return "jq failed to allocate memory."
            case .compile(let info): return "Compile Error: \(info.description)"
            }
        }
    }

    /// An error that occurs while processing an input.
    public enum ProcessingError: Error, CustomStringConvertible {
        /// Represents an error message returned from jq. This error message
        /// may be a string or a string representation of a JSON object.
        public struct ErrorMessage: CustomStringConvertible {
            /// A textual representation of this instance.
            public var description: String { "(\(isString ? "string" : "non-string")) \(message)" }
            /// The error message returned from jq.
            public var message: String
            /// A flag indicating the error message is a raw string instead of a JSON.
            public var isString: Bool
        }

        /// Information about the jq state when a `halt_error` is invoked.
        public struct Halt: CustomStringConvertible {
            /// A textual representation of this instance.
            public var description: String {
                (errorMessage?.description ?? "Program halted with no message.")
                    + "\nExit code: \(exitCode)"
            }

            /// The error message logged by halt error.
            /// The message will be `nil` if a `null` was logged.
            public let errorMessage: ErrorMessage?
            /// The partial result accumulated from previous iterations
            /// on the jq program before the halt error was invoked.
            public let partialResult: [String]
            /// The exit code associated with the halt error.
            public let exitCode: Int
        }

        /// An indication that input data is not a valid JSON or corrupted otherwise.
        case parse(ErrorMessage)
        /// An indication that an exception uncaught by the jq program was encountered.
        case exception(ErrorMessage)
        /// An indication that the program was explicitly halted with an error using
        /// the `halt_error` function.
        case halt(Halt)
        /// An indication that the program did not emit a result for the given input
        /// where one was expected.
        case noResultEmitted

        /// A textual representation of this instance.
        public var description: String {
            switch self {
            case .parse(let info): return "Parse Error: \(info.description)"
            case .halt(let info): return "Halt Error: \(info.description)"
            case .exception(let info): return "Uncaught Exception: \(info.description)"
            case .noResultEmitted: return "jq Program did not emit a result for the given input."
            }
        }
    }
}
