# Radio Player

A Flutter plugin to play streaming audio content with background support and lock screen controls.

[![flutter platform](https://img.shields.io/badge/Platform-Flutter-yellow.svg)](https://flutter.dev)
[![pub package](https://img.shields.io/pub/v/radio_player.svg)](https://pub.dev/packages/radio_player)

## Installation

By default, iOS blocks requests to non-secure HTTP URLs. To allow them, add the following to your `ios/Runner/Info.plist`:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

If necessary, add permissions to play in the background:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
    <string>processing</string>
</array>
```

## Usage

All methods in `RadioPlayer` are static, so you don't need to create an instance.

### Setting a Station

Configure the player with your station details. You can provide a logo from local assets or a network URL.

```dart
import 'package:radio_player/radio_player.dart';

RadioPlayer.setStation(
    // Station name for notifications and lock screen.
    title: "My Awesome Radio",

    // Direct URL to the audio stream (e.g., MP3, AAC, HLS).
    url: "YOUR_STREAM_URL_HERE",

    // Optional: Local asset path for the station logo.
    logoAssetPath: "assets/images/my_radio_logo.png",

    // Optional: Network URL for the station logo.
    logoNetworkUrl: "https://example.com/logo.png", 

    // Optional: Parse ICY metadata from the stream.
    parseStreamMetadata: true,

    // Optional: Find artwork on iTunes by artist and title.
    lookupOnlineArtwork: false 
);
```

### Player Controls 

Control playback with these simple methods:

```dart
RadioPlayer.play();
RadioPlayer.pause();
```

### Resetting Player

To completely stop playback, remove the media notification, and reset the player to an idle state, use `reset()`:

```dart
RadioPlayer.reset();
```

### Listening to Playback State

Subscribe to `playbackStateStream` to get updates on the player's state.

```dart
// Possible states for playbackState:
//
// - PlaybackState.playing
// - PlaybackState.paused
// - PlaybackState.buffering
// - PlaybackState.unknown
PlaybackState? playbackState;

RadioPlayer.playbackStateStream.listen((value) {
    setState(() { playbackState = value; });
});
```

### Listening to Metadata

Subscribe to `metadataStream` to receive metadata updates from the stream (artist, title, artwork).

```dart
// The Metadata object can contain the following fields:
//
// - artist (String?): The artist of the current track.
// - title (String?): The title of the current track.
// - artworkUrl (String?): A URL for the track's artwork.
// - artworkData (Uint8List?): Raw image data for the artwork.
Metadata? _metadata;

RadioPlayer.metadataStream.listen((value) {
    setState(() { _metadata = value; });
});
```

### Setting Custom Metadata

You can manually set the metadata that will be displayed in the notification and lock screen.

```dart
RadioPlayer.setCustomMetadata(
    artist: "Custom Artist Name",
    title: "Custom Song Title",
    artworkUrl: "https://example.com/custom_artwork.png" // Optional
);
```

To avoid conflicts when managing displayed track information with `setCustomMetadata`, it's highly recommended to disable automatic ICY metadata parsing. This is achieved by setting `parseStreamMetadata: false` in your initial `RadioPlayer.setStation()` call.

### Navigation Controls

The plugin allows you to display next and previous track buttons on the lock screen and in the media notification. When a user taps these buttons, your app receives a command to handle the action, such as switching to a different radio station.

The process involves two steps:

1.  **Enable the buttons:** Use `setNavigationControls` to make the buttons visible.

    ```dart
    RadioPlayer.setNavigationControls(
        showNextButton: true,
        showPreviousButton: false,
    );
    ```

2.  **Listen for commands:** Enabling the buttons connects them to the `remoteCommandStream`. Your app must subscribe to this stream to react when a user presses a button.

    ```dart
    // Possible values for the command:
    //
    // - RemoteCommand.nextTrack
    // - RemoteCommand.previousTrack
    // - RemoteCommand.unknown
    
    RadioPlayer.remoteCommandStream.listen((command) {
        if (command == RemoteCommand.nextTrack) {
            // Your logic to switch to the next station
        } else if (command == RemoteCommand.previousTrack) {
            // Your logic to switch to the previous station
        }
    });
    ```

### Volume Control

For controlling the device's audio volume, it is currently recommended to use a dedicated plugin.
You can use the [volume_regulator](https://pub.dev/packages/volume_regulator) plugin (also by this author) to manage system volume.

## Requirements 
- iOS: 15.0 or later
- Android: API Level 23 or later

## License
This project is licensed under the [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/).
