// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "reminders",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "RemindCore", targets: ["RemindCore"]),
    .executable(name: "reminders", targets: ["reminders"]),
  ],
  dependencies: [
    .package(url: "https://github.com/steipete/Commander.git", from: "0.2.0"),
  ],
  targets: [
    .target(
      name: "RemindCore",
      dependencies: [],
      linkerSettings: [
        .linkedFramework("EventKit"),
      ]
    ),
    .executableTarget(
      name: "reminders",
      dependencies: [
        "RemindCore",
        .product(name: "Commander", package: "Commander"),
      ],
      exclude: [
        "Resources/Info.plist",
      ],
      linkerSettings: [
        .unsafeFlags([
          "-Xlinker", "-sectcreate",
          "-Xlinker", "__TEXT",
          "-Xlinker", "__info_plist",
          "-Xlinker", "Sources/reminders/Resources/Info.plist",
        ]),
      ]
    ),
    .testTarget(
      name: "RemindCoreTests",
      dependencies: [
        "RemindCore",
      ]
    ),
    .testTarget(
      name: "remindersTests",
      dependencies: [
        "reminders",
        "RemindCore",
      ]
    ),
  ],
  swiftLanguageModes: [.v6]
)
