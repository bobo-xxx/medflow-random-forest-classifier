# random-forest-classifier

Random Forest classifier for diagnostic prediction in the IRE agentic bioinformatics workflow framework.

## Overview

This node trains a Random Forest model on gene expression data for binary classification (case vs control). It:

1. Fits a Random Forest classifier using the `randomForest` R package (1000 trees, variable importance, proximity)
2. Performs 5-repeat 10-fold cross-validation (rfcv) to assess prediction error vs. number of genes
3. Selects the top N genes by Mean Decrease Gini importance (or optimal number from CV)
4. Exports: importance table, diagnostic plots, selected gene list, and trained model (.rds)

## Usage

```bash
Rscript scripts/main.R train \
  --in-mat <expression_matrix.csv> \
  --in-map <group_mapping.csv> \
  --in-gene <gene_list.csv> \
  --outdir ./output \
  --seed 42
```

## Outputs

| File | Description |
|------|-------------|
| `randomForest.pdf` | Error rate vs. number of trees |
| `importance.csv` | Variable importance (Mean Decrease Gini) |
| `importance.pdf` | Variable importance plot |
| `rfcv_mean.csv` | Cross-validation error by gene count |
| `Cross-validation-error_plot.pdf` | CV error curve with optimal N marker |
| `randomforest_genes.csv` | Top N selected genes |
| `randomForest_model.rds` | Trained model object |

## Environment

```bash
conda env create -f envs/env-r-4.3.yaml
```

## License

Apache 2.0
