/// Uniquely owned debug-allocation domain.
///
/// The owner itself is noncopyable. Pass `allocator` through allocating APIs;
/// that handle is intentionally copyable and all copies observe the same
/// tracking domain.
public struct DebugAllocator<Alloc: Allocator>: ~Copyable, MemoryInspecting {
    private let alloc: Alloc
    private let tracker: AllocationTracker

    public init(
        alloc: consuming Alloc,
        options: AllocationTracker.Options = .init()
    ) {
        self.alloc = alloc
        self.tracker = AllocationTracker(options: options)
    }

    /// Copyable allocation capability associated with this debug domain.
    public var allocator: Handle {
        Handle(
            alloc: alloc,
            tracker: tracker
        )
    }

    public var inspector: MemoryInspector {
        MemoryInspector(tracker: tracker)
    }
}

public extension DebugAllocator {
    struct Handle: Allocator {
        private let alloc: Alloc
        private let tracker: AllocationTracker

        fileprivate init(
            alloc: Alloc,
            tracker: AllocationTracker
        ) {
            self.alloc = alloc
            self.tracker = tracker
        }

        public func allocate<T>(
            _ type: T.Type,
            capacity: Int
        ) -> UnsafeMutablePointer<T> {
            let pointer = alloc.allocate(
                type,
                capacity: capacity
            )
            tracker.allocateRecord(
                for: pointer,
                capacity: capacity
            )
            return pointer
        }

        public func deconstruct<T>(
            _ pointer: UnsafeMutablePointer<T>,
            count: Int
        ) {
            tracker.deconstructRecord(
                for: pointer,
                as: T.self,
                count: count
            )
            alloc.deconstruct(
                pointer,
                count: count
            )
        }

        public func deallocate<T>(
            _ pointer: UnsafeMutablePointer<T>
        ) {
            tracker.deallocateRecord(
                for: pointer,
                as: T.self
            )
            alloc.deallocate(pointer)
        }

        public func clear<T>(
            _ pointer: UnsafeMutablePointer<T>,
            count: Int
        ) {
            tracker.clearRecord(
                for: pointer,
                as: T.self,
                count: count
            )
            alloc.clear(
                pointer,
                count: count
            )
        }
    }
}

extension DebugAllocator.Handle: Sendable
where Alloc: Sendable {}

extension DebugAllocator.Handle: ConcurrentAllocator
where Alloc: ConcurrentAllocator {}
