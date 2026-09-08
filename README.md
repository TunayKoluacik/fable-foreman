# Fable Foreman: Turn Claude Fable into your agent orchestrator

Fable Foreman teaches Claude Fable or Opus, the lead, to plan coding work, assign it to capable agents, and personally verify the result. The lead stays responsible for the outcome while smaller, lower-cost workers handle suitable implementation, testing, and repairs.

This repository is free under the MIT license. Claude Code is required for full orchestration; Codex and Grok are optional.

## What it helps you do

### Choose the right agents for the work

The lead considers task complexity, available tools, cost, and prior results before assigning a worker. It can use Claude, Codex, or Grok agents, with lower-cost agents handling work they are suited to do.

### Keep track of the whole project

The lead creates a working record for assignments, decisions, completed work, and unresolved problems. It uses that record to make better-informed decisions and assignments as the work continues.

### Get repairs handled without managing every handoff

When review finds a problem, the lead sends the repair back to the original builder when possible. If an approach keeps failing, it changes the approach. Work that needs your input is recorded clearly while independent work continues.

### Verify what was actually delivered

Meaningful changes receive independent review. The Fable or Opus lead then checks the actual result against your request, personally verifies critical behavior, and tells you what is complete and what still needs attention.

## How it works

1. **Describe the result you want.** Ask for a feature, bug fix, refactor, or help planning a project. The lead identifies the work and how it will know the result is ready.
2. **Let the lead assign the work.** It gives suitable agents a clear task, ownership, and checks. Small tasks stay simple; independent work can run in parallel when useful.
3. **Review, repair, and verify.** Workers return their results and evidence. The lead arranges independent review, resolves confirmed problems, and personally checks the finished work before accepting it.
4. **Get a clear handoff.** See what changed, how it was checked, and anything still unresolved. You retain control over publishing, deployment, and other actions that need your approval.

Try this:

```text
Use /fable-foreman to build the feature described in PLAN.md. Choose suitable agents, keep track of the work, and personally verify the finished result. Ask me before deploying.
```

## Install

**Claude Code — recommended.** Paste this into a Claude Code session:

```text
Install Fable Foreman globally from https://github.com/olsenbrands/fable-foreman. Preserve my existing skills and agents, then verify that the skill folder and all five Fable Foreman agent definitions are installed.
```

Or install it manually after cloning the repository:

```bash
mkdir -p ~/.claude/skills ~/.claude/agents
cp -R skills/fable-foreman ~/.claude/skills/
cp agents/*.md ~/.claude/agents/
```

Both copies are required. The skill calls `foreman-scout`, `foreman-worker`, `foreman-verifier`, `foreman-codex-wrapper`, and `foreman-grok-wrapper` by name. Installing only the skill folder does not provide delegation or independent verification.

**Claude Desktop and claude.ai.** Package the skill folder as a ZIP and upload it through **Settings → Customize → Skills** with code execution enabled. Claude Desktop has a reduced workflow because it does not provide the Agent tool: the skill uses separate plan, execute, and self-review passes in one conversation, rather than full delegated orchestration. See Anthropic's [skills guide](https://support.claude.com/en/articles/12512180-use-skills-in-claude) for current availability and setup details.

## Before you start

**Does it work with Opus?** Yes. Fable or Opus can lead the workflow. The lead plans, assigns, supervises, and makes the final acceptance decision.

**Do I need Codex or Grok?** No. Claude agents can run the workflow on their own. Codex and Grok add options when they are installed and logged in.

**Will it reduce my AI costs?** It is designed to spend effort where it helps: capable lower-cost workers for suitable tasks, focused review, and fewer repeated handoffs. Actual cost depends on the work, models, and repairs. Savings are not guaranteed.

**Does the skill include AI usage?** No. Your existing Claude, Codex, or Grok accounts provide the models and cover their usage. Before the first billable Codex or Grok dispatch, the skill asks for authorization unless you already authorized that provider in the session or configured your own optional standing pre-approval. Read the [provider setup and consent details](skills/fable-foreman/SKILL.md#step-0--probe-the-job-site-once-per-session-then-cache--re-probe-on-model-change).

**Do I have to manage the workers myself?** No. The lead handles assignments, progress checks, review, and routine repairs within your instructions. It brings you decisions that need your input and keeps independent work moving.

## Learn more

- [Skill workflow](skills/fable-foreman/SKILL.md)
- [Routing guidance](skills/fable-foreman/references/routing.md)
- [Verification protocol](skills/fable-foreman/references/verification.md)
- [Release history and current limitations](CHANGELOG.md)

## License

MIT © Jordan Olsen
