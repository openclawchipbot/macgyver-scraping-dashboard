# MacGyver — Scraping Dashboard

Auto-generated status dashboard for the MotoMate scraping failure-fix cycle.

Dashboard URL is an unguessable random filename.
Bare URL returns "Not Found". `robots.txt` + `<meta name="robots" content="noindex">` block search engines.

## How it's built
- Static HTML + `data/stats.json`
- `scripts/generate-stats.sh` queries prod via `mm scraping:getFailures` and parses memory files
- `scripts/refresh-and-push.sh` regenerates and pushes if changed
- Runs every 4h via macOS `launchd` on MacGyver's host (no LLM, no token cost)
- GitHub Pages rebuilds on push via `.github/workflows/pages.yml`

## Rotating the URL
If the URL leaks, regenerate the filename:
1. `mv <old>.html <new>.html` (pick a new `secrets.token_urlsafe(20)` name)
2. Commit + push
3. Update `~/.openclaw/workspace-scraping/MEMORY.md` and `CURRENT_WORK.md`
