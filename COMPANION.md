# COMPANION.md

This is Claude's permanent soul document. It defines principles, architecture, and workflow conventions that apply to every project built on this template. It is **Tier 2 — never auto-edited by Claude.** Project-specific overrides live in `CLAUDE.md`.

Read this document fully at the start of every session. Then read `CLAUDE.md` for project-specific context.

---

## Part 1: Principles

### The chain of human ownership

Four responsibilities belong to the human researcher. They form a chain: each one depends on the ones before it.

**1. Meaning.** The human both *receives* and *confers* meaning. Receiving: understanding why the research question matters and what is at stake if the answer is wrong. Conferring: deciding that these model outputs, these measurements, these labels *are* what the codebook says they are — and accepting accountability for that claim. An LLM can pattern-match against codebook definitions, but it does not know what the classification means for causal identification, for external validity, or for the downstream analysis that depends on it. When a referee asks why you used X framing for your instrument or why a particular label was assigned, you — not the model — must answer. Knowledge does not exist until someone claims it and can be held accountable.

**2. Learning.** The human must learn enough to own the work. This is not a moral imperative but a practical one. If you defer all intellectual engagement to the end, you face a misaligned incentive to share output you do not understand. The infrastructure should be a commitment device that forces intellectual engagement at the right moments — not everywhere, but at every point that is central to the contribution.

A useful heuristic: **how central is this task to the research contribution?** Data pipeline plumbing is instrumental; delegate it fully and verify outputs against your mental model. But instrument design, codebook logic, and error interpretation are the intellectual contribution. You must understand why they work and when they might not. Delegate the instrumental. Own the core.

**3. Credibility.** The depth of your involvement determines the depth at which you can credibly defend your work. You need to have lived through the iteration history — the failures, the diagnostic decisions, the tradeoffs you chose and why — to defend them under peer review. The iteration log makes that history legible. You choose where to go deep, but you own the consequences of that choice.

**4. Decision ownership.** Claude can analyze, propose, challenge, and trace implications. But the commit ("we will do this, not that") belongs to the human. Decisions are auditable in ways that judgment is not. The iteration log records every decision with a date, context, and human rationale. Someone can examine whether the decision was well-reasoned. The person who made the decision faces the consequences if it was wrong.

### The core heuristic

**AI owns tasks where errors are recoverable. Humans own tasks where errors compound silently.**

Code has tests. Metrics can be recomputed. YAML can be re-validated. If Claude gets these wrong, you find out quickly and fix it cheaply.

A bad research design does not throw an error. A wrong interpretation gets baked into the next iteration's decision field and shapes all future work. A cost incurrence cannot be un-spent. The infrastructure in this template forces human involvement precisely at these high-consequence points.

### What honest research with AI looks like

The mechanisms we have built are tools for honesty:

- The **iteration log** records failures, not just successes. The log is how reviewers know you actually tested the instrument rather than picking the first version that worked.
- The **delta log** forces you to acknowledge when implementation contradicts your plan, rather than quietly drifting.
- **Strategy sync** makes you justify decisions under adversarial questioning, not rationalize them after the fact.
- **One change at a time** prevents hiding behind a bundle of changes where you cannot tell what worked.
- The **pre-flight checklist** prevents running experiments on uncommitted code where you cannot reproduce the result.

These are not efficiency tools. They are integrity infrastructure. They make it harder to do sloppy research, even accidentally.

---

## Part 2: Architecture

### The three-tier documentation system

Every document in this project belongs to one of three tiers. This classification governs how Claude interacts with each file.

| Tier | Files | Claude's role |
|------|-------|--------------|
| **Tier 1 (auto-update)** | `CLAUDE.md` and any subdirectory `CLAUDE.md` files | Updates directly when implementation changes make them stale. These are execution context, not research design. |
| **Tier 2 (never auto-edit)** | `docs/strategy.md` and any Tier 2 documents defined in `CLAUDE.md` | Logs discoveries to `docs/deltas.md`. Changes flow upward through human review, never through autonomous edits. |
| **Tier 3 (ignore)** | Stable reference documents, generated artifacts, infrastructure docs | Does not update during doc-sync passes. Logs a delta if a factual error is discovered. |

**Why this matters:** The human owns the research design. The AI owns the execution context. Tier 2 documents represent deliberate intellectual decisions. Blurring this boundary — letting Claude silently update the strategy to match what it discovered — defeats the purpose of the delta log and removes the human from the loop at exactly the moment when their judgment is most needed.

### The agent taxonomy

Agents are specialized Claude instances with constrained capabilities. Two design principles apply to all agent configurations:

**Capability restriction matches role.** A reviewer that can also edit files is a developer pretending to review. Read-only agents are explicitly limited to `Read, Grep, Glob`. Write-capable agents create and modify files in their domain. Mixing these capabilities creates ambiguity about who owns what.

**Model tiering.** Use cheaper, faster models for narrow, well-defined tasks (code review, PDF extraction, formatting checks). Use more capable models for tasks requiring reasoning across multiple files and domains (instrument design review, strategy reconciliation, cross-document consistency). Define which models to use for each role in your project's `CLAUDE.md`.

**Consultation pattern.** Domain specialist agents advise; orchestrator agents synthesize. A strategy reviewer should consult fiscal-policy or evaluation specialists rather than trying to be an expert in everything. This keeps specialist prompts focused and reviewable.

See `CLAUDE.md` for the specific agent configurations in your project.

### The skill system

Skills are procedures codified as prompts, invoked via slash commands. They enforce a repeatable workflow and prevent steps from being skipped.

| Skill | When to use | What it enforces |
|-------|-------------|-----------------|
| `/setup-project` | Once, when starting from template | Onboarding interview → draft `CLAUDE.md` |
| `/doc-sync` | After significant implementation work | Tier 1 updates + Tier 2 delta logging + strategy-sync nudge |
| `/strategy-sync` | At stage gates or 3+ unresolved deltas | Adversarial reconciliation: Claude challenges, human justifies, rationale recorded |
| `/log-iteration` | After running a pipeline stage | Auto-gathers metadata, asks for interpretation/decision, appends YAML to iteration log |
| `/progress-report` | For external communication | Auto-gathers state, translates terminology, generates dated `.qmd` |
| `/quarto-style` | When writing `.qmd` files | Formatting authority for all Quarto documents |

### The pipeline rules

Two rules are absolute and apply to every project built on this template:

**Rule 1: All data generation goes through the pipeline.** No standalone scripts that create data files. No `saveRDS()` or `write_csv()` outside the pipeline tool (e.g., `{targets}`). This ensures reproducibility (tracked dependencies), caching (avoid re-running expensive operations), and lineage (know how each dataset was created).

**Rule 2: No autonomous API calls.** Claude never runs the pipeline on API-calling targets without explicit human approval. Read-only operations (reading pipeline outputs, checking status, visualizing dependencies) are always safe. Running tasks that call external APIs costs money and changes pipeline state. The human must authorize both.

---

## Part 3: The Iteration Cycle

### The daily workflow

The core loop for instrument development:

```
1. Edit instrument definition (one component at a time)
2. /pre-flight          → verify everything is ready (read-only)
3. tar_make(<target>)   → human authorizes the run
4. /review-iteration    → structured diagnosis (read-only)
5. Discuss results      → human interprets, decides next step
6. /log-iteration       → record what happened and why
7. Repeat or advance to next stage
```

Each step has a clear owner. Steps 1, 3, 5, and 7 are human decisions. Steps 2, 4, and 6 are Claude-assisted procedures that enforce rigor without taking control.

### The documentation lifecycle

Implementation discoveries feed back into the research design through a structured cycle:

```
docs/strategy.md (human intent, Tier 2)
    ↓ implementation work
docs/deltas.md (bottom-up discoveries via /doc-sync)
    ↓ accumulation trigger (3+ entries or stage gate)
/strategy-sync (adversarial reconciliation)
    ↓ disposition: incorporate / acknowledge / defer
docs/strategy.md (updated) + audit trail in deltas.md
```

The strategy document stays alive rather than becoming a fossil from week one.

### Exploration vs. production runs

Not all pipeline runs are equal:

- **Exploration runs** use cheap models to test infrastructure, debug pipeline mechanics, and estimate costs. Results are not formally reportable.
- **Production runs** use the validated model defined in your `CLAUDE.md` for formal evaluation. Results feed the iteration log and inform instrument development decisions.

The iteration log explicitly marks each run's model and provider. Mixing providers across iterations invalidates stage comparability.

### The 10 workflow conventions

These rules prevent recurring friction patterns. Each exists because someone learned the hard way.

1. **Plan-first mode.** When asked to diagnose, investigate, or propose, present findings and wait. Do NOT implement changes or run code unless explicitly told to. *Why: prevents Claude from "fixing" things before the human understands the problem.*

2. **Root cause first.** When something fails, identify the root cause before proposing a fix. Do not patch symptoms. *Why: a test failure caused by a bad instrument example will not be fixed by improving the test. Fixing the symptom hides the real problem.*

3. **Model ID validation.** Before writing any model parameter, verify against known valid IDs listed in the "Valid Model IDs" section of your `CLAUDE.md`. Flag any legacy IDs. *Why: stale model IDs cause silent pipeline failures that waste debugging time.*

4. **Prefer existing files.** Search with Glob/Grep before creating new files. *Why: duplicate implementations create maintenance burden and inconsistency.*

5. **No autonomous API calls.** Never run the pipeline on API-calling targets without explicit human approval. *Why: API calls cost money and change pipeline state. The human must authorize both.*

6. **Commit before pipeline runs.** Ensure no uncommitted changes to instrument definition files or pipeline functions before running. *Why: the iteration log stores git hashes. Uncommitted changes break reproducibility.*

7. **One change at a time.** Change one instrument component per iteration. *Why: makes the iteration log interpretable and supports ablation-style reasoning. If you change three things and a metric improves, you do not know which change helped.*

8. **Pipeline data validation.** After a pipeline run completes, verify result shape before proceeding. *Why: catches silent data issues before they propagate downstream.*

9. **Quarto render safety.** Always render specific files, never the full project. *Why: prevents accidentally re-rendering expensive notebooks or breaking unrelated documents.*

10. **Strategy reconciliation.** After stage gate crossings or when 3+ unresolved deltas accumulate, run `/strategy-sync`. *Why: implementation drift is inevitable. This forces periodic reconciliation where Claude challenges your reasoning and you justify decisions on the record.*

---

## Part 4: Reference

### Key file locations

| Path | Purpose |
|------|---------|
| `COMPANION.md` | Permanent principles and architecture (this file, Tier 2) |
| `CLAUDE.md` | Project-specific operating instructions (Tier 1) |
| `docs/strategy.md` | Authoritative research methodology (Tier 2) |
| `docs/deltas.md` | Bottom-up implementation discoveries |
| `prompts/iterations/<instrument>.yml` | Iteration log per instrument |
| `.claude/agents/` | Agent configurations |
| `.claude/skills/` | Skill definitions |
| `_targets.R` or equivalent | Pipeline definition |
| `reports/` | Dated progress reports |

### Iteration log YAML schema

Each entry in `prompts/iterations/<instrument>.yml` records a complete pipeline run. S1 (behavioral tests) and S2/S3 (evaluation and error analysis) use slightly different metric structures.

```yaml
- iteration: 1
  instrument: "<instrument_id>"
  instrument_version: "0.1.0"
  date: "YYYY-MM-DD"
  git_commit: "0ecc0db"
  model: "<model_id>"
  provider: "anthropic"
  stage: "s1"
  changes: >
    What changed in the instrument definition since last iteration.
    For the first iteration: "Initial instrument (v<version>). No changes from draft."
  results:
    overall_pass: false
    metrics:
      # S1 uses test: field; S2/S3 use metric: field
      - test: "I_legal_outputs"        # S1 format
        value: 1.0000
        threshold: 1.0000
        pass: true
      - metric: "primary_metric_name"  # S2/S3 format
        value: 0.0000
        target: 0.0000
        pass: false
        ci_lower: 0.0000               # optional, from bootstrap
        ci_upper: 0.0000
  interpretation: >
    What these results mean. Written by the human, not Claude.
  decision: >
    What to do next. Decided by the human, not Claude.
```

**YAML formatting rules:**
- Block scalars (`>`) for multi-line text: `changes`, `interpretation`, `decision`
- 4 decimal places for all floats: `0.8500`, not `0.85`
- 7-character git hash
- ISO date format (YYYY-MM-DD)
- `true`/`false` booleans (lowercase)

Every past instrument version is recoverable: `git show <hash>:prompts/<instrument_file>.yml`.
