#import <CoreGraphics/CoreGraphics.h>
#import <CoreMIDI/CoreMIDI.h>
#import <Foundation/Foundation.h>

@interface MIDIKeyboardEmitter : NSObject
@property(nonatomic, assign) MIDIClientRef client;
@property(nonatomic, assign) MIDIPortRef inputPort;
@end

void MIDIReadProcedure(const MIDIPacketList *packetList, void *readProcRefCon,
                       void *srcConnRefCon) {
  MIDIKeyboardEmitter *emitter = (__bridge MIDIKeyboardEmitter *)readProcRefCon;
  [emitter handleMIDIPacketList:packetList];
}

@implementation MIDIKeyboardEmitter {
  NSArray<NSString *> *_keyMap;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _keyMap = @[
      @"a", @"b", @"c", @"d", @"e", @"f", @"g", @"h", @"i", @"j", @"k", @"l"
    ];
    [self setupMIDI];
  }
  return self;
}

- (void)setupMIDI {
  MIDIClientCreate(CFSTR("MIDIKeyboardEmitter"), NULL, NULL, &_client);
  MIDIInputPortCreate(_client, CFSTR("InputPort"), MIDIReadProcedure,
                      (__bridge void *)self, &_inputPort);

  ItemCount sourceCount = MIDIGetNumberOfSources();
  for (ItemCount i = 0; i < sourceCount; ++i) {
    MIDIEndpointRef source = MIDIGetSource(i);
    MIDIPortConnectSource(_inputPort, source, NULL);
  }
}

- (void)handleMIDIPacketList:(const MIDIPacketList *)packetList {
  const MIDIPacket *packet = &packetList->packet[0];
  for (int i = 0; i < packetList->numPackets; i++) {
    if (packet->length >= 3 && (packet->data[0] & 0xF0) == 0x90 &&
        packet->data[2] > 0) {
      [self sendKeyEventForNote:packet->data[1]];
    }
    packet = MIDIPacketNext(packet);
  }
}

- (void)sendKeyEventForNote:(Byte)note {
  NSString *character = _keyMap[note % 12];
  CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStatePrivate);

  // Send key down
  CGEventRef keyDown = CGEventCreateKeyboardEvent(source, 0, true);
  UniChar charCode = [character characterAtIndex:0];
  CGEventKeyboardSetUnicodeString(keyDown, 1, &charCode);
  CGEventPost(kCGHIDEventTap, keyDown);

  // Send key up
  CGEventRef keyUp = CGEventCreateKeyboardEvent(source, 0, false);
  CGEventKeyboardSetUnicodeString(keyUp, 1, &charCode);
  CGEventPost(kCGHIDEventTap, keyUp);

  CFRelease(keyDown);
  CFRelease(keyUp);
  CFRelease(source);
}

@end

int main(int argc, const char *argv[]) {
  @autoreleasepool {
    MIDIKeyboardEmitter *emitter = [[MIDIKeyboardEmitter alloc] init];
    [[NSRunLoop currentRunLoop] run];
  }
  return 0;
}
