# Canvid Homebrew Tap

This tap distributes the Apple Silicon builds of Canvid through Homebrew Cask.

## Install

Install the stable release:

```bash
brew install --cask videocom/tap/canvid
```

Install the beta release:

```bash
brew install --cask videocom/tap/canvid@beta
```

The stable and beta applications have separate bundle identities and can be
installed at the same time.

## Supported platforms

The casks support Apple Silicon Macs running macOS Monterey or newer. Canvid's
signed and notarized release artifacts are downloaded directly from
`installers.canvid.com`.

## Updates

A GitHub Actions workflow checks the stable and beta update feeds each Monday
and can also be run manually. It downloads new DMGs, calculates their SHA-256
checksums, validates the generated diff, and commits updated casks.

See [the distribution plan](docs/homebrew-cask-distribution-plan.md) for the
release contract and rollout details.
