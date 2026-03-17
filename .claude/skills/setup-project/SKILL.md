---
name: setup-project
description: Interview the researcher and draft a project-specific CLAUDE.md. Run once when starting a new project from the template.
user-invocable: true
---

# Setup Project Skill

One-time onboarding interview that produces a draft `CLAUDE.md` tailored to your project. Run this once when you start a new project from the template.

## When to Use

Run `/setup-project` exactly once, after cloning the template and before any other work. The output is a draft `CLAUDE.md` that you review, correct, and approve. After that, `CLAUDE.md` becomes a living Tier 1 document maintained by `/doc-sync`.

## Procedure

### Step 1: Pre-flight check

Before asking any questions, display this message:

> **Before we begin:** Have you read `docs/onboarding.qmd`? It explains the principles, architecture, and workflow that this template enforces — and why. The 15 minutes you spend there will make every subsequent step make more sense.
>
> If you haven't read it yet, do so now and come back. If you have (or you're ready to proceed), say "ready" and we'll begin the interview.

Wait for the user to confirm before proceeding.

### Step 2: Interview

Ask all 10 questions in a **single prompt** using AskUserQuestion. Do not ask them one at a time.

```
I'll draft your CLAUDE.md from your answers. Please answer all 10 questions as completely as you can — you can always refine the draft later.

1. **Project title, authors, institution**
   What is the full title? Who are the authors? What institution or team?

2. **Research problem** (2-3 sentences)
   What gap does this project address? Why has it been unsolved until now?

3. **Methodological frameworks and key references**
   What analytical or validation frameworks does this project use? List the key citations (e.g., "Romer & Romer (2010) for shock identification, Halterman & Keith (2025) for LLM validation").

4. **Measurement instruments**
   List each instrument with: (a) a short ID (e.g., C1, Q1, M1), (b) a one-sentence description, (c) the output type (binary classification / multi-class / extraction / estimation), and (d) any sequencing dependencies (does instrument X require instrument Y's output?).

5. **Validation pipeline stages**
   What stages does each instrument go through? For each stage: (a) name/code, (b) one-sentence description, (c) what constitutes passing.

6. **Success criteria**
   For each instrument and stage: which metric(s), what target value(s), and is each a hard gate (must pass to proceed) or a diagnostic benchmark (informs the decision)?

7. **Data and scope**
   What is the primary data source? How many labeled examples do you have for ground-truth evaluation? What is the geographic and temporal scope?

8. **Technology stack**
   What pipeline tool will you use (e.g., {targets}, DVC, Snakemake, Make)? What languages? What LLM provider? What production model ID? What exploration model ID?

9. **Phase structure** (optional)
   Does your project have multiple phases? If so, list them with a one-sentence description each. Skip if not applicable.

10. **Current status**
    What is the current state of each instrument and phase? (e.g., "C1: S0 complete, S1 in progress"; "Phase 0: in progress, Phase 1: not started")
```

### Step 3: Synthesize the draft CLAUDE.md

Using the skeleton shell at `docs/skeleton/CLAUDE.md` as the template, fill in all `<!-- POPULATE: ... -->` comments with content derived from the user's answers. Apply these rules:

- **Preserve the COMPANION.md header note** verbatim.
- **Preserve all 10 workflow conventions** verbatim. Convention 3 (`<!-- POPULATE: List your validated model IDs here -->`) should be filled with the model IDs from question 8.
- **List model IDs explicitly** in the Technology Stack section under "Valid Model IDs". Include both the production model and any exploration models.
- **For unanswered questions**: Use `<!-- Not yet specified -->` rather than omitting the section.
- **For the Current Status section**: Populate from answer 10. This is Tier 1 and will be maintained by `/doc-sync` going forward.
- **For the Claude Code Agents section**: Add a brief placeholder noting that agents should be configured following the COMPANION.md taxonomy. Do not invent specific agents.
- **Do not invent content** the user did not provide. Use placeholders for gaps.

### Step 4: Present draft for review

Present the complete draft CLAUDE.md in a code block. Then say:

> **Please review this draft carefully.** The instrument definitions, success criteria, and data constraints are the foundation of everything that follows. Wrong assumptions here propagate through every downstream decision.
>
> Common things to check:
> - Are the success criteria targets realistic given your sample size?
> - Are the instrument sequencing dependencies correct?
> - Are the model IDs current? (Check Anthropic's documentation for the latest.)
> - Does the Strategic Framing accurately characterize what this project IS and IS NOT?
>
> Tell me what to change, or say "approved" to write the file.

**Do NOT write the file automatically.** Wait for approval or change requests.

### Step 5: Write and follow up

After the user approves (with or without changes):

1. Write the approved content to `CLAUDE.md` using the Write tool.

2. Display this follow-up message:

> **CLAUDE.md written.** Two suggested next steps:
>
> **1. Populate `docs/strategy.md`**
> Describe your project to me in plain English and ask me to draft a structured plan following the section headers in `docs/strategy.md`. Review the draft carefully — correcting it is the most valuable intellectual work at project start. See `docs/onboarding.qmd` for guidance.
>
> **2. Configure your agents** (if using multi-agent workflows)
> Create agent configuration files in `.claude/agents/` following the taxonomy in `COMPANION.md`. Read-only agents get `Read, Grep, Glob` only. Write-capable agents get broader permissions. See `COMPANION.md` Part 2 for the full design principles.

## Error Handling

- **User hasn't read onboarding.qmd**: Pause at Step 1. Do not proceed until confirmed.
- **Partial answers**: Fill what you can, use `<!-- Not yet specified -->` for gaps. Do not block on missing information.
- **Conflicting answers** (e.g., success criteria contradict stated constraints): Flag the conflict in the draft with a `<!-- NOTE: potential conflict — review this -->` comment.
- **User rejects draft**: Apply requested changes and re-present. Do not write until explicitly approved.
- **CLAUDE.md already exists**: Warn the user that this will overwrite the existing file. Ask them to confirm before proceeding. Suggest running `/doc-sync` instead if they just want to update specific sections.
