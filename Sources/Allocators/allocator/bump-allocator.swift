/// Uniquely owned monotonic allocation domain.
///
/// `BumpAllocator` owns both its allocation metadata and backing storage.
/// Its `allocator` property vends a copyable, nonescapable handle whose
/// lifetime is borrowed from this owner.
///
/// This keeps ordinary allocation calls cheap while allowing Swift's lifetime
/// checker to prevent the allocator capability from outliving the arena.
public struct BumpAllocator: ~Copyable {
    fileprivate struct State {
        let base: UnsafeMutableRawPointer
        let totalBytes: Int
        let baseAlignment: Int
        var offset: Int
    }

    private let state: UnsafeMutablePointer<State>

    public init(
        totalBytes: Int,
        alignment: Int = 64
    ) {
        precondition(
            totalBytes > 0,
            "totalBytes must be greater than zero"
        )
        precondition(
            alignment > 0 && alignment & (alignment - 1) == 0,
            "alignment must be a power of two"
        )

        let base = UnsafeMutableRawPointer.allocate(
            byteCount: totalBytes,
            alignment: alignment
        )
        let state = UnsafeMutablePointer<State>.allocate(
            capacity: 1
        )

        state.initialize(
            to: State(
                base: base,
                totalBytes: totalBytes,
                baseAlignment: alignment,
                offset: 0
            )
        )

        self.state = state
    }

    deinit {
        state.pointee.base.deallocate()
        state.deinitialize(count: 1)
        state.deallocate()
    }

    /// A copyable allocator capability with a lifetime borrowed from this
    /// allocation domain.
    public var allocator: Handle {
        @_lifetime(borrow self)
        borrowing get {
            Handle(owner: self)
        }
    }

    public var usedBytes: Int {
        state.pointee.offset
    }

    public var remainingBytes: Int {
        state.pointee.totalBytes - state.pointee.offset
    }

    /// Explicitly consumes this allocation domain.
    ///
    /// A dependent allocator handle cannot remain live across this operation.
    public consuming func shutdown() {}
}

public extension BumpAllocator {
    /// Copyable allocation capability that cannot escape the lifetime of its
    /// `BumpAllocator` owner.
    struct Handle: ~Escapable, Allocator {
        fileprivate let state: UnsafeMutablePointer<State>

        @_lifetime(borrow owner)
        fileprivate init(
            owner: borrowing BumpAllocator
        ) {
            self.state = owner.state
        }

        public func allocate<T>(
            _ type: T.Type,
            capacity: Int
        ) -> UnsafeMutablePointer<T> {
            precondition(
                capacity > 0,
                "BumpAllocator requires capacity greater than zero"
            )

            let typeAlignment = MemoryLayout<T>.alignment
            precondition(
                typeAlignment <= state.pointee.baseAlignment,
                "requested type alignment exceeds bump allocator base alignment"
            )

            let (bytesNeeded, byteOverflow) = capacity.multipliedReportingOverflow(
                by: MemoryLayout<T>.stride
            )
            precondition(
                !byteOverflow,
                "requested allocation size overflowed Int"
            )

            let mask = typeAlignment - 1
            let (offsetWithMask, alignmentOverflow) = state.pointee.offset.addingReportingOverflow(mask)
            precondition(
                !alignmentOverflow,
                "requested aligned offset overflowed Int"
            )

            let alignedOffset = offsetWithMask & ~mask
            let (endOffset, endOverflow) = alignedOffset.addingReportingOverflow(bytesNeeded)

            precondition(
                !endOverflow && endOffset <= state.pointee.totalBytes,
                "BumpAllocator out of memory: requested \(bytesNeeded) bytes, \(remainingBytes(from: alignedOffset)) bytes remain"
            )

            let raw = state.pointee.base.advanced(
                by: alignedOffset
            )
            let pointer = raw.bindMemory(
                to: T.self,
                capacity: capacity
            )

            state.pointee.offset = endOffset
            return pointer
        }

        public func deconstruct<T>(
            _ pointer: UnsafeMutablePointer<T>,
            count: Int
        ) {
            precondition(
                count >= 0,
                "count must be non-negative"
            )
            pointer.deinitialize(count: count)
        }

        /// Monotonic allocations are not individually released.
        public func deallocate<T>(
            _ pointer: UnsafeMutablePointer<T>
        ) {}

        public func clear<T>(
            _ pointer: UnsafeMutablePointer<T>,
            count: Int
        ) {
            deconstruct(
                pointer,
                count: count
            )
            deallocate(pointer)
        }

        private func remainingBytes(
            from offset: Int
        ) -> Int {
            state.pointee.totalBytes - offset
        }
    }
}
