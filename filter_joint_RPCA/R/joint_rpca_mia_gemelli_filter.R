# Joint-RPCA comparison: mia and Gemelli
# This script runs the local mia workflow and compares its output with
# previously generated Gemelli Joint-RPCA output.

project_dir <- "D:/Mia Folder"
setwd(project_dir)

# Packages -----------------------------------------------------------------

required_packages <- c(
  "devtools",
  "mia",
  "MultiAssayExperiment",
  "SummarizedExperiment",
  "ggplot2",
  "dplyr",
  "tidyr",
  "tibble"
)

missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing_packages) > 0L) {
  stop(
    "Install the following packages before running this script: ",
    paste(missing_packages, collapse = ", "),
    call. = FALSE
  )
}

devtools::load_all(project_dir)

library(mia)
library(MultiAssayExperiment)
library(SummarizedExperiment)
library(ggplot2)
library(dplyr)
library(tidyr)
library(tibble)

theme_set(theme_bw())

# Output folders -----------------------------------------------------------

dir.create("results/mia", recursive = TRUE, showWarnings = FALSE)
dir.create("results/comparison", recursive = TRUE, showWarnings = FALSE)
dir.create("results/comparison/figures", recursive = TRUE, showWarnings = FALSE)

# Run Joint-RPCA with mia --------------------------------------------------

data("ibdmdb", package = "mia")
mae <- ibdmdb

mae_filtered <- filterRPCAInput(
  mae,
  experiments = c(1L, 2L),
  assay.types = c("mgx", "mtx"),
  min.sample.count = 0,
  min.feature.count = 0,
  min.feature.frequency = 0
)

mae_filtered[[1L]] <- transformAssay(
  mae_filtered[[1L]],
  assay.type = "mgx",
  method = "rclr",
  impute = FALSE
)

mae_filtered[[2L]] <- transformAssay(
  mae_filtered[[2L]],
  assay.type = "mtx",
  method = "rclr",
  impute = FALSE
)

shared_samples <- intersect(
  colnames(mae_filtered[[1L]]),
  colnames(mae_filtered[[2L]])
)

test_samples <- tail(shared_samples, 2L)

mia_result <- getJointRPCA(
  mae_filtered,
  experiments = c(1L, 2L),
  assay.types = c("rclr", "rclr"),
  ncomponents = 3L,
  max.iterations = 10L,
  test.set = test_samples
)

# Export mia output --------------------------------------------------------

write.csv(
  as.data.frame(mia_result),
  "results/mia/sample_scores.csv"
)

write.csv(
  as.data.frame(attr(mia_result, "rotation")),
  "results/mia/feature_loadings.csv"
)

write.csv(
  data.frame(
    PC = names(attr(mia_result, "percentVar")),
    percentVar = as.numeric(attr(mia_result, "percentVar")),
    proportion_explained = as.numeric(attr(mia_result, "percentVar")) / 100
  ),
  "results/mia/proportion_explained.csv",
  row.names = FALSE
)

write.csv(
  as.matrix(attr(mia_result, "distance")),
  "results/mia/distance_matrix.csv"
)

reconstruct_error <- attr(mia_result, "reconstruct_error")

write.csv(
  data.frame(
    table = if (!is.null(names(reconstruct_error)) && all(nzchar(names(reconstruct_error)))) {
      names(reconstruct_error)
    } else {
      paste0("table_", seq_along(reconstruct_error))
    },
    reconstruct_error = as.numeric(reconstruct_error)
  ),
  "results/mia/reconstruct_error.csv",
  row.names = FALSE
)

cv_error <- attr(mia_result, "cv_error")

if (!is.null(cv_error)) {
  write.csv(
    as.data.frame(cv_error),
    "results/mia/cv_error.csv",
    row.names = FALSE
  )
}

# Check Gemelli output -----------------------------------------------------

required_gemelli_files <- file.path(
  "results/gemelli",
  c(
    "sample_scores.csv",
    "feature_loadings.csv",
    "proportion_explained.csv",
    "distance_matrix.csv"
  )
)

missing_gemelli_files <- required_gemelli_files[!file.exists(required_gemelli_files)]

if (length(missing_gemelli_files) > 0L) {
  stop(
    "Run the Gemelli Python workflow first. Missing files: ",
    paste(missing_gemelli_files, collapse = ", "),
    call. = FALSE
  )
}

# Helper functions ---------------------------------------------------------

align_by_common_rows <- function(x, y) {
  common_ids <- intersect(rownames(x), rownames(y))

  if (length(common_ids) == 0L) {
    stop("No common row names found between the two tables.", call. = FALSE)
  }

  list(
    x = x[common_ids, , drop = FALSE],
    y = y[common_ids, , drop = FALSE],
    ids = common_ids
  )
}

pc_correlation_table <- function(mia_mat, gemelli_mat) {
  aligned <- align_by_common_rows(mia_mat, gemelli_mat)

  mia_aligned <- aligned$x
  gemelli_aligned <- aligned$y

  n_pcs <- min(ncol(mia_aligned), ncol(gemelli_aligned))

  data.frame(
    PC = paste0("PC", seq_len(n_pcs)),
    correlation = vapply(seq_len(n_pcs), function(i) {
      cor(mia_aligned[[i]], gemelli_aligned[[i]], use = "complete.obs")
    }, numeric(1L))
  ) |>
    mutate(
      absolute_correlation = abs(correlation),
      sign_relation = ifelse(correlation >= 0, "same sign", "opposite sign")
    )
}

long_pc_table <- function(mia_mat, gemelli_mat, id_name = "id") {
  aligned <- align_by_common_rows(mia_mat, gemelli_mat)

  mia_long <- aligned$x |>
    rownames_to_column(id_name) |>
    pivot_longer(
      cols = -all_of(id_name),
      names_to = "PC",
      values_to = "mia"
    )

  gemelli_long <- aligned$y |>
    rownames_to_column(id_name) |>
    pivot_longer(
      cols = -all_of(id_name),
      names_to = "PC",
      values_to = "gemelli"
    )

  inner_join(mia_long, gemelli_long, by = c(id_name, "PC"))
}

# Subject/sample loadings --------------------------------------------------

mia_subject_loadings <- read.csv(
  "results/mia/sample_scores.csv",
  row.names = 1,
  check.names = FALSE
)

gemelli_subject_loadings <- read.csv(
  "results/gemelli/sample_scores.csv",
  row.names = 1,
  check.names = FALSE
)

subject_pc_correlations <- pc_correlation_table(
  mia_subject_loadings,
  gemelli_subject_loadings
)

subject_loadings_long <- long_pc_table(
  mia_subject_loadings,
  gemelli_subject_loadings,
  id_name = "sample_id"
)

subject_plot <- ggplot(
  subject_loadings_long,
  aes(x = gemelli, y = mia)
) +
  geom_point(alpha = 0.75) +
  geom_smooth(method = "lm", se = FALSE) +
  facet_wrap(~ PC, scales = "free") +
  labs(
    title = "Subject loadings: mia vs Gemelli",
    subtitle = "Sample scores compared PC by PC",
    x = "Gemelli subject loading",
    y = "mia subject loading"
  )

ggsave(
  "results/comparison/figures/subject_loadings_mia_vs_gemelli.png",
  subject_plot,
  width = 9,
  height = 5,
  dpi = 300
)

# Feature loadings ---------------------------------------------------------

mia_feature_loadings <- read.csv(
  "results/mia/feature_loadings.csv",
  row.names = 1,
  check.names = FALSE
)

gemelli_feature_loadings <- read.csv(
  "results/gemelli/feature_loadings.csv",
  row.names = 1,
  check.names = FALSE
)

common_features <- intersect(
  rownames(mia_feature_loadings),
  rownames(gemelli_feature_loadings)
)

if (length(common_features) == 0L) {
  stop("No common features found between mia and Gemelli feature-loading tables.", call. = FALSE)
}

feature_pc_correlations <- pc_correlation_table(
  mia_feature_loadings,
  gemelli_feature_loadings
)

feature_loadings_long <- long_pc_table(
  mia_feature_loadings,
  gemelli_feature_loadings,
  id_name = "feature_id"
)

feature_plot <- ggplot(
  feature_loadings_long,
  aes(x = gemelli, y = mia)
) +
  geom_point(alpha = 0.5) +
  geom_smooth(method = "lm", se = FALSE) +
  facet_wrap(~ PC, scales = "free") +
  labs(
    title = "Feature loadings: mia vs Gemelli",
    subtitle = "Feature loadings compared PC by PC",
    x = "Gemelli feature loading",
    y = "mia feature loading"
  )

ggsave(
  "results/comparison/figures/feature_loadings_mia_vs_gemelli.png",
  feature_plot,
  width = 9,
  height = 5,
  dpi = 300
)

# Proportion explained -----------------------------------------------------

mia_prop <- read.csv(
  "results/mia/proportion_explained.csv",
  check.names = FALSE
)

gemelli_prop_raw <- read.csv(
  "results/gemelli/proportion_explained.csv",
  row.names = 1,
  check.names = FALSE
)

gemelli_prop <- data.frame(
  PC = rownames(gemelli_prop_raw),
  proportion_explained = as.numeric(gemelli_prop_raw[[1]])
)

prop_comparison <- bind_rows(
  mia_prop |>
    select(PC, proportion_explained) |>
    mutate(method = "mia"),
  gemelli_prop |>
    select(PC, proportion_explained) |>
    mutate(method = "Gemelli")
)

prop_difference <- prop_comparison |>
  pivot_wider(
    names_from = method,
    values_from = proportion_explained
  ) |>
  mutate(
    difference_mia_minus_gemelli = mia - Gemelli,
    absolute_difference = abs(difference_mia_minus_gemelli)
  )

prop_plot <- ggplot(
  prop_comparison,
  aes(x = PC, y = proportion_explained, fill = method)
) +
  geom_col(position = "dodge") +
  labs(
    title = "Proportion explained by principal component",
    x = "Principal component",
    y = "Proportion explained",
    fill = "Method"
  )

ggsave(
  "results/comparison/figures/proportion_explained_mia_vs_gemelli.png",
  prop_plot,
  width = 7,
  height = 5,
  dpi = 300
)

# Distance matrix ----------------------------------------------------------

mia_dist <- read.csv(
  "results/mia/distance_matrix.csv",
  row.names = 1,
  check.names = FALSE
)

gemelli_dist <- read.csv(
  "results/gemelli/distance_matrix.csv",
  row.names = 1,
  check.names = FALSE
)

common_distance_samples <- Reduce(
  intersect,
  list(
    rownames(mia_dist),
    colnames(mia_dist),
    rownames(gemelli_dist),
    colnames(gemelli_dist)
  )
)

if (length(common_distance_samples) < 2L) {
  stop("At least two common samples are required for distance comparison.", call. = FALSE)
}

mia_dist_mat <- as.matrix(
  mia_dist[common_distance_samples, common_distance_samples]
)

gemelli_dist_mat <- as.matrix(
  gemelli_dist[common_distance_samples, common_distance_samples]
)

upper_idx <- upper.tri(mia_dist_mat)

distance_plot_data <- data.frame(
  mia = mia_dist_mat[upper_idx],
  gemelli = gemelli_dist_mat[upper_idx]
)

distance_correlation <- cor(
  distance_plot_data$mia,
  distance_plot_data$gemelli,
  use = "complete.obs"
)

distance_plot <- ggplot(
  distance_plot_data,
  aes(x = gemelli, y = mia)
) +
  geom_point(alpha = 0.45) +
  geom_smooth(method = "lm", se = FALSE) +
  labs(
    title = "Distance matrix comparison: mia vs Gemelli",
    subtitle = paste0("Pearson correlation = ", signif(distance_correlation, 4)),
    x = "Gemelli pairwise distance",
    y = "mia pairwise distance"
  )

ggsave(
  "results/comparison/figures/distance_matrix_mia_vs_gemelli.png",
  distance_plot,
  width = 7,
  height = 5,
  dpi = 300
)

# Summary tables -----------------------------------------------------------

subject_summary <- subject_pc_correlations |>
  summarise(
    result = paste0(
      PC,
      ": abs(cor)=",
      signif(absolute_correlation, 4),
      " (",
      sign_relation,
      ")",
      collapse = "; "
    )
  ) |>
  pull(result)

feature_summary <- feature_pc_correlations |>
  summarise(
    result = paste0(
      PC,
      ": abs(cor)=",
      signif(absolute_correlation, 4),
      " (",
      sign_relation,
      ")",
      collapse = "; "
    )
  ) |>
  pull(result)

prop_summary <- prop_difference |>
  summarise(
    result = paste0(
      PC,
      ": abs(diff)=",
      signif(absolute_difference, 4),
      collapse = "; "
    )
  ) |>
  pull(result)

distance_summary <- paste0(
  "distance matrix cor = ",
  signif(distance_correlation, 4)
)

comparison_summary <- data.frame(
  comparison = c(
    "Subject / sample loadings",
    "Feature loadings",
    "Proportion explained",
    "Distance matrix correlation"
  ),
  comparison_type = rep("mia vs Gemelli", 4),
  what_is_compared = c(
    "PC coordinates of samples",
    "PC loadings of features",
    "Variance / eigenvalue structure",
    "Pairwise sample geometry"
  ),
  primary_result = c(
    subject_summary,
    feature_summary,
    prop_summary,
    distance_summary
  ),
  interpretation = c(
    "High absolute PC-wise correlation indicates similar sample placement.",
    "High absolute PC-wise correlation indicates similar feature contribution patterns.",
    "Small PC-wise differences indicate similar explained-variance structure.",
    "High distance correlation indicates similar global sample geometry."
  ),
  stringsAsFactors = FALSE
)

write.csv(
  subject_pc_correlations,
  "results/comparison/subject_loading_correlations.csv",
  row.names = FALSE
)

write.csv(
  feature_pc_correlations,
  "results/comparison/feature_loading_correlations.csv",
  row.names = FALSE
)

write.csv(
  prop_difference,
  "results/comparison/proportion_explained_difference.csv",
  row.names = FALSE
)

write.csv(
  distance_plot_data,
  "results/comparison/distance_matrix_pairwise_values.csv",
  row.names = FALSE
)

write.csv(
  comparison_summary,
  "results/comparison/comparison_summary.csv",
  row.names = FALSE
)

# Console summary ----------------------------------------------------------

cat("\nJoint-RPCA comparison completed.\n")
cat("\nMain output files:\n")
print(list.files("results/mia"))

cat("\nComparison output files:\n")
print(list.files("results/comparison"))

cat("\nSummary:\n")
print(comparison_summary, row.names = FALSE)

cat("\nFigures:\n")
print(list.files("results/comparison/figures"))
