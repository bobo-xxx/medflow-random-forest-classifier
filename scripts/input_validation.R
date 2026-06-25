#!/usr/bin/env Rscript

# input_validation.R: Pre-execution check for random-forest-classifier inputs.
# Accepts: --in-mat, --in-map, --in-gene
# Exit 0 if valid, non-zero + stderr message if invalid.

args <- commandArgs(trailingOnly = TRUE)

parse_arg <- function(args, name, default = NULL) {
  idx <- which(args == name)
  if (length(idx) > 0 && idx < length(args)) return(args[idx + 1])
  return(default)
}

in_mat  <- parse_arg(args, "--in-mat")
in_map  <- parse_arg(args, "--in-map")
in_gene <- parse_arg(args, "--in-gene")

# Check file existence
if (is.null(in_mat) || !file.exists(in_mat)) {
  cat("input file not found: expression matrix\n", file = stderr())
  quit(status = 1)
}
if (is.null(in_map) || !file.exists(in_map)) {
  cat("input file not found: group mapping\n", file = stderr())
  quit(status = 1)
}
if (is.null(in_gene) || !file.exists(in_gene)) {
  cat("input file not found: gene list\n", file = stderr())
  quit(status = 1)
}

# Check CSV format: at minimum, read.csv must succeed
exp_test <- tryCatch(read.csv(in_mat, row.names = 1), error = function(e) NULL)
if (is.null(exp_test)) {
  cat("input file corrupt: expression matrix is not valid CSV\n", file = stderr())
  quit(status = 1)
}

group_test <- tryCatch(read.csv(in_map, row.names = 1), error = function(e) NULL)
if (is.null(group_test)) {
  cat("input file corrupt: group mapping is not valid CSV\n", file = stderr())
  quit(status = 1)
}

gene_test <- tryCatch(read.csv(in_gene, stringsAsFactors = FALSE), error = function(e) NULL)
if (is.null(gene_test) || ncol(gene_test) < 1) {
  cat("input file corrupt: gene list is not valid CSV\n", file = stderr())
  quit(status = 1)
}

# Check group mapping has a 'group' column and exactly 2 levels
colnames(group_test) <- tolower(colnames(group_test))
if (!"group" %in% colnames(group_test)) {
  cat("input file corrupt: group mapping has no 'group' column\n", file = stderr())
  quit(status = 1)
}
if (length(unique(group_test$group)) < 2) {
  cat("data insufficient: group mapping has fewer than 2 unique groups\n", file = stderr())
  quit(status = 1)
}
if (length(unique(group_test$group)) > 2) {
  cat("data insufficient: group mapping has more than 2 unique groups (expected binary)\n", file = stderr())
  quit(status = 1)
}

# Check at least one gene from list is in expression matrix
genes <- gene_test[[1]]
common_genes <- intersect(rownames(exp_test), genes)
if (length(common_genes) == 0) {
  cat("no genes found in expression matrix\n", file = stderr())
  quit(status = 1)
}

# Check group samples match expression matrix columns
group_samples <- rownames(group_test)
exp_samples <- colnames(exp_test)
missing_samples <- setdiff(group_samples, exp_samples)
if (length(missing_samples) > 0) {
  cat("data mismatch: group mapping has samples not in expression matrix\n", file = stderr())
  quit(status = 1)
}

# All checks passed
quit(status = 0)
