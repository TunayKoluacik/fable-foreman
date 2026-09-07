# Changelog

## 0.5.0 — 2026-09-07

The "policy reconciliation" release. Every rule that let a provider family, a
billing tier, or a fixed effort level stand in for a judgment is replaced by the
judgment itself: the lead accepts, reviewers supply evidence, and seats are
qualified by what they can actually do. Recovery becomes outcome-bound and parks
instead of halting, and the crew starts keeping a performance record. Written
against an adjudicated implementation contract that resolved nine findings from
an independent review, three of them as amendments.

### Changed
- **Acceptance and reviewer qualification** (SKILL.md, `references/verification.md`,
  `references/model-matrix.md`, `agents/foreman-verifier.md`, README) — the lead
  accepts; a reviewer verdict supplies evidence, never acceptance; a reviewer
  verdict alone is never acceptance proof. Reviewer qualification is model +
  transport + allowed tools + assigned checks. Every required deterministic
  observation names its executor: a no-shell reviewer reasons over the candidate
  and the check artifacts while the lead or a designated capable executor runs
  the candidate-bound checks, and an unrun check stays UNVERIFIED. The Claude
  reviewer stays the *default* evidence seat, described honestly as
  contract-plus-detection (a no-edit tool contract plus a mutation backstop),
  not a sandbox.
- **Family bars removed** — all three families are eligible for any role when
  qualified. The "never the accepting verdict" and "advisory only" clauses that
  barred Grok, and the billed-tier authority bar, are replaced by *disclosure*:
  seat-evidence tier is recorded and weighed, never used to disqualify. Grok's
  sandbox protections and the citation-verification rule are unchanged.
- **Effort by lead judgment** (`references/routing.md`, `references/model-matrix.md`,
  `references/grok-workers.md`, `references/codex-workers.md`, SKILL.md) — fixed
  `xhigh`/`medium`/`high` prescriptions are gone from the role table, Table 5, and
  the worker references. Effort is chosen per dispatch by the lead, with the
  highest supported level as the no-evidence prior for Grok and the performance
  record as the evidence that revises it; discretion applies only where model and
  transport support it. The CursorBench effort tradeoff stays as a dated,
  SECONDARY prior with unproved cross-family transfer.
- **Personal final verification** (SKILL.md, `references/verification.md`) —
  independent reviewers supply evidence and challenge; their PASS does not
  transfer acceptance responsibility from the lead, who inspects the actual
  candidate, reconciles original requirements to evidence, adjudicates
  consequential findings, and personally checks critical behavior, material gaps,
  and disputed claims. A required observation that cannot be made is reported
  incomplete.
- **Behavior-test review trigger** — the "single-file, no logic content" review
  exemption is replaced by a behavior test: a change that cannot alter behavior
  may skip independent review; anything that can may not.
- **Outcome-bound recovery with park-and-continue** (`references/delegation.md`) —
  four separate counts keyed on outcome id (delivery attempts, fix waves, review
  rounds, recovery 0 or 1), evaluated guards-first: authority and ownership,
  then outcome state, then original-outcome limits, then failure attribution.
  Two failed fix waves buy exactly one reserved, diagnosed, changed recovery; a
  failed recovery parks the outcome as `NEEDS USER` with evidence, missing
  criterion, concrete question, and resume condition. Dependents are parked with
  their links, independent authorized work continues, and the run halts only when
  none remains. Renames, splits, re-seats, corrected tickets, and restarts never
  reset a count; a third ticket correction without a new observation counts as a
  real failure. Hard rail 6's re-dispatch now defers to the recovery/park state.
- **Review rounds** — after two rounds the lead writes a per-finding disposition;
  a third round needs a named unresolved criterion, a finite question, and a
  stopping observation; there is no automatic fourth, and round exhaustion never
  creates acceptance.
- **Builder ownership and role transitions** (`references/delegation.md`,
  `references/verification.md`) — the builder makes the WIP commit on the working
  branch and reports the hash; the lead checks clean tree and HEAD. Same builder
  first when resumable (Claude via harness continuation, Grok via launcher
  resume); Codex fresh dispatch is replacement with preserved contract, findings,
  and evidence. A reviewer never changes the candidate it is judging within the
  same assignment; a role change is an explicit journaled writable dispatch, the
  earlier verdict does not cover the new edits, affected checks are re-run, and a
  different fresh context assesses the repaired revision.
- **Plan-stage different-family challenge** — a substantial plan gets an
  off-family challenge that replaces the planned *architecture* review only.
  Candidate-specific post-build assurance is still required; a duplicate
  off-family post-build read may be omitted only with a written risk rationale.
- **Mid-tier lead** (`references/routing.md`) — when the lead is mid-tier the
  acceptance judgment must be frontier-qualified: pin a frontier seat for it or
  stop. Routine reviewers are not all promoted to frontier.
- **Factual claims corrected** — cache reuse is not guaranteed (record telemetry
  when exposed); fifteen concurrent workers is a *reported* default ceiling, not
  a measured maximum; provider telemetry with missing raw values is recorded as
  `unavailable`; a launcher `CONTEXT ALERT` is an average-based routing warning,
  never per-call billing proof; the rail-5 claim is narrowed to the common
  unverified path.
- **README** mirrors all of the above; the v0.3/v0.4 descriptions are kept and
  labelled as history rather than deleted.

### Added
- **A user-authorized global performance record** at `~/.foreman/crew-performance.md`
  with `scripts/crew-append.sh` — one self-delimited record per closed outcome
  (record key of host, run id, outcome id, closure revision, plus a content
  fingerprint and matching end-marker), bounded lock acquisition with a local
  receipt instead of an indefinite block, stale-lock reclaim only for a provably
  dead same-host owner, staged and fsynced appends with trailing-fragment
  quarantine, no-op on identical duplicates and a conflict exit on a same-key
  different-content record, and corrections appended as new rows. The lead reads
  the relevant slice before a comparable dispatch; no cross-machine sync is
  assumed. The record refuses to conclude universal provider rankings, accuracy
  without a denominator, served identity from self-report, or savings from one
  uncontrolled campaign.
- **Ledger sections** — `scripts/init-ledger.sh` now emits `## Current`
  (overwritten; parked questions and held write surfaces), a reservation section
  (a line before every dispatch, seat identity appended after, `LAUNCH UNKNOWN`
  reconciled before release), and a per-run crew record with run id, host, and
  schema version. The atomic exclusive create and the exit-0 `EXISTS` behavior on
  an existing ledger are preserved.
- **Probe output** — `scripts/probe.sh` reports Grok effort as "lead judgment per
  dispatch (no-evidence prior: highest supported)" instead of a fixed level.

### Deliberately NOT changed
- **The launchers.** `scripts/grok-dispatch.sh` and `scripts/codex-dispatch.sh`
  are untouched in this release, sandbox profiles and all.
- **Grok's sandbox and the citation contract.** Removing the family bar does not
  relax either.
- **The First Law**, the 3x expected-runtime worker timeout, and the ledger's
  append-only discipline.

### Known follow-up (not in this release)
- `scripts/grok-dispatch.sh:236` still prints "every call was repriced" where it
  means "the average exceeded 200K; individual calls may or may not have been
  repriced." Corrected in a separate ticket so the launchers stay untouched here.

## 0.4.0 — 2026-08-18

The "know what a seat costs" release. Adds xAI Grok as a third worker provider,
gives routing a dated cost/capability evidence table, and makes review findings
citable and self-correcting. Hardened by an adversarial review from Grok itself,
which returned VERDICT:REVISE with four blockers — three were conceded and the
plan was cut back accordingly.

### Added
- **`references/model-matrix.md`** — the evidence table behind seat selection:
  price, capability index, context ceilings, cache discounts, effort payoff, and
  task-type placement, each dated and sourced. Includes real per-dispatch cost
  comparisons and the finding that list prices are an *upper bound* on
  subscription-metered accounts.
- **Grok worker support** — `references/grok-workers.md`,
  `scripts/grok-dispatch.sh` (fixed-argv launcher), and
  `agents/foreman-grok-wrapper.md` (transport wrapper).
- **The finding contract** (delegation.md) — every reviewer, any provider, tags
  each finding `QUOTED` / `OBSERVED` / `DERIVED` / `INFERRED` and shows its
  citation. Seats are never asked to self-rate confidence.
- **Finding triage** (verification.md) — the foreman resolves citations before
  grading code; unsupported findings are dismissed and journaled, and one
  fabricated citation taints its whole report.
- **Self-correction** (delegation.md) — confirmed findings go to a fix worker and
  then a *fresh* verifier, automatically. The verifier never edits. Bounded by the
  existing precedence table. Stopping remains reserved for: an ask that was
  advisory in the first place (a review is not a licence to implement), a design /
  architecture / security-posture choice or user-visible contract change the user
  owns, external blockers, destructive actions, policy refusals, or a bar no seat
  clears.
- **`BILLED` evidence tier** (verification.md) — ranked below `SERVED`, for
  provider accounting like Grok's `modelUsage`. It never makes a seat `verified`.
- Grok detection in `scripts/probe.sh` (presence, version, auth mode, cached
  model ids — no billable call, no credential values printed).
- **Opt-in Codex standing pre-approval** — a machine-local flag
  (`~/.foreman/codex-preapproved` or `FOREMAN_CODEX_PREAPPROVED=1`), reported by
  `scripts/probe.sh`, lets a user skip the per-session Codex consent ask and
  exempt Codex from budget step-down. The published default is unchanged: the
  consent rule applies.

- **Route to what is actually there** (SKILL.md) — mode (harness capabilities) and
  provider pool are now two independent axes instead of an enumerated combination
  table. Any subset works: Claude-only, Claude+Codex, Claude+Grok, or all three.
  Absence is a routing input, never a blocker, and the foreman never asks the user
  to install a provider mid-run. Includes the case where mode and pool intersect to
  leave no legal acceptor — handled by a disclosed reduced-assurance rule, not a stall.

### Changed
- Seat routing now consults the matrix for the seat *within* a class, and prefers
  off-family workers for bulk implementation because Claude workers drain the same
  allowance the foreman itself runs on.
- Effort guidance is now task-shape aware: analysis/review curves are nearly flat
  (prefer `medium`), long-horizon coding is steep (prefer `high`).
- Grok launcher switches Claude-config discovery off at the source
  (`GROK_CLAUDE_*_ENABLED=false`) and passes `--no-subagents`.
- Launcher measures average prompt size per model call (the json envelope sums
  uncached input across turns); the reactive 200K rule is reworded to a decidable
  context-set rule.
- Wrapper relay is treated as a claim — pinned read-only extraction commands in
  both wrapper contracts; the foreman reads artifacts directly.
- Isolation documented honestly for macOS: no child-network block, whole-disk
  reads, writes-only confinement; Grok `workspace` is weaker than Codex
  `workspace-write`.
- Table 3 percentages corrected (Sonnet 44/45/46% cheaper, not 79/82/84%); the
  cost note corrected to the observed flat 0.17x-of-list pool rate; Table 2 notes
  the Anthropic cache-write premium.
- Launcher absolutizes paths and guards arity; `codex-dispatch.sh`'s evidence
  scanner initializes `candidate` (it raised NameError on every real stream).
- One acceptor stated consistently everywhere: the accepting verdict is always
  the Claude verifier; a Codex read-only reviewer is a second opinion.

### Deliberately NOT changed
- **The First Law is untouched.** An earlier draft would have made it
  "pool-aware" so quota pressure could move the quality bar. The adversarial
  review called that institutionalizing a past failure, and it was dropped.
- **Grok cannot hold a verifier verdict.** Its seat evidence is billed-tier, not
  served-tier, so it is an advisory reviewer and second opinion only.

## 0.3.0 — 2026-08-07

The "trust the log, see the crew" release. Derived from a comparative study of
[claudemix](https://github.com/hughminhphan/claudemix), hardened through three
rounds of adversarial review by OpenAI's frontier Codex model (16 findings →
fixed or explicitly disclosed), and live-tested head-to-head against v0.2.0.

### Added
- **Layer 0 seat provenance** (`references/verification.md`): which model
  actually served a dispatch is graded by deterministic evidence in three
  tiers — SERVED > ROUTED > REQUESTED — never by a worker's self-report.
  Dispatches without real evidence are honestly ledgered `seat: unverified`.
- **Visible-subagent Codex transport** (`references/codex-workers.md`): Codex
  jobs run inside harness-visible wrapper subagents by default — live presence
  in the UI, completion notifications instead of polling, foreman stays free
  during long builds. Direct exec remains the documented fallback for
  sub-minute calls and Codex-only mode.
- **`scripts/codex-dispatch.sh`** — fixed-argv Codex launcher: validates every
  argument, constrains artifact paths (no symlinks, no ticket aliasing),
  records the child PID for orphan control, forwards termination signals, and
  reports seat evidence honestly (current Codex CLI emits no served-model
  field; the launcher says so instead of inventing one).
- **`scripts/probe.sh`** — deterministic Step 0 probe (Codex presence/auth/
  billing mode, native-transport facts, git baseline) with secrets redacted
  from output.
- **`scripts/init-ledger.sh`** — atomic, injection-hardened ledger bootstrap
  that refuses to clobber an existing ledger.
- **`agents/foreman-codex-wrapper.md`** — bundled transport-wrapper role with
  a machine-narrowed tool list (no edit tools, no agent spawning).
- **`references/setup-runbook.md`** — agent-executable, evidence-verified
  environment setup; optional consent-gated native-GPT-subagent transport
  (claudemix-style splitter) with supply-chain pinning rules and honest
  security/ToS statements.
- **Silent-fallback hazard** documentation (`references/routing.md`) with
  current-build empirical results: what silently substitutes, what fails
  loudly, and the countermeasures.

### Changed
- Hard rails: added rail 5 (seat provenance) and a tightly-scoped transport
  carve-out to rail 1 (the wrapper may invoke the launcher exactly once).
- Behavioral anomaly is now a *trigger* for a provenance check, never itself
  evidence of which model served.
- Detected seat substitution is classified as a transport/routing failure with
  its own escalation path (never free same-seat retries).

### Known limitations (disclosed, not hidden)
- Current Codex CLI provides no served-model metadata, so Codex seats remain
  `unverified` at the SERVED tier until the CLI emits it — the launcher already
  scans version-tolerantly for the day it does.
- The wrapper-must-use-the-launcher rule is contractual and transcript-
  auditable; machine prevention requires harness-level tool policy.

## 0.2.0 — 2026-07-19

- Frontier-class LEAD seat parity: any frontier Claude (Fable, Opus) runs the
  foreman identically; Step 0 probe cache expires on mid-run model change.

## 0.1.0 — 2026-07-14

- Initial release: capability-class routing (FRONTIER/WORKHORSE/FAST),
  ticket/status delegation contract, blind fresh-context verification,
  append-only ledger, Codex CLI worker integration.
