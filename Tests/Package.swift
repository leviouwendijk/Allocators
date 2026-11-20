// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AllocatorsTests",
    products: [
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
        .executable(
            name: "talloc_ownership",
            targets: ["talloc_ownership"]
        ),
    ],
    dependencies: [
        .package(path: ".."),
    ],
    targets: [
        .target(
            name: "TestAllocators",
            dependencies: [
                .product(name: "Allocators", package: "Allocators"),
            ]
        ),
        .executableTarget(
            name: "talloc",
            dependencies: [
                "TestAllocators",
            ]
        ),
        .executableTarget(
            name: "talloc_allocator",
            dependencies: [
                "TestAllocators",
            ]
        ),
        .executableTarget(
            name: "talloc_buffer",
            dependencies: [
                "TestAllocators",
            ]
        ),
        .executableTarget(
            name: "talloc_ownership",
            dependencies: [
                .product(name: "Allocators", package: "Allocators"),
            ]
        ),
    ]
)
