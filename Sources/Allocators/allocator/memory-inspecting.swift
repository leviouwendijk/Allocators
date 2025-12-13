import Foundation

public protocol MemoryInspecting {
    var inspector: MemoryInspector { get }
    var tracker: any AllocationTracking { get }
}

extension MemoryInspecting {
    public var inspector: MemoryInspector { 
        MemoryInspector(tracker: tracker) 
    }
}
