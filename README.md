# Resonance — a music player for Android

Plays the songs stored on your phone with a clean, big-artwork design, and —
when you're online — downloads artist photos & bios, album covers & release
details, and time-synced lyrics. Everything downloaded is kept on the phone,
so it still shows when you're offline.

**Features**
- Home: greeting, Play / Shuffle all, *Your Mix*, Recently Added, Your Artists, Rediscover
- Library: Artists, Albums, Songs, and a Recently Added grid
- Album pages: cover, genre · year, track list (multi-disc aware), release date, label
- Artist pages: full-width photo, top songs, albums, Wikipedia bio, fan count
- Full-screen player: blurred-artwork backdrop, scrubber, shuffle / repeat,
  **synced lyrics** that follow the song (tap a line to jump), and the up-next queue
- Mini player above the tabs, background playback, lock-screen & notification
  controls, headphone buttons
- Search across songs, albums and artists
- Long-press any song: Play Next, Add to Queue, Go to Album, Go to Artist
- Settings: turn internet downloads on/off, clear downloaded info, rescan
- Light and dark mode follow the phone

Online info comes from free services that need no account or key:
Deezer (photos, covers, release info), Wikipedia (bios) and LRCLIB (lyrics).

---

## Option A — Get the APK without installing anything (recommended)

GitHub can build the app for you in the cloud. You only need a free GitHub account.

1. **Create a GitHub account** at <https://github.com/signup> (skip if you have one).
2. **Create a new repository**: click **+** (top right) → **New repository**.
   Name it `resonance`, choose **Public** or **Private**, and click **Create repository**.
3. **Upload the project**: on the new repo page click **uploading an existing file**.
   Unzip `resonance.zip` on your computer, open the `resonance` folder, select
   **everything inside it** (including the `.github` folder) and drag it into the browser.
   Click **Commit changes**.
   - On a Mac, the `.github` folder is hidden in Finder — press **Cmd + Shift + .** to show it.
   - If the `.github` folder didn't upload, click **Add file → Create new file**, type the name
     `.github/workflows/build-apk.yml`, paste in the contents of that file, and commit.
4. **Wait for the build**: open the **Actions** tab. A run called *Build APK* starts
   automatically and takes about 5–8 minutes. A green tick means it worked.
5. **Download the APK**: open the **Releases** section on the right of the repo's main
   page (or `https://github.com/<your-name>/resonance/releases`) and download
   **Resonance.apk**. That release link is what you share with others.

Every time you upload changed files, a fresh APK is built automatically. You can
also re-run it from **Actions → Build APK → Run workflow**.

## Option B — Build it on your own computer

1. Install **Android Studio** (<https://developer.android.com/studio>) and open it once so it
   downloads the Android SDK.
2. Install **Flutter** (<https://docs.flutter.dev/get-started/install>) and run
   `flutter doctor` until the Android items have green ticks
   (run `flutter doctor --android-licenses` and accept them).
3. In a terminal, go into this `resonance` folder and run:
   ```
   flutter create --org com.resonance --project-name resonance --platforms android .
   flutter pub get
   flutter build apk --release
   ```
   The first command adds the standard Android build files; it does **not** overwrite
   the app's own files.
4. Your APK is at `build/app/outputs/flutter-apk/app-release.apk`.

To try it live on a phone plugged in by USB (with *USB debugging* turned on in
Developer options), run `flutter run` instead.

## Installing the APK on a phone

1. Copy `Resonance.apk` to the phone (or open the Releases link on the phone and download it).
2. Tap the file. If Android asks, allow **Install unknown apps** for your browser or file manager.
3. Open **Resonance** and tap **Allow** when it asks for access to music and notifications.

If you see *"App not installed"*, uninstall any older copy of Resonance first.
Google Play Protect may warn about an app from an unknown developer — choose
**Install anyway**; this happens with any app that isn't from the Play Store.

**Where does it find music?** Any audio files Android has indexed — MP3, M4A/AAC,
FLAC, OGG, WAV, OPUS — in folders like *Music* or *Download*. Songs shorter than
20 seconds (ringtones, voice notes) are hidden. Add new files, then pull down on
Home or Library (or Settings → Rescan).

## Project layout

```
lib/
  main.dart                    app start-up, providers, themes
  models/models.dart           Song, Album, Artist, Lyrics, online info types
  services/
    media_library.dart         reads songs from the phone, groups albums/artists, cover art
    player_controller.dart     playback queue, shuffle, repeat, notification info
    online_info.dart           Deezer / Wikipedia / LRCLIB lookups with offline cache
  ui/
    root_shell.dart            tabs + mini player + permission screens
    app_nav.dart               navigation helper
    theme.dart                 colours and type
    screens/                   home, library, lists, album, artist, search, settings, now playing
    widgets/                   artwork, mini player, song rows, buttons
android/app/src/main/
  AndroidManifest.xml          permissions + background playback service
  kotlin/.../MainActivity.kt   asks Android's MediaStore for songs and embedded covers
.github/workflows/build-apk.yml  the cloud build
```

**Changing the accent colour:** edit `accent` in `lib/ui/theme.dart`.
**Changing the app name:** edit `android:label` in `AndroidManifest.xml`.

## Sharing it more widely

The APK is signed with Flutter's built-in *debug* key, which is fine for installing
on your own phones and sharing with friends. To publish on the Google Play Store you'd
create your own signing key — see <https://docs.flutter.dev/deployment/android>.
