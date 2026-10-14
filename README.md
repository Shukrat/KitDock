# Kit Dock

The shared dock behind **First Aid Kit**, **Camping Kit** and **Fishing Kit** for WoW Forever.

With two or more kits installed, their buttons snap together on a small gold pin, open one at a time, and share one minimap button (the Kits chest). Every kit ships its own copy of `KitDock.lua`; the newest copy loaded wins (see `VERSION` at the top of the file), so a player can install any mix of kits.

A kit can also register as **edges only** (`edgesOnly = true`, like Warlock Kit): it snaps to the screen edges and shows in the shared Kits menu, but never joins the pin and other kits never merge with it.

## How the kits use it

Each kit's `.pkgmeta` pulls this repository into `Libs/KitDock` when a release is built, pinned to a tag:

```yaml
externals:
  Libs/KitDock:
    url: https://github.com/Shukrat/KitDock
    tag: v18
```

and the kit's `.toc` loads `Libs\KitDock\KitDock.lua`.

The kit ships the art Kit Dock uses in its own `media` folder: `pin_dot`, `glow_ring`, `ring_prof_*` and, from v18, the Kits chest `kits_chest_32`, `_48`, `_64`, `_96` and `_128`.

## Releasing a new version

1. Raise `VERSION` in `KitDock.lua`.
2. Tag the commit `v<VERSION>` (e.g. `v18`) and push the tag.
3. In each kit, bump the `tag:` in `.pkgmeta` once you've tested it.

## Local development (Windows)

Clone this repository next to the kits (e.g. `C:\Users\Doug\Claude\KitDock`) and run `link-kits.bat` once. It links each kit's `Libs\KitDock` folder to this one with a directory junction, so every kit uses this copy in game and an edit here shows up in every kit.

## License

MIT, see `LICENSE`.
