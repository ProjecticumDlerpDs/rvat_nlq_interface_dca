# ------------------------------------------------------------
# 38_B_VES_per_model.R
#
# PURPOSE
# -------
# Create model-specific VES visualisations.
#
# Each figure:
# - Represents a single LLM
# - Aggregates over experimental iterations
# - Compares Full GDB versus Synthetic
# - Displays VES by question type
#
# INPUT
# -----
# data/analysis/results/35_question_type_level.csv
#
# OUTPUT
# ------
# data/analysis/visualisations/
#
# 38_B_VES_<model>.png
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
  
  # ----------------------------------------------------------
  # ERROR BAR LIMITS
  # ----------------------------------------------------------
  
  model_summary <- model_summary |>
    dplyr::mutate(
      
      VES_lower_sec = pmax(
        0,
        VES_mean_sec - VES_sd_sec
      ),
      
      VES_upper_sec =
        VES_mean_sec + VES_sd_sec
    )
  
  # ----------------------------------------------------------
  # CREATE PLOT
  # ----------------------------------------------------------
  
  p <- ggplot(
    model_summary,
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
      panel.grid.major.x =
        element_blank(),
      axis.text.x =
        element_text(
          angle = 15,
          hjust = 1
        ),
      plot.caption =
        element_text(
          hjust = 0
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
      "38_B_VES_",
      safe_model,
      ".png"
    )
  )
  
  # ----------------------------------------------------------
  # SAVE PLOT
  # ----------------------------------------------------------
  
  ggsave(
    filename = output_file,
    plot = p,
    width = 10,
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
cat("38_B MODEL VES VISUALISATIONS COMPLETED\n")
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