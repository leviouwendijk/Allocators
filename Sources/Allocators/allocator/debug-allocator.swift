import Foundation

public struct DebugAllocator<Base: Allocator> {
    private var base: Base

    private struct Record {
        var capacity: Int
        var type: Any.Type
        var alive: Bool
    }

    private var records: [UnsafeRawPointer: Record] = [:]

    public init(base: Base) {
        self.base = base
    }

    public mutating func allocate<T>(
        _ type: T.Type,
        capacity: Int
    ) -> UnsafeMutablePointer<T> {
        let ptr = base.allocate(T.self, capacity: capacity)
        let key = UnsafeRawPointer(ptr)

        precondition(records[key] == nil, "pointer reused without free?")

        records[key] = Record(
            capacity: capacity,
            type: T.self,
            alive: true
        )

        return ptr
    }

    public mutating func deallocate<T>(
        _ pointer: UnsafeMutablePointer<T>,
        capacity: Int
    ) {
        let key = UnsafeRawPointer(pointer)
        guard var rec = records[key] else {
            preconditionFailure("deallocate: unknown pointer \(pointer)")
        }
        precondition(rec.alive, "double free on pointer \(pointer)")
        precondition(
            rec.capacity == capacity,
            "deallocate: capacity mismatch (got \(capacity), expected \(rec.capacity))"
        )
        precondition(
            rec.type == T.self,
            "deallocate: type mismatch (stored \(rec.type), deallocating as \(T.self))"
        )

        rec.alive = false
        records[key] = rec

        base.deallocate(pointer, capacity: capacity)
    }
}
