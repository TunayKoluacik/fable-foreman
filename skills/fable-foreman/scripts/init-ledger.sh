#!/bin/sh
# fable-foreman — ledger bootstrap.
# Usage: init-ledger.sh "<task title>" [ledger-dir]
# Idempotent: refuses to overwrite an existing ledger (resume runs must
# reconcile, not reset — delegation.md). Fails loudly and nonzero on any error;
# creation is atomic (noclobber) so concurrent invocations cannot clobber.
set -eu

RAW_TITLE="${1:-untitled run}"
DIR="${2:-.foreman}"
LEDGER="$DIR/ledger.md"

# Strip control characters (incl. newlines) so a title cannot forge ledger
# sections that get trusted after compaction.
TITLE=$(printf '%s' "$RAW_TITLE" | tr -d '\000-\037\177')

if [ -f "$LEDGER" ]; then
  echo "EXISTS: $LEDGER — reconcile against the tree before dispatching (delegation.md). Not overwriting."
  exit 0
fi

mkdir -p "$DIR/scratch"

if git rev-parse --git-dir >/dev/null 2>&1; then
  HASH=$(git rev-parse -q --verify HEAD 2>/dev/null) || HASH=""
  [ -n "$HASH" ] || HASH="unborn (no commits yet)"
  STATUS=$(git status --porcelain)   # set -e aborts here if git fails
  DIRTY=$(printf '%s' "$STATUS" | grep -c . || true)
else
  HASH="no git repository"
  STATUS=""
  DIRTY=0
fi

# Run identity. RUN_ID is the stable key every crew record and every global
# append is keyed on (with host and outcome id); it must not be derived from
# the title or the path, or two runs on one task would collide.
if [ -r /dev/urandom ]; then
  RUN_ID=$(od -An -tx1 -N4 /dev/urandom | tr -d ' \n')
else
  RUN_ID=""
fi
[ -n "$RUN_ID" ] || RUN_ID=$(printf '%08x' "$$")
RUN_HOST=$(hostname 2>/dev/null) || RUN_HOST=$(uname -n)
[ -n "$RUN_HOST" ] || RUN_HOST="unknown-host"

TMP=$(mktemp "$DIR/.ledger-tmp.XXXXXX")
{
  printf '# Foreman Ledger — %s\n' "$TITLE"
  printf 'BASELINE: %s | %s dirty files | %s | run=%s host=%s schema=ledger-v2\n' \
    "$HASH" "$DIRTY" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$RUN_ID" "$RUN_HOST"
  printf '\n### Baseline worktree state (git status --porcelain, verbatim)\n```\n%s\n```\n' "$STATUS"
  printf '\n## Plan\n\n## Routing\n\n## Tasks\n\n## Attempts\n'

  # Overwritten in place every time the run state changes — this section is the
  # answer to "where does this stand", and it is the first thing read after a
  # compaction. Placeholders below are replaced, never appended to.
  printf '\n## Current\n'
  printf -- '- Outcome: <outcome id — the unit all four counts are keyed on>\n'
  printf -- '- State: <planned | dispatched | in review | recovery | NEEDS USER (parked) | accepted>\n'
  printf -- '- Owner: <who holds the write surface right now>\n'
  printf -- '- Active workers: <seat + identity + pid/session id, or none>\n'
  printf -- '- Next action: <the single next dispatch or check>\n'
  printf -- '- Missing gate: <the criterion still unmet, or none>\n'
  printf -- '- Parked: <parked outcome ids with their concrete question and resume condition, or none>\n'
  printf -- '- Held surfaces: <paths still held because a writer may be live, or none>\n'

  # A reservation is written BEFORE launch, so a launch whose result is unknown
  # is still reconcilable. Identity is appended AFTER the launch returns.
  printf '\n## Reservations\n'
  printf -- '<One line per dispatch, written before launch:\n'
  printf -- '  token | outcome id | write set | requested route | identity-after-launch\n'
  printf -- ' The first four fields are written before the process starts. The fifth is\n'
  printf -- ' appended once the launcher reports the served identity. A reservation with\n'
  printf -- ' no identity field is LAUNCH UNKNOWN: the write set stays held and must be\n'
  printf -- ' reconciled against live processes before any re-dispatch (delegation.md).>\n'

  # One block per dispatched run. Fields that were never observed are recorded
  # as "unavailable" — an absent measurement is never rendered as a zero.
  printf '\n## Crew record\n'
  printf -- '<One block per run, schema ledger-v2:\n'
  printf -- '  outcome/attempt | role/task-shape/risk | candidate | worker identity |\n'
  printf -- '  requested/served model+effort | env | start/checkpoint/end |\n'
  printf -- '  result/coverage | adjudicated defects | cause | reviewer identity |\n'
  printf -- '  times (time-to-acceptance, execution, waiting — separately) |\n'
  printf -- '  usage-or-unavailable (tokens, cache, output, reported cost, evidenced\n'
  printf -- '  charge, quota — each "unavailable" when not observed)\n'
  printf -- ' Route hypothesis: <route> because <reason>; keep-or-change: <decision>;\n'
  printf -- ' overturning observation: <what would change it>; proof: <links>.\n'
  printf -- ' At closure, append the run summary to the global performance record with\n'
  printf -- ' scripts/crew-append.sh (serialized, idempotent on host+run+outcome+rev;\n'
  printf -- ' corrections are new records with a higher rev, never rewrites).>\n'

  printf '\n## Decisions\n<Codex billing mode; seat changes; degradations>\n\n## Scratch\n%s/scratch/\n' "$DIR"
} > "$TMP"

# Atomic exclusive create via hard link: the full content is already safely in
# TMP (same directory, same filesystem), and link(2) either publishes it whole
# under the ledger name or fails because the name exists — there is no partial-
# ledger state and no way to mistake our own failed write for a concurrent
# creation (the failure mode Codex round-3 finding 9 identified in the
# noclobber approach).
if ln "$TMP" "$LEDGER" 2>/dev/null; then
  rm -f "$TMP"
  echo "CREATED: $LEDGER (baseline: $HASH, $DIRTY dirty files, run=$RUN_ID host=$RUN_HOST schema=ledger-v2)"
  # The ledger lives in the project being worked on. If it is not ignored there,
  # the verifier's clean-tree check can never pass (verification.md).
  if git rev-parse --git-dir >/dev/null 2>&1; then
    git check-ignore -q "$DIR" 2>/dev/null \
      || echo "NOTE: $DIR is not gitignored — add '$DIR/' to .gitignore or .git/info/exclude so the verifier's clean-tree check stays meaningful (delegation.md)"
  fi
elif [ -e "$LEDGER" ]; then
  rm -f "$TMP"
  echo "EXISTS (created concurrently): $LEDGER — reconcile, do not overwrite."
  exit 0
else
  rm -f "$TMP"
  echo "ERROR: could not create $LEDGER (link failed, file absent — permissions or I/O)" >&2
  exit 1
fi
