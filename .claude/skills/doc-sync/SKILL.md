---
name: doc-sync
description: Keep project documentation in sync with implementation state. Apply after completing significant implementation work (new pipeline functions, instrument changes, target updates, notebook creation/deletion). Also invocable via /doc-sync for a full documentation sync pass.
user-invocable: true
---

## Project Adaptation Required

Before using this skill, configure the following project-specific items:

- **Tier 1 file list**: Replace the template entries with your actual Tier 1 files. Minimum: `CLAUDE.md`. Add subdirectory `CLAUDE.md` files if your project uses them (e.g., `docs/phase_0/CLAUDE.md`, `notebooks/CLAUDE.md`).
- **Tier 2 file list**: Replace the template entries. Minimum: `docs/strategy.md`. Add any other human-authored specification documents you designate as Tier 2.
- **Trigger events**: Adapt "Creating or modifying instrument YAML files" and "pipeline function files" to match your instrument format and code structure.
- **Stage-gate detection**: Replace the `<instrument_id>_<stage>` pattern with your project's actual instrument IDs and stage names.
- **Tier 3 ignore list**: Replace project-specific paths with your own stable reference files and generated artifacts.

---

# Documentation Sync Skill

This skill defines how to keep project documentation accurate as the codebase evolves. It implements a three-tier system: auto-update machine context, log deltas for human-authored specifications, and ignore stable reference docs.

## When to Apply

Run a doc-sync pass after any of these events:

- Creating or modifying pipeline functions in your code directory
- Creating or modifying instrument definition files (e.g., YAML codebooks, prompt templates)
- Adding, removing, or modifying targets in the pipeline definition file
- Creating, deleting, or substantially updating notebooks
- Completing a stage gate (e.g., S0, S1, S2, S3) for any instrument
- Changing project phase status

Do NOT run doc-sync for:

- Minor edits (typo fixes, formatting changes, comment updates)
- Reading or exploring files without making changes
- Changes only to `docs/` files themselves (avoid circular updates)

## Tier 1: Auto-Update (Machine Context)

These files exist to give Claude Code accurate project state. Update them directly when implementation changes make them stale.

### Files

<!-- ADAPT: Replace with your actual Tier 1 files -->

| File | Key sections to keep current |
|------|------------------------------|
| `CLAUDE.md` (root) | "Current Status" (per-instrument stage progress), "Key Directories" (if new dirs added), "Architecture > Pipeline" (if new targets added) |
| *(add subdirectory CLAUDE.md files here)* | *(their "Status" and "Open Questions" sections)* |

### Update rules

1. **Read the file first.** Never update a file you haven't read in this session.
2. **Change only stale facts.** Do not rewrite prose, add commentary, or "improve" wording.
3. **Preserve structure.** Keep the existing heading hierarchy, formatting, and organization.
4. **Be minimal.** Update the specific lines that are stale. A status changing from "Not started" to "S0 complete, S1 in progress" is a one-line edit, not a paragraph rewrite.
5. **For notebook registries** (e.g., `notebooks/CLAUDE.md`): When a notebook is created, add an entry following the existing format. When a notebook is deleted, move its entry to an "Archived" section with a note on why.

### Example: Updating root CLAUDE.md status

```markdown
<!-- Before -->
- **C1 (Measure ID)**: Not started

<!-- After -->
- **C1 (Measure ID)**: S1 behavioral tests complete; S2 zero-shot eval in progress
```

## Tier 2: Delta Log (Human-Authored Specifications)

These files represent deliberate research design decisions. Never edit them directly. Instead, log discoveries that may require the human to update them.

### Files (never auto-edit)

<!-- ADAPT: Replace with your actual Tier 2 files -->

| File | What it specifies |
|------|-------------------|
| `docs/strategy.md` | Methodology, instrument definitions, success criteria, implementation blueprint |
| *(add other Tier 2 documents here)* | *(what each specifies)* |

### Delta log location

`docs/deltas.md`

### When to log a delta

Log an entry when implementation reveals any of these:

- A specification is wrong or incomplete (e.g., "strategy.md says X but we found Y")
- Success criteria need adjusting based on actual results
- New constraints discovered that affect the strategy
- A phase status change that the human should reflect in strategy docs
- A checklist item in a specification doc has been completed
- An assumption was validated or invalidated

### Delta log format

Each entry is a short, structured block. Most recent entries go at the top.

```markdown
## YYYY-MM-DD: [Short title]

**Type:** [status-change | correction | new-constraint | validated | invalidated]
**Affects:** `docs/strategy.md` > Section Name > Subsection
**Detail:** One to three sentences describing what was discovered or what changed.
**Suggested edit:** The specific text change, if obvious. Otherwise "Review needed."
```

### Example delta entries

```markdown
## 2026-02-18: C1 instrument S0 complete

**Type:** status-change
**Affects:** `docs/strategy.md` > Implementation Blueprint > C1 Implementation
**Detail:** C1 instrument definition (`prompts/c1_measure_id.yml`) passed S0 validation.
Behavioral test functions implemented in `R/behavioral_tests.R`. S1 tests ready to run.
**Suggested edit:** Update Step 2 status from "⬜ Pending" to "✅ Complete".
```

```markdown
## 2026-02-15: Training data count confirmed at 44 acts

**Type:** validated
**Affects:** `docs/strategy.md` > Data Constraints
**Detail:** Analysis confirms 44 aligned acts after matching. The constraint documented in strategy.md is correct.
**Suggested edit:** None needed (already accurate).
```

### Rules for delta logging

1. **Be factual.** State what happened, not what you think should happen to the strategy.
2. **Be specific.** Point to the exact section and subsection affected.
3. **Don't accumulate noise.** If a discovery confirms the strategy is correct, log it as "validated" but don't suggest edits.
4. **One entry per discovery.** Don't batch unrelated changes into one entry.

## Tier 3: Ignore (Stable / Low Priority)

These files are either stable reference documents, generated artifacts, or infrastructure docs that rarely need updates. Do not update them during a doc-sync pass.

### Files

<!-- ADAPT: Replace with your actual Tier 3 files -->

| File | Why ignore |
|------|-----------|
| `docs/literature_review.md` | Stable summary of published papers |
| `docs/methods/*.md` | Faithful summaries of reference papers |
| *(add your generated artifacts, build outputs, infrastructure guides here)* | *(reason)* |

**Exception:** If you discover a factual error in a Tier 3 reference doc, log a delta rather than editing directly.

## Running a Full Sync Pass (/doc-sync)

When invoked explicitly via `/doc-sync`, perform these steps in order:

### Step 1: Gather current state

- Read `git status` (untracked files, modifications, deletions)
- Read the pipeline definition file (e.g., `_targets.R`) for current target definitions
- Glob instrument files and notebook files for current inventory
- Note any completed pipeline runs

### Step 2: Check Tier 1 files for staleness

For each Tier 1 file:

1. Read the file
2. Compare stated facts against current state from Step 1
3. List specific lines that are stale

### Step 3: Update Tier 1 files

Apply minimal edits to fix stale facts. Follow the update rules above.

### Step 4: Check for Tier 2 deltas

Review whether any recent implementation work contradicts, extends, or validates the specification docs:

- Did any success criteria get tested? Log results.
- Were any instrument files created or updated? Log status change.
- Were any assumptions validated or invalidated? Log finding.
- Did a phase or stage gate status change? Log transition.

**Stage-gate detection (auto):** For each instrument, check if `prompts/iterations/<instrument_id>.yml` exists. If it does, read the latest iteration entry. If `overall_pass: true` for a stage not previously logged as passing:

1. Auto-log a delta to `docs/deltas.md` (e.g., "C1 S1 behavioral tests pass — all tests meet thresholds")
2. Update the root `CLAUDE.md` "Current Status" section to reflect the latest stage completion per instrument (Tier 1 auto-update)

### Step 5: Append to delta log

Add entries to `docs/deltas.md` following the format above. Do not modify existing entries.

### Step 5b: Check for strategy reconciliation trigger

Count unresolved entries in `docs/deltas.md` (headings that do NOT contain `~~` strikethrough).

If the count is **3 or more**, set an internal flag to include a nudge in Step 6. Do not take any other action.

### Step 6: Report

Summarize to the user:

- Which Tier 1 files were updated (and what changed)
- Which deltas were logged (and what they recommend)
- Any Tier 3 errors spotted (if applicable)
- **If 3+ unresolved deltas:** "N unresolved deltas in `docs/deltas.md`. Consider running `/strategy-sync` to reconcile them with strategy docs."

## Creating docs/deltas.md

If `docs/deltas.md` does not exist, create it with this header:

```markdown
# Strategy Delta Log

Bottom-up discoveries from implementation that may require updates to
human-authored specification documents (`docs/strategy.md` and any other
Tier 2 documents defined in `CLAUDE.md`).

Review this log periodically and incorporate relevant changes into the
source documents. Run `/strategy-sync` when 3 or more unresolved entries
accumulate.

---

```

New entries go immediately after the `---` separator.
