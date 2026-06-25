---
change: create-node-package
design-doc: docs/superpowers/specs/2026-06-25-random-forest-classifier-design.md
base-ref: a0d4ab90234cab2970c0ffeff1883219c83bc9c9
---

# Random Forest Classifier Node Package Implementation Plan

**Goal:** Wrap `original/scripts/model_randomForest.R` into a standards-compliant IRE node package.

**Architecture:** Single-entry `scripts/main.R` with `train` subcommand. All 7 outputs to `--outdir`. NDJSON stdout, errors to stderr.

**Tech Stack:** R 4.3, randomForest, dplyr, ggplot2, reshape2, jsonlite, testthat.

## Global Constraints

- R 4.3 via conda-forge (env in `envs/env-r-4.3.yaml`)
- Flat layout at repo root
- All string content in English
- No hardcoded secrets, no orchestration concerns (no file-locking, no confirm-file)
- Synthetic test data: 10 genes x 20 samples

## Task 1: Update Conda Environment

- [ ] 1.1 Update `envs/env-r-4.3.yaml` with all R dependencies: r-base=4.3, r-essentials, r-randomforest, r-dplyr, r-ggplot2, r-reshape2, r-yaml, r-filelock, r-jsonlite, r-testthat
- [ ] 1.2 Verify conda env resolves with dry-run

## Task 2: Create SKILL.md Contract

- [ ] 2.1 Create `SKILL.md` at repo root with v2 YAML frontmatter (name: random-forest-classifier, type: standard, inputs, outputs, entry, parameters, exceptions, hardware) and narrative body sections (Node Function, Expected Input, Exceptions)

## Task 3: Create scripts/main.R - Skeleton

- [ ] 3.1 Create `scripts/main.R` with subcommand dispatch, argument parser, NDJSON helpers, and `do_train` stub
- [ ] 3.2 Verify argument parsing: unknown subcommand exits 1, missing subcommand message

## Task 4: Implement do_train() Core Logic

- [ ] 4.1 Port core algorithm from `original/scripts/model_randomForest.R` into `do_train()`: load data, fit randomForest(ntree=1000, importance=TRUE, proximity=TRUE), 5-repeat 10-fold rfcv, gene selection, 7 output files, NDJSON result
- [ ] 4.2 Remove file-locking and confirm-file YAML logic (orchestration concern)
- [ ] 4.3 Replace positional args with `--outdir`-based paths

## Task 5: Create Test Suite

- [ ] 5.1 Create `tests/testthat.R` entry helper
- [ ] 5.2 Create `tests/testthat/helper-synthetic.R` with `create_synthetic_data()` function
- [ ] 5.3 Create `tests/testthat/test-train.R` with tests: happy path (7 output files), seed determinism, missing input file, empty gene list, unknown subcommand
- [ ] 5.4 Run tests with `Rscript -e 'testthat::test_dir("tests/testthat/")'`

## Task 6: Create Input Validation Script

- [ ] 6.1 Create `scripts/input_validation.R`: check file existence, CSV validity, group column, binary factor levels, gene overlap
- [ ] 6.2 Add input validation tests to test suite

## Task 7: Create Output Validation Script

- [ ] 7.1 Create `scripts/output_validation.R`: check all 7 files exist, non-empty, CSV column contracts, valid RDS model object
- [ ] 7.2 Add output validation tests to test suite

## Task 8: End-to-End Verification

- [ ] 8.1 Run full train with synthetic data, verify exit 0
- [ ] 8.2 Run output validation on results
- [ ] 8.3 Verify NDJSON stdout format (all lines valid JSON, final line has level: result)
- [ ] 8.4 Verify SKILL.md frontmatter as valid YAML with all required keys
- [ ] 8.5 Run full test suite (expected: 9+ tests pass)
