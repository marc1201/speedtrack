# CLAUDE.md

Speedtrack is a native iOS app that shows how fast the device is moving. It exists to test two
things: the Apple Developer account of Eins-zwei-null-eins Portugal Unipessoal, Lda, and how cheaply
a new project starts on the VPS. Keep it small.

The shared rules in `~/.claude/CLAUDE.md` apply here. This file adds what is specific to this
project.

## Stack

- Swift, SwiftUI, CoreLocation and CoreMotion. iPhone only, iOS 17 or later. No third-party
  dependencies.
- `SpeedTrack.xcodeproj` is committed and is the one source of project settings, edited by hand
  because there is no Xcode here. Its synced folders pick up new files under `App/` and `Tests/`.
- `SpeedReading` and `StillnessDetector` hold the pure logic and are unit-tested. `SpeedMonitor`
  wraps CoreLocation and CoreMotion. `ContentView` shows the number.

## There is no Xcode here

This checkout lives on a Linux VPS, where nothing Apple compiles. GitHub Actions is the compiler:

1. Commit and `git push origin HEAD:main`. Pushing needs a window that Marc has open.
2. Every push to main runs `ci/build-test.sh` on a macOS runner.
3. `gh-runs latest marc1201/speedtrack` shows the run and the first failed job's log.
   `gh-runs runs`, `gh-runs jobs` and `gh-runs log` go deeper.

Read the Swift carefully before pushing: each push is one compile and takes minutes. Bundle
several changes into one push. `ci/local-check.sh` runs on the box in about a minute, with the Linux
Swift toolchain in `~/.local/share/swift`: it parses every Swift file and runs the tests of the pure
logic. It cannot see SwiftUI, CoreLocation or CoreMotion, so Actions stays the compiler that counts.

Keep logic in `ci/*.sh`, because a workflow file cannot be pushed from here. The one exception is a
job that holds a credential, whose steps stay inline in the workflow file.

## How deployment works here

This project ships through Actions. Here a deploy is a TestFlight build. Compile pushes must not
deploy, so a release is a deliberate commit, made after the gates are green, and only that commit
starts a build.

## How we develop here

A change to `ci/`, `ci_scripts/`, `SpeedTrack.xcodeproj`, signing, permissions, entitlements or
`Info.plist` gets `security-reviewer` before the push.

## Identity

- Bundle id `vc.1201.speedtrack`. It is permanent once it is registered with Apple.
- `MARKETING_VERSION` is in the Xcode project, in the project-level Debug and Release settings. The build number is the Actions run number.

## Status

The first version is on main and passed the three gates. It compiles and its unit tests pass on
Actions, but it has never run on a real phone. TestFlight is not set up: the workflow's `testflight`
job predates the shared deployment rules, and removing it is waiting on Marc.
