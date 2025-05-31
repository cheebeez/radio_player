# Radio Player

A Flutter plugin to play streaming audio content with background support and lock screen controls.

[![flutter platform](https://img.shields.io/badge/Platform-Flutter-yellow.svg)](https://flutter.dev)
[![pub package](https://img.shields.io/pub/v/radio_player.svg)](https://pub.dev/packages/radio_player)

## Installation

To use this package, add `radio_player` as a dependency in your `pubspec.yaml` file.

```yaml
dependencies:
  radio_player: ^2.0.0
```

By default iOS forbids loading from non-https url. To cancel this restriction edit your .plist and add:

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

To create `RadioPlayer` instance, simply call the constructor.

```dart
RadioPlayer radioPlayer = RadioPlayer();
```

Configure it with your data.

```dart
radioPlayer.setChannel(title: TITLE, url: URL, imagePath: IMAGEPATH?);
```

### Player Controls 

```dart
radioPlayer.play();
radioPlayer.pause();
```

### State Event

You can use it to show if player playing or paused.

```dart
bool isPlaying = false;
//...
radioPlayer.stateStream.listen((value) {
    setState(() { isPlaying = value; });
});
```

### Metadata Event

This Event returns the current metadata.

```dart
List<String>? metadata;
//...
radioPlayer.metadataStream.listen((value) {
    setState(() { metadata = value; });
});
```

Image from metadata can be retrieved using `getArtworkImage()`

## Requirements 
- iOS: 15.0 or later
- Android: API Level 23 or later

## Reporting Issues

Before submitting an issue, please:

1.  **Check the example application:** Verify if the problem you're experiencing also occurs in the `example` app provided with this plugin. This helps determine if the issue is with the plugin itself or your specific implementation.
2.  **Provide a minimal reproducible example:** If the issue persists or is not reproducible in the example, please include a small, self-contained code snippet that demonstrates the problem. 

This information will greatly help in diagnosing and resolving your issue efficiently.

## License
This project is licensed under the [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/).
