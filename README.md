# Video Player

A personal Flutter video player for Android, built for the "no PC, no Android
Studio" workflow: you edit code from your phone/browser, push to GitHub, and
GitHub Actions builds the installable APK for you.

Audio-only playback is intentionally **not** included yet - this is the video
player only, as scoped. An audio player can be added later as a separate
piece of the app.

## Features

- Browse every video on your phone **and SD card** (uses Android's MediaStore,
  same mechanism most video player apps rely on)
- Custom gesture controls on the video surface:
  - Tap to show/hide controls
  - Double-tap left/right half to seek back/forward 10s
  - Drag up/down on the **left** half to dim/brighten the player overlay
  - Drag up/down on the **right** half to adjust volume
  - Pinch to zoom
- Play/pause, next/previous (within your library), scrubbable seek bar
- Playback speed menu (0.5x-2x)
- Subtitle track picker (for videos with embedded subtitle tracks)
- Wide format/codec support (MKV, EAC3, etc.) via `media_kit`, which uses
  `libmpv` under the hood rather than the more limited stock Android player
- Share button (rocket icon, tilted right) to send the current video file to
  another app
- Resume playback: a round button in the bottom-right corner of the library
  screen jumps straight back into your most recently watched video, from
  where you left off
- Theming: Light / Dark / System / Season gradient, with the gradient mode
  supporting both auto-detect (based on today's date) and manual season
  selection

## Project structure

```
lib/
  models/video_item.dart          Video model (wraps a photo_manager asset)
  services/
    video_scanner_service.dart    Finds videos + requests storage permission
    playback_service.dart         Saves/restores last-played position
  theme/
    theme_service.dart            Theme mode + season state, persisted
    season_gradients.dart         Gradient color palettes per season
    app_theme.dart                Light/dark ThemeData
  screens/
    home_screen.dart              Video library grid
    player_screen.dart            Full-screen player
  widgets/
    video_grid_tile.dart          Library thumbnail tile
    continue_watching_fab.dart    Round "resume" button
    gesture_control_layer.dart    Tap/drag/pinch gesture handling
    player_controls_overlay.dart  Play/pause, seek bar, speed, subtitles, share
.github/workflows/build_apk.yml   CI: builds the release APK
```

There's no `android/` folder committed to this repo on purpose - see the
"How the build works" section below.

## Building the APK (no PC required)

1. Create a new **public or private GitHub repository** (from the GitHub
   app or github.com on your phone).
2. Upload every file from this project into that repository, keeping the
   folder structure exactly as-is (the `.github/workflows/build_apk.yml`
   path matters).
3. Go to the repo's **Actions** tab. A workflow run should start
   automatically after your push (or trigger it manually via
   "Run workflow").
4. Wait for the run to finish (a few minutes).
5. Open the completed run, scroll to **Artifacts**, and download
   `video-player-apk`. It's a zip containing `app-release.apk`.
6. On your phone, unzip it (or your file manager may open it directly),
   tap the `.apk` file, and allow "install unknown apps" for whichever app
   you used to open it when prompted.

## How the build works

Since you don't have Android Studio locally to run `flutter create` once and
commit the generated native project, the workflow does that step *for you*,
every run:

1. Installs Flutter on the GitHub Actions runner.
2. Runs `flutter create --platforms=android` into a throwaway folder to
   generate a fresh, correct `android/` project matching that Flutter
   version's expected Gradle/AGP setup.
3. Copies that generated `android/` folder into the repo checkout.
4. Inserts the permissions the app needs (video/storage access, wake lock)
   into the generated `AndroidManifest.xml`.
5. Runs `flutter pub get` and `flutter build apk --release`.
6. Uploads the resulting APK as a downloadable build artifact.

This means the native Android boilerplate is always regenerated fresh and
in sync with whatever Flutter version is current - nothing to keep manually
updated.

## Notes & known limitations

- **Season detection** for the gradient theme is a simple Northern
  Hemisphere month-based guess. If you're south of the equator, just set the
  season manually from the leaf icon in the app bar instead of auto-detect.
- **Storage permission**: the app requests broad video access via
  `photo_manager`, which uses Android's MediaStore - this is what picks up
  videos on both internal storage and an SD card automatically, without you
  having to point it at folders manually.
- **Gesture sensitivity** (how far you need to drag for brightness/volume to
  change, pinch-zoom limits) is set to reasonable defaults in
  `gesture_control_layer.dart` and `player_screen.dart` - tweak the numbers
  there once you've tried it on your own device.
- **Codec support** depends on `media_kit`'s bundled `libmpv`, which covers
  MKV and EAC3/Dolby Digital Plus out of the box - no extra setup needed.

## What's next

- Audio-only player (separate from this video player, planned for later)
