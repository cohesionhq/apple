// swift-tools-version: 6.2

import PackageDescription

// As the apps build: Swift 5 mode, main actor by default, approachable
// concurrency.
let settings: [SwiftSetting] = [
    .swiftLanguageMode(.v5),
    .defaultIsolation(MainActor.self),
    .enableUpcomingFeature("DisableOutwardActorInference"),
    .enableUpcomingFeature("GlobalActorIsolatedTypesUsability"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("InferSendableFromCaptures"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("BareSlashRegexLiterals"),
]

let package = Package(
    name: "CohesionUI",
    platforms: [.iOS("27.0"), .macOS("27.0")],
    products: [
        .library(name: "CohesionUI", targets: ["CohesionUI"]),
        .library(name: "CohesionMarkdown", targets: ["CohesionMarkdown"]),
        .library(name: "CohesionScreens", targets: ["CohesionScreens"]),
    ],
    dependencies: [
        .package(path: "../CohesionCore"),
    ],
    targets: [
        // Small views anything can use, the extensions included.
        .target(
            name: "CohesionUI",
            dependencies: ["CohesionCore"],
            swiftSettings: settings
        ),
        // The Markdown parser, renderer and editor. Apart from `CohesionUI`
        // so the extensions don't link WebKit, which shows its diagrams.
        .target(
            name: "CohesionMarkdown",
            dependencies: ["CohesionUI"],
            swiftSettings: settings
        ),
        // The screens both apps' shells open, and the state a window keeps.
        .target(
            name: "CohesionScreens",
            dependencies: ["CohesionCore", "CohesionUI", "CohesionMarkdown"],
            swiftSettings: settings
        ),
    ]
)
