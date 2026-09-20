/// Uniquely owned monotonic allocation domain.
///
/// `BumpAllocator` owns the allocation domain while `allocator` produces a
/// cheap copyable capability suitable for passing through ordinary APIs.
/// Individual deallocations do not release backing storage. The backing region
/// is released when the owner and all outstanding allocator handles leave
/// scope.
///
/// This first implementation is deliberately monotonic: it does not expose a
/// reset operation, avoiding reuse of previously type-bound Swift memory until
/// we define reset/rebinding semantics explicitly.
public struct BumpAllocator: ~Copyable {
    fileprivate final class State {
        let base: UnsafeMutableRawPointer
        let totalBytes: Int
        let baseAlignment: Int
        var offset: Int

        init(
            totalBytes: Int,
            alignment: Int
        ) {
            self.totalBytes = totalBytes
            self.baseAlignment = alignment
            self.offset = 0
            self.base = UnsafeMutableRawPointer.allocate(
                byteCount: totalBytes,
                alignment: alignment
            )
        }

        deinit {
            base.deallocate()
        }
    }

    private let state: State

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

        self.state = State(
            totalBytes: totalBytes,
            alignment: alignment
        )
    }

    public var allocator: Handle {
        Handle(state: state)
    }

    public var usedBytes: Int {
        state.offset
    }

    public var remainingBytes: Int {
        state.totalBytes - state.offset
    }
}

public extension BumpAllocator {
    /// Copyable, non-Sendable allocation capability into one bump domain.
    struct Handle: Allocator {
        fileprivate let state: State

        fileprivate init(state: State) {
            self.state = state
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
                typeAlignment <= state.baseAlignment,
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
            let (offsetWithMask, alignmentOverflow) = state.offset.addingReportingOverflow(mask)
            precondition(
                !alignmentOverflow,
                "requested aligned offset overflowed Int"
            )

            let alignedOffset = offsetWithMask & ~mask
            let (endOffset, endOverflow) = alignedOffset.addingReportingOverflow(bytesNeeded)

            precondition(
                !endOverflow && endOffset <= state.totalBytes,
                "BumpAllocator out of memory: requested \(bytesNeeded) bytes, \(state.remainingBytes(from: alignedOffset)) bytes remain"
            )

            let raw = state.base.advanced(by: alignedOffset)
            let pointer = raw.bindMemory(
                to: T.self,
                capacity: capacity
            )

            state.offset = endOffset
            return pointer
        }

        /// Monotonic allocations are not individually released.
        public func deallocate<T>(
            _ pointer: UnsafeMutablePointer<T>
        ) {}
    }
}

private extension BumpAllocator.State {
    func remainingBytes(from offset: Int) -> Int {
        totalBytes - offset
    }
}
