---
name: progress-report
description: Generate a Quarto progress report (.qmd) with auto-gathered project state, terminology translation for external readers, and gt tables following project conventions.
user-invocable: true
---

## Project Adaptation Required

Before using this skill, configure the following project-specific items:

- **Terminology Mapping table**: Replace the placeholder with your project's actual internal-to-reader-facing translations. Required minimum: your instrument names, stage names, and key metrics. See the template structure in the Terminology Mapping section.
- **Target audience**: Replace `<!-- ADAPT: your audience -->` with the actual reader type (e.g., "development economists", "public health researchers", "policy analysts").
- **Report triggers / stage nomenclature**: Update the "When to Use" triggers to match your project's stage names (e.g., if you don't use S1/S2/S3, update accordingly).
- **YAML title**: Replace the placeholder title in Step 3b with your project title.
- **Setup chunk**: Uncomment `source(here("R/gt_theme.R"))` only if your project uses a custom gt theme. Otherwise leave it commented out.

---

# Progress Report Skill

Generate a Quarto progress report with auto-gathered project state, jargon-free prose for external readers, and pre-built gt tables. The skill handles tedious context assembly while keeping the human in the loop for framing and review.

## When to Use

Invoke `/progress-report` when writing a progress update for stakeholders. Typical triggers:

- An instrument crosses a stage gate (e.g., S1 pass, S2 evaluation complete)
- Monthly or milestone reporting cadence
- Budget or timeline revision needed
- Briefing material for a meeting

## Procedure

### Phase 1: Auto-gather project state (no user input)

Collect all of the following silently. Do NOT ask the user for any of this.

#### 1a. Previous report

Find the most recent `.qmd` in `reports/` (by filename date prefix). Read it and extract:

- Date of last report
- Topics/sections covered
- Forward-looking commitments (e.g., "v0.4.0 evaluation is the immediate next step")
- Metrics reported (for comparison)

If no previous report exists, note this and skip comparison elements.

#### 1b. Iteration logs

Read `prompts/iterations/*.yml` for each instrument that has a log. Extract:

- Latest iteration number, instrument version, date, stage
- Latest metrics (pass/fail, key values)
- Latest decision/interpretation

#### 1c. Git activity

Run:

```bash
git log --oneline --since="<last_report_date>" --until="today" | head -40
```

Summarize commit themes (instrument revisions, infrastructure, documentation, bug fixes). Count commits.

#### 1d. Pipeline target status

Run:

```bash
Rscript -e 'library(targets); cat(paste(tar_outdated(), collapse="\n"))'
```

And:

```bash
Rscript -e 'library(targets); p <- tar_progress(); cat(jsonlite::toJSON(table(p$progress), auto_unbox=TRUE))'
```

Note which targets are complete, outdated, or errored.

#### 1e. Strategy context

Read `CLAUDE.md` "Current Status" section and `docs/strategy.md` "Success Criteria" for target metrics per instrument.

#### 1f. Compile state summary

Assemble a short internal summary (not shown to user yet) covering:

- What changed since the last report
- Current metrics vs. targets
- Outstanding commitments from the last report (met or deferred?)

### Phase 2: Ask the user (all at once)

Present the auto-gathered state summary to the user, then ask all of the following in a **single prompt** using AskUserQuestion:

1. **Purpose/audience**: What kind of report?
   - Options: "Progress update (routine)", "Milestone report (stage gate crossed)", "Pitch/briefing (for new audience)", "Budget/timeline revision"
2. **Key takeaways**: What are the 2-3 main messages? (Free text)
3. **Sections to include** (multi-select):
   - Executive summary
   - Methodology overview (for new readers)
   - Metrics and evaluation results
   - Root cause diagnosis / error analysis
   - Timeline (original vs. revised)
   - Budget / API costs
   - Next steps
   - Technical appendix
4. **Framing notes**: Any specific framing, emphasis, or things to avoid? (Free text, optional)

After the user responds, confirm the filename: `reports/YYYYMMDD.qmd` (using today's date). If a file with that name already exists, ask the user whether to overwrite or use a suffix.

### Phase 3: Generate the report

#### 3a. Read config files

Before writing, read `_quarto.yml` and `reports/_metadata.yml` to know what's inherited. Follow all conventions in `.claude/skills/quarto-style/SKILL.md`.

#### 3b. YAML front matter

Only include what's unique to this document (everything else is inherited):

```yaml
---
title: "<!-- ADAPT: Your project title -->"
subtitle: "<purpose-specific subtitle>"
date: "<today's date>"
---
```

Do NOT repeat `format:`, `execute:`, `author:`, `date-format:`, or any other inherited settings.

#### 3c. Setup chunk

Include only if the report reads pipeline data. Load only the targets the report actually needs:

```r
#| label: setup
#| cache: false

library(targets)
library(tidyverse)
library(gt)
library(here)
library(scales)

here::i_am("reports/<filename>.qmd")
tar_config_set(store = here("_targets"))
# source(here("R/gt_theme.R"))  # ADAPT: uncomment if using custom gt theme

# Load data — only what this report uses
<target_reads>
```

#### 3d. Prose with terminology translation

Write all prose using the **Terminology Mapping** table below. Rules:

- On **first mention**, use the reader-facing term
- If the term recurs, introduce the shorthand in parentheses on first mention, then use the shorthand thereafter
- Example: "...behavioral tests (S1)..." on first mention, then "S1" alone later
- Never use internal terms without translation in the executive summary
- The executive summary should be readable by someone who has never seen a previous report

#### 3e. Tables

All tables must follow quarto-style conventions:

- Use `gt()` with the project theme function as the last step
- Use chunk options `label: tbl-{ref}` and `tbl-cap:` for titles (not `tab_header(title=)`)
- Reference tables in text with `@tbl-{ref}`
- Use `fmt_percent()`, `fmt_number()`, `comma()` for formatting
- Use `tab_footnote()` for methodological notes

#### 3f. References

If any `@citations` are used, end the document with:

```markdown
## References {.unnumbered}

::: {#refs}
:::
```

#### 3g. Write the file

Use the Write tool to create `reports/<filename>.qmd`.

### Phase 4: Present for review

After writing the file, present:

1. **Summary**: What sections were generated and key data sources used
2. **Flags for human review**: Call out any items that need verification:
   - Hardcoded metrics (values baked into prose rather than read from targets)
   - Projections or estimates (timeline dates, budget figures)
   - Comparisons with previous versions where old metrics were hardcoded
   - Claims about what changed or why
3. **Render instruction**: "To render: `quarto render reports/<filename>.qmd`"

Do NOT render the report automatically. The user should review the source first.

## Terminology Mapping

<!-- ADAPT: Replace this entire table with your project's actual terminology.
The minimum required structure is shown below. Add rows for all internal terms
that external readers would not understand.

Required categories to translate:
- Instrument names (e.g., C1, C2 → reader-facing descriptions)
- Stage names (e.g., S0, S1, S2, S3 → what each stage does)
- Key metrics (e.g., combined recall → what it measures in plain language)
- Technical ML terms used in reporting (zero-shot, fine-tuning, etc.)
- Pipeline/infrastructure terms (targets pipeline, chunk, etc.)

Example structure:
-->

Use reader-facing language on first mention. Introduce the shorthand in parentheses if reused.

| Internal term | Reader-facing language |
|---------------|----------------------|
| <!-- ADAPT: instrument_id --> | <!-- ADAPT: reader-facing description --> |
| S0 | instrument preparation (drafting machine-readable classification instructions) |
| S1 | behavioral tests (verify the model follows instructions correctly) |
| S2 | formal evaluation (measure accuracy against ground truth) |
| S3 | error analysis (diagnose failure patterns and identify instrument improvements) |
| S4 | fine-tuning (adjust model weights; last resort) |
| zero-shot | classification without providing training examples to the model |
| targets pipeline | the reproducible data processing system (R `{targets}` package) |
| <!-- ADAPT: add your project-specific terms --> | <!-- ADAPT: reader-facing translations --> |

## Section Templates

These are starting points, not mandatory structures. Adapt to the report's purpose.

### Executive Summary template

```markdown
## Executive Summary

[1-2 sentences: what this report covers and the time period]

[1-2 sentences: headline result with metrics, always including the target]

[1-2 sentences: what this means for the project / what's next]
```

### Metrics Table template

```r
#| label: tbl-<instrument>-performance
#| tbl-cap: "<Instrument> Performance Summary"

tibble(
  Metric = c(...),
  Value = c(...),
  Target = c(...),
  Status = c(...)
) %>%
  gt() %>%
  tab_header(title = "", subtitle = "...") %>%
  gt_theme_report()   # ADAPT: replace with your theme function
```

### Timeline Table template

```r
#| label: tbl-timeline
#| tbl-cap: "Implementation Timeline"

tibble(
  Phase = c(...),
  Task = c(...),
  `Previous Estimate` = c(...),
  `Current Estimate` = c(...)
) %>%
  gt() %>%
  gt_theme_report()   # ADAPT: replace with your theme function
```

## Error Handling

- **No previous report**: Skip comparison elements. Note in Phase 2 summary that this is the first report.
- **No iteration logs**: Skip metrics sections. Focus on infrastructure, methodology, or qualitative progress.
- **Pipeline targets errored**: Report the error state honestly. Do not fabricate metrics.
- **`tar_read()` fails**: Use hardcoded values from iteration logs or ask the user. Flag hardcoded values in Phase 4.
- **Git history unavailable**: Skip the activity summary. Note the gap.

## Composability

This skill references `.claude/skills/quarto-style/SKILL.md` for all formatting conventions. Do not duplicate those rules here. When in doubt about table formatting, citation style, or markdown conventions, defer to quarto-style.
