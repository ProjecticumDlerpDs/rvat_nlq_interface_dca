# ------------------------------------------------------------
# 40_A_SQL_generation_quality.R
#
# PURPOSE
# -------
# Visualise SQL generation quality per LLM.
#
# This figure explains WHY models differ in EX performance.
#
# INPUT
# -----
# data/analysis/results/34_master_execution_level.csv
#
# OUTPUT
# ------
# data/analysis/visualisations/
#
# 40_A_SQL_generation_quality.png
#
# CLASSIFICATION
# --------------
# Valid SQL
# Execution Error
# Empty Response
# Non-SQL Response
#
# ------------------------------------------------------------

library(here)
library(readr)
library(dplyr)
library(stringr)
library(ggplot2)
library(scales)

# ------------------------------------------------------------
# CONFIGURATION
# ------------------------------------------------------------

INPUT_FILE <- here(
  "data",
  "analysis",
  "results",
  "34_master_execution_level.csv"
)

OUTPUT_FILE <- here(
  "data",
  "analysis",
  "visualisations",
  "40_A_SQL_generation_quality.png"
)

# ------------------------------------------------------------
# VALIDATE INPUT
# ------------------------------------------------------------

if (!file.exists(INPUT_FILE)) {
  
  stop(
    "Master dataset not found: ",
    INPUT_FILE
  )
}

# ------------------------------------------------------------
# LOAD DATA
# ------------------------------------------------------------

master <- read_csv(
  INPUT_FILE,
  show_col_types = FALSE
)

# ------------------------------------------------------------
# VALIDATE REQUIRED COLUMNS
# ------------------------------------------------------------

required_columns <- c(
  "model",
  "sql_query",
  "status"
)

missing_columns <- setdiff(
  required_columns,
  names(master)
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
# CLASSIFY SQL GENERATION QUALITY
# ------------------------------------------------------------

master$sql_query <- ifelse(
  is.na(master$sql_query),
  "",
  master$sql_query
)

master$generation_outcome <- dplyr::case_when(
  
  # No output generated at all
  
  trimws(master$sql_query) == "" ~
    "Empty Response",
  
  # Output generated but does not resemble SQL
  
  !str_detect(
    str_to_upper(master$sql_query),
    "\\b(SELECT|WITH)\\b"
  ) ~
    "Non-SQL Response",
  
  # Executable SQL generated successfully
  
  master$status == "PASS" ~
    "Valid SQL",
  
  # SQL generated but execution failed
  
  master$status == "FAIL" ~
    "SQL Execution Failure",
  
  TRUE ~
    "Unclassified"
)

# ------------------------------------------------------------
# SUMMARY TABLE
# ------------------------------------------------------------

summary_data <- master |>
  count(
    model,
    generation_outcome
  ) |>
  group_by(model) |>
  mutate(
    
    percentage =
      n / sum(n)
    
  ) |>
  ungroup()

# ------------------------------------------------------------
# ORDER CATEGORIES
# ------------------------------------------------------------

summary_data$generation_outcome <- factor(
  summary_data$generation_outcome,
  levels = c(
    "Valid SQL",
    "SQL Execution Failure",
    "Non-SQL Response",
    "Empty Response"
  )
)

# ------------------------------------------------------------
# COLOURS
# ------------------------------------------------------------

quality_colours <- c(
  
  "Valid SQL" =
    "#1B9E77",
  
  "SQL Execution Failure" =
    "#D95F02",
  
  "Non-SQL Response" =
    "#7570B3",
  
  "Empty Response" =
    "#E7298A"
)

# ------------------------------------------------------------
# CREATE VISUALISATION
# ------------------------------------------------------------

p <- ggplot(
  summary_data,
  aes(
    x = model,
    y = percentage,
    fill = generation_outcome
  )
) +
  
  geom_col(
    width = 0.7
  ) +
  
  geom_text(
    aes(
      label =
        ifelse(
          percentage >= 0.05,
          percent(
            percentage,
            accuracy = 1
          ),
          ""
        )
    ),
    position = position_stack(
      vjust = 0.5
    ),
    size = 4,
    colour = "white",
    fontface = "bold"
  ) +
  
  scale_fill_manual(
    values = quality_colours
  ) +
  
  scale_y_continuous(
    labels = percent_format(
      accuracy = 1
    )
  ) +
  
  labs(
    title =
      "SQL Generation Quality by LLM",
    
    subtitle =
      paste(
        "Generation outcomes based on sql_query and status."
      ),
    
    x = "LLM",
    
    y = "Percentage of executions",
    
    fill = "Generation Outcome",
    
    caption =
      paste(
        "Valid SQL = executable SQL generated;",
        "SQL Execution Failure = SQL generated but execution failed;",
        "Non-SQL Response = explanatory or invalid text;",
        "Empty Response = no SQL generated."
      )
  ) +
  
  theme_minimal(
    base_size = 12
  ) +
  
  theme(
    legend.position = "top",
    panel.grid.major.x =
      element_blank()
  )

# ------------------------------------------------------------
# SAVE FIGURE
# ------------------------------------------------------------

ggsave(
  filename = OUTPUT_FILE,
  plot = p,
  width = 12,
  height = 7,
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
# CONSOLE SUMMARY
# ------------------------------------------------------------

cat("\n=========================================\n")
cat("40_A SQL GENERATION QUALITY COMPLETED\n")
cat("=========================================\n")

print(
  summary_data |>
    arrange(
      model,
      generation_outcome
    )
)

cat(
  "\nSaved:\n",
  OUTPUT_FILE,
  "\n"
)

cat("=========================================\n")