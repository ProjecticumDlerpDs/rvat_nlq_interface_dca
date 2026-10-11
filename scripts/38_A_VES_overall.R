# ------------------------------------------------------------
# 38_A_VES_overall.R
# ------------------------------------------------------------
# 
# PURPOSE
# -------
# Visualise overall VES performance by question type and
# database mode.
#
# Aggregates across:
# - all models
# - all experimental iterations
#
# INPUT
# -----
# data/analysis/results/35_question_type_level.csv
#
# OUTPUT
# ------
# data/analysis/visualisations/
#
# 38_A_VES_by_question_type_overall.png
#
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

OUTPUT_FILE <- here(
  "data",
  "analysis",
  "visualisations",
  "38_A_VES_by_question_type_overall.png"
)

# ------------------------------------------------------------
# VALIDATE INPUT
# ------------------------------------------------------------

if (!file.exists(INPUT_FILE)) {
  
  stop(
    "35_question_type_level.csv not found."
  )
}

# ------------------------------------------------------------
# LOAD DATA
# ------------------------------------------------------------

results <- read_csv(
  INPUT_FILE,
  show_col_types = FALSE
)

# ------------------------------------------------------------
# VALIDATE REQUIRED COLUMNS
# ------------------------------------------------------------

required_columns <- c(
  "model",
  "db_mode",
  "experiment_iteration",
  "question_type",
  "VES_category_mean_sec",
  "VES_between_question_sd_sec"
)

missing_columns <- setdiff(
  required_columns,
  names(results)
)

if (length(missing_columns) > 0) {
  
  stop(
    "Missing required columns: ",
    paste(
      missing_columns,
      collapse = ", "
    )
  )
}

# ------------------------------------------------------------
# QUESTION TYPE LABELS
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
# DATABASE MODE LABELS
# ------------------------------------------------------------

results$db_mode_label <- dplyr::recode(
  results$db_mode,
  "full_gdb" = "Full GDB",
  "synthetic" = "Synthetic",
  .default = results$db_mode
)

# ------------------------------------------------------------
# AGGREGATE OVER MODELS AND ITERATIONS
# ------------------------------------------------------------

ves_summary <- results |>
  group_by(
    question_type,
    db_mode_label
  ) |>
  summarise(
    
    VES_mean_sec = mean(
      VES_category_mean_sec,
      na.rm = TRUE
    ),
    
    VES_sd_sec = mean(
      VES_between_question_sd_sec,
      na.rm = TRUE
    ),
    
    .groups = "drop"
  )

# ------------------------------------------------------------
# ERROR BAR LIMITS
# ------------------------------------------------------------

ves_summary <- ves_summary |>
  dplyr::mutate(
    
    VES_lower_sec = pmax(
      0,
      VES_mean_sec - VES_sd_sec
    ),
    
    VES_upper_sec =
      VES_mean_sec + VES_sd_sec
  )

# ------------------------------------------------------------
# CREATE VISUALISATION
# ------------------------------------------------------------

ves_plot <- ggplot(
  ves_summary,
  aes(
    x = question_type,
    y = VES_mean_sec,
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
        VES_mean_sec
      )
    ),
    position = position_dodge(
      width = 0.8
    ),
    vjust = -0.5,
    size = 4
  ) +
  scale_fill_manual(
    values = c(
      "Full GDB" = "#EF7065",
      "Synthetic" = "#19B3B8"
    )
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
    
    title =
      "End-to-End Execution Time by Question Type",
    
    subtitle =
      paste0(
        "Overall benchmark summary | ",
        length(
          unique(results$model)
        ),
        " LLMs | ",
        length(
          unique(
            results$experiment_iteration
          )
        ),
        " experimental iterations"
      ),
    
    x = "Question Type",
    
    y = "Mean execution time (seconds)",
    
    fill = "Database mode",
    
    caption =
      "Bars show mean VES; error bars show ±1 SD."
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
    "Output figure was not created."
  )
}

# ------------------------------------------------------------
# FINAL REPORT
# ------------------------------------------------------------

cat("\n=========================================\n")
cat("38_A OVERALL VES VISUALISATION COMPLETED\n")
cat("=========================================\n")

cat(
  "Question-type observations:",
  nrow(ves_summary),
  "\n"
)

cat(
  "Saved:",
  OUTPUT_FILE,
  "\n"
)

cat("=========================================\n")
    