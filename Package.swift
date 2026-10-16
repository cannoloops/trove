// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Trove",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "TroveCore", linkerSettings: [.linkedLibrary("sqlite3")]),
        .executableTarget(name: "Trove", dependencies: ["TroveCore"]),
        .testTarget(name: "TroveCoreTests", dependencies: ["TroveCore"]),
    ],
    swiftLanguageModes: [.v5]
)
