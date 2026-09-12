// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "MelismaKit",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "MelismaKit", targets: ["MelismaKit"]),
        .library(name: "MelismaKitSwiftUI", targets: ["MelismaKitSwiftUI"]),
        .executable(name: "MelismaKitDemo", targets: ["MelismaKitDemo"]),
        .executable(name: "MelismaKitProbe", targets: ["MelismaKitProbe"])
    ],
    targets: [
        .target(name: "MelismaKit"),
        .target(name: "MelismaKitSwiftUI", dependencies: ["MelismaKit"]),
        .executableTarget(name: "MelismaKitDemo", dependencies: ["MelismaKit"], resources: [.copy("Resources")]),
        .executableTarget(name: "MelismaKitProbe", dependencies: ["MelismaKit"]),
        .testTarget(name: "MelismaKitTests", dependencies: ["MelismaKit"], resources: [.copy("Fixtures")])
    ],
    swiftLanguageModes: [.v5]
)
