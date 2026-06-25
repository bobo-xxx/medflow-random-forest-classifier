# Synthetic data generator for random-forest-classifier tests.
# Produces: 10 genes x 20 samples, balanced case/control.

create_synthetic_data <- function(tmpdir, seed = 42) {
  set.seed(seed)

  n_genes <- 10
  n_samples <- 20
  gene_names <- paste0("GENE", 1:n_genes)
  sample_names <- paste0("SAMPLE", 1:n_samples)

  # Expression matrix: genes x samples
  exp_mat <- matrix(
    rnorm(n_genes * n_samples, mean = 10, sd = 2),
    nrow = n_genes, ncol = n_samples,
    dimnames = list(gene_names, sample_names)
  )

  # Group mapping: balanced case/control
  group_labels <- rep(c("Control", "Case"), each = n_samples / 2)
  group_df <- data.frame(
    row.names = sample_names,
    group = group_labels
  )

  # Gene list: all 10 genes
  gene_list <- data.frame(gene = gene_names)

  # Write files
  in_mat  <- file.path(tmpdir, "exp_mat.csv")
  in_map  <- file.path(tmpdir, "group_map.csv")
  in_gene <- file.path(tmpdir, "gene_list.csv")

  write.csv(exp_mat, in_mat)
  write.csv(group_df, in_map)
  write.csv(gene_list, in_gene, row.names = FALSE)

  list(
    in_mat = in_mat, in_map = in_map, in_gene = in_gene,
    n_genes = n_genes, n_samples = n_samples
  )
}
