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

#### Scenario: Missing input file

- **WHEN** `--in-mat` points to a non-existent file
- **THEN** the script writes "input file not found" to stderr
- **AND** exits with exit code 1

#### Scenario: Empty gene list

- **WHEN** the input gene list contains no genes present in the expression matrix
- **THEN** the script writes "no genes found in expression matrix" to stderr
- **AND** exits with exit code 1

### Requirement: Input validation script checks file existence

`scripts/input_validation.R` SHALL accept the same parameters as `main.R` and verify that all input files exist and are in valid CSV format with required columns.

#### Scenario: Valid input

- **WHEN** all input files exist and have valid formats
- **THEN** `input_validation.R` exits with status 0

#### Scenario: Invalid input

- **WHEN** any input file is missing or malformed
- **THEN** `input_validation.R` exits with non-zero status
- **AND** writes a descriptive error to stderr

### Requirement: Output validation script checks output completeness

`scripts/output_validation.R` SHALL accept `--outdir` and verify that all seven expected output files exist, are non-empty, and have the expected column structure (for CSV files).

#### Scenario: Complete outputs

- **WHEN** all seven output files exist and are valid
- **THEN** `output_validation.R` exits with status 0

#### Scenario: Missing output

- **WHEN** any expected output file is missing
- **THEN** `output_validation.R` exits with non-zero status
- **AND** writes a descriptive error to stderr
