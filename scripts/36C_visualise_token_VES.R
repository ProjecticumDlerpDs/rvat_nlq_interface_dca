# ------------------------------------------------------------
# 36C_visualise_token_VES.R
#
# PURPOSE
# -------
# Visualise the relationship between model token workload
# and VES (end-to-end execution time).
#
# This is a SECONDARY / EXPLORATORY analysis.
#
# INPUT
# -----
# data/analysis/results/35_question_level.csv
#
# OUTPUT
# ------
# data/analysis/results/figures/
# 36C_token_VES_relationship.png
#
# VARIABLES
# ---------
# prompt_tokens_mean
# - mean prompt-token count across the five executions
#   of each benchmark question.
#
# generated_tokens_mean
# - mean generated-token count across the five executions
#   of each benchmark question.
#
# VES_mean_sec
# - mean end-to-end execution time across the five
#   executions of each benchmark question.
#
# ANALYTICAL LEVEL
# ----------------
# Individual executions
#       ↓
# Five repetitions summarized by question in 35_
#       ↓
# Question-level token workload and VES
#       ↓
# Exploratory visualisation
#
# INTERPRETATION
# --------------
# Token counts are treated as indicators of model workload.
#
# They are NOT interpreted as direct measurements of
# electrical energy consumption.
#
# IMPORTANT
# ---------
# This script does not recalculate the question-level
# summaries produced by 35_.
#
# It visualises relationships among those validated
# question-level summaries.
# ------------------------------------------------------------


library(here)
library(readr)
library(dplyr)
library(tidyr)
library(ggplot2)


# ------------------------------------------------------------
# CONFIGURATION
# ------------------------------------------------------------

INPUT_FILE <- here(
  "data",
  "analysis",
  "results",
  "35_question_level.csv"
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
  "36C_token_VES_relationship.png"
)

OUTPUT_FILE_BY_TYPE <- here(
  "data",
  "analysis",
  "results",
  "figures",
  "36C_token_VES_by_question_type.png"
)

# ------------------------------------------------------------
# VALIDATE INPUT
# ------------------------------------------------------------

if (!file.exists(INPUT_FILE)) {
  stop(
    "35_ question-level results not found: ",
    INPUT_FILE
  )
}


# ------------------------------------------------------------
# LOAD QUESTION-LEVEL RESULTS
# ------------------------------------------------------------

results <- readr::read_csv(
  INPUT_FILE,
  show_col_types = FALSE
)

if (!is.data.frame(results)) {
  stop(
    "Question-level results are not a data.frame."
  )
}

if (nrow(results) == 0) {
  stop(
    "Question-level results contain no observations."
  )
}

# ------------------------------------------------------------
# VALIDATE REQUIRED COLUMNS
# ------------------------------------------------------------

required_columns <- c(
  "model",
  "db_mode",
  "experiment_iteration",
  "question_id",
  "question_type",
  "n_repetitions",
  "VES_mean_sec",
  "prompt_tokens_mean",
  "generated_tokens_mean"
)

missing_columns <- setdiff(
  required_columns,
  names(results)
)

if (length(missing_columns) > 0) {
  stop(
    "Question-level results are missing required column(s): ",
    paste(
      missing_columns,
      collapse = ", "
    )
  )
}


# ------------------------------------------------------------
# VALIDATE QUESTION-LEVEL STRUCTURE
# ------------------------------------------------------------

if (!all(
  results$n_repetitions == 5
)) {
  stop(
    "Not every question-level observation represents ",
    "exactly five repetitions."
  )
}


# ------------------------------------------------------------
# VALIDATE TOKEN / VES VALUES
# ------------------------------------------------------------

if (anyNA(results$VES_mean_sec)) {
  stop(
    "VES_mean_sec contains missing values."
  )
}

if (anyNA(results$prompt_tokens_mean)) {
  stop(
    "prompt_tokens_mean contains missing values."
  )
}

if (anyNA(results$generated_tokens_mean)) {
  stop(
    "generated_tokens_mean contains missing values."
  )
}

if (any(results$VES_mean_sec < 0)) {
  stop(
    "VES_mean_sec contains negative values."
  )
}

if (any(results$prompt_tokens_mean < 0)) {
  stop(
    "prompt_tokens_mean contains negative values."
  )
}

if (any(results$generated_tokens_mean < 0)) {
  stop(
    "generated_tokens_mean contains negative values."
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
# PREPARE QUESTION-TYPE LABELS
# ------------------------------------------------------------

results$question_type_label <- dplyr::recode(
  results$question_type,
  "Lookup Queries" = "Lookup",
  "Analytical Queries" = "Analytical",
  "Unanswerable Questions" = "Unanswerable",
  "Advanced Tests (RVAT Required)" = "Advanced RVAT",
  .default = results$question_type
)


# ------------------------------------------------------------
# PREPARE LONG-FORM TOKEN DATA
# ------------------------------------------------------------
#
# Prompt-token and generated-token means are converted into
# one common structure so that both workload relationships
# can be displayed in a single faceted figure.
#
# Each resulting point still represents one benchmark
# question summarized across five executions.
# ------------------------------------------------------------

token_results <- results |>
  dplyr::select(
    model,
    db_mode,
    db_mode_label,
    experiment_iteration,
    question_id,
    question_type_label,
    VES_mean_sec,
    prompt_tokens_mean,
    generated_tokens_mean
  ) |>
  tidyr::pivot_longer(
    cols = c(
      prompt_tokens_mean,
      generated_tokens_mean
    ),
    names_to = "token_metric",
    values_to = "token_count"
  )


# ------------------------------------------------------------
# PREPARE TOKEN-METRIC LABELS
# ------------------------------------------------------------

token_results$token_metric <- factor(
  token_results$token_metric,
  levels = c(
    "prompt_tokens_mean",
    "generated_tokens_mean"
  ),
  labels = c(
    "Prompt tokens",
    "Generated tokens"
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
# CREATE TOKEN / VES VISUALISATION
# ------------------------------------------------------------
#
# Each point represents one benchmark question summarized
# across its five executions.
#
# Database modes are shown separately by colour.
#
# Linear trend lines are included only as exploratory visual
# aids. They do not constitute inferential statistical tests.
# ------------------------------------------------------------

token_ves_plot <- ggplot(
  token_results,
  aes(
    x = token_count,
    y = VES_mean_sec,
    colour = db_mode_label
  )
) +
  geom_point(
    size = 3,
    alpha = 0.8
  ) +
  geom_smooth(
    method = "lm",
    formula = y ~ x,
    se = FALSE,
    linewidth = 0.8
  ) +
  facet_wrap(
    ~ token_metric,
    scales = "free_x",
    ncol = 2
  ) +
  labs(
    title = "Token Workload and End-to-End Execution Time",
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
    x = "Mean token count per question",
    y = "Mean execution time (seconds)",
    colour = "Database mode",
    caption = paste(
      "Each point represents one benchmark question",
      "summarized across five executions.",
      "Trend lines are exploratory."
    )
  ) +
  theme_minimal(
    base_size = 12
  ) +
  theme(
    legend.position = "top",
    panel.grid.minor = element_blank(),
    strip.text = element_text(
      face = "bold"
    ),
    plot.caption = element_text(
      hjust = 0
    )
  )

# ------------------------------------------------------------
# OPTIONAL: TOKEN / VES VISUALISATION BY QUESTION TYPE
# ------------------------------------------------------------
#
# Uncomment this block to additionally encode benchmark
# question type using point shape.
#
# Visual encoding:
# - x-axis  = mean token count
# - y-axis  = mean VES
# - colour  = database mode
# - shape   = question type
# - panels  = prompt tokens / generated tokens
#
# Trend lines remain separated by database mode and are
# exploratory only.
# ------------------------------------------------------------

token_ves_plot_by_type <- ggplot(
  token_results,
  aes(
    x = token_count,
    y = VES_mean_sec,
    colour = db_mode_label
  )
) +
  geom_point(
    aes(
      shape = question_type_label
    ),
    size = 3.5,
    alpha = 0.85
  ) +
  geom_smooth(
    method = "lm",
    formula = y ~ x,
    se = FALSE,
    linewidth = 0.8
  ) +
  facet_wrap(
    ~ token_metric,
    scales = "free_x",
    ncol = 2
  ) +
  labs(
    title = "Token Workload and End-to-End Execution Time",
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
    x = "Mean token count per question",
    y = "Mean execution time (seconds)",
    colour = "Database mode",
    shape = "Question type",
    caption = paste(
      "Each point represents one benchmark question",
      "summarized across five executions.",
      "Trend lines are exploratory."
    )
  ) +
  theme_minimal(
    base_size = 12
  ) +
  theme(
    legend.position = "top",
    panel.grid.minor = element_blank(),
    strip.text = element_text(
      face = "bold"
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
  plot = token_ves_plot,
  width = 12,
  height = 6,
  units = "in",
  dpi = 300
)


# ------------------------------------------------------------
# SAVE OPTIONAL QUESTION-TYPE FIGURE
# ------------------------------------------------------------

ggsave(
  filename = OUTPUT_FILE_BY_TYPE,
  plot = token_ves_plot_by_type,
  width = 12,
  height = 6,
  units = "in",
  dpi = 300
)


# ------------------------------------------------------------
# VERIFY OUTPUTS
# ------------------------------------------------------------

if (!file.exists(OUTPUT_FILE)) {
  stop(
    "Token/VES figure was not created: ",
    OUTPUT_FILE
  )
}

if (!file.exists(OUTPUT_FILE_BY_TYPE)) {
  stop(
    "Question-type Token/VES figure was not created: ",
    OUTPUT_FILE_BY_TYPE
  )
}



# ------------------------------------------------------------
# FINAL REPORT
# ------------------------------------------------------------

cat("\n=========================================\n")
cat("36C TOKEN / VES VISUALISATION COMPLETED\n")
cat("=========================================\n")

cat(
  "Question-level observations:",
  nrow(results),
  "\n"
)

cat(
  "Visualisation observations:",
  nrow(token_results),
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
  "Standard figure:",
  OUTPUT_FILE,
  "\n"
)

cat(
  "Question-type figure:",
  OUTPUT_FILE_BY_TYPE,
  "\n"
)

cat("=========================================\n")
