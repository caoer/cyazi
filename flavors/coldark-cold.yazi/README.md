# coldark-cold.yazi

Light-appearance flavor for this config. Not an upstream yazi flavor — assembled
here, because none was needed until `theme.toml` started following the macOS
appearance and the code preview became the one thing that could not.

| File | Origin |
|------|--------|
| `tmtheme.xml` | [ArmandPhilippot/coldark-bat](https://github.com/ArmandPhilippot/coldark-bat) `Coldark-Cold.tmTheme`, vendored **unmodified**. MIT — `LICENSE-tmtheme`. |
| `flavor.toml` | Written here, deliberately near-empty. See its header. |

## Why a flavor and not `syntect_theme`

`[mgr] syntect_theme` is documented as *"not available after using a flavor,
as flavors always use their own tmTheme files"*, and it accepts **absolute paths
only** — verified: neither `tmthemes/x.tmTheme` nor
`~/.config/yazi/tmthemes/x.tmTheme` resolves. An absolute path cannot serve both
a live checkout and a store-copied deployment of this config.
Flavors are referenced by name and resolved relative to the
config dir, so they are portable by construction.

## Why Coldark-Cold

Its background (`#e3eaf2`) is within a hair of Tokyo Night Day's terminal
background (`#e1e2e7`), and `bat` ships the same theme — when bat is
wired as a previewer with `--theme-light` pointed at it, yazi's syntect path
and the bat path agree in light mode instead of drifting.

## Not the family axis

A terminal setup may offer many theme families and swap them together across
apps. This pair is variant-correct (light preview on a light
background — the actual legibility bug) but **not** family-following: previews
stay Enki-Tokyo-Night / Coldark-Cold even when the terminal is gruvbox. Making
previews follow the family would need one flavor pair per family. The UI chrome does follow
both axes, because `theme.toml` names ANSI roles rather than hexes.
