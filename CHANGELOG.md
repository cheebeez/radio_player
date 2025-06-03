## 2.1.0

* Breaking Change: Improved `setCustomMetadata` to fully support `null` values for `artist`, `title`, and `artworkUrl`.
* Breaking Change: Moved settings for ICY metadata parsing and online artwork lookup into `setChannel` parameters.
* Breaking Change: Made the `RadioPlayer` Dart class fully static.
* Breaking Change: `RadioPlayer.playbackStateStream` now emits `PlaybackState` enum, offering richer states like `buffering`.

## 2.0.0

* Migrate to Android Media3.
* Minimum iOS deployment target raised to 15.0.

## 1.7.0

* Updated Android target SDK to version 35.

## 1.6.0

* Updated Gradle to the current version.

## 1.5.0

* Added a duplicate metadata check for iOS.
* Updated Android target SDK to version 34.
* Updated ExoPlayer to the latest version.
* Updated example project.

## 1.4.0

* Fixed player behavior after disconnecting on iOS.
* Fixed metadata issues on some older Android devices.
* Fixed metadata display on the One UI lock screen.

## 1.3.0

* Added URL support for setDefaultArtwork.

## 1.2.0

* Added a metadata format check for Android.
* Fixed auto-resume playback issue on iOS.
* Updated various dependencies.

## 1.1.0

* Renamed the notification channel.
* Fixed artwork display in the Android 13 notification bar.
* Fixed an unused variable warning.

## 1.0.0

* Initial release.