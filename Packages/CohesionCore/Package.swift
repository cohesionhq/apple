// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "CohesionCore",
    platforms: [.iOS("27.0"), .macOS("27.0")],
    products: [
        .library(name: "CohesionCore", targets: ["CohesionCore"]),
    ],
    targets: [
        .target(
            name: "CohesionCore",
            swiftSettings: [
                // As the apps build: Swift 5 mode, main actor by default,
                // approachable concurrency.
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
        ),
    ]
)
