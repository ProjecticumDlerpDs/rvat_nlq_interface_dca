# ------------------------------------------------------------
# 36A_visualise_EM_EX.R
#
# PURPOSE
# -------
# Visualise Exact Match (EM) and Execution Match (EX)
# performance by benchmark question type and database mode.
#
# INPUT
# -----
# data/analysis/results/35_question_type_level.csv
#
# OUTPUT
# ------
# data/analysis/results/figures/
# 36A_EM_EX_by_question_type.png
#
# METRICS
# -------
# EM_mean
# - mean question-level Exact Match performance within
#   each benchmark question type.
#
# EX_mean
# - mean question-level Execution Match performance within
#   each benchmark question type.
#
# ANALYTICAL HIERARCHY
# --------------------
# Individual executions
#       ↓
# Question-level EM / EX rates
#       ↓
# Question-type EM / EX means
#       ↓
# Visualisation
#
# IMPORTANT
# ---------
# This script visualises only results already calculated and
# validated by 35_analyse_performance.R.
#
# It does not recalculate EM or EX and does not perform
# statistical analysis.
# ------------------------------------------------------------


library(here)
library(readr)
library(dplyr)
library(tidyr)
library(ggplot2)
library(scales)


# ------------------------------------------------------------
# CONFIGURATION
# ------------------------------------------------------------

INPUT_FILE <- here(
  "data",
  "analysis",
  "results",
  "35_question_type_level.csv"
)

FIGURE_DIR <- here(
  "data",
  "analysis",
  "results",
  "figures"
)

OUTPUT_FILE <- here(
  "data",
  "analysis",
  "results",
  "figures",
  "36A_EM_EX_by_question_type.png"
)


# ------------------------------------------------------------
# VALIDATE INPUT
# ------------------------------------------------------------

if (!file.exists(INPUT_FILE)) {
  stop(
    "35_ question-type results not found: ",
    INPUT_FILE
  )
}


# ------------------------------------------------------------
# LOAD QUESTION-TYPE RESULTS
# ------------------------------------------------------------

results <- readr::read_csv(
  INPUT_FILE,
  show_col_types = FALSE
)

if (!is.data.frame(results)) {
  stop(
    "Question-type results are not a data.frame."
  )
}

if (nrow(results) == 0) {
  stop(
    "Question-type results contain no observations."
  )
}


# ------------------------------------------------------------
# VALIDATE REQUIRED COLUMNS
# ------------------------------------------------------------

required_columns <- c(
  "model",
  "db_mode",
  "experiment_iteration",
  "question_type",
  "n_questions",
  "EM_mean",
  "EX_mean"
)

missing_columns <- setdiff(
  required_columns,
  names(results)
)

if (length(missing_columns) > 0) {
  stop(
    "Question-type results are missing required column(s): ",
    paste(
      missing_columns,
      collapse = ", "
    )
  )
}


# ------------------------------------------------------------
# VALIDATE EM / EX VALUES
# ------------------------------------------------------------

if (anyNA(results$EM_mean)) {
  stop(
    "EM_mean contains missing values."
  )
}

if (anyNA(results$EX_mean)) {
  stop(
    "EX_mean contains missing values."
  )
}

if (any(
  results$EM_mean < 0 |
  results$EM_mean > 1
)) {
  stop(
    "EM_mean contains values outside the expected 0-1 range."
  )
}

if (any(
  results$EX_mean < 0 |
  results$EX_mean > 1
)) {
  stop(
    "EX_mean contains values outside the expected 0-1 range."
  )
}


# ------------------------------------------------------------
# PREPARE QUESTION-TYPE LABELS
# ------------------------------------------------------------

question_type_order <- c(
  "Lookup Queries",
  "Analytical Queries",
  "Unanswerable Questions",
  "Advanced Tests (RVAT Required)"
)

results$question_type <- factor(
  results$question_type,
  levels = question_type_order,
  labels = c(
    "Lookup",
    "Analytical",
    "Unanswerable",
    "Advanced RVAT"
  )
)


# ------------------------------------------------------------
# PREPARE DATABASE-MODE LABELS
# ------------------------------------------------------------

results$db_mode_label <- dplyr::recode(
  results$db_mode,
  "synthetic" = "Synthetic",
  "full_gdb" = "Full GDB",
  .default = results$db_mode
)


# ------------------------------------------------------------
# PREPARE LONG-FORM ACCURACY DATA
# ------------------------------------------------------------
#
# EM_mean and EX_mean are converted into one metric column
# so that both measures can be displayed consistently in a
# single figure with separate panels.
# ------------------------------------------------------------

accuracy_results <- results |>
  dplyr::select(
    model,
    db_mode,
    db_mode_label,
    experiment_iteration,
    question_type,
    n_questions,
    EM_mean,
    EX_mean
  ) |>
  tidyr::pivot_longer(
    cols = c(
      EM_mean,
      EX_mean
    ),
    names_to = "metric",
    values_to = "performance"
  )


# ------------------------------------------------------------
# PREPARE METRIC LABELS
# ------------------------------------------------------------

accuracy_results$metric <- factor(
  accuracy_results$metric,
  levels = c(
    "EM_mean",
    "EX_mean"
  ),
  labels = c(
    "Exact Match (EM)",
    "Execution Match (EX)"
  )
)


# ------------------------------------------------------------
# PREPARE FIGURE DIRECTORY
# ------------------------------------------------------------

dir.create(
  FIGURE_DIR,
  recursive = TRUE,
  showWarnings = FALSE
)


# ------------------------------------------------------------
# CREATE EM + EX VISUALISATION
# ------------------------------------------------------------

accuracy_plot <- ggplot(
  accuracy_results,
  aes(
    x = question_type,
    y = performance,
    fill = db_mode_label
  )
) +
  geom_col(
    position = position_dodge(
      width = 0.8
    ),
    width = 0.7
  ) +
  geom_text(
    aes(
      label = scales::percent(
        performance,
        accuracy = 1
      )
    ),
    position = position_dodge(
      width = 0.8
    ),
    vjust = -0.4,
    size = 3.5
  ) +
  facet_wrap(
    ~ metric,
    ncol = 2
  ) +
  scale_y_continuous(
    limits = c(
      0,
      1.05
    ),
    breaks = seq(
      0,
      1,
      by = 0.2
    ),
    labels = scales::percent_format(
      accuracy = 1
    ),
    expand = expansion(
      mult = c(
        0,
        0.02
      )
    )
  ) +
  labs(
    title = "Query and Execution Performance by Question Type",
    subtitle = paste0(
      "Model: ",
      paste(
        unique(results$model),
        collapse = ", "
      ),
      " | Experimental iteration(s): ",
      paste(
        sort(
          unique(
            results$experiment_iteration
          )
        ),
        collapse = ", "
      )
    ),
    x = "Question type",
    y = "Performance",
    fill = "Database mode"
  ) +
  theme_minimal(
    base_size = 12
  ) +
  theme(
    legend.position = "top",
    panel.grid.major.x = element_blank(),
    strip.text = element_text(
      face = "bold"
    ),
    axis.text.x = element_text(
      angle = 15,
      hjust = 1
    )
  )


# ------------------------------------------------------------
# SAVE FIGURE
# ------------------------------------------------------------

ggsave(
  filename = OUTPUT_FILE,
  plot = accuracy_plot,
  width = 12,
  height = 6,
  units = "in",
  dpi = 300
)


# ------------------------------------------------------------
# VERIFY OUTPUT
# ------------------------------------------------------------

if (!file.exists(OUTPUT_FILE)) {
  stop(
    "EM/EX figure was not created: ",
    OUTPUT_FILE
  )
}


# ------------------------------------------------------------
# FINAL REPORT
# ------------------------------------------------------------

cat("\n=========================================\n")
cat("36A EM + EX VISUALISATION COMPLETED\n")
cat("=========================================\n")

cat(
  "Question-type observations:",
  nrow(results),
  "\n"
)

cat(
  "Visualisation observations:",
  nrow(accuracy_results),
  "\n"
)

cat(
  "Models:",
  paste(
    unique(results$model),
    collapse = ", "
  ),
  "\n"
)

cat(
  "DB modes:",
  paste(
    unique(results$db_mode),
    collapse = ", "
  ),
  "\n"
)

cat(
  "Experimental iterations:",
  paste(
    sort(
      unique(
        results$experiment_iteration
      )
    ),
    collapse = ", "
  ),
  "\n"
)

cat(
  "Saved:",
  OUTPUT_