# MoviesAPIClient

MoviesAPIClient is a personal movie and TV discovery client with native SwiftUI and Fire TV interfaces. Both clients use the same Kotlin Multiplatform models, TMDB networking, and display-server URL logic.

## What it includes

- TMDB multi-search for movies and TV shows, with optional adult-result filtering
- Favorite library and watch history
- Movie playback plus TV season and episode selection
- Server selection persisted per device
- Native Fire TV Compose UI with D-pad focus, a WebView cursor, reload controls, and fullscreen playback
- Android request and popup filtering sourced from the existing shared blocking-rule lists

Playback availability depends on the selected third-party server.

## Credits

The Android/Fire TV UI was written by Codex. The app's business logic and product behavior were created by Aryan Rogye.

## Project layout

| Path | Purpose |
| --- | --- |
| `MoviesAPIClient/` | SwiftUI app for Apple platforms |
| `MoviesShared/sharedLogic/` | Kotlin Multiplatform models, TMDB client, and display-server behavior |
| `MoviesShared/androidApp/` | Native Jetpack Compose Fire TV app and Android WebView implementation |

## Configure TMDB

Create your own TMDB API read-access token. Do not commit it.

### Apple app

Copy the template and add the token:

```shell
cp Config.example.xcconfig Config.xcconfig
```

```xcconfig
APIReadAccessToken = your_token
```

Open `MoviesAPIClient.xcodeproj` in Xcode and run the app.

### Fire TV app

Create `MoviesShared/local.properties`:

```properties
TMDB_API_READ_ACCESS_TOKEN=your_token
```

`MoviesShared/local.properties` is ignored by Git. The Android build also accepts the token from a Gradle property or the `TMDB_API_READ_ACCESS_TOKEN` environment variable.

## Build the Fire TV app

From `MoviesShared`:

```shell
./gradlew :androidApp:assembleDebug
adb install -r androidApp/build/outputs/apk/debug/androidApp-debug.apk
```

The Android app targets Fire TV's Leanback launcher and does not require a touchscreen. Use the remote to move focus; Select activates controls. In the player, the on-screen cursor sends click events to the embedded page, and Back returns focus to native controls or exits fullscreen.

## Android content blocking

The Android client keeps its implementation inside `androidApp`. It packages the canonical network and popup rule sources from the Apple project, translates compatible network rules into Android request matching, intercepts matching WebView requests, and uses DOM filtering for popup-style elements. It does not reuse WebKit APIs or compiled WebKit rule formats.

## Development notes

- Use `./gradlew :androidApp:assembleDebug` for the quickest Android iteration.
- Avoid `clean` during normal work; Gradle's configuration cache and build cache are enabled.
- `sharedLogic` is shared infrastructure. Keep platform UI, persistence, focus handling, and WebView behavior in their respective app targets.

## License

MIT. See [LICENSE](LICENSE).
