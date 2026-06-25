# Comet Design Handoff

- Change: create-node-package
- Phase: design
- Mode: compact
- Context hash: bad3c23fd048924825d1569f816f0500527ec9993d8dfe78f1216ba7928f10eb

Generated-by: comet-handoff.sh

OpenSpec remains the canonical capability spec. This handoff is a deterministic, source-traceable context pack, not an agent-authored summary.

## openspec/changes/create-node-package/proposal.md

- Source: openspec/changes/create-node-package/proposal.md
- Lines: 1-29
- SHA256: 9f3be7d1e035d23c44da2e28eff8c02ab32715ea48998994cd63378bca84cfac

```md
## Why

The `random-forest-classifier` has a working reference implementation (`original/`) but it does not conform to the IRE node package format. It uses raw positional args, writes to arbitrary paths, lacks input/output validation, and has no SKILL.md contract. This change wraps the reference into a standards-compliant IRE node that the framework and agents can discover, invoke, and compose.

## What Changes

- Create `SKILL.md` with v2 YAML frontmatter (name, description, type, inputs, outputs, parameters, exceptions, hardware) and narrative body sections covering node function, expected input, exceptions, and invocation
- Create `envs/env-r-4.3.yaml` declaring all conda/R dependencies (`randomForest`, `dplyr`, `ggplot2`, `reshape2`, `yaml`, `filelock`)
- Create `scripts/main.R` as single entry point with `train` subcommand, NDJSON stdout reporting, and portable `--outdir`-based file layout
- Create `scripts/input_validation.R` verifying input file existence, format, and semantic validity
- Create `scripts/output_validation.R` verifying output file existence, column contracts, and non-trivial results
- Write test suite in `tests/testthat/` covering happy path, missing inputs, empty gene list, and seed determinism
- Add `LICENSE` (Apache 2.0) and `README.md`

## Capabilities

### New Capabilities

- `random-forest-classifier`: Train a random forest classifier for diagnostic prediction on gene expression data, with cross-validation-based gene selection, importance ranking, and portable model export (.rds)

### Modified Capabilities

None (new node package, no existing specs to modify).

## Impact

- Affected code: `SKILL.md`, `envs/env-r-4.3.yaml`, `scripts/main.R`, `scripts/input_validation.R`, `scripts/output_validation.R`, `tests/testthat/*.R`, `LICENSE`, `README.md`
- No API changes (new package, no consumers yet)
- Dependencies: R packages `randomForest`, `dplyr`, `ggplot2`, `reshape2`, `yaml`, `filelock`
```

## openspec/changes/create-node-package/design.md

- Source: openspec/changes/create-node-package/design.md
- Lines: 1-67
- SHA256: 7ea3c3026538ab0a577773044e6bd32c52fb9d3ae83f7f63c6e7f7001afcb73f

```md
## Context

The `original/` directory contains a working random-forest-classifier R script (`model_randomForest.R`) plus Python orchestration rules (`train.py`, `common.py`). The R script takes 14 positional arguments and is tightly coupled to the upstream pipeline's YAML confirm-file protocol. The IRE framework requires every node to be a self-contained package with SKILL.md frontmatter, subcommand-dispatched main entry point, NDJSON reporting, and standard exception contracts.

## Goals / Non-Goals

**Goals:**
- Map the original R script's logic 1:1 into `scripts/main.R` with portable `--outdir` parameterization
- Create a V2 SKILL.md frontmatter that agents can parse structurally for orchestration
- Provide `envs/env-r-4.3.yaml` with all R dependencies declared
- Provide input/output validation scripts as executable contracts
- Write tests using testthat covering at least: happy path, missing input, empty gene list, seed determinism
- Follow all five IRE protocols: node package format, SKILL.md frontmatter, CLI invocation, exception handling, core connection

**Non-Goals:**
- Not modifying the Random Forest algorithm or hyperparameters
- Not adding support for alternative model types (logistic, SVM, XGBoost — those are separate nodes)
- Not implementing the Python orchestration rules (DAG, pipeline coordination) — those belong in the framework
- Not integrating with the confirm-file protocol (that is pipeline orchestration, not node concern)

## Decisions

### D1: Subcommand = `train`

The single entry point `scripts/main.R` dispatches on positional arg 1. Since the reference only does one thing (train a random forest), the subcommand is `train`. No `qc` or `fetch` subcommands are needed.

**Rationale**: Matches the CLI contract. Leaves room for future subcommands (e.g., `predict`) without breaking the interface.

### D2: Output file naming aligns with reference

Output files keep their reference names: `randomForest.pdf`, `importance.csv`, `importance.pdf`, `rfcv_mean.csv`, `Cross-validation-error_plot.pdf`, `randomforest_genes.csv`, `randomForest_model.rds`. All go under `--outdir`.

**Rationale**: Consumable by downstream nodes that already expect these names. No rename risk.

### D3: Seed is a `static`-bind parameter with default 42

The original pipeline passes `seed` from config. The node accepts `--seed` with a default of 42 for reproducibility.

**Rationale**: `bind: static` means the framework does not need to wire it. Protocol configs can override the default.

### D4: `--top` parameter controls gene selection count

When `--top` is provided (integer), exactly that many top genes are selected. When absent or "NULL"/"None", the optimal number from CV error minimum is used.

**Rationale**: Matches original behavior (line 119-123 of `model_randomForest.R`). Type is `int` with `required: false`.

### D5: NDJSON stdout, errors to stderr, exit codes per exception contract

Every progress message goes to stdout as `{"level":"info","msg":"..."}`. Final result is `{"level":"result","status":"success","files":[...]}`. Errors go to stderr with pattern-matching substrings.

**Rationale**: Required by CLI contract and exception contract.

### D6: Remove file-locking and confirm-file protocol

The original uses `filelock::lock()` and writes a YAML `confirm_file` for pipeline coordination. These are pipeline orchestration concerns, not node concerns. The node outputs files to `--outdir` and reports them, nothing more.

**Rationale**: Nodes are self-contained black boxes. Pipeline coordination belongs in the framework.

## Risks / Trade-offs

- **R environment complexity**: The `envs/env-r-4.3.yaml` must include all CRAN packages. Missing `reshape2` or `filelock` would cause runtime failures. Mitigation: list all `library()` calls from the original script as dependencies.
- **Path hardcoding in original**: The original script creates directories by parsing file paths. We replace this with `--outdir`-based construction. Mitigation: `dir.create(outdir, recursive=TRUE, showWarnings=FALSE)` at script start.
- **No integration tests with real data**: Test suite uses synthetic data. Real integration testing requires the framework orchestrator. Mitigation: input/output validation scripts serve as the executable contract.

## Open Questions

None. The design is fully specified by the reference implementation and IRE protocols.
```

## openspec/changes/create-node-package/tasks.md

- Source: openspec/changes/create-node-package/tasks.md
- Lines: 1-40
- SHA256: 79f19a4aecbd82aee59aa603b8dbccbf992e2976f01d6b29050b533afd97880d

```md
## 1. Environment and Package Foundation

- [ ] 1.1 Update `envs/env-r-4.3.yaml` with all R dependencies: randomForest, dplyr, ggplot2, reshape2, yaml, filelock
- [ ] 1.2 Verify conda environment can be created from `envs/env-r-4.3.yaml`
- [ ] 1.3 Add LICENSE (Apache 2.0) and README.md

## 2. SKILL.md Contract

- [ ] 2.1 Create `SKILL.md` with v2 YAML frontmatter (name, description, type, inputs, outputs, entry, parameters, exceptions, hardware)
- [ ] 2.2 Write narrative body sections: Node Function, Expected Input, Invocation, Expected Output, Exceptions, Reporting Requirements, Hardware Requirements

## 3. Core Script (scripts/main.R)

- [ ] 3.1 Create `scripts/main.R` with subcommand dispatch mechanism
- [ ] 3.2 Implement `train` subcommand: parse --in-mat, --in-map, --in-gene, --outdir, --seed, --top, --ntree
- [ ] 3.3 Implement randomForest::randomForest() call with ntree, importance, proximity
- [ ] 3.4 Implement 5-repeat 10-fold rfcv cross-validation
- [ ] 3.5 Implement gene selection by MeanDecreaseGini importance (top N or CV-optimal)
- [ ] 3.6 Generate all 7 output plots and files under --outdir
- [ ] 3.7 Emit NDJSON info + result lines to stdout, errors to stderr
- [ ] 3.8 Handle edge cases: empty gene list, missing input, file permission errors

## 4. Validation Scripts

- [ ] 4.1 Create `scripts/input_validation.R` checking file existence and CSV validity
- [ ] 4.2 Create `scripts/output_validation.R` checking all 7 output files exist and have expected structure

## 5. Test Suite

- [ ] 5.1 Create `tests/testthat/test-train.R` with happy path test using synthetic data
- [ ] 5.2 Add tests: missing input file, empty gene list, seed determinism
- [ ] 5.3 Add tests: unknown subcommand, invalid parameters
- [ ] 5.4 All tests pass with `Rscript -e 'testthat::test_dir("tests/testthat/")'`

## 6. Verification

- [ ] 6.1 Verify `scripts/main.R train` runs end-to-end with synthetic data
- [ ] 6.2 Verify all 7 output files are created and valid
- [ ] 6.3 Verify NDJSON stdout format and exit codes
- [ ] 6.4 Verify SKILL.md frontmatter parses as valid YAML
```

## openspec/changes/create-node-package/specs/random-forest-classifier/spec.md

- Source: openspec/changes/create-node-package/specs/random-forest-classifier/spec.md
- Lines: 1-122
- SHA256: a9c8562248422b99a617f08a6d7b31ba62b3794f6be318f2ffdc64c690c48476

[TRUNCATED]

```md
## ADDED Requirements

### Requirement: Node package conforms to flat layout

The node package SHALL use the flat layout with `SKILL.md` at the repo root, `envs/` directory for conda environments, `scripts/` for entry points and validation, and `tests/` for test suite.

#### Scenario: Flat layout structure

- **WHEN** the node package is checked out
- **THEN** `SKILL.md` exists at the repo root
- **AND** `envs/env-r-4.3.yaml` exists in the `envs/` directory
- **AND** `scripts/main.R` exists
- **AND** `scripts/input_validation.R` exists
- **AND** `scripts/output_validation.R` exists
- **AND** `tests/testthat/` contains test files

### Requirement: SKILL.md has valid v2 frontmatter

The `SKILL.md` file SHALL have a YAML frontmatter block containing all required fields: `name`, `description`, `type`, `inputs`, `outputs`, `entry`, `parameters`, `exceptions`, and `hardware`.

#### Scenario: Agent parses frontmatter

- **WHEN** an AI agent reads `SKILL.md`
- **THEN** it can parse the YAML frontmatter to discover the node's identity, input/output contracts, parameters, exception patterns, and hardware requirements

#### Scenario: Frontmatter has valid inputs

- **WHEN** an agent inspects the `inputs` section
- **THEN** each input declares `name`, `format`, `semantic_type`, and `description`
- **AND** `bind` annotations classify every parameter as `upstream`, `config`, `static`, or `framework`

### Requirement: Script entry point uses subcommand dispatch

The `scripts/main.R` SHALL be the single entry point. The first positional argument SHALL be the subcommand. The script SHALL dispatch to `train` handler for the `train` subcommand.

#### Scenario: Train subcommand

- **WHEN** invoked as `Rscript scripts/main.R train --in-mat <path> --in-map <path> --in-gene <path> --outdir <path> --seed 42`
- **THEN** the script trains a random forest model
- **AND** exits with status 0
- **AND** writes all output files to `--outdir`

#### Scenario: Unknown subcommand

- **WHEN** invoked as `Rscript scripts/main.R unknown`
- **THEN** the script writes an error to stderr
- **AND** exits with status 1

### Requirement: Train subcommand produces correct outputs

The `train` subcommand SHALL produce seven output files in `--outdir`: `randomForest.pdf`, `importance.csv`, `importance.pdf`, `rfcv_mean.csv`, `Cross-validation-error_plot.pdf`, `randomforest_genes.csv`, and `randomForest_model.rds`.

#### Scenario: Successful training

- **WHEN** valid input files are provided and the random forest fits successfully
- **THEN** all seven output files exist and are non-empty
- **AND** `importance.csv` contains columns for variables and MeanDecreaseGini
- **AND** `randomforest_genes.csv` contains the selected gene names
- **AND** `randomForest_model.rds` is a valid R model object

#### Scenario: Seed determinism

- **WHEN** the same inputs and seed are provided twice
- **THEN** the output `importance.csv` is identical in both runs
- **AND** the output `randomforest_genes.csv` is identical in both runs

### Requirement: NDJSON reporting to stdout

The script SHALL emit NDJSON lines to stdout. Informational messages SHALL have `level: "info"`. The final line SHALL have `level: "result"` with `status` and `files` fields.

#### Scenario: NDJSON output

- **WHEN** the script completes successfully
- **THEN** each stdout line is valid JSON
- **AND** the final line has `level: "result"`
- **AND** the final line includes the list of output files

### Requirement: Exception handling follows contract

The script SHALL exit non-zero on failures and write error diagnostics to stderr. The stderr output SHALL contain substrings matching the exception patterns declared in SKILL.md.
```

Full source: openspec/changes/create-node-package/specs/random-forest-classifier/spec.md

