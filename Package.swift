// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "InstructionComplianceKit",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9)
    ],
    products: [
        .library(name: "InstructionComplianceKit", targets: ["InstructionComplianceKit"]),
        .executable(name: "InstructionComplianceDemo", targets: ["InstructionComplianceDemo"])
    ],
    targets: [
        .target(name: "InstructionComplianceKit"),
        .executableTarget(
            name: "InstructionComplianceDemo",
            dependencies: ["InstructionComplianceKit"]
        ),
        .testTarget(
            name: "InstructionComplianceKitTests",
            dependencies: ["InstructionComplianceKit"]
        )
    ],
    swiftLanguageModes: [.v6]
)
