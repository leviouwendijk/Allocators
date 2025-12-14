import Foundation

#if ALLOC_DEBUG
// compiles with .inspector.leaks(), .inspector.report() for memory leak inspection
public typealias DefaultAllocator = DebugAllocator<GenericAllocator>
#else
// will currently compile the same call sites as DebugAllocator, but does not inspect:
public typealias DefaultAllocator = GenericAllocator 
#endif
