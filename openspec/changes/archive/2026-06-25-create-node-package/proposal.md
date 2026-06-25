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
