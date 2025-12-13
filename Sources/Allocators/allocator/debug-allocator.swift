import Foundation

public struct DebugAllocator<Base: Allocator> {
    public struct Options: Sendable {
        public var captureStackTraces: Bool
        public var reportLeaksOnDeinit: Bool

        public init(
            captureStackTraces: Bool = false,
            reportLeaksOnDeinit: Bool = true
        ) {
            self.captureStackTraces = captureStackTraces
            self.reportLeaksOnDeinit = reportLeaksOnDeinit
        }
    }

    private var base: Base
    private let tracker: Tracker

    private struct Record {
        var capacity: Int
        var stride: Int
        var type: Any.Type
        var alive: Bool
        var allocationID: UInt64
        var stack: [String]?
    }

    private final class Tracker {
        private let lock = NSLock()

        private let captureStackTraces: Bool
        private let reportLeaksOnDeinit: Bool

        private var nextAllocationID: UInt64 = 1
        private var records: [UnsafeRawPointer: Record] = [:]

        init(options: Options) {
            self.captureStackTraces = options.captureStackTraces
            self.reportLeaksOnDeinit = options.reportLeaksOnDeinit
        }

        deinit {
            guard reportLeaksOnDeinit else { return }
            let report = leakReportLocked()
            guard report != nil else { return }

            // Don't crash in deinit; print loudly so tests/dev runs surface it.
            fputs(report!, stderr)
        }

        func allocateRecord<T>(for pointer: UnsafeMutablePointer<T>, capacity: Int) {
            let key = UnsafeRawPointer(pointer)

            lock.lock()
            defer { lock.unlock() }

            if let existing = records[key], existing.alive {
                preconditionFailure("allocate: pointer reused without free? \(pointer)")
            }

            let id = nextAllocationID
            nextAllocationID &+= 1

            records[key] = Record(
                capacity: capacity,
                stride: MemoryLayout<T>.stride,
                type: T.self,
                alive: true,
                allocationID: id,
                stack: captureStackTraces ? Thread.callStackSymbols : nil
            )
        }

        func deallocateRecord<T>(for pointer: UnsafeMutablePointer<T>, capacity: Int) {
            let key = UnsafeRawPointer(pointer)

            lock.lock()
            defer { lock.unlock() }

            guard var rec = records[key] else {
                preconditionFailure("deallocate: unknown pointer \(pointer)")
            }

            precondition(rec.alive, "double free on pointer \(pointer) (alloc #\(rec.allocationID))")
            precondition(
                rec.capacity == capacity,
                "deallocate: capacity mismatch (got \(capacity), expected \(rec.capacity)) (alloc #\(rec.allocationID))"
            )
            precondition(
                rec.type == T.self,
                "deallocate: type mismatch (stored \(rec.type), deallocating as \(T.self)) (alloc #\(rec.allocationID))"
            )

            rec.alive = false
            records[key] = rec
        }

        func hasLeaks() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            return records.values.contains(where: { $0.alive })
        }

        func leakReport() -> String? {
            lock.lock()
            defer { lock.unlock() }
            return leakReportLocked()
        }

        private func leakReportLocked() -> String? {
            let leaks = records
                .filter { $0.value.alive }
                .sorted { $0.value.allocationID < $1.value.allocationID }

            guard !leaks.isEmpty else { return nil }

            var totalBytes = 0
            var out = ""
            out += "\n[DebugAllocator] MEMORY LEAKS DETECTED: \(leaks.count)\n"

            for (ptr, rec) in leaks {
                let bytes = rec.capacity * rec.stride
                totalBytes += bytes

                out += "\n- alloc #\(rec.allocationID)\n"
                out += "  ptr: \(ptr)\n"
                out += "  type: \(rec.type)\n"
                out += "  capacity: \(rec.capacity)\n"
                out += "  stride: \(rec.stride)\n"
                out += "  bytes: \(bytes)\n"

                if let stack = rec.stack, !stack.isEmpty {
                    out += "  stack:\n"
                    // Keep it readable; full stacks get noisy fast.
                    for line in stack.prefix(12) {
                        out += "    \(line)\n"
                    }
                    if stack.count > 12 {
                        out += "    … (\(stack.count - 12) more)\n"
                    }
                }
            }

            out += "\n[DebugAllocator] total leaked bytes (approx): \(totalBytes)\n\n"
            return out
        }
    }

    public init(base: Base, options: Options = Options()) {
        self.base = base
        self.tracker = Tracker(options: options)
    }

    public mutating func allocate<T>(
        _ type: T.Type,
        capacity: Int
    ) -> UnsafeMutablePointer<T> {
        let ptr = base.allocate(T.self, capacity: capacity)
        tracker.allocateRecord(for: ptr, capacity: capacity)
        return ptr
    }

    public mutating func deallocate<T>(
        _ pointer: UnsafeMutablePointer<T>,
        capacity: Int
    ) {
        tracker.deallocateRecord(for: pointer, capacity: capacity)
        base.deallocate(pointer, capacity: capacity)
    }

    public func hasLeaks() -> Bool {
        tracker.hasLeaks()
    }

    public func leakReport() -> String? {
        tracker.leakReport()
    }

    public func assertNoLeaks(
        file: StaticString = #file,
        filePath: StaticString = #filePath,
        line: UInt = #line
    ) {
        if let report = tracker.leakReport() {
            preconditionFailure("\(report)\n[filePath: \(filePath)]", file: file, line: line)
        }
    }
}
