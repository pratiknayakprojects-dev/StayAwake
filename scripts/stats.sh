#!/bin/bash
# StayAwake numbers: downloads, sales, refunds, activations, conversion.
# Usage: scripts/stats.sh
# For the sales section set GUMROAD_TOKEN (Gumroad > Settings > Advanced > Applications > create an
# application > "Generate access token"). Keep it out of git and chat.
# The app has no telemetry on purpose: "active users" is approximated by license activations.
set -u
REPO=pratiknayakprojects-dev/StayAwake

echo "== Downloads (GitHub; includes repeats, bots and your own tests) =="
curl -s "https://api.github.com/repos/$REPO/releases" | python3 -c "$(cat <<'E'
import json, sys
total = 0
for r in json.load(sys.stdin):
    for a in r["assets"]:
        total += a["download_count"]
        print("  %-8s %d" % (r["tag_name"], a["download_count"]))
print("  total    %d" % total)
E
)"

echo; echo "== Landing page traffic, last 14 days (needs gh login) =="
gh api "repos/$REPO/traffic/views" --jq '"  views \(.count), unique visitors \(.uniques)"' 2>/dev/null || echo "  (gh not logged in)"
gh api "repos/$REPO/traffic/clones" --jq '"  clones \(.count), unique cloners \(.uniques)"' 2>/dev/null

echo; echo "== Sales and payment lifecycle (Gumroad) =="
if [ -z "${GUMROAD_TOKEN:-}" ]; then
  echo "  set GUMROAD_TOKEN to see sales, refunds, chargebacks and activations"
  echo "  (or open gumroad.com > Analytics for views, sales and conversion)"
  exit 0
fi
GITHUB_REPO=$REPO python3 - <<'E'
import json, os, urllib.parse, urllib.request
tok, product = os.environ["GUMROAD_TOKEN"], "I9wncJk2OLsDVAKc8pDjBA=="

def call(url, data=None):
    req = urllib.request.Request(url, data=data)
    return json.load(urllib.request.urlopen(req))

sales, page = [], None
while True:
    q = {"access_token": tok, **({"page_key": page} if page else {})}
    d = call("https://api.gumroad.com/v2/sales?" + urllib.parse.urlencode(q))
    sales += d.get("sales", [])
    page = d.get("next_page_key")
    if not page:
        break
sales = [s for s in sales if s.get("product_id") == product]
paid = [s for s in sales if s.get("price", 0) > 0]
refunded = [s for s in paid if s.get("refunded")]
charged = [s for s in paid if s.get("chargedback")]
kept = [s for s in paid if not s.get("refunded") and not s.get("chargedback")]
print(f"  orders {len(sales)} (free/test {len(sales) - len(paid)}), paid {len(paid)}, refunded {len(refunded)}, chargebacks {len(charged)}")
print(f"  revenue kept ${sum(s['price'] for s in kept) / 100:.2f}")

uses = 0
for s in kept:
    key = s.get("license_key")
    if not key:
        continue
    body = urllib.parse.urlencode({"product_id": product, "license_key": key, "increment_uses_count": "false"}).encode()
    uses += call("https://api.gumroad.com/v2/licenses/verify", body).get("uses", 0)
print(f"  license activations (Macs unlocked) {uses}")
E
