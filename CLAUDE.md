# CLAUDE.md

Speedtrack is a native iOS app that shows how fast the device is moving. It exists to test two
things: the Apple Developer account of Eins-zwei-null-eins Portugal Unipessoal, Lda, and how cheaply
a new project starts on the VPS. Keep it small.

## Stack

- Swift, SwiftUI and CoreLocation. iPhone only, iOS 17 or later. No third-party dependencies.
- `project.yml` (XcodeGen) is the source of the Xcode project. `*.xcodeproj` is generated and never
  committed. Add files under `App/` or `Tests/`; XcodeGen picks them up.
- `SpeedReading` holds the pure logic and is unit-tested. `SpeedMonitor` wraps CoreLocation.
  `ContentView` shows the number.

## There is no Xcode here

This checkout lives on a Linux VPS, where nothing Apple compiles. GitHub Actions is the compiler:

1. Commit and `git push origin HEAD:main`. Pushing needs a window that Marc has open.
2. Every push to main runs `ci/build-test.sh` on a macOS runner.
3. `gh-runs latest marc1201/speedtrack` shows the run and the first failed job's log.
   `gh-runs runs`, `gh-runs jobs` and `gh-runs log` go deeper.

Read the Swift carefully before pushing: each push is one compile and takes minutes. Bundle
several changes into one push.

## Rules of the box

- Workflow files cannot be pushed from the VPS: the push token has no `workflows` permission, by
  design. Keep logic in `ci/*.sh`, which can be pushed. A change to `.github/workflows/` goes to
  Marc as a request.
- Secrets never live on the VPS. The App Store Connect key exists only as a GitHub repository
  secret, and `ci/testflight.sh` reads it from the environment.
- TestFlight builds start only by Marc's click (Actions, ios, Run workflow). Do not add a push or
  tag trigger: the VPS token could then run its own code next to the key.
- A heavy local job runs capped, or it can freeze the whole box for every project:
  `systemd-run --user --scope -p MemoryMax=2G -p MemorySwapMax=0 -- <command>`

## Identity

- Bundle id `vc.1201.speedtrack`. It is permanent once it is registered with Apple.
- `MARKETING_VERSION` is in `project.yml`. The build number is the Actions run number.

## Status

The scaffold has never been compiled: the first Actions run is its first compile. Start there,
make the run green, then build the features Marc asks for.
