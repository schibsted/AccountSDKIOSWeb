// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "AccountSDKIOSWeb",
    platforms: [
        .iOS(.v12),
    ],
    products: [
        .library(
            name: "AccountSDKIOSWeb",
            targets: ["AccountSDKIOSWeb"]),
        .library(
                   name: "AccountSDKIOSWebTests",
                   targets: ["AccountSDKIOSWebTests"])
    ],
    dependencies: [
        .package(url: "https://github.com/airsidemobile/JOSESwift.git", from: "2.3.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.4.0"),
        .package(url: "https://github.com/Brightify/Cuckoo.git", from: "1.4.0")
    ],
    targets: [
        .target(
            name: "AccountSDKIOSWeb",
            dependencies: ["JOSESwift", .product(name: "Logging", package: "swift-log")]),
        .testTarget(
            name: "AccountSDKIOSWebTests",
            dependencies: ["AccountSDKIOSWeb", "Cuckoo"]),
        .testTarget(
            name: "AccountSDKIOSWebKeychainTests",
            dependencies: ["AccountSDKIOSWeb"]),
    ]
)
