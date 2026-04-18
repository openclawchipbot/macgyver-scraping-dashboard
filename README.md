# MacGyver — Scraping Dashboard

Auto-generated status dashboard for the MotoMate scraping failure-fix cycle.
Live at: https://openclawchipbot.github.io/macgyver-scraping-dashboard/

## What it shows
- Failures fixed, transient, and skipped in the last 7 days (from daily memory files)
- Actionable queue size (failures outside skip-list)
- Total failures across all dealers
- Skip-list size
- Pending rechecks (LeadVenture re-verify queue, inactive-dealer fixes waiting for scheduled Lambda, etc.)
- Active / waiting work carried over from CURRENT_WORK.md

## How it's built
- Static HTML + a single `data/stats.json`
- `scripts/generate-stats.sh` queries prod via `mm scraping:getFailures` and parses `~/.openclaw/workspace-scraping/memory/*.md`
- A cron on MacGyver's host runs the script every 15 min and pushes a commit if `stats.json` changed
- GitHub Pages rebuilds on push (`.github/workflows/pages.yml`)

## Files
- `index.html` — dashboard UI
- `data/stats.json` — data payload (auto-regenerated)
- `scripts/generate-stats.sh` — regenerator (runs on MacGyver's host, not in CI)
- `.github/workflows/pages.yml` — Pages deploy
