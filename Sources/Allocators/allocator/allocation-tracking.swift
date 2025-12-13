import Foundation

public protocol AllocationTracking: Sendable {
    func hasLeaks() -> Bool
    func leakReport() -> String?

    func allocateRecord<T>(for pointer: UnsafeMutablePointer<T>, capacity: Int)
    func deconstructRecord<T>(for pointer: UnsafeMutablePointer<T>, as: T.Type, count: Int)
    func deallocateRecord<T>(for pointer: UnsafeMutablePointer<T>, as: T.Type)
    func clearRecord<T>(for pointer: UnsafeMutablePointer<T>, as: T.Type, count: Int)
}
