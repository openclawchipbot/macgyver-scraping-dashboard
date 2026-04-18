# MacGyver — Scraping Dashboard

Private repo. Serves a static dashboard behind an unguessable path.
Bare URL returns "Not Found". Real dashboard path is stored in
`~/.openclaw/workspace-scraping/.dashboard-url` and in MacGyver's MEMORY.md.

## How it's built
- Static HTML + `data/stats.json` under `s/<secret-slug>/`
- `scripts/generate-stats.sh` queries prod via `mm scraping:getFailures` and parses memory files
- `scripts/refresh-and-push.sh` regenerates and pushes if changed; runs on MacGyver's host via cron
- GitHub Pages rebuilds on push via `.github/workflows/pages.yml`

## Rotating the slug
If the URL leaks:
1. `mv s/<old-slug> s/<new-slug>`
2. Update `MG_OUT_PATH` in `scripts/generate-stats.sh` and `STATS_PATH` in `scripts/refresh-and-push.sh`
3. Update `~/.openclaw/workspace-scraping/.dashboard-url` and MEMORY.md
4. Commit + push
