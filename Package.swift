// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "xbar",
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(name: "XcodeProj", url: "https://github.com/tuist/xcodeproj.git", .upToNextMajor(from: "7.13.0")),
        .package(name: "PathKit", url: "https://github.com/kylef/PathKit.git", .upToNextMajor(from: "1.0.0")),
        .package(name: "ShellOut", url: "https://github.com/JohnSundell/ShellOut.git", .upToNextMajor(from: "2.3.0"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "xbar",
            dependencies: ["XcodeProj", "PathKit", "ShellOut"]),
        .testTarget(
            name: "xbarTests",
            dependencies: ["xbar"]),
    ]
)
