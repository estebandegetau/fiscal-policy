---
name: log-iteration
description: Log an instrument development iteration with auto-gathered metrics, user interpretation, and decision. Creates an auditable YAML trail in prompts/iterations/.
user-invocable: true
---

## Project Adaptation Required

Before using this skill, configure the following project-specific items:

- **Instrument names**: Replace the placeholder in Step 1 with your actual instrument IDs (populated by `/setup-project`).
- **Instrument file mapping table** (Step 3): Replace with actual paths. Default pattern: `prompts/<instrument_id>.yml` or equivalent.
- **Target name mapping table** (Step 3): Replace with your pipeline's actual target names. Default pattern: `<instrument_id>_<stage>_results`. <!-- ADAPT after setup-project -->
- **Metric definitions** (Step 4): Replace the generic template with your project's actual metrics per instrument and stage, sourced from `docs/strategy.md` Success Criteria.
- **Iteration log directory**: Default is `prompts/iterations/`. Change if your project uses a different path.

---

# Log Iteration Skill

Record an instrument development iteration: what changed, what the pipeline produced, what it means, and what to do next. Each entry captures enough context to reconstruct any past state (`git show <hash>:prompts/<instrument_file>`).

## When to Use

Invoke `/log-iteration` after running a pipeline stage (S1, S2, or S3) for any instrument and reviewing the results. Typical workflow:

1. Edit the instrument definition file
2. Run `tar_make(<target>)` (or equivalent)
3. Invoke `/log-iteration` to record the iteration

## Procedure

### Step 1: Ask the user

Ask the user for three things (use AskUserQuestion or conversational prompts):

1. **Instrument**: Which instrument?
   <!-- ADAPT: List your instrument IDs here after running /setup-project -->
2. **Stage**: Which stage was run? (`s1`, `s2`, or `s3`)
3. **Changes**: What changes were made to the instrument since the last iteration? (Free text. For the first iteration, say "Initial instrument (v<version>). No changes from draft.")

### Step 2: Auto-gather metadata

Collect these automatically (do NOT ask the user):

| Field | How to get it |
|-------|---------------|
| `instrument_version` | Read the instrument definition file and extract the version field |
| `git_commit` | Run `git rev-parse --short HEAD` |
| `date` | Today's date (YYYY-MM-DD) |
| `iteration` | Read existing log file, count entries, add 1. If file doesn't exist, iteration = 1 |

### Step 3: Read pipeline results

Use Bash to read the target results:

```bash
Rscript -e 'library(targets); cat(jsonlite::toJSON(tar_read(<target_name>), auto_unbox = TRUE, digits = 4, pretty = TRUE))'
```

**Instrument file mapping:**

<!-- ADAPT: Replace with your actual instrument files -->

| Instrument | Definition file |
|------------|----------------|
| `<instrument_id>` | `prompts/<instrument_id>.yml` |

Default pattern: `prompts/<instrument_id>.yml`

**Target name mapping:**

<!-- ADAPT: Replace with your pipeline's actual target names -->

| Instrument + Stage | Target name |
|--------------------|-------------|
| `<instrument>` + `s1` | `<instrument>_s1_results` |
| `<instrument>` + `s2` | `<instrument>_s2_eval` |
| `<instrument>` + `s3` | `<instrument>_s3_results` |

Default pattern: `<instrument_id>_<stage>_results` (use `_eval` suffix for S2 if it produces an evaluation summary).

If the target does not exist (error from `tar_read`), tell the user and ask if they want to proceed with manual metric entry or abort.

### Step 4: Extract stage-specific metrics

#### S1 metrics (behavioral tests)

The result is a list with `overall_pass`, `model`, and a summary with columns: `test`, `pass`, `metric`, `threshold`, `comparison`.

Format as:

```yaml
results:
  overall_pass: true
  metrics:
    - test: "I_legal_outputs"
      value: 1.0000
      threshold: 1.0000
      pass: true
    - test: "II_definition_recovery"
      value: 1.0000
      threshold: 1.0000
      pass: true
    - test: "III_example_recovery"
      value: 1.0000
      threshold: 1.0000
      pass: true
    - test: "IV_order_invariance"
      value: 0.0000
      threshold: 0.0500
      pass: true
```

Note: Test IV (order invariance) uses `<` comparison (lower is better). All others use `>=` (higher is better).

#### S2 metrics (zero-shot evaluation)

<!-- ADAPT: Replace with your project's actual primary metrics from docs/strategy.md Success Criteria -->

The result is a list with metric fields and optional `*_ci` confidence interval vectors.

Generic template — replace with your instrument-specific metrics:

```yaml
results:
  overall_pass: false
  metrics:
    - metric: "<primary_metric_name>"
      value: 0.0000
      ci_lower: 0.0000      # optional, from bootstrap
      ci_upper: 0.0000
      target: 0.0000
      pass: false
```

Set `overall_pass` to `true` only if ALL primary metrics (as defined in `docs/strategy.md` Success Criteria) meet their targets.

#### S3 metrics (error analysis)

<!-- ADAPT: Adapt field names to match your S3 results structure -->

Format as:

```yaml
results:
  metrics:
    - test: "V_exclusion_criteria"
      baseline_accuracy: 0.0000
      max_accuracy_drop: 0.0000
      critical_component: "<component_name>"
    - test: "VI_generic_labels"
      original_accuracy: 0.0000
      generic_accuracy: 0.0000
      change_rate: 0.0000
    - test: "VII_swapped_labels"
      follows_definitions_rate: 0.0000
      follows_names_rate: 0.0000
      interpretation: "..."
  error_distribution:
    - category: "<category_code>"
      count: 0
      pct: 0.0
  top_ablation_drops:
    - component: "<component_name>"
      drop: 0.0000
```

### Step 5: Present results and ask for interpretation

Show the user a formatted summary of the results. Then ask for:

1. **Interpretation**: What do these results mean? Why do they look this way? (Free text, will be stored as a YAML block scalar)
2. **Decision**: What to do next? (e.g., "Proceed to S2", "Revise clarification 3 to handle X", "Add negative example for Y")

> **Tip:** If the user has already run `/review-iteration` for this instrument+stage, reference that analysis for the interpretation field rather than asking the user to repeat their reasoning. If they haven't analyzed results in depth yet, suggest running `/review-iteration` first.

### Step 6: Append to iteration log

**Directory**: `prompts/iterations/`
**File**: `prompts/iterations/<instrument>.yml` (e.g., `prompts/iterations/c1.yml`)

If the directory doesn't exist, create it. If the file doesn't exist, create it with:

```yaml
# Iteration log for <INSTRUMENT_NAME>
# Each entry records a pipeline run: what changed, what happened, what to do next.
# Retrieve any past instrument version: git show <git_commit>:prompts/<instrument_file>

iterations: []
```

Then append the new entry to the `iterations` list.

### YAML formatting rules

1. **Block scalars** (`>`) for multi-line text fields: `changes`, `interpretation`, `decision`
2. **4 decimal places** for all float values (e.g., `0.8500`, not `0.85`)
3. **Short git hash** (7 characters)
4. **ISO date** format (YYYY-MM-DD)
5. **No trailing whitespace** in block scalars
6. Use `true`/`false` for booleans (lowercase)

### Complete entry schema

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
    For the first iteration: "Initial instrument (v0.1.0). No changes from draft."
  results:
    overall_pass: true
    metrics:
      - test: "I_legal_outputs"
        value: 1.0000
        threshold: 1.0000
        pass: true
  interpretation: >
    All S1 behavioral tests pass. Ready to proceed to S2.
  decision: >
    Proceed to S2 zero-shot evaluation without instrument changes.
```

## Error Handling

- **Target doesn't exist**: Tell the user which target is missing and suggest running the pipeline for that target. Offer to proceed with manual metrics or abort.
- **Instrument file doesn't exist**: Tell the user the instrument hasn't been created yet and abort.
- **JSON parsing failure**: If `tar_read()` output can't be parsed, show the raw output and ask the user to provide key metrics manually.
- **Dirty git state**: Warn the user if `git status --porcelain` shows uncommitted changes, since the logged commit hash won't fully reproduce the instrument. Suggest committing first, but don't block.

## Retrieving Past Iterations

The log stores the git commit hash per entry. To retrieve a past instrument version:

```bash
git show <hash>:prompts/<instrument_file>
```

Full reproduction of past results requires checking out the commit and re-running the pipeline. Summary metrics in the log provide quick comparison without full reproduction.
