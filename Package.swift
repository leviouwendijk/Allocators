// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Allocators",
    products: [
        .library(
            name: "Allocators",
            targets: ["Allocators"]
        ),
    ],
    targets: [
        .target(
            name: "Allocators",
            swiftSettings: [
                .enableExperimentalFeature("LifetimeDependence"),
                .enableExperimentalFeature("Lifetimes"),
            ]
        ),
    ]
)
