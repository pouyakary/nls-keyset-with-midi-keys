
// Copyright © 2025 by Pouya Kary <kary@gnu.org>

//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

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
      @0b000001 : @"a",
      @0b000010 : @"b",
      @0b000011 : @"c",
      @0b000100 : @"d",
      @0b000101 : @"e",
      @0b000110 : @"f",
      @0b000111 : @"g",
      @0b001000 : @"h",
      @0b001001 : @"i",
      @0b001010 : @"j",
      @0b001011 : @"k",
      @0b001100 : @"l",
      @0b001101 : @"m",
      @0b001110 : @"n",
      @0b001111 : @"o",
      @0b010000 : @"p",
      @0b010001 : @"q",
      @0b010010 : @"r",
      @0b010011 : @"s",
      @0b010100 : @"t",
      @0b010101 : @"u",
      @0b010110 : @"v",
      @0b010111 : @"w",
      @0b011000 : @"x",
      @0b011001 : @"y",
      @0b011010 : @"z",
      @0b011011 : @".",
      @0b011100 : @"?",
      @0b011101 : @"!",
      @0b011110 : @":",
      @0b011111 : @" ",
      @0b100000 : @"\b",
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
      bitMask |= 0b000001;
      break; // C
    case 2:
      bitMask |= 0b000010;
      break; // D
    case 4:
      bitMask |= 0b000100;
      break; // E
    case 5:
      bitMask |= 0b001000;
      break; // F
    case 7:
      bitMask |= 0b010000;
      break; // G
    case 9:
      bitMask |= 0b100000;
      break; // A
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
