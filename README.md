# Belt Tracer mod for [factorio](https://www.factorio.com/)

This is a simple mod for factorio to trace a belt through your base. Just hover over a belt and press the hotkey (default: `SHIFT-H` for "highlight"). Press it again somewhere else to clear the trace.

It also traces pipes and wires: hover over anything connected to pipes or wires and press the hotkey.

Only the belts whose items might pass through the belt you selected, or might have passed through it, will be traced. For example, it won't trace a branch upstream that went in a different direction.

## Screenshots

![4-to-4_1](/Screenshots/4-to-4_1.jpg)
![4-to-4_2](/Screenshots/4-to-4_2.jpg)
![Pipes](/Screenshots/Pipes.jpg)
![8-to-8_1](/Screenshots/8-to-8_1.jpg)
![8-to-8_2](/Screenshots/8-to-8_2.jpg)
![Modded](/Screenshots/Modded.jpg)

TODO: Update screenshots for wires and thicker traces.

## Known/suspected issues

* Traces aren't removed if you remove the belts under them.
* I've not attempted to make this scalable, it currently traces the whole belt in the handler. It traces O(1000) length belts without a hiccup but I haven't tried it on a megabase.
* Wires are only shown on the correct sides of the two vanilla combinators. They'll be shown in the center of any other entity that has multiple wire connection points.

New for 2.0:

* Traces might clear ghosts and/or prevent ghosts from being placed.

## Potential improvements

* Clear the current line when hovered over it.
* Allow multiple highlights.
* A continuous mode or tool that traces whatever it's hovered over.
* Trace both sides of the belt separately.
* Figure out how to show the trace on the map.
* Update lines as belts are placed/removed.
* Trace ghosts.
* Better colors.
* Better lines (e.g. should they be at the edges of the belts instead of the center? Curved to follow the belt curves? Shaped to match splitters?)
* Maybe color-code by how full the belt is?

Bug reports, suggestions or pull requests welcome in [discussions](https://github.com/paybara/factorio-belt-tracer/discussions) :-)

## Edge cases

* I think I've covered multiplayer correctly, but haven't tested it.
