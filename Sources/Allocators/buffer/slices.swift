import Foundation

/// Common typealiases for byte-oriented slices.
/// These are non-owning, escapable views over contiguous memory.
///
/// Lifetime is the caller’s responsibility.
public typealias ByteSlice = UnsafeBufferPointer<UInt8>
public typealias MutableByteSlice = UnsafeMutableBufferPointer<UInt8>

/// Example utility for summing an `UnsafeBufferPointer<Int>`.
@inlinable
public func _exampleSumSlice(
    _ slice: UnsafeBufferPointer<Int>
) -> Int {
    var total = 0
    for value in slice {
        total += value
    }
    return total
}

@inlinable
public func _exampleDoubleInPlace(
    _ slice: UnsafeMutableBufferPointer<Int>
) {
    for i in 0..<slice.count {
        slice[i] *= 2
    }
}
