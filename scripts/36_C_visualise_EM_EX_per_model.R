# ------------------------------------------------------------
# 36_C_visualise_EM_EX_per_model.R
#
# PURPOSE
# -------
# Create model-specific EM/EX visualisations.
#
# Each figure:
# - Represents a single LLM
# - Aggregates over experimental iterations
# - Compares Full GDB versus Synthetic database modes
# - Displays EM and EX side-by-side
#
# INPUT
# -----
# data/analysis/results/35_question_type_level.csv
#
# OUTPUT
# ------
# data/analysis/visualisations/
#
# 36_C_EM_EX_<model>.png
#
# EXAMPLES
# --------
# 36_C_EM_EX_llama3_1_8b.png
# 36_C_EM_EX_qwen2_5_coder_latest.png
# 36_C_EM_EX_sqlcoder_latest.png
#
# ANALYTICAL HIERARCHY
# --------------------
# Executions
#      ↓
# Questions
#      ↓
# Question Types
#      ↓
# Iteration Aggregation
#      ↓
# Model-Specific Visualisation
#
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

OUTPUT_DIR <- here(
  "data",
  "analysis",
  "visualisations"
)

# ------------------------------------------------------------
# VALIDATE INPUT
# ------------------------------------------------------------

if (!file.exists(INPUT_FILE)) {
  
  stop(
    "35_question_type_level.csv not found: ",
    INPUT_FILE
  )
}

# ------------------------------------------------------------
# CREATE OUTPUT DIRECTORY
# ------------------------------------------------------------

dir.create(
  OUTPUT_DIR,
  recursive = TRUE,
  showWarnings = FALSE
)

# ------------------------------------------------------------
# LOAD DATA
# ------------------------------------------------------------

results <- readr::read_csv(
  INPUT_FILE,
  show_col_types = FALSE
)

if (!is.data.frame(results)) {
  
  stop(
    "Input file is not a data.frame."
  )
}

if (nrow(results) == 0) {
  
  stop(
    "Input file contains no observations."
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
  "EM_mean",
  "EX_mean"
)

missing_columns <- setdiff(
  required_columns,
  names(results)
)

if (length(missing_columns) > 0) {
  
  stop(
    "Missing required column(s): ",
    paste(
      missing_columns,
      collapse = ", "
    )
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
# PREPARE DB MODE LABELS
# ------------------------------------------------------------

results$db_mode_label <- dplyr::recode(
  results$db_mode,
  "synthetic" = "Synthetic",
  "full_gdb" = "Full GDB",
  .default = results$db_mode
)

# ------------------------------------------------------------
# COLOUR PALETTE
# ------------------------------------------------------------

mode_colours <- c(
  "Full GDB" = "#EF7065",
  "Synthetic" = "#19B3B8"
)

# ------------------------------------------------------------
# DISCOVER MODELS
# ------------------------------------------------------------

models <- sort(
  unique(results$model)
)

# ------------------------------------------------------------
# PROCESS EACH MODEL
# ------------------------------------------------------------

for (current_model in models) {
  
  model_results <- results |>
    dplyr::filter(
      model == current_model
    )
  
  # ----------------------------------------------------------
  # AGGREGATE OVER ITERATIONS
  # ----------------------------------------------------------
  
  model_summary <- model_results |>
    dplyr::group_by(
      question_type,
      db_mode_label
    ) |>
    dplyr::summarise(
      
      EM_mean = mean(
        EM_mean,
        na.rm = TRUE
      ),
      
      EX_mean = mean(
        EX_mean,
        na.rm = TRUE
      ),
      
      .groups = "drop"
    )
  
  # ----------------------------------------------------------
  # CONVERT TO LONG FORMAT
  # ----------------------------------------------------------
  
  plot_data <- model_summary |>
    tidyr::pivot_longer(
      cols = c(
        EM_mean,
        EX_mean
      ),
      names_to = "metric",
      values_to = "performance"
    )
  
  plot_data$metric <- factor(
    plot_data$metric,
    levels = c(
      "EM_mean",
      "EX_mean"
    ),
    labels = c(
      "Exact Match (EM)",
      "Execution Match (EX)"
    )
  )
  
  # ----------------------------------------------------------
  # CREATE VISUALISATION
  # ----------------------------------------------------------
  
  p <- ggplot(
    plot_data,
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
      vjust = -0.35,
      size = 3.75
    ) +
    facet_wrap(
      ~ metric,
      ncol = 2
    ) +
    scale_fill_manual(
      values = c(
        "Full GDB" = "#EF7065",
        "Synthetic" = "#19B3B8"
      )
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
      )
    ) +
    labs(
      title =
        "Query and Execution Performance by Question Type",
      
      subtitle =
        paste0(
          "Model: ",
          current_model,
          " | Experimental iterations aggregated: ",
          length(
            unique(
              model_results$experiment_iteration
            )
          )
        ),
      
      x = "Question Type",
      y = "Performance",
      fill = "Database Mode"
    ) +
    theme_minimal(
      base_size = 12
    ) +
    theme(
      legend.position = "top",
      panel.grid.major.x =
        element_blank(),
      strip.text =
        element_text(
          face = "bold"
        ),
      axis.text.x =
        element_text(
          angle = 15,
          hjust = 1
        )
    )
  
  # ----------------------------------------------------------
  # SAFE FILE NAME
  # ----------------------------------------------------------
  
  safe_model <- gsub(
    "_+",
    "_",
    gsub(
      "[^A-Za-z0-9]",
      "_",
      current_model
    )
  )
  
  output_file <- file.path(
    OUTPUT_DIR,
    paste0(
      "36_C_EM_EX_",
      safe_model,
      ".png"
    )
  )
  
  # ----------------------------------------------------------
  # SAVE VISUALISATION
  # ----------------------------------------------------------
  
  ggsave(
    filename = output_file,
    plot = p,
    width = 12,
    height = 6,
    units = "in",
    dpi = 300
  )
  
  if (!file.exists(output_file)) {
    
    stop(
      "Failed to create figure: ",
      output_file
    )
  }
  
  cat(
    "Created:",
    basename(output_file),
    "\n"
  )
}

# ------------------------------------------------------------
# FINAL REPORT
# ------------------------------------------------------------

cat("\n=========================================\n")
cat("36_C MODEL VISUALISATIONS COMPLETED\n")
cat("=========================================\n")

cat(
  "Models processed:",
  length(models),
  "\n"
)

cat(
  "Output directory:\n"
)

cat(
  OUTPUT_DIR,
  "\n"
)

cat("=========================================\n")