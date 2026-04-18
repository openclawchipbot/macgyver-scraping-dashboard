#!/usr/bin/env zsh
# Generates data/stats.json from live prod + my memory files.
# Run by cron every N minutes.
emulate -L zsh
setopt err_exit no_unset pipe_fail

DASHBOARD_DIR="${0:A:h:h}"
MM_REPO="$HOME/Documents/git/ViewInFocus-Server-MacGyver"
MEMORY_DIR="$HOME/.openclaw/workspace-scraping/memory"
CURRENT_WORK="$HOME/.openclaw/workspace-scraping/CURRENT_WORK.md"
SKIP_LIST="$MEMORY_DIR/skip-list.txt"
RECHECK_LIST="$MEMORY_DIR/recheck-list.json"

# Ensure the mm binary and common tools are on PATH. Do NOT source .zshrc:
# it defines `mm` as an alias/function that behaves differently than the
# standalone binary at /opt/homebrew/bin/mm and breaks under err_exit.
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:$PATH"

cd "$MM_REPO"

# --- Failure totals ---
total_failures="$(mm scraping:getFailures --db prod --limit 1 2>/dev/null | grep -oE 'of [0-9]+ total' | grep -oE '[0-9]+' | head -1)"
total_failures="${total_failures:-0}"

actionable_queue="$(mm scraping:getFailures --db prod --limit 1 --excludeFile "$SKIP_LIST" 2>/dev/null | grep -oE 'of [0-9]+ total' | grep -oE '[0-9]+' | head -1)"
actionable_queue="${actionable_queue:-0}"

# Skip-list size (non-comment, non-blank lines)
skip_list_size="$(grep -cvE '^\s*(#|$)' "$SKIP_LIST" 2>/dev/null || echo 0)"

# --- Python-driven data assembly ---
# Pass file paths via env so Python handles all JSON encoding safely.
export MG_MEMORY_DIR="$MEMORY_DIR"
export MG_RECHECK_LIST="$RECHECK_LIST"
export MG_CURRENT_WORK="$CURRENT_WORK"
export MG_TOTAL_FAILURES="$total_failures"
export MG_ACTIONABLE_QUEUE="$actionable_queue"
export MG_SKIP_LIST_SIZE="$skip_list_size"
export MG_OUT_PATH="$DASHBOARD_DIR/data/stats.json"

python3 <<'PY'
import json, os, re
from datetime import date, timedelta, datetime, timezone

memory_dir = os.environ["MG_MEMORY_DIR"]
recheck_path = os.environ["MG_RECHECK_LIST"]
current_work_path = os.environ["MG_CURRENT_WORK"]
out_path = os.environ["MG_OUT_PATH"]

def load_json(p, default):
    try:
        with open(p) as f:
            return json.load(f)
    except Exception:
        return default

def read_text(p):
    try:
        with open(p) as f:
            return f.read()
    except Exception:
        return ""

# Last 7 days activity
today = date.today()
days = []
for i in range(7):
    d = today - timedelta(days=i)
    fname = os.path.join(memory_dir, f"{d.isoformat()}.md")
    entry = {"date": d.isoformat(), "fixed": [], "transient": [], "skipped": [], "rechecks": []}
    text = read_text(fname)
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped.startswith(("-", "*")):
            continue
        low = stripped.lower()
        m = re.search(r"\*\*([^*]+?)\*\*", stripped)
        dealer = m.group(1) if m else stripped.lstrip("-* ").strip()
        # Truncate long lines
        if len(dealer) > 100:
            dealer = dealer[:97] + "..."
        if "transient" in low or "recovered" in low or ("re-ran" in low and "success" in low):
            entry["transient"].append(dealer)
        elif "skip-list" in low or "added to skip" in low or "skipped" in low:
            entry["skipped"].append(dealer)
        elif "recheck" in low:
            entry["rechecks"].append(dealer)
        elif ("fix" in low and ("applied" in low or "setsettings" in low or "set_settings" in low or "deployed" in low or "settings:" in low)) \
                or "pr #" in low and "merged" in low:
            entry["fixed"].append(dealer)
    days.append(entry)

totals = {
    "fixed_7d": sum(len(d["fixed"]) for d in days),
    "transient_7d": sum(len(d["transient"]) for d in days),
    "skipped_7d": sum(len(d["skipped"]) for d in days),
    "rechecks_7d": sum(len(d["rechecks"]) for d in days),
}

recheck_list = load_json(recheck_path, [])

# Current work excerpt — pull headings + first bullet per section
cw_text = read_text(current_work_path)
cw_lines = []
for line in cw_text.splitlines():
    if line.startswith("##") or line.startswith("- "):
        cw_lines.append(line)
    if len(cw_lines) >= 80:
        break

data = {
    "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "queue": {
        "total_failures": int(os.environ.get("MG_TOTAL_FAILURES", "0") or 0),
        "actionable_queue": int(os.environ.get("MG_ACTIONABLE_QUEUE", "0") or 0),
        "skip_list_size": int(os.environ.get("MG_SKIP_LIST_SIZE", "0") or 0),
        "recheck_count": len(recheck_list) if isinstance(recheck_list, list) else 0,
    },
    "recheck_list": recheck_list if isinstance(recheck_list, list) else [],
    "activity": {"days": days, "totals": totals},
    "current_work_excerpt": cw_lines,
}

os.makedirs(os.path.dirname(out_path), exist_ok=True)
with open(out_path, "w") as f:
    json.dump(data, f, indent=2)
print(f"Wrote {out_path}")
PY
