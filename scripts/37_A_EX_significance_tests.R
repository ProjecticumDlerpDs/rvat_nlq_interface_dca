# ------------------------------------------------------------
# 37_A_EX_significance_tests.R
#
# PURPOSE
# -------
# Evaluate whether EX performance differs significantly
# between LLMs for each benchmark question type.
#
# METHODS
# -------
# 1. Kruskal-Wallis test
# 2. Pairwise Wilcoxon post-hoc test
#    with Holm correction
#
# INPUT
# -----
# data/analysis/results/35_question_level.csv
#
# OUTPUT
# ------
# data/analysis/results/
#
# 37_A_question_type_kruskal_wallis.csv
# 37_A_question_type_pairwise_wilcoxon.csv
#
# RESEARCH QUESTION
# -----------------
# Do the evaluated LLMs differ significantly in EX
# performance?
#
# PRIMARY OUTCOME
# ---------------
# EX_rate
#
# NOTES
# -----
# EM is intentionally excluded because EM exhibits no
# meaningful variation in the current benchmark dataset.
# ------------------------------------------------------------

library(here)
library(readr)
library(dplyr)

# ------------------------------------------------------------
# CONFIGURATION
# ------------------------------------------------------------

INPUT_FILE <- here(
  "data",
  "analysis",
  "results",
  "35_question_level.csv"
)

RESULTS_DIR <- here(
  "data",
  "analysis",
  "results"
)

KW_OUTPUT_FILE <- here(
  "data",
  "analysis",
  "results",
  "37_A_question_type_kruskal_wallis.csv"
)

PAIRWISE_OUTPUT_FILE <- here(
  "data",
  "analysis",
  "results",
  "37_A_question_type_pairwise_wilcoxon.csv"
)

# ------------------------------------------------------------
# VALIDATE INPUT
# ------------------------------------------------------------

if (!file.exists(INPUT_FILE)) {
  
  stop(
    "Question-level dataset not found: ",
    INPUT_FILE
  )
}

# ------------------------------------------------------------
# LOAD DATA
# ------------------------------------------------------------

question_level <- read_csv(
  INPUT_FILE,
  show_col_types = FALSE
)

if (!is.data.frame(question_level)) {
  
  stop(
    "Question-level dataset is not a data.frame."
  )
}

if (nrow(question_level) == 0) {
  
  stop(
    "Question-level dataset contains no observations."
  )
}

# ------------------------------------------------------------
# VALIDATE REQUIRED COLUMNS
# ------------------------------------------------------------

required_columns <- c(
  "model",
  "question_type",
  "EX_rate"
)

missing_columns <- setdiff(
  required_columns,
  names(question_level)
)

if (length(missing_columns) > 0) {
  
  stop(
    "Required column(s) missing: ",
    paste(
      missing_columns,
      collapse = ", "
    )
  )
}

# ------------------------------------------------------------
# DISCOVER QUESTION TYPES
# ------------------------------------------------------------

question_types <- sort(
  unique(
    question_level$question_type
  )
)

# ------------------------------------------------------------
# STORAGE
# ------------------------------------------------------------

kruskal_results <- list()

pairwise_results <- list()

# ------------------------------------------------------------
# TEST EACH QUESTION TYPE
# ------------------------------------------------------------

for (current_type in question_types) {
  
  subset_data <- question_level |>
    filter(
      question_type == current_type
    )
  
  # ----------------------------------------------------------
  # KRUSKAL-WALLIS
  # ----------------------------------------------------------
  
  kw_test <- kruskal.test(
    EX_rate ~ model,
    data = subset_data
  )
  
  kruskal_results[[length(kruskal_results) + 1]] <-
    data.frame(
      
      question_type = current_type,
      
      n_observations = nrow(subset_data),
      
      n_models = length(
        unique(
          subset_data$model
        )
      ),
      
      chi_square =
        as.numeric(
          kw_test$statistic
        ),
      
      degrees_freedom =
        as.numeric(
          kw_test$parameter
        ),
      
      p_value =
        kw_test$p.value,
      
      significant =
        ifelse(
          kw_test$p.value < 0.05,
          "YES",
          "NO"
        ),
      
      stringsAsFactors = FALSE
    )
  
  # ----------------------------------------------------------
  # PAIRWISE WILCOXON
  # ----------------------------------------------------------
  
  pairwise_test <- pairwise.wilcox.test(
    subset_data$EX_rate,
    subset_data$model,
    p.adjust.method = "holm"
  )
  
  pairwise_table <- as.data.frame(
    as.table(
      pairwise_test$p.value
    )
  )
  
  names(pairwise_table) <- c(
    "model_1",
    "model_2",
    "adjusted_p_value"
  )
  
  pairwise_table$question_type <-
    current_type
  
  pairwise_table$significant <-
    ifelse(
      !is.na(
        pairwise_table$adjusted_p_value
      ) &
        pairwise_table$adjusted_p_value < 0.05,
      "YES",
      "NO"
    )
  
  pairwise_results[[length(pairwise_results) + 1]] <-
    pairwise_table
}

# ------------------------------------------------------------
# COMBINE RESULTS
# ------------------------------------------------------------

kruskal_table <- bind_rows(
  kruskal_results
)

pairwise_table <- bind_rows(
  pairwise_results
)

# ------------------------------------------------------------
# SAVE KRUSKAL-WALLIS RESULTS
# ------------------------------------------------------------

write_csv(
  kruskal_table,
  KW_OUTPUT_FILE
)

# ------------------------------------------------------------
# SAVE PAIRWISE RESULTS
# ------------------------------------------------------------

write_csv(
  pairwise_table,
  PAIRWISE_OUTPUT_FILE
)

# ------------------------------------------------------------
# VERIFY OUTPUTS
# ------------------------------------------------------------

if (!file.exists(KW_OUTPUT_FILE)) {
  
  stop(
    "Kruskal-Wallis output not created."
  )
}

if (!file.exists(PAIRWISE_OUTPUT_FILE)) {
  
  stop(
    "Pairwise Wilcoxon output not created."
  )
}

# ------------------------------------------------------------
# CONSOLE SUMMARY
# ------------------------------------------------------------

cat("\n")
cat("=================================================\n")
cat("37_A EX SIGNIFICANCE TESTS COMPLETED\n")
cat("=================================================\n")

for (i in seq_len(nrow(kruskal_table))) {
  
  cat(
    kruskal_table$question_type[i],
    "\n"
  )
  
  cat(
    "  Chi-square:",
    round(
      kruskal_table$chi_square[i],
      4
    ),
    "\n"
  )
  
  cat(
    "  p-value:",
    signif(
      kruskal_table$p_value[i],
      6
    ),
    "\n"
  )
  
  cat(
    "  Significant:",
    kruskal_table$significant[i],
    "\n\n"
  )
}

cat(
  "Kruskal-Wallis results:\n",
  KW_OUTPUT_FILE,
  "\n\n"
)

cat(
  "Pairwise Wilcoxon results:\n",
  PAIRWISE_OUTPUT_FILE,
  "\n"
)

cat("=================================================\n")