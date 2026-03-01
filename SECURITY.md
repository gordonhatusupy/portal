# Security Policy

## Supported Versions

Portal is currently in an early public stage.

Security fixes are applied on the latest code on `main`.

| Version | Supported |
| --- | --- |
| `main` | Yes |
| Earlier commits / tags | No |

## Reporting a Vulnerability

If you discover a security issue in Portal:

1. **Do not post full exploit details in a public issue.**
2. Prefer GitHub's private vulnerability reporting / security advisory flow if it is available for this repository.
3. If private reporting is not available, contact the maintainer through GitHub first and share only the minimum details needed to start triage.

Please include:

- a short description of the issue
- impact / what an attacker could do
- steps to reproduce
- any suggested fix or mitigation, if you have one

The goal is to acknowledge and triage valid reports quickly, then ship a fix on `main`.

## Scope

This project is a native macOS developer utility. The highest priority issues are:

- command execution risks
- unsafe process handling
- accidental exposure of secrets in the repository
- supply-chain issues in GitHub Actions or build configuration

## Disclosure Expectations

- Please allow time for investigation and a fix before public disclosure.
- Once a fix is available, the project can document the issue in release notes or commit history as appropriate.
