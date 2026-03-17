---
name: strategy-sync
description: Reconcile accumulated implementation deltas with strategy docs through structured devil's advocate review. Human-driven reflection, not automation.
user-invocable: true
---

## Project Adaptation Required

Before using this skill, configure the following project-specific items:

- **Tier 2 document list in Step 1b**: Replace the placeholder with the actual Tier 2 documents defined in your `CLAUDE.md`. The default is `docs/strategy.md`; add any additional Tier 2 documents you designated.
- **Instrument terminology**: This skill uses "instrument" generically. Replace with your project's term (e.g., "codebook", "prompt template", "classifier") in the When to Use section if your project uses a specific term consistently.

---

# Strategy Sync Skill

Reconcile implementation deltas logged by `/doc-sync` with the project's human-authored strategy documents. The core value is **pushback**: Claude challenges the user's reasoning, the user justifies decisions, and the rationale is recorded as an audit trail.

This is a reflection exercise, not an automation step. The user drives all disposition decisions.

## When to Use

- After stage gate crossings (e.g., S1/S2/S3 pass for any instrument)
- When 3+ unresolved deltas accumulate in `docs/deltas.md` (doc-sync nudges at this threshold)
- Before starting a new instrument (clean slate check)
- If 0 unresolved deltas exist, report that and stop immediately

## Procedure

### Step 1: Auto-gather (silent)

1a. Read `docs/deltas.md`. Extract unresolved entries (headings that do NOT contain `~~` strikethrough).

1b. Read `docs/strategy.md` and any other Tier 2 documents referenced by the unresolved deltas (as defined in your `CLAUDE.md`).

1c. Group deltas by decision theme (e.g., "instrument scope changes", "evaluation criteria", "data constraints"), not by file section. A single group may span multiple strategy sections.

If 0 unresolved deltas: report "No unresolved deltas in `docs/deltas.md`. Nothing to reconcile." and stop.

### Step 2: Present grouped deltas

Show the user a summary table:

| Theme | Deltas | Affected strategy sections |
|-------|--------|---------------------------|
| ... | ... | ... |

Confirm with the user before proceeding to the review loop.

### Step 3: Per-group review loop

For each theme group:

**3a. Present context.** Show the delta text alongside the current strategy section text it affects.

**3b. Challenge (THE CORE STEP).** This is the devil's advocate review:

- Trace implications forward: How does this delta affect success criteria? Downstream instruments? Transfer or generalization strategy? The verification plan?
- Check consistency across ALL strategy sections, not just the one the delta references.
- Flag silent dependencies the delta doesn't mention (e.g., "if instrument scope changed, does the downstream instrument's input assumption still hold?").
- Pose 1-2 specific questions demanding justification from the user.

**3c. User disposition.** The user chooses one of:

- **Incorporate** — Edit the strategy doc to reflect the delta
- **Acknowledge** — No strategy edit needed, but record the rationale
- **Defer** — Leave unresolved for now

**3d. Handle the disposition:**

- **Incorporate:** Draft a minimal edit to the strategy doc. Show current text vs. proposed text side by side. Apply only after user approval.
- **Acknowledge:** Ask the user for a brief rationale (1-2 sentences) explaining why no edit is needed.
- **Defer:** Leave the delta unchanged in `docs/deltas.md`. Optionally ask the user to note why they're deferring.

### Step 4: Apply changes

4a. Apply approved strategy doc edits. Re-read each file before editing (safety check against concurrent changes).

4b. Mark resolved deltas in `docs/deltas.md` with a rationale audit trail:

- **Incorporate:** Replace the heading with `~~title~~ RESOLVED` and append a summary line: `**Resolved:** Incorporated into [section]. Rationale: [user's justification]`
- **Acknowledge:** Replace the heading with `~~title~~ RESOLVED` and append: `**Resolved:** No strategy edit needed. Rationale: [user's reasoning]`

4c. Deferred deltas stay unchanged in `docs/deltas.md`.

### Step 5: Report

Summarize:

- Table of themes with disposition and action taken
- List of files edited
- Count of remaining unresolved deltas

## Error Handling

- **0 unresolved deltas:** Report and stop.
- **`docs/deltas.md` missing:** Tell user to run `/doc-sync` first to create it.
- **`docs/strategy.md` unreadable:** Stop with error.
- **Referenced Tier 2 doc missing:** Warn, skip that doc's sections, continue with available docs.
- **User aborts mid-review:** Apply all completed edits, report partial progress, note which groups remain.
- **Conflicting deltas in same group:** Flag the conflict explicitly and ask user to resolve before proceeding with that group.
- **Strategy doc changed since initial read:** Re-read the file, show the conflict to the user, and ask how to proceed.

## Composability

- **Reads** deltas created by `/doc-sync`; does not create new deltas.
- **Resolved** deltas reduce the doc-sync nudge count (Step 5b threshold of 3).
- **CLAUDE.md convention 10** defines primary triggers; the doc-sync nudge is a secondary reminder.
- **Recorded justifications** feed `/progress-report` methodology sections as an audit trail.
