# Contributing

Thanks for taking the time. Odak is a small app and I would like to keep it that way, so please open an issue before starting on a new feature. Bug fixes and translation improvements can go straight to a pull request.

## Building

Requirements: macOS 14 or later, Xcode 15 or later, [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
make project        # generates Odak.xcodeproj from project.yml
open Odak.xcodeproj
```

`make build` builds from the command line. Do not commit `Odak.xcodeproj`; change `project.yml` instead.

## Tests

```sh
make test
# or, after make project:
xcodebuild test -project Odak.xcodeproj -scheme Odak -destination 'platform=macOS'
```

CI runs the same build and tests on every push and pull request. Tests must not touch the real `/etc/hosts` or call the helper. The unit tests cover the domain parser, the timer, stats and the planner dial geometry. The helper script (`Odak/Resources/odak-block`) has no test mode; check changes to it by hand on a copy with the paths changed.

## Code style

- Swift 5.9+, SwiftUI first. AppKit only where SwiftUI cannot do the job.
- Follow the style of the surrounding code: four-space indentation, `let` over `var`, no force unwraps outside tests.
- Keep dependencies at zero unless there is a strong reason.
- No network calls. Odak does not talk to the internet and should not start.

## Localization

All user-facing strings live in `Odak/Resources/Localizable.xcstrings` (English is the source, Turkish is the second language). Edit it in Xcode's string catalog editor. When you add a string, add the Turkish translation too, or mark it as needing review in the pull request. New languages are welcome.

## Pull requests

- One change per pull request, with a short description of what and why.
- Include screenshots for UI changes, in both light and dark mode.
- Make sure `xcodebuild test` passes locally.
- Any change to the privileged helper or the sudoers rule needs a clear explanation and will get a careful review.
- Add a line to `CHANGELOG.md` under Unreleased.

## Security issues

Please do not open a public issue. Use [Report a vulnerability](https://github.com/slymnyg/odak/security/advisories/new) to reach me privately or see [SECURITY.md](SECURITY.md).
