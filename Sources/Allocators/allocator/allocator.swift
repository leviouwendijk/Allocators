import Foundation

/// A simple allocator protocol for manually managed heap memory.
/// 
/// The allocator is responsible for returning uninitialized storage and
/// later deinitializing and deallocating it.
public protocol Allocator: Sendable {
    /// Allocates space for `capacity` elements of type `T`.
    ///
    /// - Note: The returned memory is uninitialized. The caller is
    ///   responsible for initializing it (e.g. `initialize(to:)`,
    ///   `initialize(repeating:count:)`, or per-element `initialize`).
    func allocate<T>(
        _ type: T.Type,
        capacity: Int
    ) -> UnsafeMutablePointer<T>

    /// Deinitializes and deallocates storage previously obtained from `allocate`.
    ///
    /// - Important: `capacity` must match what was originally passed to `allocate`,
    ///   and the caller must ensure that at most `capacity` elements were initialized.
    func deallocate<T>(
        _ pointer: UnsafeMutablePointer<T>,
        capacity: Int
    )
}

