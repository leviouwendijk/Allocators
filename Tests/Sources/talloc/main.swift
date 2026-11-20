import TestAllocators

try TestAllocators.runAll(
    arguments: Array(
        CommandLine.arguments.dropFirst()
    )
)
