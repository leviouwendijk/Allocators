import Foundation

public protocol LeakCheckingAllocator {
    func hasLeaks() -> Bool
    func leakReport() -> String?
    func assertNoLeaks(file: StaticString, filePath: StaticString, line: UInt)
}

public struct DebugAllocator<Base: Allocator>: Allocator, LeakCheckingAllocator {
    private let base: Base
    private let tracker: Tracker

    public init(
        base: Base,
        options: Options = Options()
    ) {
        self.base = base
        self.tracker = Tracker(options: options)
    }

    public func allocate<T>(_ type: T.Type, capacity: Int) -> UnsafeMutablePointer<T> {
        let ptr = base.allocate(T.self, capacity: capacity)
        tracker.allocateRecord(for: ptr, capacity: capacity)
        return ptr
    }

    public func deconstruct<T>(_ pointer: UnsafeMutablePointer<T>, count: Int) {
        tracker.deconstructRecord(for: pointer, as: T.self, count: count)
        base.deconstruct(pointer, count: count)
    }

    public func deallocate<T>(_ pointer: UnsafeMutablePointer<T>) {
        tracker.deallocateRecord(for: pointer, as: T.self)
        base.deallocate(pointer)
    }

    public func clear<T>(_ pointer: UnsafeMutablePointer<T>, count: Int) {
        tracker.clearRecord(for: pointer, as: T.self, count: count)
        base.clear(pointer, count: count)
    }

    public func hasLeaks() -> Bool { tracker.hasLeaks() }
    public func leakReport() -> String? { tracker.leakReport() }

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

extension DebugAllocator {
    private final class Tracker: @unchecked Sendable {
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
            fputs(report!, stderr)
        }

        func allocateRecord<T>(for pointer: UnsafeMutablePointer<T>, capacity: Int) {
            let key = UnsafeRawPointer(pointer)

            lock.lock()
            defer { lock.unlock() }

            if let existing = records[key], existing.state != .freed {
                preconditionFailure("allocate: pointer reused without free? \(pointer)")
            }

            let id = nextAllocationID
            nextAllocationID &+= 1

            records[key] = Record(
                capacity: capacity,
                stride: MemoryLayout<T>.stride,
                type: T.self,
                state: .allocated,
                allocationID: id,
                stack: captureStackTraces ? Thread.callStackSymbols : nil
            )
        }

        func clearRecord<T>(for pointer: UnsafeMutablePointer<T>, as: T.Type, count: Int) {
            let key = UnsafeRawPointer(pointer)

            lock.lock()
            defer { lock.unlock() }

            guard var rec = records[key] else {
                preconditionFailure("clear: unknown pointer \(pointer)")
            }

            precondition(rec.state == .allocated, "clear: invalid state \(rec.state) (alloc #\(rec.allocationID))")
            precondition(
                rec.type == T.self,
                "clear: type mismatch (stored \(rec.type), clearing as \(T.self)) (alloc #\(rec.allocationID))"
            )
            precondition(
                rec.capacity == count,
                "clear: count/capacity mismatch (got \(count), expected \(rec.capacity)) (alloc #\(rec.allocationID))"
            )

            rec.state = .freed
            records[key] = rec
        }

        func deconstructRecord<T>(for pointer: UnsafeMutablePointer<T>, as: T.Type, count: Int) {
            let key = UnsafeRawPointer(pointer)

            lock.lock()
            defer { lock.unlock() }

            guard var rec = records[key] else {
                preconditionFailure("deconstruct: unknown pointer \(pointer)")
            }

            precondition(rec.state == .allocated, "deconstruct: invalid state \(rec.state) (alloc #\(rec.allocationID))")
            precondition(
                rec.type == T.self,
                "deconstruct: type mismatch (stored \(rec.type), deconstructing as \(T.self)) (alloc #\(rec.allocationID))"
            )
            precondition(
                rec.capacity == count,
                "deconstruct: count/capacity mismatch (got \(count), expected \(rec.capacity)) (alloc #\(rec.allocationID))"
            )

            rec.state = .deconstructed
            records[key] = rec
        }

        /// Used by `deallocate(pointer)` where capacity isn't available.
        func deallocateRecord<T>(for pointer: UnsafeMutablePointer<T>, as: T.Type) {
            let key = UnsafeRawPointer(pointer)

            lock.lock()
            defer { lock.unlock() }

            guard var rec = records[key] else {
                preconditionFailure("deallocate: unknown pointer \(pointer)")
            }

            precondition(rec.state != .freed, "double free on pointer \(pointer) (alloc #\(rec.allocationID))")
            precondition(
                rec.type == T.self,
                "deallocate: type mismatch (stored \(rec.type), deallocating as \(T.self)) (alloc #\(rec.allocationID))"
            )

            rec.state = .freed
            records[key] = rec
        }

        func hasLeaks() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            return records.values.contains(where: { $0.state != .freed })
        }

        func leakReport() -> String? {
            lock.lock()
            defer { lock.unlock() }
            return leakReportLocked()
        }

        private func leakReportLocked() -> String? {
            let leaks = records
                .filter { $0.value.state != .freed }
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
                out += "  state: \(rec.state)\n"
                out += "  capacity: \(rec.capacity)\n"
                out += "  stride: \(rec.stride)\n"
                out += "  bytes: \(bytes)\n"

                if let stack = rec.stack, !stack.isEmpty {
                    out += "  stack:\n"
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
}

extension DebugAllocator {
    private enum LifeState: CustomStringConvertible {
        case allocated
        case deconstructed
        case freed

        var description: String {
            switch self {
            case .allocated: return "allocated"
            case .deconstructed: return "deconstructed"
            case .freed: return "freed"
            }
        }
    }

    private struct Record {
        var capacity: Int
        var stride: Int
        var type: Any.Type
        var state: LifeState
        var allocationID: UInt64
        var stack: [String]?
    }


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
}
