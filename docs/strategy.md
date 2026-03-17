# Strategy

**TIER 2 DOCUMENT — Claude never auto-edits this file.** Changes flow upward through `docs/deltas.md`. See `COMPANION.md` for the three-tier documentation system.

---

## How to populate this document

1. Describe your project to Claude in plain English.
2. Ask Claude to draft a structured plan following the section headers below.
3. Review and correct carefully — the draft will be wrong in important ways. Your corrections encode your methodological choices and the constraints that make them non-obvious. This correction step is the most valuable intellectual work you do at project start.
4. Paste the final draft into the sections below and delete these instructions.

See `docs/onboarding.qmd` for more guidance on this process.

---

<!-- POPULATE: Remove the instruction block above after populating each section. -->

## Research Problem

<!-- What gap does this project address?
- What is missing from the literature?
- Why has it been unsolved until now?
- What are the consequences of leaving it unsolved? -->

## Research Contribution

<!-- What does this project add?
- Methodological contributions (new approaches, frameworks, validations)
- Empirical contributions (new datasets, estimates, measurements)
- Be specific about what is novel vs. what applies existing methods -->

## Methodology

<!-- How does the project work at a high level?
- Frameworks applied (cite key references)
- Processing pipeline (document → instrument → output)
- Why this approach is appropriate for the research problem -->

## Measurement Instruments

<!-- For each instrument (e.g., C1, C2, ...) or measurement task:
- Name and description
- Input type and output type
- Sequencing: which instruments depend on others?
- Key design decisions and why -->

## Validation Framework

<!-- How is each instrument validated?
- Stage names and descriptions (e.g., S0-S3 if using H&K)
- What constitutes passing each stage
- What triggers advancement vs. revision -->

## Success Criteria

<!-- Per-instrument target metrics:
- Metric name, target value
- Hard gate (must pass to proceed) vs. diagnostic benchmark (informs decision)
- Rationale for each target -->

## Data and Scope

<!-- Primary data:
- Sources and access method
- Labeled example count (for ground-truth evaluation)
- Geographic / temporal scope
- Known constraints (sample size limits, missing coverage, etc.) -->

## Implementation Sequencing

<!-- In what order will instruments and phases be developed?
- Dependencies between instruments
- Phase structure (if applicable)
- What must be true before each phase can begin -->
