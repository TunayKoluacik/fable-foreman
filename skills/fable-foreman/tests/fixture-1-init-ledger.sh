#!/bin/sh
# Fixture 1 (contract "Fixtures before acceptance" item 1) — init-ledger.sh.
#
#   * a fresh directory gets a ledger carrying the new ledger-v2 sections
#     (## Current, ## Reservations, ## Crew record) and a BASELINE line with
#     run=, host= and schema=ledger-v2;
#   * a second invocation exits 0, prints EXISTS, and leaves the file
#     byte-identical (sha256 compared, not eyeballed);
#   * a directory that is not a git repository still works.
#
# Hermetic: everything happens under one mktemp -d, removed on exit. Nothing is
# read from or written to $HOME.
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/lib.sh"
SCRIPT="$HERE/../scripts/init-ledger.sh"

TMP=$(mktemp -d "${TMPDIR:-/tmp}/foreman-fx1.XXXXXX") || exit 1
trap 'rm -rf "$TMP"' EXIT INT TERM

# ---------------------------------------------------------------- case 1.1
# Fresh, non-git directory.
mkdir -p "$TMP/nogit"
OUT=$( cd "$TMP/nogit" && sh "$SCRIPT" "fixture one run" ".foreman" 2>&1 ); RC=$?
LEDGER="$TMP/nogit/.foreman/ledger.md"

assert_eq "1.1 fresh dir: exit 0" "0" "$RC"
case "$OUT" in *CREATED:*) pass "1.1 fresh dir: prints CREATED" ;; *) fail "1.1 fresh dir: prints CREATED (got: $OUT)" ;; esac
assert_file "1.1 fresh dir: ledger created" "$LEDGER"
assert_contains "1.1 ledger has ## Current"      "$LEDGER" "## Current"
assert_contains "1.1 ledger has ## Reservations" "$LEDGER" "## Reservations"
assert_contains "1.1 ledger has ## Crew record"  "$LEDGER" "## Crew record"
assert_contains "1.1 Current has Missing gate placeholder"   "$LEDGER" "- Missing gate:"
assert_contains "1.1 Current has Held surfaces placeholder"  "$LEDGER" "- Held surfaces:"
assert_contains "1.1 Reservations name LAUNCH UNKNOWN"       "$LEDGER" "LAUNCH UNKNOWN"
assert_contains "1.1 Reservations state the line format"     "$LEDGER" "token | outcome id | write set | requested route | identity-after-launch"
assert_contains "1.1 Crew record names crew-append.sh"       "$LEDGER" "crew-append.sh"
assert_contains "1.1 Crew record has route hypothesis"       "$LEDGER" "Route hypothesis:"
assert_contains "1.1 BASELINE carries schema=ledger-v2"      "$LEDGER" "schema=ledger-v2"
# run= must be 8 hex chars and host= non-empty, on the BASELINE line itself.
if grep -Eq '^BASELINE: .* \| run=[0-9a-f]{8} host=[^ ]+ schema=ledger-v2$' "$LEDGER"; then
  pass "1.1 BASELINE carries run=<8-hex> host=<hostname>"
else
  fail "1.1 BASELINE carries run=<8-hex> host=<hostname> (got: $(grep '^BASELINE:' "$LEDGER"))"
fi
assert_contains "1.1 non-git baseline recorded as such" "$LEDGER" "no git repository"

# ---------------------------------------------------------------- case 1.2
# Second invocation: exit 0, EXISTS, byte-identical.
BEFORE=$(sha_of "$LEDGER")
OUT2=$( cd "$TMP/nogit" && sh "$SCRIPT" "a different title" ".foreman" 2>&1 ); RC2=$?
AFTER=$(sha_of "$LEDGER")
assert_eq "1.2 existing ledger: exit 0"        "0" "$RC2"
case "$OUT2" in *EXISTS:*) pass "1.2 existing ledger: prints EXISTS" ;; *) fail "1.2 existing ledger: prints EXISTS (got: $OUT2)" ;; esac
assert_eq "1.2 existing ledger: byte-identical" "$BEFORE" "$AFTER"

# ---------------------------------------------------------------- case 1.3
# A real git repository: baseline recorded, gitignore note emitted when the
# ledger directory is not ignored.
mkdir -p "$TMP/repo"
( cd "$TMP/repo" && git init -q . && git config user.email t@example.invalid && git config user.name t ) >/dev/null 2>&1
OUT3=$( cd "$TMP/repo" && sh "$SCRIPT" "git run" ".foreman" 2>&1 ); RC3=$?
LEDGER3="$TMP/repo/.foreman/ledger.md"
assert_eq "1.3 git repo: exit 0" "0" "$RC3"
assert_file "1.3 git repo: ledger created" "$LEDGER3"
assert_contains "1.3 git repo: unborn HEAD recorded" "$LEDGER3" "unborn (no commits yet)"
assert_contains "1.3 git repo: has ## Current" "$LEDGER3" "## Current"
case "$OUT3" in *"is not gitignored"*) pass "1.3 git repo: gitignore note preserved" ;; *) fail "1.3 git repo: gitignore note preserved (got: $OUT3)" ;; esac

# ---------------------------------------------------------------- case 1.4
# The scratch directory the ledger points at is really created.
if [ -d "$TMP/nogit/.foreman/scratch" ]; then pass "1.4 scratch dir created"; else fail "1.4 scratch dir created"; fi

finish "fixture 1 (init-ledger)"
