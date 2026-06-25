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
