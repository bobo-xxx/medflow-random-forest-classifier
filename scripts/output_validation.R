#!/usr/bin/env Rscript

# output_validation.R: Post-execution check for random-forest-classifier outputs.
# Accepts: --outdir
# Verifies all 7 expected output files exist, are non-empty, and have valid structure.
# Exit 0 if valid, non-zero + stderr message if invalid.

args <- commandArgs(trailingOnly = TRUE)

parse_arg <- function(args, name, default = NULL) {
  idx <- which(args == name)
  if (length(idx) > 0 && idx < length(args)) return(args[idx + 1])
  return(default)
}

outdir <- parse_arg(args, "--outdir", ".")

expected_files <- c(
  "randomForest.pdf",
  "importance.csv",
  "importance.pdf",
  "rfcv_mean.csv",
  "Cross-validation-error_plot.pdf",
  "randomforest_genes.csv",
  "randomForest_model.rds"
)

# Check each file exists and is non-empty
for (f in expected_files) {
  path <- file.path(outdir, f)
  if (!file.exists(path)) {
    cat("output file missing:", f, "\n", file = stderr())
    quit(status = 1)
  }
  if (file.info(path)$size == 0) {
    cat("output file empty:", f, "\n", file = stderr())
    quit(status = 1)
  }
}

# Validate CSV structure
importance_path <- file.path(outdir, "importance.csv")
imp <- tryCatch(read.csv(importance_path), error = function(e) NULL)
if (is.null(imp)) {
  cat("output file corrupt: importance.csv is not valid CSV\n", file = stderr())
  quit(status = 1)
}
if (!"MeanDecreaseGini" %in% colnames(imp)) {
  cat("output file corrupt: importance.csv missing MeanDecreaseGini column\n", file = stderr())
  quit(status = 1)
}

# Validate rfcv_mean.csv structure
rfcv_path <- file.path(outdir, "rfcv_mean.csv")
rfcv <- tryCatch(read.csv(rfcv_path), error = function(e) NULL)
if (is.null(rfcv)) {
  cat("output file corrupt: rfcv_mean.csv is not valid CSV\n", file = stderr())
  quit(status = 1)
}
if (!all(c("x", "y") %in% colnames(rfcv))) {
  cat("output file corrupt: rfcv_mean.csv missing required columns (x, y)\n", file = stderr())
  quit(status = 1)
}

# Validate randomforest_genes.csv is non-empty
genes_path <- file.path(outdir, "randomforest_genes.csv")
sel_genes <- tryCatch(read.csv(genes_path), error = function(e) NULL)
if (is.null(sel_genes)) {
  cat("output file corrupt: randomforest_genes.csv is not valid CSV\n", file = stderr())
  quit(status = 1)
}
if (nrow(sel_genes) == 0) {
  cat("output file empty: randomforest_genes.csv has no genes selected\n", file = stderr())
  quit(status = 1)
}

# Validate model RDS can be loaded
model_path <- file.path(outdir, "randomForest_model.rds")
model <- tryCatch(readRDS(model_path), error = function(e) NULL)
if (is.null(model)) {
  cat("output file corrupt: randomForest_model.rds cannot be deserialized\n", file = stderr())
  quit(status = 1)
}
if (!inherits(model, "randomForest")) {
  cat("output file corrupt: randomForest_model.rds is not a randomForest object\n", file = stderr())
  quit(status = 1)
}

# All checks passed
quit(status = 0)
