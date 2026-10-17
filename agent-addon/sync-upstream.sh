#!/usr/bin/env bash
# Pull the latest storytold/figcraft into `upstream-sync`, rebase `agent-addon` on top of it and
# rebuild the headless CLI. Run from anywhere inside the repository.
#
#   agent-addon/sync-upstream.sh            # fetch, fast-forward, rebase, build
#   agent-addon/sync-upstream.sh --no-build # skip the cargo build
#   agent-addon/sync-upstream.sh --push     # also push both branches to origin
#
# Branch model (see agent-addon/README.md):
#   upstream-sync  mirrors upstream/main, never carries local commits
#   agent-addon   upstream-sync + the agent-addon/ directory (scripts and docs only)
set -euo pipefail

UPSTREAM_REMOTE="${UPSTREAM_REMOTE:-upstream}"
UPSTREAM_URL="${UPSTREAM_URL:-https://github.com/storytold/figcraft.git}"
UPSTREAM_BRANCH="${UPSTREAM_BRANCH:-main}"
SYNC_BRANCH="${SYNC_BRANCH:-upstream-sync}"
PRODUCT_BRANCH="${PRODUCT_BRANCH:-agent-addon}"

build=1
push=0
for arg in "$@"; do
  case "$arg" in
    --no-build) build=0 ;;
    --push) push=1 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

root="$(git rev-parse --show-toplevel)"
cd "$root"

if [ -n "$(git status --porcelain)" ]; then
  echo "error: working tree is not clean; commit or stash first" >&2
  exit 1
fi

if ! git remote get-url "$UPSTREAM_REMOTE" >/dev/null 2>&1; then
  echo "+ git remote add $UPSTREAM_REMOTE $UPSTREAM_URL"
  git remote add "$UPSTREAM_REMOTE" "$UPSTREAM_URL"
fi

echo "+ git fetch $UPSTREAM_REMOTE --tags --prune"
git fetch "$UPSTREAM_REMOTE" --tags --prune

start_branch="$(git rev-parse --abbrev-ref HEAD)"
before="$(git rev-parse "$SYNC_BRANCH" 2>/dev/null || echo none)"

# 1. upstream-sync: pure mirror, fast-forward only.
if git show-ref --verify --quiet "refs/heads/$SYNC_BRANCH"; then
  git checkout -q "$SYNC_BRANCH"
  git merge --ff-only "$UPSTREAM_REMOTE/$UPSTREAM_BRANCH"
else
  git checkout -q -b "$SYNC_BRANCH" "$UPSTREAM_REMOTE/$UPSTREAM_BRANCH"
fi
after="$(git rev-parse "$SYNC_BRANCH")"

if [ "$before" = "$after" ]; then
  echo "$SYNC_BRANCH already at $(git rev-parse --short "$after"); nothing new upstream"
else
  echo "$SYNC_BRANCH: $(git rev-parse --short "$before") -> $(git rev-parse --short "$after")"
  git log --oneline "$before..$after" | head -40
fi

# 2. agent-addon: our commits replayed on the new upstream tip.
if git show-ref --verify --quiet "refs/heads/$PRODUCT_BRANCH"; then
  git checkout -q "$PRODUCT_BRANCH"
  if ! git rebase "$SYNC_BRANCH"; then
    cat >&2 <<MSG

error: rebase of $PRODUCT_BRANCH onto $SYNC_BRANCH hit a conflict.
Resolve it, then: git rebase --continue && agent-addon/build.sh
(or abort with: git rebase --abort)
MSG
    exit 1
  fi
else
  git checkout -q -b "$PRODUCT_BRANCH" "$SYNC_BRANCH"
fi

echo "$PRODUCT_BRANCH now at $(git rev-parse --short HEAD) (upstream $(git describe --tags --always "$SYNC_BRANCH"))"

# 3. Rebuild the binary the addon calls.
if [ "$build" = 1 ]; then
  "$root/agent-addon/build.sh"
fi

if [ "$push" = 1 ]; then
  echo "+ git push origin $SYNC_BRANCH"
  git push origin "$SYNC_BRANCH"
  echo "+ git push --force-with-lease origin $PRODUCT_BRANCH"
  git push --force-with-lease origin "$PRODUCT_BRANCH"
fi

if [ "$start_branch" != "$PRODUCT_BRANCH" ] && [ "$start_branch" != "HEAD" ]; then
  git checkout -q "$start_branch"
fi
