#!/bin/bash
# Run this from your flake root: /home/scott/nix

echo "=== Nix flake file tree ==="
tree -L 3 --noreport 2>/dev/null || find . -type f -name "*.nix" | sort

echo
echo "=== File contents ==="
find . -type f -name "*.nix" -print0 | while IFS= read -r -d '' file; do
    echo "===== $file ====="
    cat "$file"
    echo
done