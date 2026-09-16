# Shared Logic and Fire TV App

For project setup and the full architecture overview, see the [root README](../README.md).

`sharedLogic` contains the Kotlin Multiplatform models, TMDB client, and display-server URL behavior used by both Apple and Android clients. `androidApp` is the native Jetpack Compose Fire TV client.

## Configure TMDB

Provide the TMDB API read-access token without committing it:

```properties
# local.properties (already ignored by Git)
TMDB_API_READ_ACCESS_TOKEN=your_token
```

Gradle user properties and the `TMDB_API_READ_ACCESS_TOKEN` environment variable are also supported.

## Build and install

```shell
./gradlew :androidApp:assembleDebug
adb install -r androidApp/build/outputs/apk/debug/androidApp-debug.apk
```

The app declares the Leanback launcher and does not require a touchscreen. Search, tabs, favorite actions, server selection, seasons, episodes, playback, and reload controls are focusable with a Fire TV remote.

## Content blocking

Android packages the canonical `NetworkBlockingRules.json` and `PopupFilters.json` files from the existing iOS feature directory. The platform-specific implementation in `androidApp` compiles WebKit-style source rules into Android host and regular-expression matchers, intercepts matching WebView requests, blocks new windows and non-web navigation, and injects popup/DOM filtering JavaScript after navigation. It does not use WebKit APIs or compiled WebKit rule formats.
