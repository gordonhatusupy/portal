# Contributing to Portal

Thanks for your interest in improving Portal.

## Local setup

1. Clone the repository.
2. Open `Portal.xcodeproj` in Xcode.
3. Use the shared `Portal` scheme.

If you update `project.yml`, regenerate the Xcode project before committing:

```bash
xcodegen
```

## Build and test

Build:

```bash
xcodebuild \
  -project Portal.xcodeproj \
  -scheme Portal \
  -configuration Debug \
  -derivedDataPath .derivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Test:

```bash
xcodebuild \
  -project Portal.xcodeproj \
  -scheme Portal \
  -configuration Debug \
  -derivedDataPath .derivedData \
  CODE_SIGNING_ALLOWED=NO \
  test
```

## Pull request guidelines

- Keep changes focused and easy to review.
- Prefer small, incremental pull requests over large rewrites.
- Include screenshots or screen recordings for visible UI changes.
- Preserve the native macOS implementation approach (Swift, SwiftUI, AppKit).
- Add or update tests when changing parsing, filtering, or server action behavior.

## Things not to commit

- `.build/`
- `.derivedData/`
- local cache directories
- machine-specific generated files

The repo `.gitignore` already covers the main local build artifacts.
