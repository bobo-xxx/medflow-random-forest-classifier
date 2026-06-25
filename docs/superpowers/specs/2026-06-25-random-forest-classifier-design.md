---
comet_change: create-node-package
role: technical-design
canonical_spec: openspec
---

# Random Forest Classifier Node Package Design

## Architecture

```
scripts/main.R  (single entry, subcommand dispatch)
  ├── train handler
  │     ├── Parse args (--in-mat, --in-map, --in-gene, --outdir, --seed, --top, --ntree)
  │     ├── Load data (read.csv)
  │     ├── randomForest::randomForest(ntree=1000, importance=TRUE, proximity=TRUE)
  │     ├── rfcv(): 5-repeat 10-fold cross-validation
  │     ├── Gene selection: top N by MeanDecreaseGini, or CV-optimal
  │     ├── Output: 7 files under --outdir
  │     └── NDJSON reporting to stdout
  ├── input_validation.R
  │     └── Check file existence, CSV format, required columns
  └── output_validation.R
        └── Check all 7 output files exist, valid format, non-empty
```

## Data Flow

```
Input (CSV)                  Processing                     Output (under --outdir)
───────────                  ──────────                     ───────────────────────
in_mat: expression matrix ─┐
in_map: group labels ──────┤─► randomForest() ─────────────► randomForest.pdf
in_gene: gene list ────────┘       │                         importance.csv
                                   ├► importance() ─────────► importance.pdf
                                   ├► rfcv() ×5 ───────────► rfcv_mean.csv
                                   │                         Cross-validation-error_plot.pdf
                                   └► head(imp, n) ─────────► randomforest_genes.csv
                                   └► saveRDS() ────────────► randomForest_model.rds
```

## Key Design Decisions

1. **Subcommand = train**: Single-action node. First positional arg dispatched via if/else.
2. **Output naming preserved**: Original file names kept for downstream compatibility.
3. **No orchestration concerns**: File-locking and confirm-file YAML removed — those are framework/pipeline responsibilities, not node concerns.
4. **Synthetic testing**: 10 genes x 20 samples synthetic data; real data testing requires framework integration.
5. **NDJSON reporting**: `{"level":"info","msg":"..."}` for progress, `{"level":"result","status":"success","files":[...]}` for final.

## Environment

- R 4.3 via conda-forge
- CRAN packages: `randomForest`, `dplyr`, `ggplot2`, `reshape2`, `yaml`, `filelock` (yaml/filelock may be needed if confirm-file is kept as an optional flag; otherwise only the first four)

## Error Handling

| Condition | Exit Code | stderr Pattern | Exception Nature |
|-----------|-----------|----------------|-----------------|
| Missing input file | 1 | "input file not found" | data_insufficient |
| Empty gene list | 1 | "no genes found in expression matrix" | data_insufficient |
| Unknown subcommand | 1 | "unknown subcommand" | env_bug |

## Testing

- Framework: testthat
- Test file: `tests/testthat/test-train.R`
- Coverage: happy path, seed determinism, missing inputs, empty gene list, unknown subcommand
- Synthetic data: 10 genes x 20 samples, balanced case/control
