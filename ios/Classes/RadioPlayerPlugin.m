#import "RadioPlayerPlugin.h"
#if __has_include(<radio_player/radio_player-Swift.h>)
#import <radio_player/radio_player-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "radio_player-Swift.h"
#endif

@implementation RadioPlayerPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftRadioPlayerPlugin registerWithRegistrar:registrar];
}
@end
