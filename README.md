# Belt Tracer mod for [factorio](https://www.factorio.com/)

This is a simple mod for factorio to trace a belt through your spaghetti. Just hover over a belt (or pipe!) and press the hotkey (default: `SHIFT-H`). Press it somewhere else to clear the trace.

Only the belts *relevant to the selected belt* are traced. Meaning only belts whose items might pass through the belt you selected, or might have passed through it, will be traced. For example, it won't trace a branch upstream that went in a different direction.

## TODO before launch

* Add screenshots
* Make public
* Upload to mod portal

## Known/suspected issues
* I suspect if you highlight a belt, save, disable the mod and then load ...then the highlight will be permanently affixed to the map (until the belts are destroyed).
* I've not attempted to make this scalable, it currently traces the whole belt in the handler. It traces O(1000) length belts without a hiccup but I haven't tried it on a megabase.
* When tracing pipes to boilers, both water and steam will be traced.
* Other fluid-carrying entities (e.g. from mods) are unlikely to work.

## Potential improvements
* Allow multiple highlights.
* Trace both sides of the belt separately.
* Figure out how to show the trace on the map.
* Better colors.
* GUI, e.g. an extra panel when you click on a belt, with a button to trace it and maybe some other info. (Like it should be able to list the current belt content, if that'd be useful.)

Bug reports, suggestions or pull requests welcome :-)

## Edge cases
* I think I've covered multiplayer correctly, but haven't tested it.
* I think I've covered surfaces other than "nauvis" (other mods), but haven't tested it.
