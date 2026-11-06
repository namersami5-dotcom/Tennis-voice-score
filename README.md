# Tennis Voice Score — Flutter project source

## Included in this iteration
- Android/iOS Flutter project source
- Local SQLite persistence for players, completed matches, and current match
- English and Arabic speech command parsing, with an EN/AR selector on the live match screen
- First-to-10 scoring (configurable in a future settings iteration), no deuce, no two-point margin
- Voice point commands, Undo, Pause, Resume
- Text-to-speech point and match-win announcements
- Player list and individual statistics
- Leaderboard: wins, then win rate, then point difference
- Match history and a Head-to-Head comparison page
- Venue field and match score history

## Voice phrases
English:
- `Point for 1`, `Point one`, `Player one`
- `Point for 2`, `Point two`, `Player two`
- `Undo`, `Pause`, `Resume`

Arabic examples:
- `نقطة للاعب الأول` / `نقطة للاعب الاول` / `نقطة للاعب واحد`
- `نقطة للاعب الثاني` / `نقطة للاعب اثنين`
- `تراجع` / `إيقاف` / `استئناف`

The app chooses an available installed speech locale matching Arabic or English. Actual Arabic locale availability and recognition quality vary by device and installed speech services.

## Build and run
1. Install Flutter SDK and Android Studio. For iOS builds, use macOS with Xcode.
2. Extract this archive, open a terminal in the extracted folder, and run `flutter create .` to generate the native Android/iOS platform folders.
3. Run `flutter pub get`.
4. Add the permissions below to the generated platform files.
5. Run `flutter run`.

### Android
Add inside `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.INTERNET"/>
```

### iOS
Add inside `ios/Runner/Info.plist`:
```xml
<key>NSSpeechRecognitionUsageDescription</key>
<string>Speech recognition listens for tennis scoring commands.</string>
<key>NSMicrophoneUsageDescription</key>
<string>The microphone listens for tennis scoring commands.</string>
```

## Important production notes
This archive contains Flutter source code, not a signed APK or IPA. It has not been compiled or tested on physical Android/iOS devices in this environment. Speech recognition is provided by the operating system speech service; it may require network access depending on device, locale, and installed offline language packs. Keep the app in the foreground during play. Mobile operating systems may suspend microphone access in the background.

The current version is a practical development build, not yet a fully field-validated umpire. Test on the actual phone at court distance and in wind/court noise. Tune the recognition locale, cooldown, and restart behavior after those tests. The Undo history is held in memory for the current live screen; persistent point-by-point undo history is a recommended next hardening step. Cloud sync, 7/30-day performance panels, streak analytics, editable target points, and comprehensive automated tests remain future work.

## Build an APK without a computer (GitHub Actions)
This archive includes `.github/workflows/build-android.yml`. Upload the project files to a new GitHub repository, then open **Actions → Build Android APK → Run workflow**. When the workflow finishes, open its run, scroll to **Artifacts**, and download `tennis-voice-score-apk`. Extract the downloaded artifact ZIP to get `app-release.apk`, then open the APK on your Android phone to install it. GitHub may ask you to enable Actions for the repository.
