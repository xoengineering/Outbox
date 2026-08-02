// swift-tools-version: 6.3

import PackageDescription

let package = Package(
  name: "OutboxKit",
  platforms: [
    // Raise to 26.6 once Xcode ships a 26.6 SDK; 26.5 is the current ceiling.
    .iOS("26.5"),
    .macOS("26.5"),
  ],
  products: [
    .library(
      name: "OutboxKit",
      targets: ["OutboxKit"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/jpsim/Yams.git", from: "6.2.2")
  ],
  targets: [
    .target(
      name: "OutboxKit",
      dependencies: ["Yams"]
    ),
    .testTarget(
      name: "OutboxKitTests",
      dependencies: ["OutboxKit"],
      resources: [
        .copy("Fixtures")
      ]
    ),
  ],
  swiftLanguageModes: [.v6]
)
