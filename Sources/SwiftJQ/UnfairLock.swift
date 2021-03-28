import Darwin

/// A Swift wrapper for `os_unfair_lock`.
final class UnfairLock {
    private var unfairLock = os_unfair_lock_s()

    /// Locks the underlying unfair lock.
    @inlinable
    func lock() {
        os_unfair_lock_lock(&unfairLock)
    }

    /// Unlocks the underlying unfair lock.
    @inlinable
    func unlock() {
        os_unfair_lock_unlock(&unfairLock)
    }
}
