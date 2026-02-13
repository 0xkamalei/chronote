// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "chronote-cli",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "chronote-cli", targets: ["chronote-cli"]),
    ],
    targets: [
        .executableTarget(
            name: "chronote-cli",
            linkerSettings: [
                .linkedLibrary("sqlite3"),
            ]
        ),
    ]
)
