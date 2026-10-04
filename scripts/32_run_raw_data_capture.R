# ------------------------------------------------------------
# 32_run_raw_data_capture.R
#
# PURPOSE
# -------
# Execute benchmark questions repeatedly through the existing
# RVAT NLQ production pipeline and preserve the resulting
# observations as raw research data.
#
# DESIGN
# ------
# - Uses production database configuration from 01_
# - Uses production model/temperature configuration from 02_
# - Uses production query execution from 03_
# - Uses production logging from 04_
# - Does not implement separate LLM, DB, timing, or scoring logic
# - Does not calculate EM or EX
# - Captures experimental provenance at execution time:
# question_id
# run_id
# db_mode
#
# RAW OUTPUT
# ----------
# data/raw/raw_capture_<model>_<db_mode>_<timestamp>.rds
#
# NOTES
# -----
# The benchmark CSV may contain empty trailing rows.
# These are removed automatically during import.
# ------------------------------------------------------------


library(here)


# ------------------------------------------------------------
# CONFIGURATION
# ------------------------------------------------------------

BENCHMARK_FILE <- here(
  "data",
  "benchmark_questions.csv"
)

# Validation setting.
# Increase to 5 only after the capture workflow has passed.
N_RUNS <- 5


# ------------------------------------------------------------
# LOAD PRODUCTION PIPELINE
# ------------------------------------------------------------

source(here("R", "01_db_connection.R"))
source(here("R", "02_ollama_config.R"))
source(here("R", "03_query_execution.R"))
source(here("R", "04_logging_pipeline.R"))


# ------------------------------------------------------------
# RESOLVE ACTIVE PRODUCTION SETTINGS
# ------------------------------------------------------------

db_mode_used <- DB_MODE
model_used <- model_name
temperature_used <- model_temperature

cat("\n=========================================\n")
cat("RAW DATA CAPTURE\n")
cat("=========================================\n")
cat("Model:", model_used, "\n")
cat("Temperature:", temperature_used, "\n")
cat("DB mode:", db_mode_used, "\n")
cat("Runs per question:", N_RUNS, "\n")


# ------------------------------------------------------------
# LOAD BENCHMARK DEFINITIONS
# ------------------------------------------------------------

if (!file.exists(BENCHMARK_FILE)) {
  stop(
    "Benchmark file not found: ",
    BENCHMARK_FILE
  )
}

# The benchmark file is semicolon-delimited.
benchmark <- read.csv2(
  BENCHMARK_FILE,
  stringsAsFactors = FALSE,
  check.names = FALSE
)


# ------------------------------------------------------------
# VALIDATE REQUIRED BENCHMARK COLUMNS
# ------------------------------------------------------------

required_columns <- c(
  "Question number",
  "Type",
  "NLQ",
  "Expected query",
  "Expected answer",
  "Notes"
)

missing_columns <- setdiff(
  required_columns,
  names(benchmark)
)

if (length(missing_columns) > 0) {
  stop(
    "Benchmark file is missing required column(s): ",
    paste(missing_columns, collapse = ", ")
  )
}


# ------------------------------------------------------------
# REMOVE EMPTY TRAILING / ACCIDENTAL ROWS
# ------------------------------------------------------------

valid_question_number <- !is.na(
  benchmark[["Question number"]]
)

valid_nlq <- !is.na(
  benchmark[["NLQ"]]
) &
  nzchar(
    trimws(benchmark[["NLQ"]])
  )

benchmark <- benchmark[
  valid_question_number & valid_nlq,
  ,
  drop = FALSE
]

rownames(benchmark) <- NULL

if (nrow(benchmark) == 0) {
  stop(
    "No valid benchmark questions found after removing empty rows."
  )
}


# ------------------------------------------------------------
# VALIDATE QUESTION IDENTIFIERS
# ------------------------------------------------------------

if (anyDuplicated(benchmark[["Question number"]])) {
  stop(
    "Duplicate question numbers found in benchmark file."
  )
}


# ------------------------------------------------------------
# CREATE STABLE QUESTION IDENTIFIERS
# ------------------------------------------------------------

benchmark$question_id <- sprintf(
  "Q%02d",
  as.integer(benchmark[["Question number"]])
)


# ------------------------------------------------------------
# REPORT TEST PLAN
# ------------------------------------------------------------

expected_observations <- nrow(benchmark) * N_RUNS

cat("\nBenchmark questions:", nrow(benchmark), "\n")
cat("Expected observations:", expected_observations, "\n")

cat("\nQuestions loaded:\n")

for (i in seq_len(nrow(benchmark))) {
  cat(
    benchmark$question_id[i],
    "|",
    benchmark[["Type"]][i],
    "|",
    benchmark[["NLQ"]][i],
    "\n"
  )
}


# ------------------------------------------------------------
# CLEAR ANY PRE-EXISTING SESSION LOG
# ------------------------------------------------------------

clear_query_log()


# ------------------------------------------------------------
# EXPERIMENTAL CAPTURE STORAGE
# ------------------------------------------------------------

raw_results <- list()
counter <- 1


# ------------------------------------------------------------
# MAIN CAPTURE LOOP
# ------------------------------------------------------------

for (i in seq_len(nrow(benchmark))) {
  
  question_id <- benchmark$question_id[i]
  user_query <- benchmark[["NLQ"]][i]
  
  for (run_id in seq_len(N_RUNS)) {
    
    cat(
      "\n-----------------------------------------\n"
    )
    
    cat(
      "Question:",
      question_id,
      "| Run:",
      run_id,
      "of",
      N_RUNS,
      "\n"
    )
    
    cat(
      "NLQ:",
      user_query,
      "\n"
    )
    
    # --------------------------------------------------------
    # EXECUTE THROUGH AUTHORITATIVE PRODUCTION LOGGER
    # --------------------------------------------------------
    #
    # 04_logging_pipeline.R owns:
    # - NL -> SQL -> DB execution
    # - end-to-end timing
    # - token capture
    # - model metadata
    # - PASS / FAIL logging
    #
    # 32_ deliberately does not duplicate this logic.
    # --------------------------------------------------------
    
    log_query_execution(
      user_query = user_query,
      con = con,
      verbose = TRUE
    )
    
    
    # --------------------------------------------------------
    # RETRIEVE OBSERVATION JUST PRODUCED
    # --------------------------------------------------------
    
    current_log <- get_query_log()
    
    if (is.null(current_log) || nrow(current_log) == 0) {
      stop(
        "Production logger did not return an observation for ",
        question_id,
        ", run ",
        run_id,
        "."
      )
    }
    
    observation <- current_log[
      nrow(current_log),
      ,
      drop = FALSE
    ]
    
    
    # --------------------------------------------------------
    # ATTACH EXPERIMENTAL PROVENANCE
    # --------------------------------------------------------
    #
    # These fields are known at execution time.
    # They must therefore be captured now rather than inferred
    # later from row order or timestamps.
    # --------------------------------------------------------
    
    observation$question_id <- question_id
    observation$run_id <- run_id
    observation$db_mode <- db_mode_used
    
    
    # --------------------------------------------------------
    # PLACE PROVENANCE FIELDS FIRST
    # --------------------------------------------------------
    
    observation <- observation[
      ,
      c(
        "question_id",
        "run_id",
        "db_mode",
        setdiff(
          names(observation),
          c(
            "question_id",
            "run_id",
            "db_mode"
          )
        )
      ),
      drop = FALSE
    ]
    
    
    # --------------------------------------------------------
    # STORE OBSERVATION
    # --------------------------------------------------------
    
    raw_results[[counter]] <- observation
    counter <- counter + 1
  }
}


# ------------------------------------------------------------
# COMBINE RAW OBSERVATIONS
# ------------------------------------------------------------

if (length(raw_results) == 0) {
  stop("No raw observations were captured.")
}

raw_capture <- do.call(
  rbind,
  raw_results
)

rownames(raw_capture) <- NULL


# ------------------------------------------------------------
# VALIDATE OBSERVATION COUNT
# ------------------------------------------------------------

if (nrow(raw_capture) != expected_observations) {
  stop(
    "Raw capture observation count mismatch. Expected ",
    expected_observations,
    " but captured ",
    nrow(raw_capture),
    "."
  )
}


# ------------------------------------------------------------
# VALIDATE EXPERIMENTAL PROVENANCE
# ------------------------------------------------------------

if (anyNA(raw_capture$question_id)) {
  stop("Missing question_id found in raw capture.")
}

if (anyNA(raw_capture$run_id)) {
  stop("Missing run_id found in raw capture.")
}

if (anyNA(raw_capture$db_mode)) {
  stop("Missing db_mode found in raw capture.")
}


# ------------------------------------------------------------
# VALIDATE QUESTION x RUN COMBINATIONS
# ------------------------------------------------------------

expected_keys <- expand.grid(
  question_id = benchmark$question_id,
  run_id = seq_len(N_RUNS),
  stringsAsFactors = FALSE
)

observed_keys <- raw_capture[
  ,
  c(
    "question_id",
    "run_id"
  ),
  drop = FALSE
]

if (anyDuplicated(observed_keys)) {
  stop(
    "Duplicate question_id/run_id combinations found."
  )
}

expected_key_strings <- paste(
  expected_keys$question_id,
  expected_keys$run_id,
  sep = "::"
)

observed_key_strings <- paste(
  observed_keys$question_id,
  observed_keys$run_id,
  sep = "::"
)

missing_keys <- setdiff(
  expected_key_strings,
  observed_key_strings
)

if (length(missing_keys) > 0) {
  stop(
    "Missing question/run combinations: ",
    paste(missing_keys, collapse = ", ")
  )
}


# ------------------------------------------------------------
# VALIDATE PRODUCTION CONFIGURATION IN CAPTURE
# ------------------------------------------------------------

if (!all(raw_capture$db_mode == db_mode_used)) {
  stop(
    "Captured db_mode does not consistently match active DB_MODE."
  )
}

if (
  "model" %in% names(raw_capture) &&
  !all(raw_capture$model == model_used)
) {
  stop(
    "Captured model does not consistently match production model."
  )
}

if (
  "model_temperature" %in% names(raw_capture) &&
  !all(
    is.na(raw_capture$model_temperature) |
    raw_capture$model_temperature == temperature_used
  )
) {
  stop(
    "Captured temperature does not match production temperature."
  )
}


# ------------------------------------------------------------
# PREPARE RAW OUTPUT DIRECTORY
# ------------------------------------------------------------

dir.create(
  here("data", "raw"),
  recursive = TRUE,
  showWarnings = FALSE
)


# ------------------------------------------------------------
# BUILD RESEARCH OUTPUT FILE NAME
# ------------------------------------------------------------

model_safe <- gsub(
  "[^A-Za-z0-9._-]",
  "_",
  model_used
)

timestamp_tag <- format(
  Sys.time(),
  "%Y%m%d_%H%M%S"
)

output_file <- here(
  "data",
  "raw",
  paste0(
    "raw_capture_",
    model_safe,
    "_",
    db_mode_used,
    "_",
    timestamp_tag,
    ".rds"
  )
)


# ------------------------------------------------------------
# SAVE RAW RESEARCH CAPTURE
# ------------------------------------------------------------

saveRDS(
  raw_capture,
  file = output_file
)


# ------------------------------------------------------------
# VERIFY RAW RDS INTEGRITY
# ------------------------------------------------------------

if (!file.exists(output_file)) {
  stop(
    "Raw RDS file was not created: ",
    output_file
  )
}

verification_capture <- tryCatch(
  readRDS(output_file),
  error = function(e) {
    stop(
      "Raw RDS integrity check failed: ",
      e$message
    )
  }
)

if (!identical(raw_capture, verification_capture)) {
  stop(
    paste(
      "Raw RDS integrity check failed:",
      "saved data does not match captured data."
    )
  )
}

cat("✅ Raw RDS integrity verified\n")

rm(verification_capture)


# ------------------------------------------------------------
# FINAL REPORT
# ------------------------------------------------------------

cat("\n=========================================\n")
cat("RAW DATA CAPTURE COMPLETED\n")
cat("=========================================\n")

cat(
  "Model:",
  model_used,
  "\n"
)

cat(
  "Temperature:",
  temperature_used,
  "\n"
)

cat(
  "DB mode:",
  db_mode_used,
  "\n"
)

cat(
  "Questions:",
  nrow(benchmark),
  "\n"
)

cat(
  "Runs per question:",
  N_RUNS,
  "\n"
)

cat(
  "Observations:",
  nrow(raw_capture),
  "\n"
)

cat(
  "Saved:",
  output_file,
  "\n"
)

cat("=========================================\n")