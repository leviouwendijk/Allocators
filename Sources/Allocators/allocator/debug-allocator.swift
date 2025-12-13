import Foundation

public struct DebugAllocator<Alloc: Allocator>: Allocator {
    private let alloc: Alloc
    public var tracker: any AllocationTracking

    public init(
        alloc: Alloc,
        options: AllocationTracker.Options = .init()
    ) {
        self.alloc = alloc
        self.tracker = AllocationTracker(options: options)
    }

    public func allocate<T>(_ type: T.Type, capacity: Int) -> UnsafeMutablePointer<T> {
        let ptr = alloc.allocate(T.self, capacity: capacity)
        tracker.allocateRecord(for: ptr, capacity: capacity)
        return ptr
    }

    public func deconstruct<T>(_ pointer: UnsafeMutablePointer<T>, count: Int) {
        tracker.deconstructRecord(for: pointer, as: T.self, count: count)
        alloc.deconstruct(pointer, count: count)
    }

    public func deallocate<T>(_ pointer: UnsafeMutablePointer<T>) {
        tracker.deallocateRecord(for: pointer, as: T.self)
        alloc.deallocate(pointer)
    }

    public func clear<T>(_ pointer: UnsafeMutablePointer<T>, count: Int) {
        tracker.clearRecord(for: pointer, as: T.self, count: count)
        alloc.clear(pointer, count: count)
    }

    // public func hasLeaks() -> Bool { tracker.hasLeaks() }
    // public func leakReport() -> String? { tracker.leakReport() }

    // public func assertNoLeaks(
    //     file: StaticString = #file,
    //     filePath: StaticString = #filePath,
    //     line: UInt = #line
    // ) {
    //     if let report = tracker.leakReport() {
    //         preconditionFailure("\(report)\n[filePath: \(filePath)]", file: file, line: line)
    //     }
    // }
}
