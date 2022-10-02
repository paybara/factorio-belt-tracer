# Belt Tracer mod for [factorio](https://www.factorio.com/)

This is a simple mod for factorio to trace a belt through your base. Just hover over a belt (or pipe!) and press the hotkey (default: `SHIFT-H` for "highlight"). Press it again somewhere else to clear the trace.

Only the belts whose items might pass through the belt you selected, or might have passed through it, will be traced. For example, it won't trace a branch upstream that went in a different direction.

## Screenshots

![4-to-4_1](/Screenshots/4-to-4_1.jpg)
![4-to-4_2](/Screenshots/4-to-4_2.jpg)
![Pipes](/Screenshots/Pipes.jpg)
![8-to-8_1](/Screenshots/8-to-8_1.jpg)
![8-to-8_2](/Screenshots/8-to-8_2.jpg)
![Modded](/Screenshots/Modded.jpg)

## TODO before launch

* Upload to mod portal

## Known/suspected issues
* Traces aren't removed if you remove the belts under them.
* I've not attempted to make this scalable, it currently traces the whole belt in the handler. It traces O(1000) length belts without a hiccup but I haven't tried it on a megabase.
* When tracing pipes to boilers, both water and steam will be traced.
* Other fluid-carrying entities (e.g. from mods) are unlikely to work.

## Potential improvements
* Clear the current line when hovered over it.
* Allow multiple highlights.
* Trace both sides of the belt separately.
* Figure out how to show the trace on the map.
* Update lines as belts are placed/removed.
* Trace ghosts.
* Better colors.
* Better lines (e.g. should they be at the edges of the belts instead of the center? Curved to follow the belt curves? Shaped to match splitters?)
* Maybe color-code by how full the belt is?
* GUI, e.g. an extra panel when you click on a belt, with a button to trace it and maybe some other info. (Like it should be able to list the current belt contents, if that'd be useful.)

Bug reports, suggestions or pull requests welcome in [discussions](https://github.com/paybara/factorio-belt-tracer/discussions) :-)

## Edge cases
* I think I've covered multiplayer correctly, but haven't tested it.
