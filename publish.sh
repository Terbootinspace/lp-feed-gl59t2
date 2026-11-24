#!/bin/bash
# Usage: publish.sh <path-to-new-packages.json>
# Validates and publishes Brett's widget feed to GitHub Pages.
set -euo pipefail
cd /workspace/luna-pkg-site

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <path-to-new-packages.json>" >&2
  exit 2
fi

SRC="$1"
TOKEN="$(tr -d '[:space:]' < /workspace/luna-pkg-token.txt)"
DEST="p/${TOKEN}.json"
LIVE_URL="https://terbootinspace.github.io/lp-feed-gl59t2/p/${TOKEN}.json"

python3 -c "import json,sys; d=json.load(open(sys.argv[1])); assert 'packages' in d" "$SRC"

changed="$(python3 -c '
import json, sys
new = json.load(open(sys.argv[1]))
try:
    old = json.load(open(sys.argv[2]))
except Exception:
    old = {}
print("yes" if new.get("packages") != old.get("packages") else "no")
' "$SRC" "$DEST")"

if [ "$changed" = "no" ]; then
  echo "NO CHANGE"
  exit 0
fi

cp "$SRC" "$DEST"
git add -- "$DEST"
if ! git commit -m "Update package feed"; then
  echo "PUBLISH FAILED"
  exit 1
fi

if ! git push origin main; then
  echo "PUBLISH FAILED"
  exit 1
fi

python3 -c '
import json, sys, time, urllib.request

live_url = sys.argv[1]
dest = sys.argv[2]
expected = json.load(open(dest))
deadline = time.time() + 120
last_err = "no response"
while time.time() < deadline:
    try:
        req = urllib.request.Request(live_url, headers={"User-Agent": "luna-pkg-publish/1.0", "Cache-Control": "no-cache"})
        with urllib.request.urlopen(req, timeout=20) as resp:
            raw = resp.read()
        live = json.loads(raw.decode())
        if live == expected:
            sys.stdout.buffer.write(raw[:80])
            sys.stdout.buffer.write(b"\n")
            sys.exit(0)
        last_err = "live feed does not match the commit yet"
    except Exception as e:
        last_err = str(e)
    time.sleep(5)
print("PUBLISH FAILED: live URL did not update:", last_err, file=sys.stderr)
sys.exit(1)
' "$LIVE_URL" "$DEST"
