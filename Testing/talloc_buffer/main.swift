import TestAllocators

try TestAllocators.runBuffer(
    arguments: Array(
        CommandLine.arguments.dropFirst()
    )
)
