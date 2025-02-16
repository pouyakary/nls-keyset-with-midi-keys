#import <CoreGraphics/CoreGraphics.h>
#import <CoreMIDI/CoreMIDI.h>
#import <Foundation/Foundation.h>

// ─── Declarations ──────────────────────────────────────────────────────── ✣ ─

void MIDIReadProcedure(const MIDIPacketList *packetList, void *readProcRefCon,
                       void *srcConnRefCon);

@interface MIDIKeyboardEmitter : NSObject

@property(nonatomic, assign) MIDIClientRef client;
@property(nonatomic, assign) MIDIPortRef inputPort;
@property(nonatomic, strong) NSMutableSet<NSNumber *> *activeNotes;
@property(nonatomic, strong) NSMutableSet<NSNumber *> *chordNotes;
@property(nonatomic, readonly) NSDictionary<NSNumber *, NSString *> *keyMap;

- (void)setupMIDI;
- (void)handleMIDIPacketList:(const MIDIPacketList *)packetList;

@end

// ─── Midi Keyboard Emitter ─────────────────────────────────────────────── ✣ ─

@implementation MIDIKeyboardEmitter {
  NSDictionary<NSNumber *, NSString *> *_keyMap;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _keyMap = @{
      @0b00001 : @"a",
      @0b00010 : @"b",
      @0b00011 : @"c",
      @0b00100 : @"d",
      @0b00101 : @"e",
      @0b00110 : @"f",
      @0b00111 : @"g",
      @0b01000 : @"h",
      @0b01001 : @"i",
      @0b01010 : @"j",
      @0b01011 : @"k",
      @0b01100 : @"l",
      @0b01101 : @"m",
      @0b01110 : @"n",
      @0b01111 : @"o",
      @0b10000 : @"p",
      @0b10001 : @"q",
      @0b10010 : @"r",
      @0b10011 : @"s",
      @0b10100 : @"t",
      @0b10101 : @"u",
      @0b10110 : @"v",
      @0b10111 : @"w",
      @0b11000 : @"x",
      @0b11001 : @"y",
      @0b11010 : @"z",
      @0b11011 : @",",
      @0b11100 : @".",
      @0b11101 : @":",
      @0b11110 : @"?",
      @0b11111 : @" "
    };

    _activeNotes = [NSMutableSet set];
    _chordNotes = [NSMutableSet set];
    [self setupMIDI];
  }
  return self;
}

// ─── Setup Midi ────────────────────────────────────────────────────────── ✣ ─

- (void)setupMIDI {
  OSStatus status =
      MIDIClientCreate(CFSTR("MIDIKeyboardEmitter"), NULL, NULL, &_client);

  if (status != noErr) {
    NSLog(@"Failure In Creating MIDI Client: %d", (int)status);
    return;
  }

  status = MIDIInputPortCreate(_client, CFSTR("InputPort"), MIDIReadProcedure,
                               (__bridge void *)self, &_inputPort);
  if (status != noErr) {
    NSLog(@"Failure In Creating Input Port: %d", (int)status);
    return;
  }

  ItemCount sourceCount = MIDIGetNumberOfSources();
  for (ItemCount i = 0; i < sourceCount; i++) {
    MIDIEndpointRef source = MIDIGetSource(i);
    MIDIPortConnectSource(_inputPort, source, NULL);
  }
}

// ─── Create Bit Mask ───────────────────────────────────────────────────── ✣ ─

- (Byte)bitMaskForNotes:(NSSet<NSNumber *> *)notes {
  Byte bitMask = 0;
  for (NSNumber *noteNumber in notes) {
    Byte note = noteNumber.unsignedCharValue;
    switch (note % 12) {
    case 0:
      bitMask |= 0b00001;
      break; // C
    case 2:
      bitMask |= 0b00010;
      break; // D
    case 4:
      bitMask |= 0b00100;
      break; // E
    case 5:
      bitMask |= 0b01000;
      break; // F
    case 7:
      bitMask |= 0b10000;
      break; // G
    }
  }
  return bitMask;
}

// ─── Handle Midi Packet List ───────────────────────────────────────────── ✣ ─

- (void)handleMIDIPacketList:(const MIDIPacketList *)packetList {
  @synchronized(self) {
    NSMutableSet *tempNotes = [self.activeNotes mutableCopy];
    const MIDIPacket *packet = &packetList->packet[0];

    for (int i = 0; i < packetList->numPackets; i++) {
      Byte status = packet->data[0];
      Byte note = packet->data[1];
      Byte velocity = packet->data[2];

      if ((status & 0xF0) == 0x90 && velocity > 0) { // Note On
        [tempNotes addObject:@(note)];
        [self.chordNotes addObject:@(note)];
      } else { // Note Off
        [tempNotes removeObject:@(note)];
      }
      packet = MIDIPacketNext(packet);
    }

    self.activeNotes = tempNotes;

    if (tempNotes.count == 0 && self.chordNotes.count > 0) {
      Byte bitMask = [self bitMaskForNotes:self.chordNotes];
      NSString *character = _keyMap[@(bitMask)];
      if (character)
        [self sendKeyEventForString:character];
      [self.chordNotes removeAllObjects];
    }
  }
}

// ─── Send Key Event For String ─────────────────────────────────────────── ✣ ─

- (void)sendKeyEventForString:(NSString *)string {
  if (string.length != 1)
    return;

  CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStatePrivate);
  UniChar charValue = [string characterAtIndex:0];

  CGEventRef keyDown = CGEventCreateKeyboardEvent(source, 0, true);
  CGEventKeyboardSetUnicodeString(keyDown, 1, &charValue);
  CGEventPost(kCGHIDEventTap, keyDown);
  CFRelease(keyDown);

  CGEventRef keyUp = CGEventCreateKeyboardEvent(source, 0, false);
  CGEventKeyboardSetUnicodeString(keyUp, 1, &charValue);
  CGEventPost(kCGHIDEventTap, keyUp);
  CFRelease(keyUp);

  CFRelease(source);
}

@end

// ─── Midi Read Procedure ───────────────────────────────────────────────── ✣ ─

void MIDIReadProcedure(const MIDIPacketList *packetList, void *readProcRefCon,
                       void *srcConnRefCon) {
  MIDIKeyboardEmitter *emitter = (__bridge MIDIKeyboardEmitter *)readProcRefCon;
  [emitter handleMIDIPacketList:packetList];
}

// ─── Main ──────────────────────────────────────────────────────────────── ✣ ─

int main(int argc, const char *argv[]) {
  NSLog(@"Keyset Service Up & Running.");
  @autoreleasepool {
    MIDIKeyboardEmitter *emitter = [[MIDIKeyboardEmitter alloc] init];
    [[NSRunLoop currentRunLoop] run];
  }
  return 0;
}
