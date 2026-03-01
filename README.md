# Portal

[![Security](https://github.com/gordonhatusupy/portal/actions/workflows/security.yml/badge.svg)](https://github.com/gordonhatusupy/portal/actions/workflows/security.yml)

Portal is a native macOS menu bar utility for monitoring and managing running local web servers.

When Portal is running, it lives in your menu bar and Dock, automatically discovers local web servers, shows the project name, active Git branch, localhost URL, and runtime, and lets you open or stop a server in one click.

<p align="center">
  <img src="public/app%20icon@2x.png" alt="Portal app icon" width="128" />
</p>

## Features

- Native macOS app built with SwiftUI + AppKit
- Menu bar status item with a compact floating panel
- Dock-visible while running for standard macOS app behavior
- Auto-detects running local web servers via `lsof`
- Resolves project name from the server's working directory
- Resolves the active Git branch when the project is in a Git worktree
- Displays the full localhost URL and the server runtime
- Opens a server in your default browser
- Stops a server with a terminate-first, force-kill fallback
- Shows a dedicated empty state when no local servers are running

## Requirements

- macOS 14 or later
- Xcode 16 or newer (recommended)
- Swift 6 toolchain

## Direct download releases

Portal supports direct-download release packaging via GitHub Releases.

When a signed and notarized build is published, you will be able to download the latest packaged app from the repository's [Releases](https://github.com/gordonhatusupy/portal/releases) page, unzip it, and move `Portal.app` into `/Applications`.

## Running in Xcode

1. Clone this repository.
2. Open `Portal.xcodeproj` in Xcode.
3. Select the `Portal` scheme.
4. Build and run the app.

Once launched, Portal will appear in your menu bar and Dock.

## Building from the command line

The primary supported workflow is the Xcode project.

If you change `project.yml`, regenerate the project first:

```bash
xcodegen
```

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

Run tests:

```bash
xcodebuild \
  -project Portal.xcodeproj \
  -scheme Portal \
  -configuration Debug \
  -derivedDataPath .derivedData \
  CODE_SIGNING_ALLOWED=NO \
  test
```

## Installing the app locally

After building, the app bundle will be available at:

```bash
.derivedData/Build/Products/Debug/Portal.app
```

You can run it directly from there, or copy it into `/Applications`:

```bash
rsync -a --delete ".derivedData/Build/Products/Debug/Portal.app/" "/Applications/Portal.app/"
```

## How it works

Portal has two main parts:

- `Portal`: the macOS app target (AppKit status item + floating panel, SwiftUI interface)
- `PortalCore`: shared discovery, parsing, Git resolution, and server actions

At runtime, Portal:

1. Uses `lsof` to inspect listening TCP servers.
2. Filters down to likely local development servers.
3. Resolves the best project root from the process working directory or executable path.
4. Reads the current Git branch when a `.git` worktree is present.
5. Builds a row model with the app name, URL, and runtime.

## Known limitations

- Server detection is heuristic-based and optimized for local development servers.
- HTTPS is not inferred yet; URLs currently open as `http://localhost:<port>`.
- Signed/notarized direct-download releases require Apple Developer signing credentials and a tagged release workflow run.
- Some system listeners may be filtered out or ignored if they do not resolve to a plausible project directory.

## Roadmap

- Improve server detection heuristics
- Add launch-at-login support
- Ship signed / notarized downloadable releases
- Publish GitHub Releases with packaged `.app` builds
- Add richer actions such as restart or log access

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup, build, and pull request guidelines.

## License

Portal is released under the [MIT License](LICENSE).
