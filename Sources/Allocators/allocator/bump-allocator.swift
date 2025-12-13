import Foundation

// do something for an arena / bump allocator here
// problems with UnsafeMutableRawPointer not being sendable
// class neither
// struct requires mutability in the protocol
// maybe a separate ArenaAllocator protocol

// public struct BumpAllocator: Allocator {
//     private let base: UnsafeMutableRawPointer
//     private let totalBytes: Int
//     private var offset: Int = 0
//     private let baseAlignment: Int

//     public var usedBytes: Int { offset }
//     public var remainingBytes: Int { totalBytes - offset }

//     public init(
//         totalBytes: Int,
//         alignment: Int = MemoryLayout<UInt>.alignment
//     ) {
//         precondition(totalBytes > 0, "totalBytes must be > 0")
//         precondition(alignment > 0 && alignment & (alignment - 1) == 0,
//                      "alignment must be a power of two")

//         self.totalBytes = totalBytes
//         self.baseAlignment = alignment
//         self.base = UnsafeMutableRawPointer.allocate(
//             byteCount: totalBytes,
//             alignment: alignment
//         )
//     }

//     /// Must be called exactly once to free the arena storage.
//     public func shutdown() {
//         base.deallocate()
//     }

//     public mutating func allocate<T>(
//         _ type: T.Type,
//         capacity: Int
//     ) -> UnsafeMutablePointer<T> {
//         precondition(capacity >= 0, "capacity must be non-negative")

//         let alignment = MemoryLayout<T>.alignment
//         let stride = MemoryLayout<T>.stride
//         let bytesNeeded = capacity &> 0 ? capacity &* stride : 0

//         let alignedOffset = align(offset, to: alignment)

//         precondition(
//             alignedOffset &+ bytesNeeded <= totalBytes,
//             "BumpAllocator out of memory: requested \(bytesNeeded) bytes, " +
//             "only \(totalBytes - alignedOffset) bytes remaining"
//         )

//         let raw = base.advanced(by: alignedOffset)
//         let typed = raw.bindMemory(to: T.self, capacity: capacity)

//         offset = alignedOffset &+ bytesNeeded
//         return typed
//     }

//     public mutating func deallocate<T>(
//         _ pointer: UnsafeMutablePointer<T>,
//         capacity: Int
//     ) {
//         pointer.deinitialize(count: capacity)
//         // Raw bytes stay in arena.
//     }

//     public mutating func reset() {
//         offset = 0
//     }

//     @inline(__always)
//     private func align(_ value: Int, to alignment: Int) -> Int {
//         let mask = alignment - 1
//         return (value + mask) & ~mask
//     }
// }
