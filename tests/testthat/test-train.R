context("Random Forest Classifier - train subcommand")

# Project root: tests/testthat/ is 2 levels below repo root
proj_root <- normalizePath(file.path("..", ".."))

# Helper: run node script, capture exit code and outputs
# Uses --vanilla to avoid testthat environment interference with R subprocesses
run_node <- function(args) {
  main_script <- file.path(proj_root, "scripts", "main.R")
  stdout_file <- tempfile("rf_stdout_")
  stderr_file <- tempfile("rf_stderr_")
  all_args <- c("--vanilla", main_script, args)
  status <- system2("Rscript", all_args, stdout = stdout_file, stderr = stderr_file)
  list(
    exit_code = status,
    stdout = if (file.exists(stdout_file)) readLines(stdout_file) else character(0),
    stderr = if (file.exists(stderr_file)) paste(readLines(stderr_file), collapse = "\n") else ""
  )
}

# Helper: run validation script
run_validation <- function(script_name, args) {
  val_script <- file.path(proj_root, "scripts", script_name)
  stdout_file <- tempfile("rf_stdout_")
  stderr_file <- tempfile("rf_stderr_")
  all_args <- c("--vanilla", val_script, args)
  status <- system2("Rscript", all_args, stdout = stdout_file, stderr = stderr_file)
  list(
    exit_code = status,
    stdout = if (file.exists(stdout_file)) readLines(stdout_file) else character(0),
    stderr = if (file.exists(stderr_file)) paste(readLines(stderr_file), collapse = "\n") else ""
  )
}

test_that("happy path trains model and produces 7 output files", {
  tmpdir <- tempfile("rf_test_")
  dir.create(tmpdir)
  outdir <- file.path(tmpdir, "output")

  data <- create_synthetic_data(tmpdir)

  res <- run_node(c(
    "train",
    "--in-mat",  data$in_mat,
    "--in-map",  data$in_map,
    "--in-gene", data$in_gene,
    "--outdir",  outdir,
    "--seed",    "42"
  ))

  expect_equal(res$exit_code, 0L)

  # Check all 7 output files exist and are non-empty
  expected_files <- c(
    "randomForest.pdf",
    "importance.csv",
    "importance.pdf",
    "rfcv_mean.csv",
    "Cross-validation-error_plot.pdf",
    "randomforest_genes.csv",
    "randomForest_model.rds"
  )

  for (f in expected_files) {
    path <- file.path(outdir, f)
    expect_true(file.exists(path))
    expect_gt(file.info(path)$size, 0)
  }

  # Verify importance.csv structure
  imp <- read.csv(file.path(outdir, "importance.csv"))
  expect_true("MeanDecreaseGini" %in% colnames(imp))
  expect_gt(nrow(imp), 0)

  # Verify selected genes CSV
  sel_genes <- read.csv(file.path(outdir, "randomforest_genes.csv"))
  expect_gt(nrow(sel_genes), 0)

  # Verify model RDS can be loaded
  model <- readRDS(file.path(outdir, "randomForest_model.rds"))
  expect_s3_class(model, "randomForest")

  # Verify final NDJSON result line
  stdout_lines <- res$stdout
  last_line <- stdout_lines[length(stdout_lines)]
  last_json <- jsonlite::fromJSON(last_line)
  expect_equal(last_json$level, "result")
  expect_equal(last_json$status, "success")
  expect_equal(length(last_json$files), 7)

  unlink(tmpdir, recursive = TRUE)
})

test_that("seed determinism produces identical importance and selected genes", {
  tmpdir1 <- tempfile("rf_det_1_")
  tmpdir2 <- tempfile("rf_det_2_")
  dir.create(tmpdir1)
  dir.create(tmpdir2)
  outdir1 <- file.path(tmpdir1, "output")
  outdir2 <- file.path(tmpdir2, "output")

  data <- create_synthetic_data(tmpdir1, seed = 42)

  run_node(c(
    "train",
    "--in-mat",  data$in_mat,
    "--in-map",  data$in_map,
    "--in-gene", data$in_gene,
    "--outdir",  outdir1,
    "--seed",    "123"
  ))

  run_node(c(
    "train",
    "--in-mat",  data$in_mat,
    "--in-map",  data$in_map,
    "--in-gene", data$in_gene,
    "--outdir",  outdir2,
    "--seed",    "123"
  ))

  imp1 <- read.csv(file.path(outdir1, "importance.csv"))
  imp2 <- read.csv(file.path(outdir2, "importance.csv"))
  expect_equal(imp1, imp2)

  genes1 <- read.csv(file.path(outdir1, "randomforest_genes.csv"))
  genes2 <- read.csv(file.path(outdir2, "randomforest_genes.csv"))
  expect_equal(genes1, genes2)

  unlink(tmpdir1, recursive = TRUE)
  unlink(tmpdir2, recursive = TRUE)
})

test_that("missing input file exits with code 1 and writes to stderr", {
  tmpdir <- tempfile("rf_miss_")
  dir.create(tmpdir)
  outdir <- file.path(tmpdir, "output")
  nonexistent <- file.path(tmpdir, "nonexistent.csv")

  res <- run_node(c(
    "train",
    "--in-mat",  nonexistent,
    "--in-map",  nonexistent,
    "--in-gene", nonexistent,
    "--outdir",  outdir
  ))

  expect_equal(res$exit_code, 1L)

  expect_match(res$stderr, "input file not found")

  unlink(tmpdir, recursive = TRUE)
})

test_that("empty gene list exits with code 1", {
  tmpdir <- tempfile("rf_empty_")
  dir.create(tmpdir)
  outdir <- file.path(tmpdir, "output")

  exp_mat <- matrix(
    rnorm(10 * 20, mean = 10, sd = 2),
    nrow = 10, ncol = 20,
    dimnames = list(paste0("GENE", 1:10), paste0("SAMPLE", 1:20))
  )
  in_mat <- file.path(tmpdir, "exp.csv")
  write.csv(exp_mat, in_mat)

  group_df <- data.frame(
    row.names = paste0("SAMPLE", 1:20),
    group = rep(c("Control", "Case"), each = 10)
  )
  in_map <- file.path(tmpdir, "group.csv")
  write.csv(group_df, in_map)

  gene_list <- data.frame(gene = paste0("NONEXISTENT", 1:5))
  in_gene <- file.path(tmpdir, "genes.csv")
  write.csv(gene_list, in_gene, row.names = FALSE)

  res <- run_node(c(
    "train",
    "--in-mat",  in_mat,
    "--in-map",  in_map,
    "--in-gene", in_gene,
    "--outdir",  outdir
  ))

  expect_equal(res$exit_code, 1L)

  expect_match(res$stderr, "no genes found in expression matrix")

  unlink(tmpdir, recursive = TRUE)
})

test_that("unknown subcommand exits with code 1", {
  res <- run_node(c("unknown_arg"))

  expect_equal(res$exit_code, 1L)

  expect_match(res$stderr, "unknown subcommand")
})

test_that("input_validation.R passes for valid synthetic data", {
  tmpdir <- tempfile("rf_ival_")
  dir.create(tmpdir)
  data <- create_synthetic_data(tmpdir)

  res <- run_validation("input_validation.R", c(
    "--in-mat",  data$in_mat,
    "--in-map",  data$in_map,
    "--in-gene", data$in_gene
  ))

  expect_equal(res$exit_code, 0L)

  unlink(tmpdir, recursive = TRUE)
})

test_that("input_validation.R fails for missing file", {
  tmpdir <- tempfile("rf_ival2_")
  dir.create(tmpdir)
  data <- create_synthetic_data(tmpdir)
  nonexistent <- file.path(tmpdir, "nope.csv")

  res <- run_validation("input_validation.R", c(
    "--in-mat",  nonexistent,
    "--in-map",  data$in_map,
    "--in-gene", data$in_gene
  ))

  expect_equal(res$exit_code, 1L)

  expect_match(res$stderr, "input file not found")

  unlink(tmpdir, recursive = TRUE)
})

test_that("output_validation.R passes after successful training", {
  tmpdir <- tempfile("rf_oval_")
  dir.create(tmpdir)
  outdir <- file.path(tmpdir, "output")
  data <- create_synthetic_data(tmpdir)

  run_node(c(
    "train",
    "--in-mat",  data$in_mat,
    "--in-map",  data$in_map,
    "--in-gene", data$in_gene,
    "--outdir",  outdir,
    "--seed",    "42"
  ))

  res <- run_validation("output_validation.R", c(
    "--outdir", outdir
  ))

  expect_equal(res$exit_code, 0L)

  unlink(tmpdir, recursive = TRUE)
})

test_that("output_validation.R fails for empty output directory", {
  tmpdir <- tempfile("rf_oval2_")
  dir.create(tmpdir)

  res <- run_validation("output_validation.R", c(
    "--outdir", tmpdir
  ))

  expect_equal(res$exit_code, 1L)

  expect_match(res$stderr, "output file missing")

  unlink(tmpdir, recursive = TRUE)
})

test_that("SKILL.md frontmatter is valid YAML with all required keys", {
  skill_content <- readLines(file.path(proj_root, "SKILL.md"))
  sep_lines <- which(skill_content == "---")
  expect_true(length(sep_lines) >= 2)

  fm_yaml <- skill_content[(sep_lines[1] + 1):(sep_lines[2] - 1)]
  fm <- yaml::yaml.load(paste(fm_yaml, collapse = "\n"))

  required_keys <- c("name", "description", "type", "inputs", "outputs",
                     "entry", "parameters", "exceptions", "hardware")
  for (key in required_keys) {
    expect_true(key %in% names(fm), info = paste("Missing key:", key))
  }
  expect_equal(fm$type, "standard")
  expect_equal(fm$entry, "scripts/main.R")
  expect_equal(fm$name, "random-forest-classifier")
})
