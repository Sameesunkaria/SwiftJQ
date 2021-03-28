import Cjq

extension JQ {
    /// Output configuration options for the result of the jq program.
    public struct OutputConfiguration {
        /// Represents white space characters to use for indenting pretty output.
        public enum IndentSpace {
            /// The pretty output is indented with a single tab for each level.
            case tabs
            /// The pretty output is indented with the associated number of
            /// spaces (no more than 7) for each level.
            case spaces(Int)
        }

        /// The output configuration option that sorts keys in lexicographic order.
        public var sortedKeys: Bool
        /// The output configuration option that returns string results directly
        /// instead of formatting them as a quoted JSON string.
        public var rawString: Bool
        /// The output configuration option that uses ample white space and
        /// indentation to make output easy to read.
        public var pretty: Bool
        /// The output configuration option that specifies the white space
        /// characters to use for indenting the pretty output.
        ///
        /// This option is only used when the `pretty` output configuration
        /// is enabled.
        public var indent: IndentSpace

        /// Creates a new OutputConfiguration.
        public init(
            sortedKeys: Bool = false,
            rawString: Bool = false,
            pretty: Bool = false,
            indent: IndentSpace = .spaces(4)
        ) {
            self.sortedKeys = sortedKeys
            self.rawString = rawString
            self.pretty = pretty
            self.indent = indent
        }

        var jvPrintFlags: Int32 {
            var flags: UInt32 = 0
            flags |= sortedKeys ? JV_PRINT_SORTED.rawValue : 0
            flags |= pretty ? JV_PRINT_PRETTY.rawValue : 0
            switch indent {
            case .tabs: flags |= JV_PRINT_TAB.rawValue
            // The number of spaces are bounded to a value from 0 to 7.
            // The flag representing the number of spaces is equal to
            // the number of spaces, bit-shifted left by 8. These flags
            // don't have a named case in the enumeration.
            case .spaces(let count): flags |= UInt32(min(max(count, 0), 7)) << 8
            }
            return Int32(flags)
        }
    }
}
