# ------------------------------------------------------------
# 34_analyse_evaluation.R
#
# VERSION
# -------
# Version 1 - analysis ingestion and provenance validation
#
# PURPOSE
# -------
# Construct a trusted execution-level analysis dataset by
# combining:
#
# 1. Machine-generated measurements from the pristine
#    evaluation templates produced by 33_
#
# 2. Human-generated EM and EX scores from manually scored
#    files stored under data/analysis/
#
# DATA PROVENANCE
# ---------------
# Machine-generated variables are taken ONLY from:
#
#   data/processed/*_evaluation_template.csv
#
# Human-generated variables are taken ONLY from:
#
#   data/analysis/*_scored-<iteration>*
#
# The scored file contributes ONLY:
#
#   question_id
#   run_id
#   EM
#   EX
#
# This prevents spreadsheet software from unintentionally
# changing machine-generated numeric measurements such as:
#
#   model_temperature
#   time_total_sec
#   prompt_tokens
#   generated_tokens
#
# JOIN KEY
# --------
# question_id + run_id
#
# EXPERIMENTAL ITERATION
# ----------------------
# Derived from the scored filename:
#
#   *_scored-1* -> iteration 1
#   *_scored-2* -> iteration 2
#   *_scored-3* -> iteration 3
#
# VERSION 1 OUTPUT
# ----------------
# Builds and validates an execution-level master dataset.
#
# Version 1 DOES NOT:
# - aggregate repetitions
# - calculate question-level performance
# - calculate category-level performance
# - perform statistical tests
# - perform token correlations
# - classify errors
#
# Those steps will be added only after the master dataset
# has been independently validated.
# ------------------------------------------------------------


library(here)
library(readr)
library(readxl)


# ------------------------------------------------------------
# CONFIGURATION
# ------------------------------------------------------------

PROCESSED_DIR <- here(
  "data",
  "processed"
)

ANALYSIS_DIR <- here(
  "data",
  "analysis"
)

RESULTS_DIR <- here(
  "data",
  "analysis",
  "results"
)


# ------------------------------------------------------------
# ENSURE REQUIRED DIRECTORIES EXIST
# ------------------------------------------------------------

if (!dir.exists(PROCESSED_DIR)) {
  stop(
    "Processed-data directory not found: ",
    PROCESSED_DIR
  )
}

if (!dir.exists(ANALYSIS_DIR)) {
  stop(
    "Analysis directory not found: ",
    ANALYSIS_DIR
  )
}

dir.create(
  RESULTS_DIR,
  recursive = TRUE,
  showWarnings = FALSE
)


# ------------------------------------------------------------
# HELPER: READ SCORED FILE
# ------------------------------------------------------------
#
# During development scored files may be either:
#
#   .csv
#   .xlsx
#
# Only question_id, run_id, EM and EX will subsequently
# be retained from these manually handled files.
# ------------------------------------------------------------

read_scored_file <- function(file_path) {
  
  extension <- tolower(
    tools::file_ext(file_path)
  )
  
  if (extension == "csv") {
    
    return(
      readr::read_delim(
        file_path,
        delim = ";",
        show_col_types = FALSE,
        trim_ws = TRUE
      )
    )
  }
  
  if (extension == "xlsx") {
    
    return(
      readxl::read_excel(
        file_path
      )
    )
  }
  
  stop(
    "Unsupported scored-file format: ",
    file_path
  )
}


# ------------------------------------------------------------
# HELPER: IDENTIFY EXPERIMENTAL ITERATION
# ------------------------------------------------------------

extract_iteration <- function(file_name) {
  
  match_result <- regexec(
    "_scored-([0-9]+)",
    file_name,
    ignore.case = TRUE
  )
  
  extracted <- regmatches(
    file_name,
    match_result
  )[[1]]
  
  if (length(extracted) < 2) {
    stop(
      "Could not determine experimental iteration from: ",
      file_name
    )
  }
  
  as.integer(extracted[2])
}


# ------------------------------------------------------------
# HELPER: IDENTIFY CORRESPONDING TEMPLATE
# ------------------------------------------------------------
#
# Example:
#
# scored:
# raw_capture_qwen2.5-coder_latest_synthetic_20261004_224217_
# evaluation_scored-1.csv
#
# template:
# raw_capture_qwen2.5-coder_latest_synthetic_20261004_224217_
# evaluation_template.csv
#
# Files that were saved through Excel may contain an extra
# extension component, so template identification is based
# on the stable capture prefix rather than blindly replacing
# the full scored filename.
# ------------------------------------------------------------

find_template_file <- function(
    scored_file,
    processed_dir
) {
  
  scored_name <- basename(
    scored_file
  )
  
  capture_prefix <- sub(
    "_evaluation_scored-[0-9]+.*$",
    "",
    scored_name,
    ignore.case = TRUE
  )
  
  template_files <- list.files(
    processed_dir,
    pattern = "_evaluation_template\\.csv$",
    full.names = TRUE,
    ignore.case = TRUE
  )
  
  template_names <- basename(
    template_files
  )
  
  candidates <- template_files[
    startsWith(
      template_names,
      paste0(
        capture_prefix,
        "_evaluation_template"
      )
    )
  ]
  
  if (length(candidates) == 0) {
    stop(
      "No pristine evaluation template found for scored file: ",
      scored_name
    )
  }
  
  if (length(candidates) > 1) {
    stop(
      "Multiple evaluation templates match scored file: ",
      scored_name
    )
  }
  
  candidates[1]
}


# ------------------------------------------------------------
# DISCOVER SCORED FILES
# ------------------------------------------------------------

scored_files <- list.files(
  ANALYSIS_DIR,
  pattern = "_scored-[0-9]+.*\\.(csv|xlsx)$",
  full.names = TRUE,
  ignore.case = TRUE
)


# ------------------------------------------------------------
# VALIDATE SCORED FILE DISCOVERY
# ------------------------------------------------------------

if (length(scored_files) == 0) {
  stop(
    "No scored evaluation files found under: ",
    ANALYSIS_DIR
  )
}


cat("\n=========================================\n")
cat("34_ ANALYSIS INGESTION - VERSION 1\n")
cat("=========================================\n")

cat(
  "Scored files discovered:",
  length(scored_files),
  "\n"
)

for (file in scored_files) {
  cat(
    "-",
    basename(file),
    "\n"
  )
}


# ------------------------------------------------------------
# MASTER STORAGE
# ------------------------------------------------------------

master_results <- list()


# ------------------------------------------------------------
# PROCESS EACH SCORED ITERATION
# ------------------------------------------------------------

for (i in seq_along(scored_files)) {
  
  scored_file <- scored_files[i]
  
  scored_name <- basename(
    scored_file
  )
  
  
  cat("\n-----------------------------------------\n")
  
  cat(
    "Processing scored file:",
    scored_name,
    "\n"
  )
  
  
  # ----------------------------------------------------------
  # DETERMINE EXPERIMENTAL ITERATION
  # ----------------------------------------------------------
  
  experiment_iteration <- extract_iteration(
    scored_name
  )
  
  cat(
    "Experimental iteration:",
    experiment_iteration,
    "\n"
  )
  
  
  # ----------------------------------------------------------
  # LOCATE PRISTINE 33_ TEMPLATE
  # ----------------------------------------------------------
  
  template_file <- find_template_file(
    scored_file,
    PROCESSED_DIR
  )
  
  template_name <- basename(
    template_file
  )
  
  cat(
    "Matched template:",
    template_name,
    "\n"
  )
  
  
  # ----------------------------------------------------------
  # LOAD AUTHORITATIVE TEMPLATE
  # ----------------------------------------------------------
  
  template <- readr::read_csv(
    template_file,
    show_col_types = FALSE
  )
  
  
  # ----------------------------------------------------------
  # LOAD MANUALLY SCORED FILE
  # ----------------------------------------------------------
  
  scored <- read_scored_file(
    scored_file
  )
  
  
  # ----------------------------------------------------------
  # VALIDATE TEMPLATE REQUIRED COLUMNS
  # ----------------------------------------------------------
  
  required_template_columns <- c(
    "question_id",
    "run_id",
    "question_type",
    "db_mode",
    "timestamp",
    "user_query",
    "sql_query",
    "prompt_tokens",
    "generated_tokens",
    "rows_returned",
    "status",
    "error_message",
    "model",
    "model_parameters",
    "model_capability",
    "model_temperature",
    "time_total_sec"
  )
  
  missing_template_columns <- setdiff(
    required_template_columns,
    names(template)
  )
  
  if (length(missing_template_columns) > 0) {
    
    stop(
      "Template is missing required column(s): ",
      paste(
        missing_template_columns,
        collapse = ", "
      )
    )
  }
  
  
  # ----------------------------------------------------------
  # VALIDATE SCORED REQUIRED COLUMNS
  # ----------------------------------------------------------
  
  required_scored_columns <- c(
    "question_id",
    "run_id",
    "EM",
    "EX"
  )
  
  missing_scored_columns <- setdiff(
    required_scored_columns,
    names(scored)
  )
  
  if (length(missing_scored_columns) > 0) {
    
    stop(
      "Scored file is missing required column(s): ",
      paste(
        missing_scored_columns,
        collapse = ", "
      )
    )
  }
  
  
  # ----------------------------------------------------------
  # RETAIN ONLY HUMAN ANNOTATIONS FROM SCORED FILE
  # ----------------------------------------------------------
  
  scored_annotations <- scored[
    ,
    c(
      "question_id",
      "run_id",
      "EM",
      "EX"
    ),
    drop = FALSE
  ]
  
  
  # ----------------------------------------------------------
  # NORMALISE IDENTIFIER TYPES
  # ----------------------------------------------------------
  
  template$question_id <- as.character(
    template$question_id
  )
  
  scored_annotations$question_id <- as.character(
    scored_annotations$question_id
  )
  
  template$run_id <- as.integer(
    template$run_id
  )
  
  scored_annotations$run_id <- as.integer(
    scored_annotations$run_id
  )
  
  
  # ----------------------------------------------------------
  # NORMALISE SCORE TYPES
  # ----------------------------------------------------------
  
  scored_annotations$EM <- suppressWarnings(
    as.integer(
      scored_annotations$EM
    )
  )
  
  scored_annotations$EX <- suppressWarnings(
    as.integer(
      scored_annotations$EX
    )
  )
  
  
  # ----------------------------------------------------------
  # BUILD UNIQUE JOIN KEYS
  # ----------------------------------------------------------
  
  template$key <- paste(
    template$question_id,
    template$run_id,
    sep = "::"
  )
  
  scored_annotations$key <- paste(
    scored_annotations$question_id,
    scored_annotations$run_id,
    sep = "::"
  )
  
  
  # ----------------------------------------------------------
  # VALIDATE DUPLICATES
  # ----------------------------------------------------------
  
  if (anyDuplicated(template$key)) {
    stop(
      "Duplicate question_id/run_id combination found ",
      "in template: ",
      template_name
    )
  }
  
  if (anyDuplicated(scored_annotations$key)) {
    stop(
      "Duplicate question_id/run_id combination found ",
      "in scored file: ",
      scored_name
    )
  }
  
  
  # ----------------------------------------------------------
  # VALIDATE KEY SETS ARE IDENTICAL
  # ----------------------------------------------------------
  
  missing_scores <- setdiff(
    template$key,
    scored_annotations$key
  )
  
  extra_scores <- setdiff(
    scored_annotations$key,
    template$key
  )
  
  if (length(missing_scores) > 0) {
    
    stop(
      "Scored file is missing observation(s): ",
      paste(
        missing_scores,
        collapse = ", "
      )
    )
  }
  
  if (length(extra_scores) > 0) {
    
    stop(
      "Scored file contains unexpected observation(s): ",
      paste(
        extra_scores,
        collapse = ", "
      )
    )
  }
  
  
  # ----------------------------------------------------------
  # VALIDATE EM / EX COMPLETENESS
  # ----------------------------------------------------------
  
  if (anyNA(scored_annotations$EM)) {
    stop(
      "EM contains missing or non-numeric values in: ",
      scored_name
    )
  }
  
  if (anyNA(scored_annotations$EX)) {
    stop(
      "EX contains missing or non-numeric values in: ",
      scored_name
    )
  }
  
  
  # ----------------------------------------------------------
  # VALIDATE EM / EX VALUES
  # ----------------------------------------------------------
  
  if (!all(
    scored_annotations$EM %in% c(0L, 1L)
  )) {
    
    stop(
      "EM must contain only 0 or 1 in: ",
      scored_name
    )
  }
  
  if (!all(
    scored_annotations$EX %in% c(0L, 1L)
  )) {
    
    stop(
      "EX must contain only 0 or 1 in: ",
      scored_name
    )
  }
  
  
  # ----------------------------------------------------------
  # MATCH SCORES TO AUTHORITATIVE TEMPLATE
  # ----------------------------------------------------------
  
  score_match <- match(
    template$key,
    scored_annotations$key
  )
  
  if (anyNA(score_match)) {
    stop(
      "Internal score matching failed for: ",
      scored_name
    )
  }
  
  
  # ----------------------------------------------------------
  # CONSTRUCT TRUSTED ITERATION DATASET
  # ----------------------------------------------------------
  
  iteration_data <- template
  
  iteration_data$EM <- scored_annotations$EM[
    score_match
  ]
  
  iteration_data$EX <- scored_annotations$EX[
    score_match
  ]
  
  
  # ----------------------------------------------------------
  # ADD EXPERIMENTAL PROVENANCE
  # ----------------------------------------------------------
  
  iteration_data$experiment_iteration <-
    experiment_iteration
  
  iteration_data$source_template <-
    template_name
  
  iteration_data$source_scored <-
    scored_name
  
  
  # ----------------------------------------------------------
  # REMOVE TEMPORARY JOIN KEY
  # ----------------------------------------------------------
  
  iteration_data$key <- NULL
  
  
  # ----------------------------------------------------------
  # VALIDATE EXPECTED ITERATION STRUCTURE
  # ----------------------------------------------------------
  
  expected_questions <- 19L
  expected_runs <- 5L
  expected_observations <-
    expected_questions * expected_runs
  
  if (nrow(iteration_data) != expected_observations) {
    
    stop(
      "Expected ",
      expected_observations,
      " observations but found ",
      nrow(iteration_data),
      " in ",
      scored_name
    )
  }
  
  
  # ----------------------------------------------------------
  # VALIDATE QUESTION COUNT
  # ----------------------------------------------------------
  
  observed_questions <- unique(
    iteration_data$question_id
  )
  
  if (length(observed_questions) != expected_questions) {
    
    stop(
      "Expected ",
      expected_questions,
      " unique questions but found ",
      length(observed_questions),
      " in ",
      scored_name
    )
  }
  
  
  # ----------------------------------------------------------
  # VALIDATE FIVE RUNS PER QUESTION
  # ----------------------------------------------------------
  
  run_counts <- table(
    iteration_data$question_id
  )
  
  if (!all(run_counts == expected_runs)) {
    
    stop(
      "Not every question contains exactly ",
      expected_runs,
      " repetitions in ",
      scored_name
    )
  }
  
  
  # ----------------------------------------------------------
  # VALIDATE CONFIGURATION CONSISTENCY
  # ----------------------------------------------------------
  
  if (length(unique(iteration_data$model)) != 1) {
    stop(
      "More than one model found in iteration: ",
      scored_name
    )
  }
  
  if (length(unique(iteration_data$db_mode)) != 1) {
    stop(
      "More than one db_mode found in iteration: ",
      scored_name
    )
  }
  
  if (
    length(
      unique(
        iteration_data$model_temperature
      )
    ) != 1
  ) {
    
    stop(
      "More than one model_temperature found in iteration: ",
      scored_name
    )
  }
  
  
  # ----------------------------------------------------------
  # REPORT ITERATION VALIDATION
  # ----------------------------------------------------------
  
  cat(
    "Model:",
    unique(iteration_data$model),
    "\n"
  )
  
  cat(
    "DB mode:",
    unique(iteration_data$db_mode),
    "\n"
  )
  
  cat(
    "Temperature:",
    unique(iteration_data$model_temperature),
    "\n"
  )
  
  cat(
    "Observations:",
    nrow(iteration_data),
    "\n"
  )
  
  cat(
    "Questions:",
    length(unique(iteration_data$question_id)),
    "\n"
  )
  
  cat(
    "Runs/question:",
    expected_runs,
    "\n"
  )
  
  cat(
    "EM scores valid: YES\n"
  )
  
  cat(
    "EX scores valid: YES\n"
  )
  
  
  # ----------------------------------------------------------
  # STORE TRUSTED ITERATION
  # ----------------------------------------------------------
  
  master_results[[i]] <- iteration_data
}


# ------------------------------------------------------------
# COMBINE ITERATIONS
# ------------------------------------------------------------

master_analysis <- do.call(
  rbind,
  master_results
)

rownames(master_analysis) <- NULL


# ------------------------------------------------------------
# FINAL MASTER VALIDATION
# ------------------------------------------------------------

if (nrow(master_analysis) == 0) {
  stop(
    "Master analysis dataset contains no observations."
  )
}


# ------------------------------------------------------------
# ORDER IMPORTANT COLUMNS
# ------------------------------------------------------------

preferred_columns <- c(
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
  "generated_tokens",
  "model_temperature",
  "timestamp",
  "status",
  "error_message",
  "source_template",
  "source_scored"
)

master_analysis <- master_analysis[
  ,
  c(
    preferred_columns,
    setdiff(
      names(master_analysis),
      preferred_columns
    )
  ),
  drop = FALSE
]


# ------------------------------------------------------------
# SAVE VERSION-1 MASTER DATASET
# ------------------------------------------------------------

master_file <- here(
  "data",
  "analysis",
  "results",
  "34_master_execution_level.csv"
)

readr::write_csv(
  master_analysis,
  master_file,
  na = ""
)


# ------------------------------------------------------------
# READ-BACK VALIDATION
# ------------------------------------------------------------

verification_master <- readr::read_csv(
  master_file,
  show_col_types = FALSE
)

if (
  nrow(verification_master) !=
  nrow(master_analysis)
) {
  
  stop(
    "Master CSV integrity check failed: ",
    "row count differs after export."
  )
}


# ------------------------------------------------------------
# FINAL REPORT
# ------------------------------------------------------------

cat("\n=========================================\n")
cat("34_ VERSION 1 COMPLETED\n")
cat("=========================================\n")

cat(
  "Iterations processed:",
  length(scored_files),
  "\n"
)

cat(
  "Master observations:",
  nrow(master_analysis),
  "\n"
)

cat(
  "Models:",
  paste(
    unique(master_analysis$model),
    collapse = ", "
  ),
  "\n"
)

cat(
  "DB modes:",
  paste(
    unique(master_analysis$db_mode),
    collapse = ", "
  ),
  "\n"
)

cat(
  "Experimental iterations:",
  paste(
    sort(
      unique(
        master_analysis$experiment_iteration
      )
    ),
    collapse = ", "
  ),
  "\n"
)

cat(
  "Saved:",
  master_file,
  "\n"
)

cat("=========================================\n")