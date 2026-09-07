#!/bin/sh
# Fixture 3 (contract item 3, amendment 3) — crew-append.sh on a SCRATCH target.
#
# Cases, in order:
#   3.1 two concurrent appends both land exactly once
#   3.2 identical duplicate is a NOOP and writes nothing
#   3.3 same key, different content -> CONFLICT exit 76, nothing written,
#       receipt names both fingerprints
#   3.4 correction is a new record at rev+1 (prior record untouched)
#   3.5 read-only target -> non-zero exit and a retryable receipt
#   3.6 writer kill -9'd while holding the lock, pid now DEAD -> next call
#       reclaims and commits
#   3.7 lock owner pid is a LIVE process on this host -> bounded timeout,
#       exit 75, receipt naming the owner; lock left in place
#   3.8 writer kill -9'd mid-append -> trailing fragment quarantined, prior
#       complete records byte-identical (sha256 of the prefix), re-run commits
#       exactly one record
#   3.9 foreign-host lock (even with a dead pid) is NEVER reclaimed -> exit 75
#
# The target is always a file under one mktemp -d. This fixture never names
# $HOME/.foreman or the real crew-performance.md; run-all.sh additionally
# refuses to start if either could be reached.
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/lib.sh"
SCRIPT="$HERE/../scripts/crew-append.sh"

TMP=$(mktemp -d "${TMPDIR:-/tmp}/foreman-fx3.XXXXXX") || exit 1
cleanup_fx3() {
  # Kill any test-hook writer still parked in its sleep, then remove the tree.
  [ -n "${STRAY_PIDS:-}" ] && kill -9 $STRAY_PIDS 2>/dev/null
  chmod -R u+w "$TMP" 2>/dev/null
  rm -rf "$TMP"
}
trap cleanup_fx3 EXIT INT TERM
STRAY_PIDS=""

TARGET="$TMP/crew-performance.md"
RECEIPTS="$TMP/receipts"
HOSTNAME_NOW=$(hostname 2>/dev/null || uname -n)

export CREW_APPEND_RECEIPT_DIR="$RECEIPTS"
export CREW_APPEND_LOCK_WAIT=6
export CREW_APPEND_TEST_PAUSE_SECS=25

mkrec() { # mkrec <path> <run> <outcome> <rev> <body-text>
  { printf 'RECORD host=%s run=%s outcome=%s rev=%s\n' "$HOSTNAME_NOW" "$2" "$3" "$4"
    printf 'body: %s\n' "$5"
    printf 'disposition: accepted\nusage: unavailable\n'
  } > "$1"
}

run_append() { sh "$SCRIPT" "$@"; }
n_records() { grep -c '^END fp=' "$TARGET" 2>/dev/null || true; }

# ---------------------------------------------------------------- 3.1
mkrec "$TMP/r1" run-aaa out-1 1 "first closure"
mkrec "$TMP/r2" run-bbb out-2 1 "second closure"
CREW_APPEND_LOCK_WAIT=15 run_append "$TMP/r1" "$TARGET" > "$TMP/c1.out" 2>&1 &
P1=$!
CREW_APPEND_LOCK_WAIT=15 run_append "$TMP/r2" "$TARGET" > "$TMP/c2.out" 2>&1 &
P2=$!
wait $P1; RC1=$?
wait $P2; RC2=$?
assert_eq "3.1 concurrent append A exit 0" "0" "$RC1"
assert_eq "3.1 concurrent append B exit 0" "0" "$RC2"
assert_contains "3.1 A reports APPENDED" "$TMP/c1.out" "APPENDED key=RECORD host=$HOSTNAME_NOW run=run-aaa outcome=out-1 rev=1"
assert_contains "3.1 B reports APPENDED" "$TMP/c2.out" "APPENDED key=RECORD host=$HOSTNAME_NOW run=run-bbb outcome=out-2 rev=1"
assert_eq "3.1 exactly two complete records" "2" "$(n_records)"
assert_eq "3.1 record A present exactly once" "1" "$(count_matches "$TARGET" "run=run-aaa outcome=out-1 rev=1 fp=")"
assert_eq "3.1 record B present exactly once" "1" "$(count_matches "$TARGET" "run=run-bbb outcome=out-2 rev=1 fp=")"
if [ ! -e "$TARGET.lock" ]; then pass "3.1 lock released after both writers"; else fail "3.1 lock released after both writers"; fi

# ---------------------------------------------------------------- 3.2
SHA_BEFORE=$(sha_of "$TARGET")
run_append "$TMP/r1" "$TARGET" > "$TMP/dup.out" 2>&1; RCD=$?
assert_eq "3.2 identical duplicate exit 0" "0" "$RCD"
assert_contains "3.2 identical duplicate reports NOOP" "$TMP/dup.out" "NOOP key=RECORD host=$HOSTNAME_NOW run=run-aaa outcome=out-1 rev=1"
assert_eq "3.2 duplicate wrote nothing" "$SHA_BEFORE" "$(sha_of "$TARGET")"

# ---------------------------------------------------------------- 3.3
mkrec "$TMP/r1-different" run-aaa out-1 1 "DIFFERENT content under the same key"
run_append "$TMP/r1-different" "$TARGET" > "$TMP/conf.out" 2>&1; RCC=$?
assert_eq "3.3 conflicting duplicate exit 76" "76" "$RCC"
assert_contains "3.3 conflict reported" "$TMP/conf.out" "CONFLICT key=RECORD host=$HOSTNAME_NOW run=run-aaa outcome=out-1 rev=1"
assert_eq "3.3 conflict wrote nothing" "$SHA_BEFORE" "$(sha_of "$TARGET")"
CONF_RECEIPT=$(ls -1t "$RECEIPTS"/crew-append-receipt-*.md 2>/dev/null | head -1)
assert_file "3.3 conflict left a receipt" "${CONF_RECEIPT:-/nonexistent}"
if [ -n "${CONF_RECEIPT:-}" ]; then
  EXIST_FP=$(sed -n 's/^RECORD host='"$HOSTNAME_NOW"' run=run-aaa outcome=out-1 rev=1 fp=//p' "$TARGET" | head -1)
  INCOMING_FP=$(sed -n 's/.*incoming-fp=\([0-9a-f]*\).*/\1/p' "$TMP/conf.out" | head -1)
  assert_contains "3.3 receipt names the existing fingerprint" "$CONF_RECEIPT" "existing fp:  $EXIST_FP"
  assert_contains "3.3 receipt names the incoming fingerprint" "$CONF_RECEIPT" "incoming fp:  $INCOMING_FP"
  assert_contains "3.3 receipt is marked retryable"            "$CONF_RECEIPT" "RETRYABLE:"
fi

# ---------------------------------------------------------------- 3.4
# A correction is a NEW record at rev+1 naming the prior key in its body. The
# body deliberately mentions the prior key mid-line; only line-leading "RECORD "
# would be a framing forgery, and that is refused separately.
cp "$TARGET" "$TMP/before-correction"
BEFORE_CORR_SHA=$(sha_of "$TMP/before-correction")
BEFORE_CORR_BYTES=$(wc -c < "$TMP/before-correction" | tr -d ' ')
mkrec "$TMP/r1-corr" run-aaa out-1 2 "correction of key [host=$HOSTNAME_NOW run=run-aaa outcome=out-1 rev=1] — cause reclassified"
run_append "$TMP/r1-corr" "$TARGET" > "$TMP/corr.out" 2>&1; RCR=$?
assert_eq "3.4 correction at rev=2 exit 0" "0" "$RCR"
assert_contains "3.4 correction appended" "$TMP/corr.out" "APPENDED key=RECORD host=$HOSTNAME_NOW run=run-aaa outcome=out-1 rev=2"
assert_eq "3.4 three complete records now" "3" "$(n_records)"
assert_eq "3.4 rev=1 record still present exactly once" "1" "$(count_matches "$TARGET" "run=run-aaa outcome=out-1 rev=1 fp=")"
head -c "$BEFORE_CORR_BYTES" "$TARGET" > "$TMP/after-correction-prefix"
assert_eq "3.4 prior records byte-identical after the correction" "$BEFORE_CORR_SHA" "$(sha_of "$TMP/after-correction-prefix")"

# A body line that would forge a record boundary is refused outright.
{ printf 'RECORD host=%s run=run-eee outcome=out-9 rev=1\n' "$HOSTNAME_NOW"; printf 'END fp=deadbeef\n'; } > "$TMP/r-forge"
SHA_FORGE=$(sha_of "$TARGET")
run_append "$TMP/r-forge" "$TARGET" > "$TMP/forge.out" 2>&1; RCG=$?
assert_eq "3.4b framing forgery in the body is refused (exit 2)" "2" "$RCG"
assert_eq "3.4b framing forgery wrote nothing" "$SHA_FORGE" "$(sha_of "$TARGET")"

# ---------------------------------------------------------------- 3.5
SHA_RO=$(sha_of "$TARGET")
chmod 444 "$TARGET"
if [ "$(id -u)" = "0" ]; then
  fail "3.5 SKIPPED — running as root, a read-only file is still writable"
else
  run_append "$TMP/r2" "$TARGET" > "$TMP/ro.out" 2>&1; RCO=$?
  if [ "$RCO" != "0" ]; then pass "3.5 read-only target exits non-zero (got $RCO)"; else fail "3.5 read-only target exits non-zero (got 0)"; fi
  RO_RECEIPT=$(ls -1t "$RECEIPTS"/crew-append-receipt-*.md 2>/dev/null | head -1)
  assert_file "3.5 read-only target left a receipt" "${RO_RECEIPT:-/nonexistent}"
  [ -n "${RO_RECEIPT:-}" ] && assert_contains "3.5 receipt says the target was not writable" "$RO_RECEIPT" "not writable"
  assert_eq "3.5 read-only target unchanged" "$SHA_RO" "$(sha_of "$TARGET")"
  if [ ! -e "$TARGET.lock" ]; then pass "3.5 lock released after the I/O failure"; else fail "3.5 lock released after the I/O failure"; fi
fi
chmod 644 "$TARGET"

# ---------------------------------------------------------------- 3.6
# A writer that really dies while holding the lock. The EXIT trap cannot run
# under SIGKILL, so the lock directory survives with a now-dead owner pid.
mkrec "$TMP/r3" run-ccc out-3 1 "third closure"
# Launched as `sh "$SCRIPT"` directly, never through a shell function: $! must
# be the crew-append.sh process itself, since that is the pid it writes into the
# lock owner file and the pid this case has to kill.
CREW_APPEND_TEST_PAUSE_AFTER_LOCK=1 sh "$SCRIPT" "$TMP/r3" "$TARGET" > "$TMP/hold.out" 2>&1 &
HOLDER=$!
STRAY_PIDS="$STRAY_PIDS $HOLDER"
if wait_until 5 '[ -f "$TARGET.lock/owner" ]'; then
  pass "3.6 test-hook writer took the lock"
else
  fail "3.6 test-hook writer took the lock"
fi
OWNER_PID=$(sed -n 's/^pid=//p' "$TARGET.lock/owner" 2>/dev/null | head -1)
assert_eq "3.6 owner file records the launched pid" "$HOLDER" "${OWNER_PID:-none}"
kill -9 "$HOLDER" 2>/dev/null
wait "$HOLDER" 2>/dev/null
if wait_until 5 '! kill -0 "$OWNER_PID" 2>/dev/null'; then
  pass "3.6 lock owner pid is provably dead"
else
  fail "3.6 lock owner pid is provably dead"
fi
if [ -d "$TARGET.lock" ]; then pass "3.6 killed writer left the lock behind"; else fail "3.6 killed writer left the lock behind"; fi
run_append "$TMP/r3" "$TARGET" > "$TMP/reclaim.out" 2>&1; RCK=$?
assert_eq "3.6 next call exits 0 after reclaiming" "0" "$RCK"
assert_contains "3.6 reclaim is reported"  "$TMP/reclaim.out" "RECLAIM stale lock"
assert_contains "3.6 record committed"     "$TMP/reclaim.out" "APPENDED key=RECORD host=$HOSTNAME_NOW run=run-ccc outcome=out-3 rev=1"
assert_eq "3.6 four complete records now"  "4" "$(n_records)"
assert_eq "3.6 committed exactly once"     "1" "$(count_matches "$TARGET" "run=run-ccc outcome=out-3 rev=1 fp=")"

# ---------------------------------------------------------------- 3.7
# Same host, but the owner pid is a LIVE process: never reclaimed, bounded wait.
sleep 25 &
LIVE=$!
STRAY_PIDS="$STRAY_PIDS $LIVE"
mkdir -p "$TARGET.lock"
printf 'pid=%s\nhost=%s\nstart=%s\n' "$LIVE" "$HOSTNAME_NOW" "1970-01-01T00:00:00Z" > "$TARGET.lock/owner"
SHA_LIVE=$(sha_of "$TARGET")
mkrec "$TMP/r4" run-ddd out-4 1 "fourth closure"
T0=$(date +%s)
CREW_APPEND_LOCK_WAIT=2 run_append "$TMP/r4" "$TARGET" > "$TMP/live.out" 2>&1; RCL=$?
T1=$(date +%s)
assert_eq "3.7 live same-host owner: exit 75" "75" "$RCL"
if [ "$((T1 - T0))" -le 8 ]; then pass "3.7 returned within the bound ($((T1 - T0))s for a 2s wait)"; else fail "3.7 returned within the bound ($((T1 - T0))s)"; fi
assert_eq "3.7 nothing written" "$SHA_LIVE" "$(sha_of "$TARGET")"
if [ -d "$TARGET.lock" ]; then pass "3.7 live owner's lock left in place"; else fail "3.7 live owner's lock left in place"; fi
LIVE_RECEIPT=$(ls -1t "$RECEIPTS"/crew-append-receipt-*.md 2>/dev/null | head -1)
assert_file "3.7 timeout left a receipt" "${LIVE_RECEIPT:-/nonexistent}"
if [ -n "${LIVE_RECEIPT:-}" ]; then
  assert_contains "3.7 receipt names the live owner pid" "$LIVE_RECEIPT" "pid=$LIVE"
  assert_contains "3.7 receipt explains why not reclaimed" "$LIVE_RECEIPT" "owner pid still exists on this host"
fi
kill -9 "$LIVE" 2>/dev/null; wait "$LIVE" 2>/dev/null
rm -rf "$TARGET.lock"

# ---------------------------------------------------------------- 3.9
# Foreign-host lock, dead pid: never reclaimed even though the pid is not alive
# here, because the owner is not on this host.
mkdir -p "$TARGET.lock"
printf 'pid=%s\nhost=%s\nstart=%s\n' "999999" "some-other-mac.invalid" "1970-01-01T00:00:00Z" > "$TARGET.lock/owner"
SHA_FOREIGN=$(sha_of "$TARGET")
CREW_APPEND_LOCK_WAIT=2 run_append "$TMP/r4" "$TARGET" > "$TMP/foreign.out" 2>&1; RCF=$?
assert_eq "3.9 foreign-host lock: exit 75" "75" "$RCF"
assert_eq "3.9 foreign-host lock: nothing written" "$SHA_FOREIGN" "$(sha_of "$TARGET")"
if [ -d "$TARGET.lock" ]; then pass "3.9 foreign-host lock never removed"; else fail "3.9 foreign-host lock never removed"; fi
assert_absent "3.9 no reclaim attempted on a foreign host" "$TMP/foreign.out" "RECLAIM stale lock"
FOR_RECEIPT=$(ls -1t "$RECEIPTS"/crew-append-receipt-*.md 2>/dev/null | head -1)
[ -n "${FOR_RECEIPT:-}" ] && assert_contains "3.9 receipt names the foreign host" "$FOR_RECEIPT" "host=some-other-mac.invalid"
[ -n "${FOR_RECEIPT:-}" ] && assert_contains "3.9 receipt states the foreign-host rule" "$FOR_RECEIPT" "a foreign-host lock is never reclaimed"
rm -rf "$TARGET.lock"

# ---------------------------------------------------------------- 3.8
# Writer killed mid-append. Snapshot the intact prefix first so "prior complete
# records preserved byte-for-byte" is a sha256 comparison, not a claim.
cp "$TARGET" "$TMP/prefix.snapshot"
PREFIX_SHA=$(sha_of "$TMP/prefix.snapshot")
PREFIX_BYTES=$(wc -c < "$TMP/prefix.snapshot" | tr -d ' ')
RECORDS_BEFORE=$(n_records)

CREW_APPEND_TEST_PAUSE_MID_APPEND=1 sh "$SCRIPT" "$TMP/r4" "$TARGET" > "$TMP/torn.out" 2>&1 &
TORN=$!
STRAY_PIDS="$STRAY_PIDS $TORN"
if wait_until 5 'grep -q "run=run-ddd outcome=out-4 rev=1 fp=" "$TARGET"'; then
  pass "3.8 partial append landed in the target"
else
  fail "3.8 partial append landed in the target"
fi
TORN_OWNER=$(sed -n 's/^pid=//p' "$TARGET.lock/owner" 2>/dev/null | head -1)
assert_eq "3.8 mid-append owner file records the launched pid" "$TORN" "${TORN_OWNER:-none}"
kill -9 "$TORN" 2>/dev/null
wait "$TORN" 2>/dev/null
wait_until 5 '! kill -0 "$TORN" 2>/dev/null' || true
assert_eq "3.8 fragment is not a record (END count unchanged)" "$RECORDS_BEFORE" "$(n_records)"

run_append "$TMP/r4" "$TARGET" > "$TMP/recover.out" 2>&1; RCV=$?
assert_eq "3.8 re-run exits 0" "0" "$RCV"
assert_contains "3.8 fragment quarantined" "$TMP/recover.out" "QUARANTINED incomplete fragment"
assert_contains "3.8 record then committed" "$TMP/recover.out" "APPENDED key=RECORD host=$HOSTNAME_NOW run=run-ddd outcome=out-4 rev=1"
assert_file "3.8 quarantine file exists" "$TARGET.quarantine"
assert_contains "3.8 quarantine holds the fragment header" "$TARGET.quarantine" "run=run-ddd outcome=out-4 rev=1 fp="
assert_contains "3.8 quarantine carries a note line" "$TARGET.quarantine" "quarantined incomplete fragment"
assert_eq "3.8 exactly one committed record for the key" "1" "$(count_matches "$TARGET" "run=run-ddd outcome=out-4 rev=1 fp=")"
assert_eq "3.8 exactly one more complete record" "$((RECORDS_BEFORE + 1))" "$(n_records)"
head -c "$PREFIX_BYTES" "$TARGET" > "$TMP/prefix.after"
assert_eq "3.8 prior complete records byte-identical" "$PREFIX_SHA" "$(sha_of "$TMP/prefix.after")"

# ---------------------------------------------------------------- invariants
if [ -z "$(ls -1 "$TMP"/crew-performance.md.staging.* 2>/dev/null)" ]; then
  pass "3.X no staging files left behind"
else
  fail "3.X no staging files left behind"
fi
if [ ! -e "$TARGET.lock" ]; then pass "3.X no lock left behind"; else fail "3.X no lock left behind"; fi

finish "fixture 3 (crew-append)"
