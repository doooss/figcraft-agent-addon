#!/usr/bin/env bash
# Build the headless CLI in release mode and copy it to agent-addon/dist/figcraft-cli, next to a
# version stamp the addon can read. Pass extra cargo arguments after `--`.
#
#   agent-addon/build.sh
#   agent-addon/build.sh --link     # also symlink ~/.local/bin/figcraft-cli to the built binary
#   agent-addon/build.sh -- --locked
set -euo pipefail

root="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
cd "$root"

link=0
if [ "${1:-}" = "--link" ]; then link=1; shift; fi
extra=()
if [ "${1:-}" = "--" ]; then shift; extra=("$@"); fi

echo "+ cargo build --release -p figcraft-cli ${extra[*]:-}"
cargo build --release -p figcraft-cli ${extra[@]+"${extra[@]}"}

dist="$root/agent-addon/dist"
mkdir -p "$dist"
cp -f "$root/target/release/figcraft-cli" "$dist/figcraft-cli"
chmod +x "$dist/figcraft-cli"

version="$("$dist/figcraft-cli" --version)"
commit="$(git rev-parse --short HEAD)"
upstream="$(git describe --tags --always upstream-sync 2>/dev/null || echo unknown)"
cat > "$dist/VERSION" <<MSG
$version
commit=$commit
upstream=$upstream
built=$(date -u +%Y-%m-%dT%H:%M:%SZ)
MSG

echo "built $dist/figcraft-cli ($version, commit $commit, upstream $upstream)"

# A globally installed fig-agent-addon finds the binary on PATH; the symlink keeps pointing at
# this path, so later builds need no re-link.
if [ "$link" = 1 ]; then
  bin="${FIGCRAFT_LINK_DIR:-$HOME/.local/bin}"
  mkdir -p "$bin"
  ln -sfn "$dist/figcraft-cli" "$bin/figcraft-cli"
  echo "linked $bin/figcraft-cli -> $dist/figcraft-cli"
fi
