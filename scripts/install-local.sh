#!/usr/bin/env bash
# Build a release binary and put the local working tree's `xcrashlytics` on
# PATH. Dev/testing only.
#
#   * If installed via brew, the keg binary is overwritten in place
#     (`brew reinstall xcrashlytics` restores the released version).
#   * Otherwise the build product is symlinked into the Homebrew bin dir, so
#     later `swift build -c release` runs are picked up without rerunning this.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> swift build -c release"
swift build -c release --package-path "$REPO_ROOT"

BIN="$(swift build -c release --package-path "$REPO_ROOT" --show-bin-path)/xcrashlytics"
[[ -x "$BIN" ]] || { echo "error: build produced no binary at $BIN" >&2; exit 1; }

if brew list xcrashlytics &>/dev/null; then
  TARGET="$(brew --prefix xcrashlytics)/bin/xcrashlytics"
  echo "==> overwriting brew binary $(readlink -f "$TARGET")"
  cp "$BIN" "$TARGET"
else
  TARGET="$(brew --prefix)/bin/xcrashlytics"
  echo "==> symlinking $TARGET -> $BIN"
  ln -sf "$BIN" "$TARGET"
fi

echo "==> done: $(command -v xcrashlytics) -> $(xcrashlytics --version) ($(git -C "$REPO_ROOT" rev-parse --short HEAD))"
