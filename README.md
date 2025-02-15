# Radio Player

A Flutter plugin to play streaming audio content with background support and lock screen controls.

[![flutter platform](https://img.shields.io/badge/Platform-Flutter-yellow.svg)](https://flutter.dev)
[![pub package](https://img.shields.io/pub/v/radio_player.svg)](https://pub.dev/packages/radio_player)

## Installation

To use this package, add `radio_player` as a dependency in your `pubspec.yaml` file.

```yaml
dependencies:
  radio_player: ^1.7.1
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
- iOS: SDK 10.0 or later
- Android: API Level 23 or later

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.
Please make sure to update tests as appropriate.
