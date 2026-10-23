// swift-tools-version:5.10
// Lets the platform-independent logic in Shared/Core build and test without
// Xcode (Linux CI, or the Swift toolchain on Windows). The iOS app itself is
// defined in project.yml.
import PackageDescription

let package = Package(
    name: "FajsoCore",
    products: [
        .library(name: "FajsoCore", targets: ["FajsoCore"])
    ],
    targets: [
        .target(name: "FajsoCore", path: "Shared/Core"),
        .testTarget(name: "FajsoCoreTests", dependencies: ["FajsoCore"], path: "Tests/FajsoCoreTests")
    ]
)
