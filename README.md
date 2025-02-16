![](https://github.com/user-attachments/assets/b18d4f89-188b-423b-aad6-c4237dd5348d)

Recently I've been obsessing with the oNLine System (NLS)'s Keyset and I wished
I could have one. Thinking about this, I thought: "What if it was with a real
Piano?". And so I had to build it! This is for Mac and you can have fun with it
too.

![Screen recording of the Keyset software running, a hand over a MIDI controller pushing chords and the text "Hello" appear on the screen.](https://github.com/user-attachments/assets/be378891-0e0a-4412-8a89-32de63a3105f)

## How To Run This?

You should have a Mac with developer tools installed. Then you can do
`% make run` in the cloned directory of this repo and work with it. If you are
running this for the first time, the system will ask for some Accessibility
accesses (to act as a keyboard)

## Mapping

This table works on all octaves. The order of the keys are reverse of the
original. That is basically an error on my part that has remained. The system
has a sixth key (`A`) that maps to the backspace. This is something the original
version lacked, and I didn't wish to have it on the five notes, because it was
very error prone.

| C  | D  | E  | F  | G  | A  | Printed Character |
| :- | :- | :- | :- | :- | :- | :---------------: |
| x  | -  | -  | -  | -  | -  |        `A`        |
| -  | x  | -  | -  | -  | -  |        `B`        |
| x  | x  | -  | -  | -  | -  |        `C`        |
| -  | -  | x  | -  | -  | -  |        `D`        |
| x  | -  | x  | -  | -  | -  |        `E`        |
| -  | x  | x  | -  | -  | -  |        `F`        |
| x  | x  | x  | -  | -  | -  |        `G`        |
| -  | -  | -  | x  | -  | -  |        `H`        |
| x  | -  | -  | x  | -  | -  |        `I`        |
| -  | x  | -  | x  | -  | -  |        `J`        |
| x  | x  | -  | x  | -  | -  |        `K`        |
| -  | -  | x  | x  | -  | -  |        `L`        |
| x  | -  | x  | x  | -  | -  |        `M`        |
| -  | x  | x  | x  | -  | -  |        `N`        |
| x  | x  | x  | x  | -  | -  |        `O`        |
| -  | -  | -  | -  | x  | -  |        `P`        |
| x  | -  | -  | -  | x  | -  |        `Q`        |
| -  | x  | -  | -  | x  | -  |        `R`        |
| x  | x  | -  | -  | x  | -  |        `S`        |
| -  | -  | x  | -  | x  | -  |        `T`        |
| x  | -  | x  | -  | x  | -  |        `U`        |
| -  | x  | x  | -  | x  | -  |        `V`        |
| x  | x  | x  | -  | x  | -  |        `W`        |
| -  | -  | -  | x  | x  | -  |        `X`        |
| x  | -  | -  | x  | x  | -  |        `Y`        |
| -  | x  | -  | x  | x  | -  |        `Z`        |
| x  | x  | -  | x  | x  | -  |        `.`        |
| -  | -  | x  | x  | x  | -  |        `?`        |
| x  | -  | x  | x  | x  | -  |        `!`        |
| -  | x  | x  | x  | x  | -  |        `:`        |
| x  | x  | x  | x  | x  | -  |       Space       |
| -  | -  | -  | -  | -  | x  |    Back Space     |
