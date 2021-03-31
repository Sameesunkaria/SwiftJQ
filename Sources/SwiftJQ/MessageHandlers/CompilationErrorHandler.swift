import Cjq

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
