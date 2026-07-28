#!/usr/bin/env bash
# Headless end-to-end smoke test for the cyazi config.
#
# Boots yazi inside a detached tmux session on a scratch directory, then
# asserts observable behavior — not just a clean exit:
#   1. the file list draws (config + init.lua + every plugin setup loaded)
#   2. the `count` linemode renders the async child count for a directory
#   3. <Tab> triggers the layout-cycle plugin (notify shows the next mode)
#   4. `q` quits with exit 0
#   5. the yazi log contains no ERROR lines
#
# Requires on PATH: yazi, tmux. Config under test: $YAZI_CONFIG_HOME
# (defaults to the repo root, so `tests/smoke.sh` tests the live checkout).
# Every path it writes lives under $SMOKE_TMP (default: fresh mktemp dir).
set -euo pipefail

here=$(cd "$(dirname "$0")/.." && pwd)
export YAZI_CONFIG_HOME="${YAZI_CONFIG_HOME:-$here}"
work="${SMOKE_TMP:-$(mktemp -d "${TMPDIR:-/tmp}/cyazi-smoke.XXXXXX")}"
mkdir -p "$work"

export HOME="$work/home"
export XDG_STATE_HOME="$work/state"
export XDG_CACHE_HOME="$work/cache"
export XDG_CONFIG_HOME="$work/cfg"
mkdir -p "$HOME" "$XDG_STATE_HOME" "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME"
export YAZI_LOG=info
export TERM=xterm-256color
unset EDITOR VISUAL

# Scratch tree the instance browses: a subdir with exactly 3 children (the
# count linemode must render "3" on its row) and one plain file.
box="$work/box"
mkdir -p "$box/subdir"
touch "$box/subdir/a" "$box/subdir/b" "$box/subdir/c"
echo hello >"$box/note.txt"

tm() { tmux -S "$work/tmux.sock" -f /dev/null "$@"; }
pane() { tm capture-pane -pt smoke >"$work/pane" 2>/dev/null || true; }

fail() {
  echo "FAIL: $1" >&2
  echo "--- pane ---" >&2
  cat "$work/pane" >&2 || true
  echo "--- log ---" >&2
  cat "$(log_file)" >&2 || true
  tm kill-server 2>/dev/null || true
  exit 1
}

log_file() {
  find "$work" -name 'yazi.log' 2>/dev/null | head -1
}

# Poll until $1 greps true in the captured pane, up to ~10s.
wait_pane() {
  for _ in $(seq 1 50); do
    pane
    if grep -qE "$1" "$work/pane"; then return 0; fi
    sleep 0.2
  done
  return 1
}

tm new-session -d -s smoke -x 120 -y 40 -c "$box" \
  "yazi '$box'; echo exit=\$? >'$work/exit'"

# 1. UI draws with our scratch entries
wait_pane 'subdir' || fail "yazi never drew the file list"
grep -q 'note.txt' "$work/pane" || fail "file list is missing note.txt"

# 2. count linemode: subdir's row shows its immediate-child count (3)
found=""
for _ in $(seq 1 50); do
  pane
  if grep 'subdir' "$work/pane" | grep -qE '\b3\b'; then
    found=yes
    break
  fi
  sleep 0.2
done
[ -n "$found" ] || fail "count linemode never rendered 3 for subdir/"

# 3. layout-cycle: <Tab> cycles responsive -> preview (notify names the mode)
tm send-keys -t smoke Tab
wait_pane '\bpreview\b' || fail "layout-cycle did not react to <Tab>"
# ...and back around to responsive (preview -> list -> responsive)
tm send-keys -t smoke Tab
tm send-keys -t smoke Tab
wait_pane '\bresponsive\b' || fail "layout-cycle did not cycle back to responsive"

# 4. clean quit
tm send-keys -t smoke q
for _ in $(seq 1 50); do
  [ -f "$work/exit" ] && break
  sleep 0.2
done
[ -f "$work/exit" ] || fail "yazi did not exit after q"
grep -qx 'exit=0' "$work/exit" || fail "yazi exited non-zero: $(cat "$work/exit")"

# 5. no errors logged. Terminal capability probes (DA1/DSR) time out under
# headless tmux and log as ERROR from yazi_emulator — environment noise, not
# config defects, so that module is excluded from the scan.
log=$(log_file)
if [ -n "$log" ] && grep -w ERROR "$log" | grep -v 'yazi_emulator'; then
  fail "yazi.log contains ERROR lines"
fi

tm kill-server 2>/dev/null || true
echo "smoke: OK (config=$YAZI_CONFIG_HOME)"
