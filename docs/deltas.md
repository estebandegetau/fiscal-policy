# Strategy Delta Log

Bottom-up discoveries from implementation that may require updates to
human-authored specification documents (`docs/strategy.md` and any other
Tier 2 documents defined in `CLAUDE.md`).

Review this log periodically and incorporate relevant changes into the
source documents. Run `/strategy-sync` when 3 or more unresolved entries
accumulate.

---

## 2026-10-30: Malaysia ToR adds a single-country firm-level data path

**Type:** scope-change
**Affects:** `docs/strategy.md` > Data and Scope; `CLAUDE.md` > Current Status
**Detail:** The Malaysia ToR (`docs/ToR_Tax_Policy_and_Corporate_Investment_Malaysia.docx`, box due 15 Feb 2027) adds a Malaysia-only workstream outside Phases 1–3. Milestone 1 builds a separate data path in ringgit (`R/ms1_data.R`, `R/ms1_diagnostics.R`, `docs/ms1_data_suitability.qmd`):

- Osiris, Malaysia subset.
- DOSM Manufacturing Census, 2000–2015 panel.
- DOSM Economic Census 2022.
- Hand-entered statutory CIT schedule (unverified).
- WDI investment benchmark.

It does not use `clean_orbis_data()` (USD, cross-country). Findings that bear on strategy:

- Only Iskandar (2007) among the 15 incentive shocks is a causal candidate with current data.
- Headline CIT cuts are best identified via effective-tax-rate exposure in Osiris, but are underpowered (MDE ~40% of the mean investment rate).
- The census has an MSIC 2000→2008 break between the 2005 and 2010 waves.

**Suggested edit:** Add the Malaysia workstream and its milestones to Data and Scope and Implementation Sequencing. Record the statutory CIT cuts as in scope, and note that the shock dataset has `delta_pp` for only 1 of 15 incentive shocks.

---

## 2026-03-20: Phase 1 complete — macro local projections graduated

**Type:** status-change
**Affects:** `docs/strategy.md` > Implementation Sequencing
**Detail:** Phase 1 (macro effects of tax cuts/hikes using all episodes) is complete. STATA code from `Charts_October_1_2025_.do` has been translated into R (`R/local_projections.R`). The pipeline runs CIT and PIT treatments across 7 macro outcomes (GDP pc, tax revenue, income tax revenue, individual income tax, private investment, FDI, consumption) with cumulative IRFs over horizons 0–5. Results notebook (`notebooks/lp.qmd`) shows very few statistically significant coefficients at the macro level, reinforcing the motivation for Phase 2 (micro data). Strategy doc should be populated to reflect the completed Phase 1 design and findings.
**Suggested edit:** Populate the Implementation Sequencing section to mark Phase 1 as complete and document the macro-level null-result finding as motivation for Phase 2.

