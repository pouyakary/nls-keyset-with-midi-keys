#import <CoreGraphics/CoreGraphics.h>
#import <CoreMIDI/CoreMIDI.h>
#import <Foundation/Foundation.h>

@interface MIDIKeyboardEmitter : NSObject

@property(nonatomic, assign) MIDIClientRef client;
@property(nonatomic, assign) MIDIPortRef inputPort;
@property(nonatomic, strong) NSMutableSet *activeNotes;
@property(nonatomic, strong) NSMutableSet *chordNotes; // new property

- (void)handleMIDIPacketList:(const MIDIPacketList *)packetList;
- (Byte)bitmaskForNotes:(NSSet *)notes; // new method

@end

void MIDIReadProcedure(const MIDIPacketList *packetList, void *readProcRefCon,
                       void *srcConnRefCon) {
  MIDIKeyboardEmitter *emitter = (__bridge MIDIKeyboardEmitter *)readProcRefCon;
  [emitter handleMIDIPacketList:packetList];
}

@implementation MIDIKeyboardEmitter {
  NSDictionary *_keyMap;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    // _keyMap maps the bitmask (from 1 to 31) to corresponding characters.
    _keyMap = @{
      @(0b00001) : @"a",
      @(0b00010) : @"b",
      @(0b00011) : @"c",
      @(0b00100) : @"d",
      @(0b00101) : @"e",
      @(0b00110) : @"f",
      @(0b00111) : @"g",
      @(0b01000) : @"h",
      @(0b01001) : @"i",
      @(0b01010) : @"j",
      @(0b01011) : @"k",
      @(0b01100) : @"l",
      @(0b01101) : @"m",
      @(0b01110) : @"n",
      @(0b01111) : @"o",
      @(0b10000) : @"p",
      @(0b10001) : @"q",
      @(0b10010) : @"r",
      @(0b10011) : @"s",
      @(0b10100) : @"t",
      @(0b10101) : @"u",
      @(0b10110) : @"v",
      @(0b10111) : @"w",
      @(0b11000) : @"x",
      @(0b11001) : @"y",
      @(0b11010) : @"z",
      @(0b11011) : @",",
      @(0b11100) : @".",
      @(0b11101) : @":",
      @(0b11110) : @"?",
      @(0b11111) : @" "
    };

    self.activeNotes = [NSMutableSet set];
    self.chordNotes = [NSMutableSet set]; // initialize new property
    [self setupMIDI];
  }
  return self;
}

- (void)setupMIDI {
  MIDIClientCreate(CFSTR("MIDIKeyboardEmitter"), NULL, NULL, &_client);
  MIDIInputPortCreate(_client, CFSTR("InputPort"), MIDIReadProcedure,
                      (__bridge void *)self, &_inputPort);
  ItemCount sourceCount = MIDIGetNumberOfSources();
  for (ItemCount i = 0; i < sourceCount; i++) {
    MIDIEndpointRef source = MIDIGetSource(i);
    MIDIPortConnectSource(_inputPort, source, NULL);
  }
}

// This method computes a bitmask based on the activity of notes across all
// octaves. It assigns bits for the pitch classes: C (mod 12 == 0), D (== 2), E
// (== 4), F (== 5), and G (== 7).
- (Byte)activeNotesBitmask {
  Byte bitmask = 0;
  for (NSNumber *noteNumber in self.activeNotes) {
    Byte note = [noteNumber unsignedCharValue];
    Byte pitchClass = note % 12;
    if (pitchClass == 0) { // C
      bitmask |= 0b00001;
    } else if (pitchClass == 2) { // D
      bitmask |= 0b00010;
    } else if (pitchClass == 4) { // E
      bitmask |= 0b00100;
    } else if (pitchClass == 5) { // F
      bitmask |= 0b01000;
    } else if (pitchClass == 7) { // G
      bitmask |= 0b10000;
    }
  }
  return bitmask;
}

- (Byte)bitmaskForNotes:(NSSet *)notes {
  Byte bitmask = 0;
  for (NSNumber *noteNumber in notes) {
    Byte note = [noteNumber unsignedCharValue];
    Byte pitchClass = note % 12;
    if (pitchClass == 0) { // C
      bitmask |= 0b00001;
    } else if (pitchClass == 2) { // D
      bitmask |= 0b00010;
    } else if (pitchClass == 4) { // E
      bitmask |= 0b00100;
    } else if (pitchClass == 5) { // F
      bitmask |= 0b01000;
    } else if (pitchClass == 7) { // G
      bitmask |= 0b10000;
    }
  }
  return bitmask;
}

- (void)handleMIDIPacketList:(const MIDIPacketList *)packetList {
  // Use a temporary set to aggregate note events from the entire packet list.
  NSMutableSet *tempNotes = [self.activeNotes mutableCopy];
  const MIDIPacket *packet = &packetList->packet[0];

  for (int i = 0; i < packetList->numPackets; i++) {
    Byte status = packet->data[0];
    Byte note = packet->data[1];
    Byte velocity = packet->data[2];

    if ((status & 0xF0) == 0x90) { // Note On
      if (velocity > 0) {
        [tempNotes addObject:@(note)];
        [self.chordNotes addObject:@(note)]; // accumulate chord note
      } else { // Note On with zero velocity as Note Off.
        [tempNotes removeObject:@(note)];
      }
    } else if ((status & 0xF0) == 0x80) { // Note Off
      [tempNotes removeObject:@(note)];
    }

    packet = MIDIPacketNext(packet);
  }

  self.activeNotes = tempNotes;

  // When all keys are released, output the chord if one was formed.
  if (tempNotes.count == 0 && self.chordNotes.count > 0) {
    Byte bitmask = [self bitmaskForNotes:self.chordNotes];
    NSString *character = _keyMap[@(bitmask)];
    if (character) {
      [self sendKeyEventForString:character];
    }
    [self.chordNotes removeAllObjects]; // reset for next chord
  }
}

- (void)sendKeyEventForString:(NSString *)string {
  CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStatePrivate);
  for (NSUInteger i = 0; i < string.length; i++) {
    unichar character = [string characterAtIndex:i];
    // Generate and post key down event.
    CGEventRef keyDown = CGEventCreateKeyboardEvent(source, 0, true);
    CGEventKeyboardSetUnicodeString(keyDown, 1, &character);
    CGEventPost(kCGHIDEventTap, keyDown);
    CFRelease(keyDown);
    // Generate and post key up event.
    CGEventRef keyUp = CGEventCreateKeyboardEvent(source, 0, false);
    CGEventKeyboardSetUnicodeString(keyUp, 1, &character);
    CGEventPost(kCGHIDEventTap, keyUp);
    CFRelease(keyUp);
  }
  CFRelease(source);
}

@end

int main(int argc, const char *argv[]) {
  @autoreleasepool {
    MIDIKeyboardEmitter *emitter = [[MIDIKeyboardEmitter alloc] init];
    [[NSRunLoop currentRunLoop] run];
    return 0;
  }
}
