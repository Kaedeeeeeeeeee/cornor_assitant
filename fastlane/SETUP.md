# Corner Peek fastlane Setup

This folder automates App Store Connect uploads for Corner Peek.

## What It Can Do

- Upload App Store screenshots from `/tmp/peek-app-store-screenshots`.
- Upload localized metadata generated from `CornerAssistantApp/docs/AppStore-Materials.md`.
- Upload a signed macOS `.pkg` when App Store export is available.

It does not store App Store Connect credentials in git.

## Local Credentials

The current local API key configuration is stored in `.env.asc`, which is ignored by git.

Required variables:

```bash
ASC_KEY_ID=...
ASC_ISSUER_ID=...
ASC_KEY_PATH=/absolute/path/to/AuthKey_XXXXXXXXXX.p8
```

The `.p8` key should stay outside the repository and use `chmod 600`.

## Commands

Use the Homebrew Ruby already installed on this machine:

```bash
PATH="/opt/homebrew/opt/ruby/bin:$PATH" bundle install
```

Load the local API key environment:

```bash
set -a
source .env.asc
set +a
```

Prepare derived assets:

```bash
PATH="/opt/homebrew/opt/ruby/bin:$PATH" bundle exec fastlane mac prepare_app_store_assets
```

Upload screenshots only:

```bash
PATH="/opt/homebrew/opt/ruby/bin:$PATH" bundle exec fastlane mac upload_screenshots
```

The screenshot lane uses `script/upload_fastlane_screenshots_direct.rb` instead of fastlane deliver's default screenshot uploader. This is intentional: deliver accepted all local screenshot folders for macOS but only created screenshots in the primary `en-US` locale during testing.

Upload metadata only:

```bash
PATH="/opt/homebrew/opt/ruby/bin:$PATH" bundle exec fastlane mac upload_metadata
```

Upload metadata and screenshots together:

```bash
PATH="/opt/homebrew/opt/ruby/bin:$PATH" bundle exec fastlane mac upload_app_store_assets
```

Upload a signed macOS package:

```bash
PATH="/opt/homebrew/opt/ruby/bin:$PATH" bundle exec fastlane mac upload_pkg pkg:/absolute/path/to/CornerPeek.pkg
```

Submit the prepared App Store version for review after the desired build is processed and selected:

```bash
PATH="/opt/homebrew/opt/ruby/bin:$PATH" bundle exec fastlane mac submit_for_review build_number:3
```

## Stable Cloud Build Fallback

The local machine may be running a macOS/Xcode beta that App Store Connect does
not yet accept for Mac App Store uploads. In that case, use the repository's
manual GitHub Actions workflow instead of creating the final package locally:

```text
Actions -> Build Corner Peek App Store Package -> Run workflow
```

The workflow runs on `macos-15`, archives `CornerAssistantApp`, exports a Mac App
Store `.pkg`, and publishes it as the `corner-peek-app-store-pkg` artifact. If
`upload_to_app_store` is set to `true`, it also uploads the package with
`fastlane mac upload_pkg`.

Required GitHub Actions secrets:

```text
PEEK_APP_CERTIFICATE_BASE64        # base64 of the Apple Distribution .p12
PEEK_INSTALLER_CERTIFICATE_BASE64  # base64 of the 3rd Party Mac Developer Installer .p12
PEEK_P12_PASSWORD                  # password shared by the two .p12 files
PEEK_PROVISION_PROFILE_BASE64      # base64 of Corner_Peek_Mac_App_Store.provisionprofile
PEEK_KEYCHAIN_PASSWORD             # temporary CI keychain password
PEEK_ASC_KEY_ID                    # App Store Connect API key id, only needed for upload_to_app_store=true
PEEK_ASC_ISSUER_ID                 # App Store Connect issuer id, only needed for upload_to_app_store=true
PEEK_ASC_KEY_CONTENT_BASE64        # base64 of the AuthKey_*.p8 content, only needed for upload_to_app_store=true
```

To prepare these values locally without uploading them, run:

```bash
./script/prepare_github_actions_secrets.sh
```

The script writes sensitive files under `/tmp/peek-github-actions-secrets` by
default. Do not commit that directory, and delete it after the repository secrets
are configured.

## Screenshot Locales

By default, `script/prepare_fastlane_screenshots.sh` copies the same screenshot set to `en-US`, `zh-Hans`, and `ja`.

Override this when needed:

```bash
PEEK_FASTLANE_SCREENSHOT_LOCALES=en-US ./script/prepare_fastlane_screenshots.sh
```

The screenshots are currently English UI composites. Replace per-locale files under `fastlane/screenshots/<locale>/` if localized screenshot text is prepared later.

## Source of Truth

- Metadata source: `CornerAssistantApp/docs/AppStore-Materials.md`
- Screenshot source: `script/capture_app_store_screenshot.sh`
- Generated fastlane folders: `fastlane/metadata` and `fastlane/screenshots`

The generated folders are ignored by git because they are reproducible.
