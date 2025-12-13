import Foundation

public struct MemoryInspector: Sendable {
    private let tracker: any AllocationTracking

    public init(tracker: any AllocationTracking) {
        self.tracker = tracker
    }

    public func leaks() -> Bool {
        tracker.hasLeaks()
    }

    public func report() -> String? {
        tracker.leakReport()
    }

    public func assert(
        file: StaticString = #file,
        filePath: StaticString = #filePath,
        line: UInt = #line
    ) {
        if let r = tracker.leakReport() {
            preconditionFailure("\(r)\n[filePath: \(filePath)]", file: file, line: line)
        }
    }
}
