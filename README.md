# Cohesion for Apple platforms

Cohesion's native apps: a SwiftUI client of `cohesiond` for iPhone and
iPad, with a share extension, widgets and Live Activities, and a
notification service extension, and an app for the Mac. They pair with a
`cohesiond` from [cohesionhq/cohesion](https://github.com/cohesionhq/cohesion),
which holds every rule and all the data; the apps send it commands and
reload when it says something changed.

## Building

Xcode 27 or later. The project is `Cohesion.xcodeproj`; the shared code is
in two local Swift packages under `Packages/` (`CohesionCore` and
`CohesionUI`). There are no other dependencies.

```sh
# The iOS app and its three extensions
xcodebuild -scheme Cohesion -destination 'generic/platform=iOS Simulator' build

# The Mac app
xcodebuild -scheme CohesionMac -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

Simulator and unsigned Mac builds need no Apple developer account. To run
on a device, pick your own team under Signing & Capabilities for each
target; the project names none. Keep the bundle identifiers
(`com.hellocohesion.plus…`) only if you can sign for them; otherwise
change them, along with the keychain group in the entitlements.

Pushes and Live Activities arrive through Cohesion Cloud
(hellocohesion.cloud), so they need a build signed for the shipping bundle
identifiers; everything else works against any `cohesiond` you can reach.

## Layout

`ARCHITECTURE.md` maps the targets, packages and flows. `docs/` holds the
design rules (`design.md`), the platform wiring (`platform-integrations.md`),
how to compare a screen with the web UI (`parity-with-web.md`) and the
product direction (`product-direction.md`). `CLAUDE.md` and
`.claude/skills/` are the working rules for coding agents, and read as a
contributor's guide too.

## Licence

Copyright © 2026 Jackson Zamorano.

Licensed under the Apache License, version 2.0 (Apache-2.0); see
[LICENSE](LICENSE).
