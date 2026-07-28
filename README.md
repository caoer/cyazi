# cyazi

ZT's [yazi](https://yazi-rs.github.io) configuration as a Nix flake — config, local plugins, vendored plugins with recorded patches, and two flavors. Dual-compat: one config serves both stable yazi (26.5.6) and nightly.

The repo root **is** the `YAZI_CONFIG_HOME`: point yazi at a checkout and every edit is live.

## Usage

Try it without installing anything:

```sh
nix run github:caoer/cyazi
```

As a flake input, the config directory is `packages.<system>.default`:

```nix
inputs.cyazi.url = "github:caoer/cyazi";

# home-manager
xdg.configFile."yazi".source = inputs.cyazi.packages.${pkgs.system}.default;
```

`packages.<system>.yazi` is yazi/ya wrapped onto this config (`YAZI_CONFIG_HOME` still overridable). Builds substitute from `cache.0xtau.com` (in this flake's `nixConfig`; CI pushes every platform).

Live checkout instead of a store copy:

```sh
YAZI_CONFIG_HOME=/path/to/cyazi yazi
```

## Layout

- `yazi.toml`, `keymap.toml`, `theme.toml`, `init.lua` — the config. `init.lua` is thin: it only calls each plugin's `setup()`.
- `plugins/*.yazi` — local plugins (`layout-cycle`, `count`, `smart-enter`, `archive-walk`, `video-montage`, `audio-preview`, `git-root`) plus vendored upstream plugins managed by `ya pkg` via `package.toml`.
- `plugins/patches/` — recorded diffs on vendored plugins; `plugins/LOCAL-PATCHES.md` explains the workflow (`apply.sh` re-applies after `ya pkg upgrade --discard`).
- `flavors/` — `tokyo-night` (dark) and `coldark-cold` (light); UI chrome uses ANSI role names so it follows the terminal palette in both appearances.

Highlights:

- **layout-cycle** — `<Tab>` cycles responsive → big-preview → list-only; a terminal resize snaps back to responsive.
- **count** — linemode showing each directory's immediate-child count, computed off the render thread by an async fetcher (files show size).
- **archive-walk** — browse disk images and squashfs like directories.
- **duckdb previews** — csv/tsv/parquet/xlsx/sqlite render as tables.

## Personal endpoints (vfs.toml)

`vfs.toml` (SFTP/VFS hosts, users, ports) is personal and stays out of git — it is gitignored, and the Nix package is built from an explicit fileset that excludes it. Drop your own `vfs.toml` into a checkout and yazi reads it live.

## Testing

Everything is checkable headlessly — no interactive terminal needed:

```sh
nix flake check   # lua syntax + TOML parse + end-to-end smoke test
tests/smoke.sh    # same smoke test against the live checkout (needs yazi + tmux)
```

The smoke test boots yazi in a detached tmux on a scratch tree and asserts observable behavior: the file list draws, the `count` linemode renders the right number, `<Tab>` actually cycles layouts, `q` exits 0, and the log is error-free. `nix develop` provides yazi, tmux, and lua.

## License

Local code is [MIT](LICENSE). Vendored plugins and flavors keep their own licenses in their directories.
