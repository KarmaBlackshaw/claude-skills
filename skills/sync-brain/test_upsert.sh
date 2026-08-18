#!/usr/bin/env bash
# Self-check for the sync-brain push upsert: insert once, then re-push the same
# session id with a corrected headline -> single entry, new headline. Runnable:
#   bash skills/sync-brain/test_upsert.sh
set -euo pipefail

S="$(mktemp)"
trap 'rm -f "$S" "$S.tmp"' EXIT
cat > "$S" <<'EOF'
## Sessions (newest first)

### 2026-08-08 — old other session
<!-- session: aaaa -->
EOF

upsert() { # $1=headline $2=marker
  awk -v h="$1" -v m="$2" '{a[NR]=$0} $0==m{seen=1} /^## Sessions \(newest first\)/{hdr=NR} END{if(seen){for(i=1;i<=NR;i++){if(a[i+1]==m&&a[i]~/^### /)a[i]=h; print a[i]}}else{for(i=1;i<=NR;i++){print a[i]; if(i==hdr){print ""; print h; print m}}}}' "$S" > "$S.tmp" && mv "$S.tmp" "$S"
}

M='<!-- session: bbbb -->'
upsert "### 2026-08-09 — first pass headline" "$M"   # insert
upsert "### 2026-08-09 — corrected headline" "$M"    # update in place

got_new=$(grep -c 'corrected headline' "$S" || true)
got_old=$(grep -c 'first pass headline' "$S" || true)
got_marker=$(grep -cF "$M" "$S" || true)
got_other=$(grep -c 'old other session' "$S" || true)

[ "$got_new" -eq 1 ]    || { echo "FAIL: corrected headline count=$got_new (want 1)"; exit 1; }
[ "$got_old" -eq 0 ]    || { echo "FAIL: stale headline survived ($got_old)"; exit 1; }
[ "$got_marker" -eq 1 ] || { echo "FAIL: marker count=$got_marker (want 1, no dup)"; exit 1; }
[ "$got_other" -eq 1 ]  || { echo "FAIL: clobbered other session"; exit 1; }
echo "PASS: insert then update -> one entry, corrected headline, no dup marker"
