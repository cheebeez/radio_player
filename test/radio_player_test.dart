import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
//import 'package:radio_player/radio_player.dart';

void main() {
  const MethodChannel channel = MethodChannel('radio_player');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('getPlatformVersion', () async {
    //expect(await RadioPlayer.platformVersion, '42');
  });
}
