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
