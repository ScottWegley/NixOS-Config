#!/usr/bin/env bash
#
# update.sh — Update flake inputs, rebuild the system, and diff package closures.
#
# Workflow:
#   1. Capture store paths of the current system closure (/run/current-system)
#   2. nix flake update          (moves flake.lock to latest input revisions)
#   3. nixos-rebuild switch      (build + activate the new system)
#   4. Capture store paths of the new system closure
#   5. Diff before/after and print a summary
#
# Usage: sudo ./update.sh
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "This script needs root for 'nixos-rebuild switch'." >&2
  echo "Run it as: sudo $0" >&2
  exit 1
fi

FLAKE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSTEM_PROFILE="/run/current-system"
STAMP="$(date +%Y%m%d-%H%M%S)"
WORKDIR="$(mktemp -d /tmp/nix-update.XXXXXX)"
trap 'rm -rf "$WORKDIR"' EXIT

BEFORE="$WORKDIR/before.txt"
AFTER="$WORKDIR/after.txt"
DIFF_OUT="/tmp/nix-update-diff-$STAMP.txt"
MAX_LIST=50   # max entries printed per section; the rest stay in $DIFF_OUT

# /nix/store/<hash>-name-version -> name-version (readable)
strip_hash() { sed 's|/nix/store/[a-z0-9]\{32\}-||'; }

echo "==> [1/5] Capturing current system closure..."
nix path-info -r "$SYSTEM_PROFILE" | sort > "$BEFORE"
echo "      $(wc -l < "$BEFORE") store paths in current system"

echo "==> [2/5] Updating flake inputs (nix flake update)..."
nix flake update --flake "$FLAKE_DIR"

if [[ -d "$FLAKE_DIR/.git" ]]; then
  echo "      Lockfile changes vs HEAD:"
  git -C "$FLAKE_DIR" diff --stat flake.lock | sed 's/^/        /' || true
fi

echo "==> [3/5] Rebuilding system (nixos-rebuild switch)..."
nixos-rebuild switch --flake "$FLAKE_DIR"

echo "==> [4/5] Capturing new system closure..."
nix path-info -r "$SYSTEM_PROFILE" | sort > "$AFTER"
echo "      $(wc -l < "$AFTER") store paths in new system"

echo "==> [5/5] Diffing closures..."
diff "$BEFORE" "$AFTER" > "$DIFF_OUT" || true   # diff exits 1 when files differ

added=$(comm -13 "$BEFORE" "$AFTER" | wc -l)
removed=$(comm -23 "$BEFORE" "$AFTER" | wc -l)

echo
if [[ $added -eq 0 && $removed -eq 0 ]]; then
  echo "No package changes — system closure is identical."
else
  echo "Summary: $added paths added, $removed paths removed (full diff: $DIFF_OUT)"

  list_changes() {
    local label="$1" file_a="$2" file_b="$3"
    local count
    comm -"$4" "$file_a" "$file_b" | strip_hash | sort -u > "$WORKDIR/list.txt"
    count=$(wc -l < "$WORKDIR/list.txt")
    echo
    echo "--- $label ($count) ---"
    head -n "$MAX_LIST" "$WORKDIR/list.txt"
    if (( count > MAX_LIST )); then
      echo "... and $(( count - MAX_LIST )) more (see $DIFF_OUT)"
    fi
  }

  list_changes "Removed from system" "$BEFORE" "$AFTER" 23
  list_changes "Added to system"     "$BEFORE" "$AFTER" 13
fi
