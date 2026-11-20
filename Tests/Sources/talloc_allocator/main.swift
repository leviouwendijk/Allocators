import TestAllocators

try TestAllocators.runAllocator(
    arguments: Array(
        CommandLine.arguments.dropFirst()
    )
)
