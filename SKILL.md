---
name: random-forest-classifier
description: >
  Random Forest classifier for diagnostic prediction on gene expression data.
  Fits a randomForest model with 1000 trees, importance ranking, and proximity
  matrix, performs 5-repeat 10-fold cross-validation (rfcv) to assess prediction
  error vs. number of genes, and selects top N genes by MeanDecreaseGini or
  CV-optimal count. Use for binary classification in transcriptomics biomarker
  discovery when prior nodes have produced an expression matrix, group mapping,
  and candidate gene list.
type: standard

inputs:
  - name: expression_matrix.csv
    format: csv
    semantic_type: expression_matrix
    description: "Normalized expression matrix (genes x samples, row names in column 1, comma-separated)"

  - name: sample_group.csv
    format: csv
    semantic_type: sample_annotation
    description: "Sample-to-group mapping (columns: sample, group; first column is row names; comma-separated)"

  - name: gene_list.csv
    format: csv
    semantic_type: gene_list
    description: "Candidate gene list (single-column CSV, no header required)"

outputs:
  - name: randomForest.pdf
    format: pdf
    semantic_type: diagnostic_plot
    description: "Error rate vs. number of trees plot"

  - name: importance.csv
    format: csv
    semantic_type: importance_table
    columns: [MeanDecreaseAccuracy, MeanDecreaseGini]
    description: "Variable importance table sorted by MeanDecreaseGini"

  - name: importance.pdf
    format: pdf
    semantic_type: diagnostic_plot
    description: "Variable importance plot (type=2, unscaled)"

  - name: rfcv_mean.csv
    format: csv
    semantic_type: cv_error_table
    columns: [x, y]
    description: "Mean cross-validation error by gene count (5-repeat 10-fold rfcv)"

  - name: Cross-validation-error_plot.pdf
    format: pdf
    semantic_type: diagnostic_plot
    description: "CV error curve with vertical line at optimal gene count"

  - name: randomforest_genes.csv
    format: csv
    semantic_type: gene_list
    columns: [x]
    description: "Top N selected genes by MeanDecreaseGini importance"

  - name: randomForest_model.rds
    format: rds
    semantic_type: model_object
    description: "Serialized randomForest model object for downstream prediction"

file_layout:
  nesting: flat
file_discovery:
  recursive: false
  pattern: "*.csv"

entry: scripts/main.R

parameters:
  - name: train
    type: choice
    choices: [train]
    required: true
    bind: config
    description: "Subcommand: train the random forest classifier"

  - name: --in-mat
    type: file
    required: true
    bind: upstream
    description: "Expression matrix CSV (genes x samples, row names in column 1)"

  - name: --in-map
    type: file
    required: true
    bind: upstream
    description: "Sample-to-group mapping CSV (row names: sample IDs, column: group)"

  - name: --in-gene
    type: file
    required: true
    bind: upstream
    description: "Candidate gene list (single-column CSV)"

  - name: --outdir
    type: file_out
    required: true
    bind: framework
    description: "Output directory for all generated files"

  - name: --seed
    type: int
    required: false
    default: 42
    bind: static
    description: "Random seed for reproducibility"

  - name: --top
    type: string
    required: false
    default: NULL
    bind: static
    description: "Number of top genes to select by importance. If NULL or None, uses CV-optimal count."

  - name: --ntree
    type: int
    required: false
    default: 1000
    bind: static
    description: "Number of trees in the random forest"

exceptions:
  - exit_code: 1
    pattern: "input file not found"
    nature: data_insufficient
    action: halt

  - exit_code: 1
    pattern: "no genes found in expression matrix"
    nature: data_insufficient
    action: skip_with_warning

  - exit_code: 1
    pattern: "unknown subcommand"
    nature: env_bug
    action: escalate

hardware:
  memory_gb: 8
  cpu: 4
  gpu: false
  runtime: "~15 min"
---

# Node Function

This node trains a Random Forest classifier for diagnostic prediction using the `randomForest` R package. It fits a random forest model with `ntree=1000` (default), computes variable importance by MeanDecreaseGini and MeanDecreaseAccuracy, and calculates the proximity matrix. To support gene selection, it performs 5-repeat 10-fold cross-validation via `rfcv()` and selects either the top N genes by importance (`--top`) or the number minimizing cross-validation error.

**Algorithm**: Breiman's Random Forest (classification mode) with Gini impurity splitting.

**Intent**: Given a pre-filtered gene expression matrix and binary group labels (case vs. control), train a classifier that ranks genes by diagnostic importance and exports a portable model object for downstream prediction or model comparison.

# Expected Input

**Expression Matrix** (`--in-mat`): A comma-separated CSV file with genes as rows and samples as columns. The first column contains gene identifiers (used as row names). Values are normalized expression levels.

**Sample Group Mapping** (`--in-map`): A comma-separated CSV with row names as sample IDs and one column named `group`. The group column must be a factor with exactly two levels (control, case). Row names must match the column names in the expression matrix.

**Gene List** (`--in-gene`): A single-column CSV file listing candidate gene names. These genes must be present as row names in the expression matrix. The intersection of listed genes with the expression matrix rows is used for training.

**Validity conditions**:
- All three input files must exist and be readable
- At least one gene from the gene list must be present in the expression matrix
- The group mapping must have exactly 2 factor levels and cover all expression matrix columns
- All content is in English

# Invocation

```bash
Rscript scripts/main.R train \
  --in-mat expression_matrix.csv \
  --in-map sample_group.csv \
  --in-gene gene_list.csv \
  --outdir ./output \
  --seed 42 \
  --top NULL \
  --ntree 1000
```

The first positional argument `train` is the subcommand. All other parameters use `--name value` convention.

# Expected Output

Seven files written to `--outdir`:

| File | Format | Description |
|------|--------|-------------|
| `randomForest.pdf` | PDF | Error rate vs. number of trees |
| `importance.csv` | CSV | Variable importance (MeanDecreaseAccuracy, MeanDecreaseGini) sorted by Gini |
| `importance.pdf` | PDF | Variable importance plot (type=2, unscaled) |
| `rfcv_mean.csv` | CSV | Mean CV error by gene count (columns: x, y) |
| `Cross-validation-error_plot.pdf` | PDF | CV error curve with vertical line at optimal gene count |
| `randomforest_genes.csv` | CSV | Top N selected genes |
| `randomForest_model.rds` | RDS | Serialized randomForest model object |

If `--top` is NULL or None, the number of selected genes is determined by the CV error minimum.

Stdout emits NDJSON: `{"level":"info","msg":"..."}` for progress and a final
`{"level":"result","status":"success","files":[...],"seed":...,"ntree":...,"genes_used":...,"genes_selected":...}`.

# Exceptions

**Input file not found (exit code 1)**: A required input file does not exist or cannot be read. Check file paths and permissions. The pipeline halts.

**No genes found in expression matrix (exit code 1)**: None of the genes in `--in-gene` are present as row names in the expression matrix. This is a data insufficiency error; the node skips with a warning.

**Unknown subcommand (exit code 1)**: The first positional argument is not `train`. This indicates a configuration error in the protocol. Escalated to the human operator.

# Reporting Requirements

All output to stdout is NDJSON (one JSON object per line). Info lines for progress tracking. Final result line with `status`, `files`, and metadata. All content in English.

# Hardware Requirements

- Memory: 8 GB recommended (for matrices up to 500 genes x 200 samples)
- CPU: 4 cores
- GPU: not required
- Estimated runtime: ~15 minutes for typical datasets
