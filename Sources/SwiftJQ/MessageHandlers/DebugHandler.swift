import Cjq

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
