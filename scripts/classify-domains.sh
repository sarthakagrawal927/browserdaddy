#!/bin/bash
# Batch-classify top archive domains via classifier.dev into
# domain_categories(host, category, confidence).
#
# PRIVACY: sends domain names only (no URLs, titles, or timestamps) to
# classifier.dev. The app itself never makes this call — run this script
# manually whenever the domain set has grown.
#
# Usage: scripts/classify-domains.sh [limit]   (default: top 800 by visits)
set -euo pipefail
DB="${BROWSERDADDY_DB:-$HOME/Library/Application Support/BrowserDaddy/browserdaddy.db}"
LIMIT="${1:-800}"

python3 - "$DB" "$LIMIT" <<'PY'
import json, sqlite3, subprocess, sys

db_path, limit = sys.argv[1], int(sys.argv[2])
HOST = """CASE WHEN url LIKE 'http%' THEN
  substr(substr(url, instr(url,'//')+2), 1,
         instr(substr(url, instr(url,'//')+2)||'/', '/')-1)
  ELSE substr(url,1,40) END"""

db = sqlite3.connect(db_path)
db.execute("""CREATE TABLE IF NOT EXISTS domain_categories
             (host TEXT PRIMARY KEY, category TEXT, confidence REAL)""")
known = {r[0] for r in db.execute("SELECT host FROM domain_categories")}
doms = [r[0] for r in db.execute(
    f"SELECT {HOST} h, COUNT(*) c FROM visits GROUP BY h "
    f"ORDER BY c DESC LIMIT {limit}") if r[0] not in known]
if not doms:
    print("nothing new to classify"); sys.exit(0)

labels = ["development","ai-tools","cloud-infra","documentation",
          "social-media","video","music","news","shopping","finance",
          "communication","productivity","search","gaming",
          "entertainment","education","travel","health","other"]
out = subprocess.run(
    ["curl","-s","-m","300","https://classifier.dev/v1/classify",
     "-H","content-type: application/json",
     "-d", json.dumps({"inputs": doms, "labels": labels})],
    capture_output=True, text=True)
res = json.loads(out.stdout).get("results") or []
pairs = [(d, res[i]["label"], res[i].get("confidence", 0))
         for i, d in enumerate(doms[:len(res)])]
db.executemany("INSERT OR REPLACE INTO domain_categories VALUES (?,?,?)",
               pairs)
db.commit()
n = db.execute(f"""SELECT COUNT(*) FROM visits v
    JOIN domain_categories c ON c.host = {HOST}""").fetchone()[0]
tot = db.execute("SELECT COUNT(*) FROM visits").fetchone()[0]
print(f"classified {len(pairs)} new domains; coverage {n}/{tot} "
      f"= {100*n/tot:.1f}% of visits")
PY
