#!/bin/env Rscript
suppressPackageStartupMessages(library(yaml))
suppressPackageStartupMessages(library(filelock))
library(dplyr)
library(randomForest)
library(ggplot2)

file_lock <- function(path, FUN, ..., exclusive = TRUE, timeout = 5000) {
  FUN <- match.fun(FUN)
  lock_file <- paste0(path, ".lock")
  lock <- lock(lock_file, exclusive = exclusive, timeout = timeout)
  unlock <- unlock
  if (is.null(lock)) {
    stop(paste0("The file lock cannot be obtained: ", lock_file))
  } else {
    res <- tryCatch(
      forceAndCall(1, FUN, path, ...),
      error = function(e) stop(e),
      finally = unlock(lock)
    )
  }
  invisible(res)
}



args <- commandArgs(trailingOnly = TRUE)
in_mat <- args[1]
in_map <- args[2]
in_gene <- args[3]

rfplot <- args[4]
imp <- args[5]
impplot <- args[6]
train_cv_res <- args[7]
in_type <- args[8]
confirm_file <- args[9]
seed <- as.numeric(args[10])
errplot <- args[11]
out_mat <- args[12]
top <- args[13]
model_rds_path <- args[14]

set.seed(seed)
ntree <- 1000

make_dir <- function(file) {
  path <- dirname(file)
  if (!dir.exists(path)) {
    dir.create(path, recursive = TRUE)
  }
}
for (file in c(rfplot)) {
  make_dir(file)
}

exp <- read.csv(in_mat, row.names = 1)
genes <- read.csv(in_gene)[[1]]
in_num <- length(genes)
group <- read.csv(in_map, row.names = 1)
colnames(group) <- "group"
group$group <- factor(group$group, levels = unique(group$group))
genes <- intersect(rownames(exp), genes)

ferr_rt <- t(exp[genes, rownames(group)])

rf_output <- randomForest(
  x = ferr_rt,
  y = group[[1]],
  importance = TRUE,
  ntree = ntree,
  proximity = TRUE
)

pdf(file = rfplot, width = 8, height = 5)
par(oma = c(0, 0, 0, 0), mar = c(4, 4, 1, 1), las = 1)
plot(rf_output, type = "l", cex = 0.7)
dev.off()
pdf(file = impplot, width = 8, height = 5)
par(oma = c(0, 0, 0, 0), mar = c(4, 4, 1, 1), las = 1)
varImpPlot(rf_output,
  type = 2,
  scale = FALSE,
  # col = "skyblue",
  # main = NULL,
  cex = 0.7
)
dev.off()
rf_importances <- importance(rf_output, scale = FALSE)

rf_importances2 <- rf_importances %>%
  as.data.frame() %>%
  arrange(desc(MeanDecreaseGini))

# 保存结果
write.csv(rf_importances2, imp)

# 3 交叉验证辅助评估选择特定数量的基因----
# 5次重复十折交叉验证

ferr_rt_train_cv <- lapply(1:5, function(i) {
  set.seed(seed + i)
  rfcv(ferr_rt, group[[1]], cv.fold = 10, step = 1.5)
})

## 3.1 提取验证结果绘图----
train_cv <- data.frame(sapply(ferr_rt_train_cv, "[[", "error.cv"))
train_cv$gene_num <- rownames(train_cv)
train_cv <- reshape2::melt(train_cv, id = "gene_num")
train_cv$gene_num <- as.numeric(as.character(train_cv$gene_num))

rfcv_mean <- aggregate(train_cv$value,
  by = list(train_cv$gene_num), FUN = mean
)
colnames(rfcv_mean) <- c("x", "y")
write.csv(rfcv_mean, train_cv_res, row.names = FALSE)

n <- rfcv_mean$x[which.min(rfcv_mean$y)]
if (top != "NULL" && top != "None") {
  n <- as.integer(top)
} else {
  top <- NULL
}
# 拟合线图
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

## 3.2 结合上图选取的变量数提取结果----

write.csv(head(rownames(rf_importances2), n), out_mat, row.names = FALSE)

saveRDS(rf_output, model_rds_path)
cat("随机森林模型已保存至:", model_rds_path, "\n")


in_info <- if (in_type == "parallel") "基于{<color=red>LLLLRGs}" else paste0("基于", in_type, "算法")

file_lock(confirm_file, function(confirm_file) {
  confirm <- if (file.exists(confirm_file)) {
    yaml.load(readChar(confirm_file, nchars = file.info(confirm_file)$size))
  } else {
    list()
  }
  confirm["randomforest"] <- "RF（Random Forest）"
  confirm["rf_in_type"] <- in_type
  confirm["rf_in_num"] <- in_num
  confirm["rf_seed"] <- seed
  confirm["rf_ntree"] <- ntree
  confirm["rf_top"] <- top
  confirm["rf_use_cv"] <- is.null(top)
  confirm["rf_genes"] <- paste(head(rownames(rf_importances2), n), collapse = "，")
  write_yaml(confirm, confirm_file)
})