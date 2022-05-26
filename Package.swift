// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ActoCrawler",
    platforms: [.macOS(.v12)],
    products: [
        .library(
            name: "ActoCrawler",
            targets: ["ActoCrawler"]),
        .library(
            name: "ActoCrawlerPlaywright",
            targets: ["ActoCrawlerPlaywright"]),
        .executable(
            name: "ScraperExample",
            targets: ["ScraperExample"]),
        .executable(
            name: "ImageScraperExample",
            targets: ["ImageScraperExample"]),
        .executable(
            name: "PagingScraperExample",
            targets: ["PagingScraperExample"]),
        .executable(
            name: "HeadlessBrowserExample",
            targets: ["HeadlessBrowserExample"]),
    ],
    dependencies: [
        .package(url: "https://github.com/inamiy/Actomaton.git", branch: "main"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.0.0"),
        // .package(url: "https://github.com/apple/swift-async-algorithms.git", branch: "main"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.4.2"),
        .package(url: "https://github.com/pvieito/PythonKit.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "AsyncChannel"),
        .target(
            name: "PythonKitAsync",
            dependencies: [
                .product(name: "PythonKit", package: "PythonKit")
            ],
            resources: [.copy("pythonkit-async.py")]
        ),
        .target(
            name: "ActoCrawler",
            dependencies: [
                "AsyncChannel",
                .product(name: "Actomaton", package: "Actomaton"),
                .product(name: "Collections", package: "swift-collections"),
                // .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "SwiftSoup", package: "SwiftSoup"),
            ],
            swiftSettings: [
                .unsafeFlags([
                    "-Xfrontend", "-warn-concurrency",
                    "-Xfrontend", "-enable-actor-data-race-checks",
                ])
            ]
        ),
        .target(
            name: "ActoCrawlerPlaywright",
            dependencies: [
                "ActoCrawler", "PythonKitAsync"
            ],
            swiftSettings: [
                .unsafeFlags([
                    "-Xfrontend", "-warn-concurrency",
                    "-Xfrontend", "-enable-actor-data-race-checks",
                ])
            ]
        ),
        .testTarget(
            name: "ActoCrawlerTests",
            dependencies: ["ActoCrawler"]),
        .executableTarget(
            name: "ScraperExample",
            dependencies: ["ActoCrawler"],
            path: "Examples/ScraperExample"),
        .executableTarget(
            name: "ImageScraperExample",
            dependencies: ["ActoCrawler"],
            path: "Examples/ImageScraperExample"),
        .executableTarget(
            name: "PagingScraperExample",
            dependencies: ["ActoCrawler"],
            path: "Examples/PagingScraperExample"),
        .executableTarget(
            name: "HeadlessBrowserExample",
            dependencies: ["ActoCrawlerPlaywright"],
            path: "Examples/HeadlessBrowserExample"),
    ]
)
