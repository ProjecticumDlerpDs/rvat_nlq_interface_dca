# ------------------------------------------------------------
# 36B_visualise_VES.R
#
# PURPOSE
# -------
# Visualise VES performance by benchmark question type and
# database mode.
#
# VES DEFINITION
# --------------
# VES is represented by time_total_sec:
# end-to-end execution time across the production workflow.
#
# INPUT
# -----
# data/analysis/results/35_question_type_level.csv
#
# OUTPUT
# ------
# data/analysis/results/figures/
# 36B_VES_by_question_type.png
#
# METRICS
# -------
# VES_category_mean_sec
# - mean of the question-level mean execution times within
#   each benchmark question type.
#
# VES_category_median_sec
# - median of the question-level median execution times within
#   each benchmark question type.
#
# VES_between_question_sd_sec
# - standard deviation of question-level mean execution times
#   within each benchmark question type.
#
# ANALYTICAL HIERARCHY
# --------------------
# Individual execution times
#       ↓
# Question-level VES summaries
#       ↓
# Question-type VES summaries
#       ↓
# Visualisation
#
# IMPORTANT
# ---------
# This script visualises only VES statistics already
# calculated and validated by 35_analyse_performance.R.
#
# It does not recalculate VES or perform statistical tests.
# ------------------------------------------------------------


library(here)
library(readr)
library(dplyr)
library(ggplot2)


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
  "36B_VES_by_question_type.png"
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
  "VES_category_mean_sec",
  "VES_category_median_sec",
  "VES_between_question_sd_sec"
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
# VALIDATE VES VALUES
# ------------------------------------------------------------

if (anyNA(
  results$VES_category_mean_sec
)) {
  stop(
    "VES_category_mean_sec contains missing values."
  )
}

if (anyNA(
  results$VES_category_median_sec
)) {
  stop(
    "VES_category_median_sec contains missing values."
  )
}

if (anyNA(
  results$VES_between_question_sd_sec
)) {
  stop(
    "VES_between_question_sd_sec contains missing values."
  )
}

if (any(
  results$VES_category_mean_sec < 0
)) {
  stop(
    "VES_category_mean_sec contains negative values."
  )
}

if (any(
  results$VES_category_median_sec < 0
)) {
  stop(
    "VES_category_median_sec contains negative values."
  )
}

if (any(
  results$VES_between_question_sd_sec < 0
)) {
  stop(
    "VES_between_question_sd_sec contains negative values."
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

if (anyNA(results$question_type)) {
  stop(
    "Unexpected question_type found in VES results."
  )
}


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
# CALCULATE ERROR-BAR BOUNDARIES
# ------------------------------------------------------------
#
# Error bars show +/- one between-question standard deviation
# around the category-level mean.
#
# VES cannot be negative, so the lower plotting boundary is
# restricted to zero.
# ------------------------------------------------------------

results <- results |>
  dplyr::mutate(
    
    VES_lower_sec = pmax(
      0,
      VES_category_mean_sec -
        VES_between_question_sd_sec
    ),
    
    VES_upper_sec =
      VES_category_mean_sec +
      VES_between_question_sd_sec
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
# CREATE VES VISUALISATION
# ------------------------------------------------------------

ves_plot <- ggplot(
  results,
  aes(
    x = question_type,
    y = VES_category_mean_sec,
    fill = db_mode_label
  )
) +
  geom_col(
    position = position_dodge(
      width = 0.8
    ),
    width = 0.7
  ) +
  geom_errorbar(
    aes(
      ymin = VES_lower_sec,
      ymax = VES_upper_sec
    ),
    position = position_dodge(
      width = 0.8
    ),
    width = 0.2
  ) +
  geom_text(
    aes(
      label = sprintf(
        "%.1f s",
        VES_category_mean_sec
      )
    ),
    position = position_dodge(
      width = 0.8
    ),
    vjust = -0.5,
    size = 3.5
  ) +
  scale_y_continuous(
    expand = expansion(
      mult = c(
        0,
        0.12
      )
    )
  ) +
  labs(
    title = "End-to-End Execution Time by Question Type",
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
    y = "Mean execution time (seconds)",
    fill = "Database mode",
    caption = paste(
      "Bars show category mean VES;",
      "error bars show +/- 1 SD between questions."
    )
  ) +
  theme_minimal(
    base_size = 12
  ) +
  theme(
    legend.position = "top",
    panel.grid.major.x = element_blank(),
    axis.text.x = element_text(
      angle = 15,
      hjust = 1
    ),
    plot.caption = element_text(
      hjust = 0
    )
  )


# ------------------------------------------------------------
# SAVE FIGURE
# ------------------------------------------------------------

ggsave(
  filename = OUTPUT_FILE,
  plot = ves_plot,
  width = 10,
  height = 6,
  units = "in",
  dpi = 300
)


# ------------------------------------------------------------
# VERIFY OUTPUT
# ------------------------------------------------------------

if (!file.exists(OUTPUT_FILE)) {
  stop(
    "VES figure was not created: ",
    OUTPUT_FILE
  )
}


# ------------------------------------------------------------
# FINAL REPORT
# ------------------------------------------------------------

cat("\n=========================================\n")
cat("36B VES VISUALISATION COMPLETED\n")
cat("=========================================\n")

cat(
  "Question-type observations visualised:",
  nrow(results),
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
  OUTPUT_FILE,
  "\n"
)

cat("=========================================\n")