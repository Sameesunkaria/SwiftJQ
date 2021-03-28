import Cjq

extension JQ {
    /// The `CompilationErrorHandler` accumulates the error messages into an array.
    final class CompilationErrorHandler {
        private(set) var errorMessages = [String]()
        private func handle(message: jv) {
            let formattedMessage = jq_format_error(message)
            errorMessages.append(String(cString: jv_string_value(formattedMessage)))
            jv_free(formattedMessage)
        }

        /// Unretained raw pointer to `self`.
        var rawPointer: UnsafeMutableRawPointer { Unmanaged.passUnretained(self).toOpaque() }

        /// A callback for handling error messages that are reported during compilation.
        let callback: jq_msg_cb = { handlerPointer, message in
            guard
                let errorHandler = handlerPointer.map({
                    Unmanaged<CompilationErrorHandler>
                        .fromOpaque($0)
                        .takeUnretainedValue()
                })
            else {
                return
            }

            errorHandler.handle(message: message)
        }
    }

    /// The `DebugHandler` prints debug messages from the jq program to the console.
    final class DebugHandler {
        private func handle(message: jv) {
            let messageDump = jv_dump_string(message, 0)
            print("JQ DEBUG: \(String(cString: jv_string_value(messageDump)))")
            jv_free(messageDump)
        }

        /// Unretained raw pointer to `self`.
        var rawPointer: UnsafeMutableRawPointer { Unmanaged.passUnretained(self).toOpaque() }

        /// A callback for handling debug messages that are reported
        /// while the input is being processed.
        let callback: jq_msg_cb = { handlerPointer, message in
            guard
                let debugHandler = handlerPointer.map({
                    Unmanaged<DebugHandler>
                        .fromOpaque($0)
                        .takeUnretainedValue()
                })
            else {
                return
            }

            debugHandler.handle(message: message)
        }
    }
}
