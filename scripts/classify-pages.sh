#!/bin/bash
# Batch-classify top visited pages via classifier.dev into
# page_categories(url, category, confidence).
#
# PRIVACY: sends "host — page title" text to classifier.dev. Titles are
# real content — more sensitive than domains. Runs only when you run it;
# the app never calls out. Re-run to classify newly-visited top pages.
#
# Usage: scripts/classify-pages.sh [limit]   (default: top 2000 pages)
set -euo pipefail
DB="${BROWSERDADDY_DB:-$HOME/Library/Application Support/BrowserDaddy/browserdaddy.db}"
LIMIT="${1:-2000}"

python3 - "$DB" "$LIMIT" <<'PY'
import json, sqlite3, subprocess, sys

db_path, limit = sys.argv[1], int(sys.argv[2])
db = sqlite3.connect(db_path)
db.execute("""CREATE TABLE IF NOT EXISTS page_categories
             (url TEXT PRIMARY KEY, category TEXT, confidence REAL)""")
known = {r[0] for r in db.execute("SELECT url FROM page_categories")}
# top pages by visit count with a usable title
rows = db.execute("""SELECT url, MAX(title) t, COUNT(*) c FROM visits
    WHERE title != '' AND url LIKE 'http%' GROUP BY url
    ORDER BY c DESC LIMIT ?""", (limit,)).fetchall()
items = [(u, f"{u.split('/')[2] if '//' in u else u} — {t[:160]}")
         for u, t, c in rows if u not in known and t.strip()]
if not items:
    print("nothing new to classify"); sys.exit(0)

labels = ["programming","devops-infra","ai-ml","web-dev","data",
          "news","entertainment","gaming","finance","shopping",
          "social-media","music","video-entertainment","tutorial-docs",
          "science","politics","sports","health","travel","food",
          "productivity","communication","search-homepage","nsfw","other"]

all_pairs = []
for i in range(0, len(items), 1000):
    batch = items[i:i+1000]
    out = subprocess.run(
        ["curl","-s","-m","300","https://classifier.dev/v1/classify",
         "-H","content-type: application/json",
         "-d", json.dumps({"inputs":[t for _,t in batch], "labels":labels})],
        capture_output=True, text=True)
    res = json.loads(out.stdout).get("results") or []
    all_pairs += [(u, res[j]["label"], res[j].get("confidence",0))
                  for j,(u,_) in enumerate(batch[:len(res)])]
    print(f"  batch {i//1000+1}: {len(res)}")

db.executemany("INSERT OR REPLACE INTO page_categories VALUES (?,?,?)",
               all_pairs)
db.commit()
n = db.execute("""SELECT COUNT(*) FROM visits v
    JOIN page_categories c ON c.url = v.url""").fetchone()[0]
tot = db.execute("SELECT COUNT(*) FROM visits").fetchone()[0]
print(f"classified {len(all_pairs)} pages; visit coverage {n}/{tot} "
      f"= {100*n/tot:.1f}%")
PY
