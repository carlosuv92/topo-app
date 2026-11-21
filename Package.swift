// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Topo",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Topo", targets: ["Topo"])
    ],
    targets: [
        .executableTarget(
            name: "Topo",
            path: "Sources/Topo",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("AppKit")
            ]
        )
    ]
)
