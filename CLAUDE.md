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
- A heavy local job runs capped, or it can freeze the whole box for every project:
  `systemd-run --user --scope -p MemoryMax=2G -p MemorySwapMax=0 -- <command>`

## How deployment works here

Every 1201 project deploys the same way, and this one is no exception. PawOS is the working
example: a push to main, and GitHub Actions does the rest.

- **An open window is the only human step.** A design that needs Marc per release is wrong: no
  click per build, no key revoked after each run, no manual upload.
- **Nothing deploys from the Mac or the VPS.** Not as a fallback, not once. Neither machine holds a
  deploy credential or runs a release step. One-time setup may touch a vendor console or the Mac;
  a release never does.
- **At most one credential, set once.** No credential at all is better. If one is needed, it lives
  only as a repository secret with the narrowest role that works. Never an App Store Connect key
  with the Admin role, in any form: not in GitHub, not temporarily, not as a one-shot key. A wider
  role is Marc's decision, never a default.
- **Repository code never runs next to a credential,** because the VPS token can change that code.
  Either no credential exists, or the job holding it runs no repository code. A route that cannot
  do this goes to Marc as a trade-off. It does not get a click added instead.
- **Marc's part is one-time setup,** sent as one message with exact steps. After that he does
  nothing per release.
- **A red deploy is yours.** Read it with `gh-runs`, fix it and push again. Marc gets the result,
  not fix commands.

Here a deploy is a TestFlight build. Compile pushes must not deploy, so a release is a deliberate
commit, made after the gates are green, and only that commit starts a build.

## How we develop here

Speedtrack is small, but it follows the same process as every 1201 project. Skipping it because a
change looks small or urgent is not an option.

1. One concern at a time, in a commit whose message says why.
2. The three reviewers in `.claude/agents/` run before work is called done and before any build
   goes to TestFlight, never afterwards:
   - `dedup-reviewer` when a change adds or moves shared code. It runs first, so the others see
     the final diff.
   - `qa` on every change, against the Actions run of that exact commit.
   - `security-reviewer` on every change, with no bundling. A change to `ci/`, signing, permissions,
     entitlements or `Info.plist` gets it before the push.
3. Judge every finding yourself and fix what is real. A security blocker stops the work until it
   is fixed. Run the gate again on the fixes, and report anything you left and why.
4. Size the gate to the change: agents where they help, never a crowd on the same few lines.

## Working with Marc

- Decide what you can with a safe default, state the default, and build it. Ask only what is
  truly his to decide.
- Automate his steps. What must stay his, such as root or a vendor console, goes into one message
  at the end, with the exact lines and the expected result. No chains of "run this, paste that".
- Never ask him to paste something you can read yourself.
- What he says about his own accounts and data is fact. If a tool disagrees, suspect the tool.
- When he reports a failure, answer with the fix.
- Anything that widens a credential or a permission is his decision. Bring one recommendation.

## Identity

- Bundle id `vc.1201.speedtrack`. It is permanent once it is registered with Apple.
- `MARKETING_VERSION` is in `project.yml`. The build number is the Actions run number.

## Status

The app compiles and its three unit tests pass on Actions. The scaffold went in without the three
gates, so they run on it first. TestFlight is not set up: `ci/testflight.sh` and the workflow's
`testflight` job predate the deployment rules above and must be replaced before their first use.
