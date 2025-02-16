#import <CoreAudio/CoreAudio.h>
#import <CoreMIDI/CoreMIDI.h>
#import <Foundation/Foundation.h>

@interface MIDIKeyboardEmitter : NSObject
@property(nonatomic, assign) MIDIClientRef client;
@property(nonatomic, assign) MIDIPortRef inputPort;

- (void)handleMIDIPacketList:(const MIDIPacketList *)packetList;
@end

void MIDIReadProcedure(const MIDIPacketList *packetList, void *readProcRefCon,
                       void *srcConnRefCon) {
  MIDIKeyboardEmitter *emitter = (__bridge MIDIKeyboardEmitter *)readProcRefCon;
  [emitter handleMIDIPacketList:packetList];
}

@implementation MIDIKeyboardEmitter

- (instancetype)init {
  self = [super init];
  if (self) {
    [self setupMIDI];
  }
  return self;
}

- (void)setupMIDI {
  OSStatus status =
      MIDIClientCreate(CFSTR("MIDIKeyboardEmitter"), NULL, NULL, &_client);
  if (status != noErr) {
    NSLog(@"Error creating MIDI client: %d", (int)status);
    return;
  }

  status = MIDIInputPortCreate(_client, CFSTR("Input port"), MIDIReadProcedure,
                               (__bridge void *)(self), &_inputPort);
  if (status != noErr) {
    NSLog(@"Error creating MIDI input port: %d", (int)status);
    return;
  }

  ItemCount sourceCount = MIDIGetNumberOfSources();
  for (ItemCount i = 0; i < sourceCount; ++i) {
    MIDIEndpointRef source = MIDIGetSource(i);
    status = MIDIPortConnectSource(_inputPort, source, NULL);
    if (status != noErr) {
      NSLog(@"Error connecting MIDI source: %d", (int)status);
    }
  }
}

- (void)handleMIDIPacketList:(const MIDIPacketList *)packetList {
  const MIDIPacket *packet = &packetList->packet[0];
  for (int i = 0; i < packetList->numPackets; i++) {
    if (packet->length >= 3) {
      Byte status = packet->data[0];
      Byte note = packet->data[1];

      if ((status & 0xF0) == 0x90) { // Note On event
        [self emitCharacterForNote:note];
      }
    }
    packet = MIDIPacketNext(packet);
  }
}

- (void)emitCharacterForNote:(Byte)note {
  NSString *noteName = [self noteNameForMIDINote:note];
  if (noteName.length > 0) {
    printf("%s", [noteName UTF8String]);
    fflush(stdout);
  }
}

- (NSString *)noteNameForMIDINote:(Byte)note {
  NSArray *noteNames = @[
    @"C", @"C#", @"D", @"D#", @"E", @"F", @"F#", @"G", @"G#", @"A", @"A#", @"B"
  ];
  return noteNames[note % 12];
}

@end

int main(int argc, const char *argv[]) {
  @autoreleasepool {
    MIDIKeyboardEmitter *emitter = [[MIDIKeyboardEmitter alloc] init];
    NSLog(@"MIDI Keyboard Emitter is running. Press Ctrl+C to exit.");
    [[NSRunLoop currentRunLoop] run];
  }
  return 0;
}
