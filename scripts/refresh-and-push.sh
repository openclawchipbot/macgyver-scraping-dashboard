#!/usr/bin/env zsh
# Regenerate stats.json and push a commit if it changed.
# Run by cron on MacGyver's host.
emulate -L zsh
setopt err_exit no_unset pipe_fail

SCRIPT_DIR="${0:A:h}"
REPO_DIR="${SCRIPT_DIR:h}"

cd "$REPO_DIR"

# Pull any remote changes first (should be no-op; I'm the only writer)
git pull --rebase --quiet origin main || true

# Regenerate
"$SCRIPT_DIR/generate-stats.sh"

# Commit only if changed
if ! git diff --quiet -- data/stats.json; then
  git -c user.name="MacGyver Bot" -c user.email="bot-macgyver@motomate123.com" \
      add data/stats.json
  git -c user.name="MacGyver Bot" -c user.email="bot-macgyver@motomate123.com" \
      commit -m "Refresh stats.json ($(date -u +%Y-%m-%dT%H:%MZ))" --no-verify --quiet
  git push --quiet origin main
  echo "Pushed stats refresh"
else
  echo "No change; skipping push"
fi
