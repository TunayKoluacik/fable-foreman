#!/bin/sh
# fable-foreman v0.5 fixture runner.
#
#   sh skills/fable-foreman/tests/run-all.sh
#
# Runs fixtures 1, 2, 3 and 5 of the v0.5 implementation contract and prints one
# PASS/FAIL line per case, then a per-fixture and overall summary. Exits 0 only
# if every case passed. (Fixture 4, the Grok launcher runtime check, is not here:
# it dispatches a real billable worker and is run by hand.)
#
# SAFETY: every fixture works inside its own `mktemp -d` and must never reach
# the real global state. This runner refuses to start if $FOREMAN_HOME or the
# crew-append target could resolve under the real $HOME/.foreman, and it
# fingerprints $HOME/.foreman before and after the run to prove nothing there
# changed.
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
REAL_FOREMAN="$HOME/.foreman"

refuse() { printf 'REFUSING TO RUN: %s\n' "$*" >&2; exit 2; }

# --- guard 1: no inherited environment may point the fixtures at real state ---
if [ -n "${FOREMAN_HOME:-}" ]; then
  RESOLVED=$(cd "$FOREMAN_HOME" 2>/dev/null && pwd) || RESOLVED="$FOREMAN_HOME"
  case "$RESOLVED" in
    "$REAL_FOREMAN"|"$REAL_FOREMAN"/*)
      refuse "FOREMAN_HOME resolves under the real $REAL_FOREMAN. The fixtures must only ever touch scratch state. Unset FOREMAN_HOME and re-run." ;;
  esac
  printf 'note: FOREMAN_HOME is set to %s; fixtures override it with their own mktemp dirs.\n' "$FOREMAN_HOME"
fi

# --- guard 2: no crew-append target may resolve under the real ~/.foreman ---
for VAR in "${CREW_APPEND_TARGET:-}" "${FOREMAN_CREW_TARGET:-}" "${CREW_APPEND_RECEIPT_DIR:-}"; do
  [ -n "$VAR" ] || continue
  case "$VAR" in
    "$REAL_FOREMAN"|"$REAL_FOREMAN"/*|*/.foreman/crew-performance.md)
      refuse "a crew target env var points at real global state ($VAR)." ;;
  esac
done

# --- guard 3: refuse if the real global record is somehow already locked by us -
if [ -e "$REAL_FOREMAN/crew-performance.md.lock" ]; then
  printf 'note: %s/crew-performance.md.lock exists; the fixtures will not touch it.\n' "$REAL_FOREMAN"
fi

# --- baseline fingerprint of the real ~/.foreman ------------------------------
snapshot_real() {
  if [ -d "$REAL_FOREMAN" ]; then
    find "$REAL_FOREMAN" -type f -exec shasum -a 256 {} \; 2>/dev/null | sort
  else
    printf 'ABSENT\n'
  fi
}
BEFORE_SNAP=$(snapshot_real)

# ------------------------------------------------------------------------------
FIXTURES="fixture-1-init-ledger.sh fixture-2-probe.sh fixture-3-crew-append.sh fixture-5-precedence.sh"
TOTAL_FAIL=0
SUMMARY=""

for F in $FIXTURES; do
  printf '\n===== %s =====\n' "$F"
  if sh "$HERE/$F"; then
    SUMMARY="$SUMMARY
  PASS  $F"
  else
    SUMMARY="$SUMMARY
  FAIL  $F"
    TOTAL_FAIL=$((TOTAL_FAIL + 1))
  fi
done

# --- prove the real global state is untouched ---------------------------------
AFTER_SNAP=$(snapshot_real)
printf '\n===== safety check =====\n'
if [ "$BEFORE_SNAP" = "$AFTER_SNAP" ]; then
  printf 'PASS  real %s unchanged by the run (sha256 of every file compared)\n' "$REAL_FOREMAN"
else
  printf 'FAIL  real %s CHANGED during the run\n' "$REAL_FOREMAN"
  TOTAL_FAIL=$((TOTAL_FAIL + 1))
fi

printf '\n===== summary =====%s\n' "$SUMMARY"
if [ "$TOTAL_FAIL" = "0" ]; then
  printf 'ALL FIXTURES PASSED (1, 2, 3, 5)\n'
  exit 0
fi
printf '%s FIXTURE(S) FAILED\n' "$TOTAL_FAIL"
exit 1
