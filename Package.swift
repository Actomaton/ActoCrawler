// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ActoCrawler",
    platforms: [.macOS("15.4")],
    products: [
        .library(
            name: "ActoCrawler",
            targets: ["ActoCrawler"]),
        .library(
            name: "ActoCrawlerNetworking",
            targets: ["ActoCrawlerNetworking"]),
        .library(
            name: "ActoCrawlerHTML",
            targets: ["ActoCrawlerHTML"]),
        .library(
            name: "ActoCrawlerPlaywrightPy",
            targets: ["ActoCrawlerPlaywrightPy"]),
        .library(
            name: "ActoCrawlerPlaywrightJS",
            targets: ["ActoCrawlerPlaywrightJS"]),
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
            name: "HeadlessBrowserPyExample",
            targets: ["HeadlessBrowserPyExample"]),
        .executable(
            name: "HeadlessBrowserJSExample",
            targets: ["HeadlessBrowserJSExample"]),
    ],
    dependencies: [
        .package(url: "https://github.com/inamiy/Actomaton.git", branch: "main"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-async-algorithms.git", from: "1.0.0"),
        .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.50.0"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.4.2"),
        .package(url: "https://github.com/pvieito/PythonKit.git", branch: "master"),
    ],
    targets: [
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
                .product(name: "Actomaton", package: "Actomaton"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "Collections", package: "swift-collections"),
            ],
            path: "Sources/ActoCrawler"
        ),
        .target(
            name: "ActoCrawlerNetworking",
            dependencies: [
                "ActoCrawler",
            ],
            path: "Sources/ActoCrawlerNetworking"
        ),
        .target(
            name: "ActoCrawlerHTML",
            dependencies: [
                "ActoCrawlerNetworking",
                .product(name: "SwiftSoup", package: "SwiftSoup"),
            ],
            path: "Sources/ActoCrawlerHTML"
        ),
        .target(
            name: "ActoCrawlerPlaywrightPy",
            dependencies: [
                "ActoCrawler", "PythonKitAsync"
            ]
        ),
        .target(
            name: "ActoCrawlerPlaywrightJS",
            dependencies: [
                "ActoCrawler",
                .product(name: "JavaScriptKit", package: "JavaScriptKit"),
                .product(name: "JavaScriptEventLoop", package: "JavaScriptKit"),
            ]
        ),
        .testTarget(
            name: "ActoCrawlerTests",
            dependencies: ["ActoCrawler"]),
        .testTarget(
            name: "ActoCrawlerPlaywrightJSTests",
            dependencies: [
                "ActoCrawlerPlaywrightJS",
                .product(name: "JavaScriptEventLoopTestSupport", package: "JavaScriptKit"),
            ]
        ),
        .executableTarget(
            name: "ScraperExample",
            dependencies: ["ActoCrawlerHTML"],
            path: "Examples/ScraperExample"),
        .executableTarget(
            name: "ImageScraperExample",
            dependencies: ["ActoCrawlerHTML"],
            path: "Examples/ImageScraperExample"),
        .executableTarget(
            name: "PagingScraperExample",
            dependencies: ["ActoCrawlerHTML"],
            path: "Examples/PagingScraperExample"),
        .executableTarget(
            name: "HeadlessBrowserPyExample",
            dependencies: ["ActoCrawlerPlaywrightPy"],
            path: "Examples/HeadlessBrowserPyExample",
            exclude: ["pyproject.toml", "uv.lock", "output"]),
        .executableTarget(
            name: "HeadlessBrowserJSExample",
            dependencies: ["ActoCrawlerPlaywrightJS"],
            path: "Examples/HeadlessBrowserJSExample",
            exclude: ["main.mjs", "package.json", "package-lock.json", "node_modules", "output"]),
    ],
    swiftLanguageModes: [.v6]
)
