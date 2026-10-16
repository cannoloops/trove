// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "Trove",
    platforms: [.macOS(.v26)],
    dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.6")],
    targets: [
        .target(name: "TroveCore", linkerSettings: [.linkedLibrary("sqlite3")]),
        .executableTarget(name: "Trove", dependencies: ["TroveCore", .product(name: "Sparkle", package: "Sparkle")],
                          linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]),
        .testTarget(name: "TroveCoreTests", dependencies: ["TroveCore"]),
    ],
    swiftLanguageModes: [.v5]
)
