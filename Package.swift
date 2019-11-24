// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GRDBOpenCombine",
    platforms: [
        .iOS("10.0"),
        .macOS("10.12"),
        .tvOS("9.0"),
        .watchOS("2.0"),
    ],
    products: [
        .library(name: "GRDBCombine", targets: ["GRDBCombine"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", .upToNextMajor(from: "4.1.0")),
        .package(url: "https://github.com/broadwaylamb/OpenCombine.git", .upToNextMajor(from: "0.5.0"))
    ],
    targets: [
        .target(
            name: "GRDBCombine",
            dependencies: ["GRDB", "OpenCombine", "OpenCombineDispatch"]),
        .testTarget(
            name: "GRDBCombineTests",
            dependencies: ["GRDBCombine", "GRDB", "OpenCombine"])
    ],
    swiftLanguageVersions: [.v5]
)
