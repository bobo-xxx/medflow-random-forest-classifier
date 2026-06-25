#!/usr/bin/env Rscript
# Suppress all warnings (ggplot2 deprecation, etc.) from stdout
options(warn = -1)
suppressPackageStartupMessages(library(jsonlite))
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(randomForest))
suppressPackageStartupMessages(library(ggplot2))
suppressPackageStartupMessages(library(reshape2))

# ── NDJSON reporting ──────────────────────────────────────────────────────────

ndjson_info <- function(msg) {
  cat(jsonlite::toJSON(list(level = "info", msg = msg), auto_unbox = TRUE), "\n")
}

ndjson_result <- function(status, files, metadata = list()) {
  cat(jsonlite::toJSON(c(
    list(level = "result", status = status, files = files),
    metadata
  ), auto_unbox = TRUE), "\n")
}

die <- function(msg, exit_code = 1L) {
  cat(msg, file = stderr())
  quit(status = exit_code)
}

# ── Core training logic ───────────────────────────────────────────────────────

do_train <- function(in_mat, in_map, in_gene, outdir, seed, top, ntree) {

  # ── Input validation ──────────────────────────────────────────────────────
  ndjson_info("Validating input files")
  for (f in c(in_mat, in_map, in_gene)) {
    if (is.null(f) || !file.exists(f)) {
      die(paste0("input file not found: ", f, "\n"), 1L)
    }
  }
  ndjson_info("All input files exist")

  # Ensure output directory
  if (!dir.exists(outdir)) {
    dir.create(outdir, recursive = TRUE)
  }

  # ── Load data ─────────────────────────────────────────────────────────────
  ndjson_info("Loading expression matrix")
  exp <- read.csv(in_mat, row.names = 1)

  ndjson_info("Loading gene list")
  genes <- read.csv(in_gene, stringsAsFactors = FALSE)[[1]]

  ndjson_info("Loading group mapping")
  group <- read.csv(in_map, row.names = 1)
  colnames(group) <- "group"
  group$group <- factor(group$group, levels = unique(group$group))

  # Intersect gene list with expression matrix
  genes <- intersect(rownames(exp), genes)
  if (length(genes) == 0) {
    die("no genes found in expression matrix\n", 1L)
  }
  ndjson_info(paste("Using", length(genes), "genes for training"))

  # ── Transpose: samples as rows, genes as columns ──────────────────────────
  ferr_rt <- t(exp[genes, rownames(group)])

  # ── Fit random forest ─────────────────────────────────────────────────────
  set.seed(seed)
  ndjson_info(paste("Fitting randomForest with ntree =", ntree))
  rf_output <- randomForest(
    x = ferr_rt,
    y = group[[1]],
    importance = TRUE,
    ntree = ntree,
    proximity = TRUE
  )

  # ── Output 1: Error rate plot ─────────────────────────────────────────────
  rfplot <- file.path(outdir, "randomForest.pdf")
  pdf(file = rfplot, width = 8, height = 5)
  par(oma = c(0, 0, 0, 0), mar = c(4, 4, 1, 1), las = 1)
  plot(rf_output, type = "l", cex = 0.7)
  dev.off()
  ndjson_info(paste("Wrote", rfplot))

  # ── Output 2: Importance plot ─────────────────────────────────────────────
  impplot <- file.path(outdir, "importance.pdf")
  pdf(file = impplot, width = 8, height = 5)
  par(oma = c(0, 0, 0, 0), mar = c(4, 4, 1, 1), las = 1)
  varImpPlot(rf_output, type = 2, scale = FALSE, cex = 0.7)
  dev.off()
  ndjson_info(paste("Wrote", impplot))

  # ── Output 3: Importance CSV ──────────────────────────────────────────────
  rf_importances <- importance(rf_output, scale = FALSE)
  rf_importances2 <- rf_importances %>%
    as.data.frame() %>%
    arrange(desc(MeanDecreaseGini))

  imp <- file.path(outdir, "importance.csv")
  write.csv(rf_importances2, imp)
  ndjson_info(paste("Wrote", imp))

  # ── Cross-validation (5-repeat 10-fold) ───────────────────────────────────
  ndjson_info("Running 5-repeat 10-fold cross-validation (rfcv)")
  ferr_rt_train_cv <- lapply(1:5, function(i) {
    set.seed(seed + i)
    rfcv(ferr_rt, group[[1]], cv.fold = 10, step = 1.5)
  })

  # ── Output 4: CV error table ──────────────────────────────────────────────
  train_cv <- data.frame(sapply(ferr_rt_train_cv, "[[", "error.cv"))
  train_cv$gene_num <- rownames(train_cv)
  train_cv <- reshape2::melt(train_cv, id = "gene_num")
  train_cv$gene_num <- as.numeric(as.character(train_cv$gene_num))

  rfcv_mean <- aggregate(train_cv$value,
    by = list(train_cv$gene_num), FUN = mean
  )
  colnames(rfcv_mean) <- c("x", "y")

  train_cv_res <- file.path(outdir, "rfcv_mean.csv")
  write.csv(rfcv_mean, train_cv_res, row.names = FALSE)
  ndjson_info(paste("Wrote", train_cv_res))

  # ── Determine optimal gene count ──────────────────────────────────────────
  n <- rfcv_mean$x[which.min(rfcv_mean$y)]
  if (!is.null(top) && top != "NULL" && top != "None") {
    n <- as.integer(top)
  }

  # ── Output 5: CV error plot ───────────────────────────────────────────────
  errplot <- file.path(outdir, "Cross-validation-error_plot.pdf")
  p <- ggplot(rfcv_mean, aes(x, y)) +
    geom_line(lwd = 0.35) +
    geom_point(color = "#ef475d", size = 0.5) +
    geom_text(
      label = rfcv_mean$x, size = 2,
      nudge_x = (max(rfcv_mean$x) - min(rfcv_mean$x)) / 50,
      nudge_y = (max(rfcv_mean$y) - min(rfcv_mean$y)) / 20
    ) +
    geom_vline(xintercept = n, lty = 2, lwd = 0.35) +
    theme_bw() +
    theme(panel.grid = element_blank()) +
    theme(
      line = element_line(size = 0.35),
      text = element_text(size = 6),
      axis.text = element_text(size = 6),
      axis.title = element_text(size = 6)
    ) +
    labs(title = "", x = "Number of genes", y = "Cross-validation error")
  ggsave(
    plot = p, filename = errplot,
    height = 5, width = 8.1, units = "cm"
  )
  ndjson_info(paste("Wrote", errplot))

  # ── Output 6: Selected genes ──────────────────────────────────────────────
  out_mat <- file.path(outdir, "randomforest_genes.csv")
  write.csv(head(rownames(rf_importances2), n), out_mat, row.names = FALSE)
  ndjson_info(paste("Wrote", out_mat))

  # ── Output 7: Serialized model ────────────────────────────────────────────
  model_rds_path <- file.path(outdir, "randomForest_model.rds")
  saveRDS(rf_output, model_rds_path)
  ndjson_info(paste("Wrote", model_rds_path))

  # ── Final NDJSON result ───────────────────────────────────────────────────
  output_files <- c(
    rfplot, imp, impplot, train_cv_res, errplot, out_mat, model_rds_path
  )
  ndjson_result(
    status = "success",
    files = output_files,
    metadata = list(
      seed = seed,
      ntree = ntree,
      genes_used = length(genes),
      genes_selected = n,
      cv_method = "5-repeat 10-fold rfcv"
    )
  )
}

# ── Argument parsing ──────────────────────────────────────────────────────────

parse_arg <- function(args, name, default = NULL) {
  idx <- which(args == name)
  if (length(idx) > 0 && idx < length(args)) {
    return(args[idx + 1])
  }
  return(default)
}

args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 1) {
  die("error: no subcommand provided. valid: train\n", 1L)
}

subcommand <- args[1]
param_args <- args[-1]

# ── Subcommand dispatch ───────────────────────────────────────────────────────

if (subcommand == "train") {
  ndjson_info("Dispatching to Random Forest training handler")

  in_mat  <- parse_arg(param_args, "--in-mat")
  in_map  <- parse_arg(param_args, "--in-map")
  in_gene <- parse_arg(param_args, "--in-gene")
  outdir  <- parse_arg(param_args, "--outdir", ".")
  seed    <- as.integer(parse_arg(param_args, "--seed", "42"))
  top     <- parse_arg(param_args, "--top", "NULL")
  ntree   <- as.integer(parse_arg(param_args, "--ntree", "1000"))

  do_train(in_mat, in_map, in_gene, outdir, seed, top, ntree)

} else {
  die(paste0("unknown subcommand: ", subcommand, ". valid: train\n"), 1L)
}
