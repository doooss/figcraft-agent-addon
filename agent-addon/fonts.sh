#!/usr/bin/env bash
# Fetch or update storytold/craft-fonts next to this repository (../craft-fonts), the optional
# build input that embeds fallback fonts into the binary (today: Noto Sans CJK, Noto Sans Arabic,
# Noto Sans Thai, BIZ UD Gothic/Mincho, Shippori Mincho). Latin and Korean text still use the installed
# system fonts (the CJK set has no Hangul); the embedded set covers Japanese, Simplified Chinese,
# Arabic and Thai on machines without those fonts. Without this checkout the binary has no built-in fonts at all.
#
#   agent-addon/fonts.sh          # clone or pull ../craft-fonts, then rebuild the text crate
set -euo pipefail

root="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
dir="${CRAFT_FONTS_DIR:-$root/../craft-fonts}"

if [ -d "$dir/.git" ]; then
  echo "+ git -C $dir pull --ff-only"
  git -C "$dir" pull --ff-only
else
  echo "+ git clone --depth 1 https://github.com/storytold/craft-fonts.git $dir"
  git clone --depth 1 https://github.com/storytold/craft-fonts.git "$dir"
fi

# crates/text/build.rs reads the fonts at compile time. Cargo replays a cached build-script
# result otherwise, and `cargo clean -p` touches one profile at a time, so clean both.
cd "$root"
cargo clean -p figcraft-text
cargo clean --release -p figcraft-text
echo "fonts ready in $dir; run agent-addon/build.sh"
