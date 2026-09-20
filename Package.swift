// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Allocators",
    products: [
        .library(
            name: "Allocators",
            targets: ["Allocators"]
        ),
        .executable(
            name: "talloc",
            targets: ["talloc"]
        ),
        .executable(
            name: "talloc_allocator",
            targets: ["talloc_allocator"]
        ),
        .executable(
            name: "talloc_buffer",
            targets: ["talloc_buffer"]
        ),
    ],
    targets: [
        .target(
            name: "Allocators"
        ),
        .target(
            name: "TestAllocators",
            dependencies: [
                "Allocators",
            ],
            path: "Testing/TestAllocators"
        ),
        .executableTarget(
            name: "talloc",
            dependencies: [
                "TestAllocators",
            ],
            path: "Testing/talloc"
        ),
        .executableTarget(
            name: "talloc_allocator",
            dependencies: [
                "TestAllocators",
            ],
            path: "Testing/talloc_allocator"
        ),
        .executableTarget(
            name: "talloc_buffer",
            dependencies: [
                "TestAllocators",
            ],
            path: "Testing/talloc_buffer"
        ),
    ]
)
