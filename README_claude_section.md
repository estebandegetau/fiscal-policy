# Claude Code Research Companion

This template includes a Claude Code companion system with principles, architecture, and workflow conventions for rigorous LLM-assisted research. It is ready to populate for your specific project.

## What this is

**`COMPANION.md`** is the permanent soul document. It establishes four principles that govern every interaction with Claude in this project: human confers meaning, delegate instrumental and own the core, credibility tracks involvement, and decisions belong to humans. These principles are not guidelines — they are the load-bearing structure of an honest research process. They exist because LLMs can produce plausible-sounding output at every step while the human quietly disengages from the work that actually matters. COMPANION.md makes that disengagement visible and costly.

The companion system operationalizes these principles through a three-tier documentation architecture, a set of workflow skills, and an auditable iteration log. Every pipeline run is recorded with its metrics, the human's interpretation, and the human's decision. Every implementation discovery that contradicts the research plan is logged for reconciliation. The result is a project history that is defensible at peer review — not because Claude generated it, but because the human was forced to engage with it at every critical point.

## The three-tier documentation system

| Tier | Files | What Claude does |
|------|-------|-----------------|
| **Tier 1 (auto-update)** | `CLAUDE.md` and subdirectory variants | Updates directly when implementation changes make them stale |
| **Tier 2 (never auto-edit)** | `docs/strategy.md` and designated documents | Logs discoveries to `docs/deltas.md`; human reconciles via `/strategy-sync` |
| **Tier 3 (ignore)** | Stable references, generated artifacts | Leaves alone; logs a delta if a factual error is found |

The key constraint: Claude never edits Tier 2 documents. Research design decisions — what to measure, how to validate it, what counts as success — are human-owned. Implementation discoveries flow upward through the delta log, where the human reconciles them under adversarial questioning from Claude. This is not bureaucracy; it is the mechanism that keeps the strategy document honest.

## The skill system

Six slash commands enforce a repeatable workflow:

| Skill | When to use | What it enforces |
|-------|-------------|-----------------|
| `/setup-project` | Once, from template | Onboarding interview → draft `CLAUDE.md` |
| `/doc-sync` | After significant work | Tier 1 updates + Tier 2 delta logging |
| `/strategy-sync` | Stage gates or 3+ deltas | Adversarial reconciliation of deltas with strategy |
| `/log-iteration` | After each pipeline stage | Auto-gathered metadata + human interpretation/decision |
| `/progress-report` | External communication | Auto-gathered state + terminology translation for readers |
| `/quarto-style` | Writing `.qmd` files | Formatting authority for all Quarto documents |

## The iteration log as lab notebook

If you have worked in Stata or R, you know the problem: you changed a parameter three weeks ago, results improved, and you cannot reconstruct what you changed or why. The iteration log (`prompts/iterations/<instrument>.yml`) is that lab notebook. Every pipeline run records the instrument version, model, metrics, your interpretation, your decision, and a git hash linking to the exact file state. Reconstruct any past result with `git show <hash>:<instrument_file>`.

## Claude Infrastructure Checklist

Use this checklist when setting up a new project from this template:

- [ ] Set `ANTHROPIC_API_KEY` in your environment (`.env` or shell profile)
- [ ] Read `docs/onboarding.qmd` — the principles and architecture before anything else
- [ ] Run `/setup-project` to generate your project-specific `CLAUDE.md` (takes ~15-30 min of interview)
- [ ] Describe your project to Claude and ask for a draft `docs/strategy.md`
- [ ] Review and correct `docs/strategy.md` carefully — this is the most valuable intellectual work at project start
- [ ] Configure agents in `.claude/agents/` following the taxonomy in `COMPANION.md`
- [ ] Run `/doc-sync` after your first significant implementation session

## Directory structure

```
COMPANION.md                          ← Soul document (Tier 2, never auto-edited)
CLAUDE.md                             ← Project instructions (Tier 1, maintained by /doc-sync)
docs/
  onboarding.qmd                      ← Human-facing narrative guide
  strategy.md                         ← Authoritative methodology (Tier 2)
  deltas.md                           ← Implementation discovery log
.claude/
  skills/
    setup-project/SKILL.md            ← One-time onboarding interview
    doc-sync/SKILL.md                 ← Documentation sync (three-tier)
    strategy-sync/SKILL.md            ← Adversarial delta reconciliation
    log-iteration/SKILL.md            ← Iteration log entry
    progress-report/SKILL.md          ← External progress reports
    quarto-style/SKILL.md             ← Quarto formatting authority
```
