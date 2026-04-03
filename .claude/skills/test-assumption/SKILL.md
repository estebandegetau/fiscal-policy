---
name: test-assumption
description: Empirical verification of uncertain claims about R functions, Quarto rendering, or data transformations. Write a minimal test, run it, report the verdict.
user-invocable: true
---

# Test Assumption Skill

Verify uncertain claims empirically instead of reasoning about them. This skill implements Convention 11 (Empirical verification) from the project's CLAUDE.md.

## When to Use

Invoke `/test-assumption` (or self-invoke during implementation) when uncertain about:

- Whether an R function exists or behaves as expected
- Whether variable labels, attributes, or metadata survive a transformation
- Whether a Quarto layout renders correctly
- Whether a pipeline target produces the expected shape or type
- Any other runtime behavior that is faster to test than to reason about

## Procedure

### Step 1: State the claim

Write a single sentence describing the assumption to test. Be specific.

**Examples:**

- "`knitr::fig_cap()` exists and sets figure captions programmatically"
- "Column labels survive a `left_join` when both tables have labels"
- "A Quarto chunk with `layout-ncol=3` distributes loop output into 3 columns"
- "`fixest::feols` accepts a `weights` argument"

### Step 2: Write a minimal test

Create the smallest possible script that confirms or refutes the claim:

- **R function/behavior**: Write a short R script in a temp file (`/tmp/test_assumption.R`)
- **Quarto rendering**: Write a minimal `.qmd` file (`/tmp/test_assumption.qmd`) with only what's needed to test the layout or rendering claim
- **Pipeline target**: Use `Rscript -e 'targets::tar_read(target_name) |> str()'` to inspect an existing target

The test must produce unambiguous output: either it works or it errors/produces wrong output.

### Step 3: Run the test

- R scripts: `Rscript /tmp/test_assumption.R`
- Quarto files: `quarto render /tmp/test_assumption.qmd`
- Pipeline reads: `Rscript -e '...'`

### Step 4: Report the verdict

State clearly:

- **Claim**: (the assumption)
- **Verdict**: CONFIRMED or REFUTED
- **Evidence**: The relevant output or error message (keep brief)

### Step 5: Clean up and proceed

Delete temp files (`/tmp/test_assumption.*`). Proceed with implementation based on the empirical result, not the prior assumption.

## Rules

- **No reasoning without evidence.** If you catch yourself writing "I believe this should work" or "this function probably accepts", stop and test instead.
- **Minimal tests only.** The test should take seconds to write and run. If it requires significant setup, the question is too broad — break it down.
- **Delete artifacts.** Test files are disposable. Never leave temp files behind.
- **No logging.** This is a quick check, not an iteration record. Use `/log-iteration` for formal pipeline runs.
