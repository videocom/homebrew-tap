# Canvid Homebrew Cask Distribution Plan

## Goal

Distribute the Apple Silicon builds of Canvid through a vendor-owned Homebrew tap with support for both stable and beta releases:

```bash
brew install --cask videocom/tap/canvid
brew install --cask videocom/tap/canvid@beta
```

Keep ongoing maintenance low by having GitHub Actions check Canvid's existing update feeds once per week, while also allowing maintainers to run the update manually.

## Scope

This first iteration will:

- Provide separate stable and beta casks.
- Install the existing signed and notarized DMGs published on `installers.canvid.com`.
- Support Apple Silicon only, matching the current Canvid macOS build.
- Allow stable and beta to be installed at the same time.
- Poll for releases weekly.
- Support manual update runs through GitHub Actions.
- Commit validated version and checksum updates directly to the default branch.

This iteration will not:

- Build Canvid inside the tap.
- Publish or mirror Canvid artifacts.
- Use `version :latest` or `sha256 :no_check`.
- Submit the casks to the official `Homebrew/homebrew-cask` repository.
- Trigger updates directly from the Canvid release workflow.
- Add Intel or universal macOS support.

## Existing release contract

| Channel | Update feed | DMG naming pattern | Installed application |
| --- | --- | --- | --- |
| Stable | `https://installers.canvid.com/latest-mac.yml` | `Canvid-v<version>-mac.dmg` | `Canvid.app` |
| Beta | `https://installers.canvid.com/beta-mac.yml` | `Canvid Beta-v<version>-mac.dmg` | `Canvid Beta.app` |

The applications can coexist because the beta build has a distinct application name, bundle identifier, and data directory.

Published release files must remain immutable. A released version must never be overwritten with different bytes because its Homebrew SHA-256 checksum is part of the cask definition.

## Proposed repository layout

```text
homebrew-tap/
├── .github/
│   └── workflows/
│       └── update-canvid-casks.yml
├── Casks/
│   ├── canvid.rb
│   └── canvid@beta.rb
├── docs/
│   └── homebrew-cask-distribution-plan.md
├── scripts/
│   └── update-canvid-casks.rb
└── README.md
```

## Cask definitions

### Stable

`Casks/canvid.rb` will contain:

- A concrete stable version.
- The corresponding DMG SHA-256.
- The versioned `installers.canvid.com` URL.
- `app "Canvid.app"`.
- `auto_updates true`.
- `depends_on arch: :arm64`.
- A `livecheck` block backed by `latest-mac.yml`.

### Beta

`Casks/canvid@beta.rb` will contain:

- A concrete prerelease version.
- The corresponding DMG SHA-256.
- The versioned beta DMG URL.
- `app "Canvid Beta.app"`.
- `auto_updates true`.
- `depends_on arch: :arm64`.
- A `livecheck` block backed by `beta-mac.yml`.

The casks will not conflict with one another because the stable and beta applications have distinct bundle identities and installation paths.

## Update automation

Create `.github/workflows/update-canvid-casks.yml` with two triggers:

```yaml
on:
  schedule:
    - cron: "17 3 * * 1"
  workflow_dispatch:
```

The schedule runs every Monday at 03:17 UTC. A non-round minute reduces the chance of delays caused by GitHub Actions load at the start of an hour.

The workflow will:

1. Check out the tap repository.
2. Run `scripts/update-canvid-casks.rb`.
3. Exit successfully without a commit when both casks are current.
4. Review the generated diff and ensure only the expected cask fields changed.
5. Commit updated casks with:

   ```text
   chore(casks): update Canvid releases
   ```

6. Push the commit to `main` using the repository-scoped `GITHUB_TOKEN`.

Required workflow permission:

```yaml
permissions:
  contents: write
```

Use a concurrency group so scheduled and manually triggered runs cannot update the casks simultaneously.

## Updater behavior

Implement `scripts/update-canvid-casks.rb` with only Ruby's standard library.

For each channel, the updater will:

1. Download its update feed over HTTPS.
2. Extract the version from the top-level `version` field.
3. Validate the version against a strict channel-specific pattern.
4. Compare it with the version currently recorded in the cask.
5. Skip the DMG download when the cask is already current.
6. Construct the artifact URL from a fixed trusted base URL and the validated version.
7. Download the DMG with redirects, retries, and failure-on-HTTP-error enabled.
8. Calculate its SHA-256 while streaming, without retaining the large DMG.
9. Update only the cask's `version` and `sha256` fields.
10. Fail without modifying either cask if any feed, download, validation, or checksum step fails.

Stable versions must match:

```text
<major>.<minor>.<patch>
```

Beta versions must match:

```text
<major>.<minor>.<patch>-beta.<number>
```

The updater must not evaluate values from the remote feed as Ruby or shell code.

## Validation

Before the initial publication:

1. Run the updater twice and confirm the second run produces no changes.
2. Run:

   ```bash
   brew audit --new --cask videocom/tap/canvid
   brew audit --new --cask videocom/tap/canvid@beta
   ```

3. Install both applications:

   ```bash
   brew install --cask videocom/tap/canvid
   brew install --cask videocom/tap/canvid@beta
   ```

4. Confirm both applications launch on a clean Apple Silicon Mac without disabling Gatekeeper.
5. Confirm stable and beta can run and retain separate application data.
6. Confirm an export succeeds, exercising Canvid's packaged native dependencies.
7. Uninstall both casks and confirm Homebrew removes the application bundles.
8. Manually trigger the workflow and confirm an unchanged release produces no commit.

## GitHub repository settings

Configure the repository as follows:

- Make the repository public so Homebrew can consume it as `videocom/tap`.
- Enable GitHub Actions.
- Permit the workflow `GITHUB_TOKEN` to write repository contents.
- Allow the updater workflow to push to `main`.
- Do not require secrets for the polling workflow.

If branch protection later prevents direct pushes, change the workflow to open an automated pull request instead of weakening the protection.

GitHub may disable scheduled workflows in a public repository after 60 days without repository activity. The manual trigger remains part of the workflow, but maintainers should verify that the schedule is enabled when releases resume after a long pause.

## Rollout

1. Implement and locally validate both casks.
2. Implement the updater and its behavior-level tests.
3. Add the weekly/manual GitHub Actions workflow.
4. Create the public GitHub repository as `videocom/homebrew-tap`.
5. Push `main`.
6. Configure the required Actions write permission.
7. Install stable and beta from the public tap on a clean Apple Silicon Mac.
8. Add the Homebrew commands to Canvid's download or installation documentation.
9. Observe the first real stable and beta updates before treating the automation as unattended.

## Acceptance criteria

- `brew install --cask videocom/tap/canvid` installs the current stable application.
- `brew install --cask videocom/tap/canvid@beta` installs the current beta application.
- Stable and beta can be installed simultaneously.
- Every cask release uses a concrete version and SHA-256.
- An unchanged weekly or manual run creates no commit.
- A new valid feed version updates only the matching cask.
- A malformed feed or failed artifact download creates no commit.
- Concurrent workflow runs cannot race.
- No long-lived secret is required for polling or committing within the tap repository.

## Possible follow-up

After the vendor tap has operated reliably:

- Trigger the updater immediately from the Canvid publishing workflow with `repository_dispatch`, retaining the weekly poll as recovery.
- Submit `canvid` and then `canvid@beta` to the official `Homebrew/homebrew-cask` repository if Canvid meets its public-interest and maintenance criteria.
- Add Intel or universal casks only if Canvid begins publishing and testing those artifacts.
