# Brainstorm Summary

- Change: create-node-package
- Date: 2026-06-25

## Confirmed Technical Approach

Approach A: Direct 1:1 mapping of `original/scripts/model_randomForest.R` into IRE node package format:
- `scripts/main.R` with `train` subcommand dispatch
- All 7 outputs written under `--outdir` (no path-parsing mkdir)
- Remove file-locking/confirm-file YAML orchestration (framework concern)
- `--seed` default 42 (static bind), `--top` optional (NULL = CV-optimal), `--ntree` default 1000
- NDJSON info + result lines to stdout, errors with patterns to stderr
- Synthetic testthat tests with 10 genes x 20 samples

## Key Trade-offs and Risks

- Remove confirm-file protocol: nodes are black boxes; pipeline coordination is framework domain
- `reshape2` required for rfcv plotting (melt); available on conda-forge
- PDF device works without display server (headless-safe)
- Synthetic test data only; real integration testing needs framework orchestrator

## Testing Strategy

- testthat framework: `tests/testthat/test-train.R`
- Tests: happy path (7 files), seed determinism, missing input, empty gene list, unknown subcommand
- Output validation: CSV column contracts, non-zero rows, valid RDS model

## Spec Patches

None — OpenSpec delta spec is complete with WHEN/THEN scenarios for all 8 requirements.
