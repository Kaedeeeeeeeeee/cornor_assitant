fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Mac

### mac prepare_app_store_assets

```sh
[bundle exec] fastlane mac prepare_app_store_assets
```

Generate fastlane metadata and screenshot folders from repository sources

### mac upload_screenshots

```sh
[bundle exec] fastlane mac upload_screenshots
```

Upload generated App Store screenshots without touching metadata or binary

### mac upload_metadata

```sh
[bundle exec] fastlane mac upload_metadata
```

Upload generated App Store metadata without touching screenshots or binary

### mac upload_app_store_assets

```sh
[bundle exec] fastlane mac upload_app_store_assets
```

Upload generated App Store metadata and screenshots without touching binary

### mac upload_pkg

```sh
[bundle exec] fastlane mac upload_pkg
```

Upload a signed macOS pkg to App Store Connect

### mac submit_for_review

```sh
[bundle exec] fastlane mac submit_for_review
```

Submit the prepared macOS App Store version for review

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
