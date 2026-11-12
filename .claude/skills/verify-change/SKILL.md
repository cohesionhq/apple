---
name: verify-change
description: Build and check a change to Cohesion's apps (the iOS app, its share, widget and notification extensions, and the Mac app) before calling it done. Use after any code or project change in this repo, before committing or reporting, and whenever asked to build, test, lint or check the app, or to screenshot it in the simulator.
---

# Verify a change

There are no test targets and no linter. A change is checked by a build of
every target with no new warnings, plus a careful read of what the build
can't prove.

## 1. Build every target

The `Cohesion` scheme embeds the three extensions, so one build compiles
all four iOS targets, and the packages with them:

```sh
xcodebuild -scheme Cohesion -destination 'generic/platform=iOS Simulator' build > /tmp/cohesion-apple-build.log 2>&1; echo "exit=$?"
grep -E 'error:|warning:' /tmp/cohesion-apple-build.log | grep -v '^ ' | sort -u
```

- It must end in `** BUILD SUCCEEDED **` with exit 0. No signing is needed
  for the simulator.
- In a type-check that gives up ("unable to type-check this expression") or
  a nonsense error about `Array`, look for a member or memberwise `init` that
  isn't `public` in another package, or an API unavailable on the Mac.
- With `-quiet`, xcodebuild may print `error: the following command failed
  with exit code 0 but produced no further output`. That line is noise when
  the exit code is 0.
- An incremental build only reports warnings for the files it recompiled.

## 2. Warnings: none

A clean build has no warnings but
`appintentsmetadataprocessor … Metadata extraction skipped`, which is
noise. Any other warning is yours to fix. If a warning can't be fixed, list
it here (file and message, since line numbers drift) in the same commit.

The project and the packages default to `MainActor` isolation
(`SWIFT_DEFAULT_ACTOR_ISOLATION`, `.defaultIsolation`) in Swift 5 mode with
approachable concurrency. Code that runs off the main
actor (widget providers, the notification service, `Codable` types shared
with ActivityKit) is marked `nonisolated`, as the existing types are.

## 3. Where the code lives

What more than one target uses is in `Packages/`, public, not added to a
target. The extensions link `CohesionCore` and `CohesionUI` and never
`CohesionMarkdown` or `CohesionScreens`. `membershipExceptions` in
`Cohesion.xcodeproj/project.pbxproj` is only for what stays under
`Cohesion/`: the asset catalog, the icon, and the Live Activity's attributes.

## 4. What the build can't prove

Say so in the report rather than claiming it was tested:

- **UI**: layout, copy and animation, on the Mac as well when a screen
  changed. Visuals are checked by eye on a device; list what to look at.
- **Anything needing a live cohesiond**: the simulator's pairing usually
  can't reach a server ("Could not connect to the server").
- **Pushes, notifications, Live Activities and widgets fed by the cloud**:
  these need a paired physical device.
- **Decoding**: compare a changed model against a real reply (see the
  `add-feature` skill) rather than assuming the shape.

## 5. Optional: look at it in a preview

For layout, prefer a `#Preview` over the simulator: the screens have previews
over canned data (`ARCHITECTURE.md`, "Previews"), rendered with Xcode's
`RenderPreview` tool. Use `displayMode: "interactive"` with a `snapshotDelay` of
about 3 seconds, since a static render presents no sheet and finishes no load.
A new screen gets a preview there, and a command it loads a reply in
`PreviewData`.

## 6. Optional: look at it in the simulator

Use this when a screenshot helps, for example layout that shows without
data. Pick a booted simulator from `xcrun simctl list devices booted`:

```sh
SIM='iPhone 18 Pro'
xcodebuild -scheme Cohesion -destination "platform=iOS Simulator,name=$SIM" -derivedDataPath /tmp/cohesion-apple-dd -quiet build
xcrun simctl install "$SIM" /tmp/cohesion-apple-dd/Build/Products/Debug-iphonesimulator/Cohesion.app
xcrun simctl launch --terminate-running-process "$SIM" com.hellocohesion.app
sleep 3; xcrun simctl io "$SIM" screenshot /tmp/cohesion-apple.png
```

Then read the PNG. Lists left empty or as last kept, with no alert, are
expected without a reachable server. Open deep links with
`xcrun simctl openurl "$SIM" cohesionplus://agent/<id>`. Don't re-pair the
simulator or change its data without being asked.

Keep it to the end state: one screenshot per device the change affects,
taken with `simctl` as above, even when a dispatch asks to "verify in the
simulator". Don't tap through screens to explore.

Use the `device-interaction` skill only when the change can't be seen
without interacting (a tap, a gesture, a hardware-keyboard key). Its
subagent re-reads the screen and a screenshot on every step, so start it
with `model: "sonnet"` and a narrow prompt: what to open, the one
interaction, what to screenshot, then hand back. One subagent per device,
and only for the devices the change affects.
