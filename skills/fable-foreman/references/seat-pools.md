# Seat pools: parallel dispatch across subscriptions and local inference

A **pool** is one quota boundary: one subscription or account on one provider, one metered API key, or
one local inference server. Rate limits and quotas are per pool, so the skill's "sequential by default"
rule is a *per-pool* rule — dispatching to two different pools at once costs neither of them anything
extra. This file is the procedure for finding the pools a session can reach, recording them, and
scheduling across them.

## Step 0 addition — enumerate pools (once per session, cache in the ledger)

Probe every seat family reachable from the session; each yields zero or more pools:

1. **The session's own provider** — the LEAD family. Its subagent seats share the session's quota:
   one pool.
2. **Other-provider CLIs** — probe → consent → tier discovery as in codex-workers.md and grok-workers.md
   (the worked examples). Each authenticated account is one pool. Two accounts on the same provider are
   two pools; a provider's parallel ceiling (SKILL.md Step 0) is that pool's concurrency.
3. **Provider bridges exposed as tools** (an MCP or plugin that answers model queries under a separate
   subscription): one pool per bridge. Use its own usage/quota tool if it has one before dispatching;
   the consent rule is the same as for a CLI — it spends a separate subscription.
4. **Local inference servers** — anything answering an OpenAI- or Anthropic-compatible endpoint on
   the machine (`/v1/models` on the configured port). One pool per server, **concurrency 1** unless the
   server documents parallel slots *and* the machine has the RAM for them. A local pool spends no money;
   it spends wall-clock, thermal headroom and memory that the user's other jobs may need.

Record the registry in `.foreman/ledger.md`:

| pool | family | account / endpoint | billing | verified seats → class | concurrency | quota left | consent |
|---|---|---|---|---|---|---|---|

"Verified" means one tiny call succeeded on that seat this session. A pool with no verified seat is not
dispatchable.

## Local seats and the First Law

Local models get a capability class **only from evidence measured on this machine**: a probe or gate
the project ships, a prior benchmark record, or a pilot ticket whose output the blind verifier passed.
Absent evidence, a local seat is FAST at most (scanning, extraction, mechanical edits) and never a
verifier of anything except deterministic checks it can run. Cross-family verification applies: a
cloud seat verifies local work. If no local seat clears a task's bar, the task goes to a cloud pool —
never to a local seat because it is free.

Local-specific limits to check before every dispatch (as of 2026-09; verify on your machine):

- **Throughput and ceilings**: decode speed on CPU-only machines is often single-digit to low
  double-digit tokens per second; prefill of a large harness system prompt can take minutes. Pin the
  harness + server combinations that passed the project's gate; a harness stream watchdog can abort a
  slow prefill. Set the ticket's expected wall time from the probe's numbers, not from cloud habits.
- **Residency**: one model resident at a time on laptop-class RAM. Switching models is a load, not a
  call — batch tickets per model.
- **Contention**: a local pool that is running the user's own benchmark or build is **unavailable**;
  check for a running server or job before starting one, and never kill one you did not start.
- **Thermals**: sustained load throttles; if the machine reports a speed limit below 100 %, expect
  the probe's numbers to be optimistic.

Consent: a local pool needs consent when the machine is also the user's workstation or benchmark rig
(the dispatch competes with their work); otherwise state that a local server will be started, which
model, and on which port.

## Scheduling across pools

- **Within a pool: sequential.** One in-flight ticket per pool unless its concurrency is verified higher.
- **Across pools: parallel is free of quota contention.** Independent tickets with disjoint write sets
  go to different pools concurrently. Announce the fan-out as usual: crew size, pools, seats, why.
- **Class first, pool second.** Resolve a ticket's class (routing.md), then pick the pool holding a
  verified seat of that class with the most quota left; prefer cross-family pairing for build/verify.
- **Same-class tickets, several pools**: round-robin by remaining quota, not by provider preference.
- **Shared-quota traps**: a subagent and the session share one pool; a second-provider CLI and that
  provider's bridge tool may share one account. Two entries that share a quota boundary are one pool —
  merge them in the registry.
- **Local pools in a parallel wave**: one ticket per local pool, sized to its measured speed; do not
  wait on it to advance cloud tickets — collect it like a background job.

## Failure and rerouting

- Rate-limit or quota exhaustion in a pool: stop dispatching to it, move the remaining tickets of that
  class to another pool with a verified seat of the same class, log the move. Never step the class down
  to stay in a cheaper pool (First Law).
- Local server crash or silence: LOST protocol (delegation.md); restart the server once; a second
  failure marks the pool unavailable for the run.
- A pool that refuses a task on policy grounds is a blocker to surface, not a reason to try the next
  pool (hard rail 2).

## Ticket and readback

Unchanged. Any worker harness that honors a base-URL environment variable can run a ticket against a
local pool; the ticket still travels as a file, the report still opens with one status, the verifier
still opens with one verdict.
