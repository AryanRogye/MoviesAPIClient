# Movies for LG webOS TV

This standalone webOS TV app follows the Android/Fire TV client: six discovery sections, movie and TV search, favorites, collections with optional PINs, watch history, detail pages, season and episode selection, and the same nine display-server URL patterns. It is written as a packaged web app with no build dependencies.

## Build and install

With Developer Mode and Key Server enabled on your TV, run this from the repository root:

```sh
./deploy-lg-tv.sh
```

It packages, installs, and launches on the saved `HomeLGTV` device. Pass another configured device name if needed:

```sh
./deploy-lg-tv.sh DEVICE_NAME
```

For the LG Simulator, open the `LGTVScratch` folder through its **Launch App** menu. The simulator must be installed separately from [LG's official download](https://webostv.developer.lge.com/develop/tools/simulator-installation).

For a remote-free token setup, copy `config.example.js` to `config.local.js` and set `window.LG_TMDB_TOKEN` to your TMDB API Read Access Token. `config.local.js` is ignored by Git, but **it is included in the packaged `.ipk` and can be extracted from it**. Keep the package private. You can instead enter a token in **Settings** on the TV, where it is stored in the app's local storage. The app needs a network connection for TMDB and artwork. Favorites, history, collections, and settings are local to the LG device, with no sync to iOS or Android.

Use the remote's arrow keys and OK to navigate. The server buttons appear on the detail page and above the player; selecting another server loads it immediately. Back closes playback, then returns to the previous screen. On embedded player pages, the Magic Remote pointer may be needed to select controls within the provider's frame.

## Playback and blocker limits

The iOS app's blocker uses WebKit content rule lists and scripts injected into every frame. A packaged webOS web app cannot attach those hooks to cross-origin pages. The embedded player has no iframe sandbox because some providers reject sandboxed frames. It cannot block the provider's network subrequests or inspect its cross-origin DOM. Some providers may still refuse iframe embedding or require cookies.

LG's [web engine documentation](https://webostv.developer.lge.com/develop/specifications/web-api-and-web-engine) also notes that packaged `file:` web apps do not support cookies. Playback and provider compatibility need validation on the target TV.

## Files

- `index.html`: webOS entry point
- `app.js`: state, TMDB requests, screens, persistence, and remote navigation
- `styles.css`: TV layout and focus styling
- `appinfo.json`: webOS package metadata
- `config.example.js`: template for the optional, Git-ignored `config.local.js`

This product uses the TMDB API but is not endorsed or certified by TMDB.
