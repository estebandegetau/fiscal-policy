---
name: pipeline
description: Run the targets pipeline, diagnose failures, fix them, and iterate until targets succeed. Enforces commit-before-run and result shape validation.
user-invocable: true
---

# Pipeline Skill

Run the targets pipeline with iterative error diagnosis and fixing. This skill enforces Convention 6 (commit before pipeline runs) and Convention 8 (pipeline data validation).

## When to Use

Invoke `/pipeline` when:

- You want to build all or a subset of targets after implementation work
- A previous `tar_make()` failed and you want Claude to diagnose and fix iteratively
- You want to verify that the pipeline produces correctly shaped outputs

## Procedure

### Step 1: Pre-flight checks

Before running anything:

1. **Check for uncommitted changes** to `R/` and `_targets.R`:
   ```bash
   git status R/ _targets.R
   ```
2. If there are uncommitted changes, **stop and advise the user**:
   > "There are uncommitted changes to pipeline files. Please run `/commit` first (Convention 6: commit before pipeline runs)."
3. If clean, proceed.

### Step 2: Run the pipeline

Run the full pipeline or a specified subset:

```r
# Full pipeline
Rscript -e "targets::tar_make()"

# Subset (if user specified targets)
Rscript -e "targets::tar_make(names = c(target_1, target_2))"
```

### Step 3: Handle the result

#### On success

1. Report which targets were built, skipped, or already up to date
2. **Validate result shapes** (Convention 8): For each newly built target, run a quick shape check:
   ```r
   Rscript -e "targets::tar_read(target_name) |> str(max.level = 1)"
   ```
3. Report dimensions and types. Flag anything unexpected (zero rows, all NAs, unexpected types).
4. Done.

#### On failure

Diagnose the error by category:

| Error Pattern | Diagnosis | Fix Strategy |
|---------------|-----------|--------------|
| `cannot allocate vector of size` / killed signal | **OOM** | Reduce columns loaded, compute inline instead of storing model objects, subset data earlier |
| `segfault` / `caught segfault` | **Segfault** | Check panel balance, estimator compatibility, try alternative estimation method |
| `NA` / `NaN` in results where not expected | **NA propagation** | Trace NA source upstream, add explicit `na.rm` or filter before estimation |
| `Error in [function]: could not find function` | **Missing function** | Check package is loaded, verify function exists via `/test-assumption` |
| `no variation in treatment` / `singular matrix` | **Estimation failure** | Check treatment variation in the subset, verify panel structure, consider dropping the specification |
| Other | **Unknown** | Read the full error, inspect the failing function, diagnose root cause before fixing |

### Step 4: Fix

Apply a single, targeted fix to the relevant R file. Follow Convention 7 (one change at a time) — do not bundle multiple fixes.

### Step 5: Iterate

Return to Step 2. **Maximum 5 iterations.** If the pipeline still fails after 5 fix attempts:

1. Report what was fixed and what remains broken
2. Show the current error with context
3. Stop and ask the user for guidance

### Step 6: Report

Summarize the run:

- **Targets built**: list of successfully built targets
- **Fixes applied**: what was changed and why (one line each)
- **Remaining issues**: anything still broken (if applicable)
- **Shape validation**: dimensions and types of key outputs

## Rules

- **Convention 5**: Never run targets that make external API calls without explicit user approval. This project currently has no API-calling targets, but check if new targets have been added.
- **Convention 6**: Do not run the pipeline with uncommitted changes to `R/` or `_targets.R`. Advise `/commit` instead.
- **Convention 7**: One fix per iteration. Do not batch multiple changes.
- **Convention 8**: Always validate result shapes after a successful build.
- **Convention 9**: If the pipeline includes Quarto render targets, render specific files only (never the full project).
- **5-iteration cap**: Stop after 5 failed fix attempts. Runaway loops waste time and obscure the real problem.
