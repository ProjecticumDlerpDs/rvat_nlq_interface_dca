# ------------------------------------------------------------
# 35_analyse_performance.R
#
# PURPOSE
# -------
# Perform quantitative performance analysis on the trusted
# execution-level master dataset produced by
# 34_analyse_evaluation.R.
#
# PRIMARY OUTCOMES
# ----------------
# EM
# - manual binary evaluation of generated query correctness
#
# EX
# - manual binary evaluation of returned answer correctness
#
# VES
# - end-to-end execution time represented by time_total_sec
#
# PRIMARY REPORTING LEVEL
# -----------------------
# Question type:
#
# - Lookup Queries
# - Analytical Queries
# - Unanswerable Questions
# - Advanced Tests (RVAT Required)
#
# ANALYTICAL HIERARCHY
# --------------------
# Execution / repetition
#       ↓
# Question
#       ↓
# Question type
#       ↓
# Experimental iteration
#       ↓
# Model x database mode condition
#
# IMPORTANT
# ---------
# The five repetitions of a question are summarized BEFORE
# question-level results are aggregated by question type.
#
# This ensures that the benchmark question, rather than each
# individual execution, forms the intermediate analytical unit.
#
# INPUT
# -----
# data/analysis/results/34_master_execution_level.csv
#
# OUTPUTS
# -------
# data/analysis/results/35_question_level.csv
# data/analysis/results/35_question_type_level.csv
#
# FUTURE EXTENSIONS
# -----------------
# - three-iteration condition summaries
# - model comparisons
# - DB-mode comparisons
# - formal inferential statistics
# - token/VES exploratory analysis
# - graphics derived from validated summary datasets
#
# ERROR ANALYSIS
# --------------
# Error/hallucination classification is intentionally excluded.
# This will be handled in a later dedicated analysis script.
# ------------------------------------------------------------


library(here)
library(readr)
library(dplyr)


# ------------------------------------------------------------
# CONFIGURATION
# ------------------------------------------------------------

RESULTS_DIR <- here(
  "data",
  "analysis",
  "results"
)

MASTER_FILE <- here(
  "data",
  "analysis",
  "results",
  "34_master_execution_level.csv"
)


# ------------------------------------------------------------
# VALIDATE INPUT
# ------------------------------------------------------------

if (!dir.exists(RESULTS_DIR)) {
  stop(
    "Analysis-results directory not found: ",
    RESULTS_DIR
  )
}

if (!file.exists(MASTER_FILE)) {
  stop(
    "34_ master analysis file not found: ",
    MASTER_FILE
  )
}


# ------------------------------------------------------------
# LOAD TRUSTED EXECUTION-LEVEL DATA
# ------------------------------------------------------------

master <- readr::read_csv(
  MASTER_FILE,
  show_col_types = FALSE
)

if (!is.data.frame(master)) {
  stop(
    "34_ master dataset is not a data.frame."
  )
}

if (nrow(master) == 0) {
  stop(
    "34_ master dataset contains no observations."
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
  "run_id",
  "question_type",
  "EM",
  "EX",
  "time_total_sec",
  "prompt_tokens",
  "generated_tokens"
)

missing_columns <- setdiff(
  required_columns,
  names(master)
)

if (length(missing_columns) > 0) {
  stop(
    "Master dataset is missing required column(s): ",
    paste(
      missing_columns,
      collapse = ", "
    )
  )
}


# ------------------------------------------------------------
# NORMALISE ANALYTICAL TYPES
# ------------------------------------------------------------

master$experiment_iteration <- as.integer(
  master$experiment_iteration
)

master$run_id <- as.integer(
  master$run_id
)

master$EM <- as.integer(
  master$EM
)

master$EX <- as.integer(
  master$EX
)

master$time_total_sec <- as.numeric(
  master$time_total_sec
)

master$prompt_tokens <- as.numeric(
  master$prompt_tokens
)

master$generated_tokens <- as.numeric(
  master$generated_tokens
)


# ------------------------------------------------------------
# VALIDATE IDENTIFIERS
# ------------------------------------------------------------

if (anyNA(master$model)) {
  stop(
    "model contains missing values."
  )
}

if (anyNA(master$db_mode)) {
  stop(
    "db_mode contains missing values."
  )
}

if (anyNA(master$experiment_iteration)) {
  stop(
    "experiment_iteration contains missing values."
  )
}

if (anyNA(master$question_id)) {
  stop(
    "question_id contains missing values."
  )
}

if (anyNA(master$run_id)) {
  stop(
    "run_id contains missing values."
  )
}

if (anyNA(master$question_type)) {
  stop(
    "question_type contains missing values."
  )
}


# ------------------------------------------------------------
# VALIDATE PRIMARY OUTCOMES
# ------------------------------------------------------------

if (anyNA(master$EM)) {
  stop(
    "EM contains missing values."
  )
}

if (anyNA(master$EX)) {
  stop(
    "EX contains missing values."
  )
}

if (!all(master$EM %in% c(0L, 1L))) {
  stop(
    "EM must contain only 0 or 1."
  )
}

if (!all(master$EX %in% c(0L, 1L))) {
  stop(
    "EX must contain only 0 or 1."
  )
}

if (anyNA(master$time_total_sec)) {
  stop(
    "time_total_sec contains missing or non-numeric values."
  )
}

if (any(master$time_total_sec < 0)) {
  stop(
    "time_total_sec contains negative values."
  )
}


# ------------------------------------------------------------
# VALIDATE QUESTION REPETITIONS
# ------------------------------------------------------------

repetition_check <- master |>
  dplyr::count(
    model,
    db_mode,
    experiment_iteration,
    question_id,
    name = "n_repetitions"
  )

if (!all(
  repetition_check$n_repetitions == 5
)) {
  stop(
    paste(
      "Not every question has exactly five repetitions.",
      "Inspect repetition_check."
    )
  )
}


# ------------------------------------------------------------
# REPORT INPUT STRUCTURE
# ------------------------------------------------------------

cat("\n=========================================\n")
cat("35_ PERFORMANCE ANALYSIS\n")
cat("=========================================\n")

cat(
  "Execution-level observations:",
  nrow(master),
  "\n"
)

cat(
  "Models:",
  paste(
    unique(master$model),
    collapse = ", "
  ),
  "\n"
)

cat(
  "DB modes:",
  paste(
    unique(master$db_mode),
    collapse = ", "
  ),
  "\n"
)

cat(
  "Experimental iterations:",
  paste(
    sort(
      unique(
        master$experiment_iteration
      )
    ),
    collapse = ", "
  ),
  "\n"
)


# ------------------------------------------------------------
# QUESTION-LEVEL ANALYSIS
# ------------------------------------------------------------
#
# Every benchmark question is executed five times.
#
# These five repetitions are summarized FIRST.
#
# EM_rate and EX_rate:
# - proportions across the five binary observations.
#
# VES:
# - mean execution time
# - median execution time
# - within-question SD across the five execution times
#
# Token counts:
# - mean across the five executions
# ------------------------------------------------------------

question_level <- master |>
  dplyr::group_by(
    model,
    db_mode,
    experiment_iteration,
    question_id,
    question_type
  ) |>
  dplyr::summarise(
    
    n_repetitions = dplyr::n(),
    
    EM_rate = mean(
      EM,
      na.rm = TRUE
    ),
    
    EX_rate = mean(
      EX,
      na.rm = TRUE
    ),
    
    VES_mean_sec = mean(
      time_total_sec,
      na.rm = TRUE
    ),
    
    VES_median_sec = median(
      time_total_sec,
      na.rm = TRUE
    ),
    
    VES_sd_sec = sd(
      time_total_sec,
      na.rm = TRUE
    ),
    
    prompt_tokens_mean = mean(
      prompt_tokens,
      na.rm = TRUE
    ),
    
    generated_tokens_mean = mean(
      generated_tokens,
      na.rm = TRUE
    ),
    
    .groups = "drop"
  )


# ------------------------------------------------------------
# VALIDATE QUESTION-LEVEL OUTPUT
# ------------------------------------------------------------

if (!all(
  question_level$n_repetitions == 5
)) {
  stop(
    "Question-level aggregation contains an unexpected ",
    "number of repetitions."
  )
}

expected_question_rows <- length(
  unique(
    paste(
      master$model,
      master$db_mode,
      master$experiment_iteration,
      master$question_id,
      sep = "::"
    )
  )
)

if (
  nrow(question_level) !=
  expected_question_rows
) {
  stop(
    "Question-level row count does not match expected ",
    "model/db_mode/iteration/question combinations."
  )
}


# ------------------------------------------------------------
# VALIDATE QUESTION-LEVEL EM / EX RATES
# ------------------------------------------------------------
#
# With exactly five binary repetitions, valid rates are:
#
# 0.0, 0.2, 0.4, 0.6, 0.8, 1.0
# ------------------------------------------------------------

valid_rates <- seq(
  0,
  1,
  by = 0.2
)

rate_tolerance <- 1e-10

valid_EM_rates <- vapply(
  question_level$EM_rate,
  function(x) {
    any(
      abs(
        x - valid_rates
      ) < rate_tolerance
    )
  },
  logical(1)
)

valid_EX_rates <- vapply(
  question_level$EX_rate,
  function(x) {
    any(
      abs(
        x - valid_rates
      ) < rate_tolerance
    )
  },
  logical(1)
)

if (!all(valid_EM_rates)) {
  stop(
    "Unexpected EM_rate detected at question level."
  )
}

if (!all(valid_EX_rates)) {
  stop(
    "Unexpected EX_rate detected at question level."
  )
}

# ------------------------------------------------------------
# SAVE QUESTION-LEVEL RESULTS
# ------------------------------------------------------------

question_file <- here(
  "data",
  "analysis",
  "results",
  "35_question_level.csv"
)

readr::write_csv(
  question_level,
  question_file,
  na = ""
)


# ------------------------------------------------------------
# QUESTION-TYPE ANALYSIS
# ------------------------------------------------------------
#
# IMPORTANT:
#
# This aggregation operates on QUESTION-LEVEL summaries.
#
# It does NOT aggregate directly from individual execution
# observations.
#
# Therefore each question contributes one summary value to
# its benchmark category within each experimental iteration.
#
# EM / EX:
# - mean of question-level rates
# - between-question SD
#
# VES:
# - mean of question-level mean execution times
# - median of question-level median execution times
# - SD of question-level mean execution times
#
# This preserves the analytical hierarchy:
#
# executions -> questions -> question types
# ------------------------------------------------------------

question_type_level <- question_level |>
  dplyr::group_by(
    model,
    db_mode,
    experiment_iteration,
    question_type
  ) |>
  dplyr::summarise(
    
    n_questions = dplyr::n(),
    
    EM_mean = mean(
      EM_rate,
      na.rm = TRUE
    ),
    
    EM_sd = sd(
      EM_rate,
      na.rm = TRUE
    ),
    
    EX_mean = mean(
      EX_rate,
      na.rm = TRUE
    ),
    
    EX_sd = sd(
      EX_rate,
      na.rm = TRUE
    ),
    
    VES_category_mean_sec = mean(
      VES_mean_sec,
      na.rm = TRUE
    ),
    
    VES_category_median_sec = median(
      VES_median_sec,
      na.rm = TRUE
    ),
    
    VES_between_question_sd_sec = sd(
      VES_mean_sec,
      na.rm = TRUE
    ),
    
    prompt_tokens_mean = mean(
      prompt_tokens_mean,
      na.rm = TRUE
    ),
    
    generated_tokens_mean = mean(
      generated_tokens_mean,
      na.rm = TRUE
    ),
    
    .groups = "drop"
  )


# ------------------------------------------------------------
# VALIDATE QUESTION-TYPE STRUCTURE
# ------------------------------------------------------------

expected_question_types <- c(
  "Lookup Queries",
  "Analytical Queries",
  "Unanswerable Questions",
  "Advanced Tests (RVAT Required)"
)

observed_question_types <- unique(
  question_type_level$question_type
)

missing_question_types <- setdiff(
  expected_question_types,
  observed_question_types
)

if (length(missing_question_types) > 0) {
  warning(
    "Question type(s) not represented in current data: ",
    paste(
      missing_question_types,
      collapse = ", "
    )
  )
}


# ------------------------------------------------------------
# VALIDATE EXPECTED QUESTIONS PER TYPE
# ------------------------------------------------------------

expected_type_counts <- c(
  "Lookup Queries" = 5L,
  "Analytical Queries" = 6L,
  "Unanswerable Questions" = 6L,
  "Advanced Tests (RVAT Required)" = 2L
)

expected_counts <- unname(
  expected_type_counts[
    question_type_level$question_type
  ]
)

if (anyNA(expected_counts)) {
  stop(
    "Unexpected question_type found in question-type results."
  )
}

if (!all(
  question_type_level$n_questions ==
  expected_counts
)) {
  stop(
    "Question-type aggregation contains an unexpected ",
    "number of benchmark questions."
  )
}


# ------------------------------------------------------------
# VALIDATE QUESTION-TYPE METRICS
# ------------------------------------------------------------

if (anyNA(question_type_level$EM_mean)) {
  stop(
    "EM_mean contains missing values at question-type level."
  )
}

if (anyNA(question_type_level$EX_mean)) {
  stop(
    "EX_mean contains missing values at question-type level."
  )
}

if (anyNA(
  question_type_level$VES_category_mean_sec
)) {
  stop(
    "VES_category_mean_sec contains missing values."
  )
}

if (anyNA(
  question_type_level$VES_category_median_sec
)) {
  stop(
    "VES_category_median_sec contains missing values."
  )
}

if (anyNA(
  question_type_level$VES_between_question_sd_sec
)) {
  stop(
    "VES_between_question_sd_sec contains missing values."
  )
}


# ------------------------------------------------------------
# SAVE QUESTION-TYPE RESULTS
# ------------------------------------------------------------

question_type_file <- here(
  "data",
  "analysis",
  "results",
  "35_question_type_level.csv"
)

readr::write_csv(
  question_type_level,
  question_type_file,
  na = ""
)


# ------------------------------------------------------------
# READ-BACK VALIDATION
# ------------------------------------------------------------

question_verify <- readr::read_csv(
  question_file,
  show_col_types = FALSE
)

type_verify <- readr::read_csv(
  question_type_file,
  show_col_types = FALSE
)

if (
  nrow(question_verify) !=
  nrow(question_level)
) {
  stop(
    "Question-level CSV failed read-back validation."
  )
}

if (
  nrow(type_verify) !=
  nrow(question_type_level)
) {
  stop(
    "Question-type CSV failed read-back validation."
  )
}


# ------------------------------------------------------------
# CONSOLE SUMMARY
# ------------------------------------------------------------

cat("\n-----------------------------------------\n")
cat("QUESTION-LEVEL ANALYSIS\n")
cat("-----------------------------------------\n")

cat(
  "Question-level observations:",
  nrow(question_level),
  "\n"
)

cat(
  "Saved:",
  question_file,
  "\n"
)


cat("\n-----------------------------------------\n")
cat("QUESTION-TYPE ANALYSIS\n")
cat("-----------------------------------------\n")

cat(
  "Question-type observations:",
  nrow(question_type_level),
  "\n"
)

cat(
  "Saved:",
  question_type_file,
  "\n"
)


# ------------------------------------------------------------
# DISPLAY PRIMARY QUESTION-TYPE RESULTS
# ------------------------------------------------------------

cat("\nPrimary question-type results:\n")

print(
  question_type_level |>
    dplyr::select(
      model,
      db_mode,
      experiment_iteration,
      question_type,
      n_questions,
      EM_mean,
      EX_mean,
      VES_category_mean_sec,
      VES_category_median_sec,
      VES_between_question_sd_sec
    )
)


# ------------------------------------------------------------
# FINAL REPORT
# ------------------------------------------------------------

cat("\n=========================================\n")
cat("35_ PERFORMANCE ANALYSIS COMPLETED\n")
cat("=========================================\n")

cat(
  "Execution observations analysed:",
  nrow(master),
  "\n"
)

cat(
  "Question-level results:",
  nrow(question_level),
  "\n"
)

cat(
  "Question-type results:",
  nrow(question_type_level),
  "\n"
)

cat(
  "Question-level file:",
  question_file,
  "\n"
)

cat(
  "Question-type file:",
  question_type_file,
  "\n"
)

cat("=========================================\n")