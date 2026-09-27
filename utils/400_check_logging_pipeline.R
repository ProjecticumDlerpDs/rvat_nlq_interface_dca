# ------------------------------------------------------------
# 400_check_logging_pipeline.R
#
# PURPOSE
# -------
# Validate execution and in-memory logging for:
# - synthetic
# - full_gdb
#
# Checks:
# 1. Logging environment
# 2. Mode-specific query execution
# 3. Return structure
# 4. Log creation and structure
# 5. Status and model metadata
# 6. Execution timing
# 7. Multiple log entries
# 8. Log clearing
#
# Query execution itself is validated separately in
# 300_check_query_execution.R.
# ------------------------------------------------------------

library(DBI)
library(here)

source(here("R", "01_db_connection.R"))
source(here("R", "02_ollama_config.R"))
source(here("R", "03_query_execution.R"))
source(here("R", "04_logging_pipeline.R"))


cat("
=====================================
LOGGING PIPELINE CHECK
=====================================
")


# ------------------------------------------------------------
# 1. MODE, CONNECTION AND INITIAL LOG
# ------------------------------------------------------------

cat("\n[1] Checking logging environment\n")

if (!DB_MODE %in% c("synthetic", "full_gdb")) {
  stop("Unsupported DB_MODE: ", DB_MODE)
}

if (!exists("con") || !DBI::dbIsValid(con)) {
  stop("Database connection is not valid.")
}

clear_query_log()

if (!is.null(get_query_log())) {
  stop("Log was not empty after initialisation.")
}

cat("DB_MODE:", DB_MODE, "\n")
cat("Connection valid: TRUE\n")
cat("Initial log empty\n")


# ------------------------------------------------------------
# 2. MODE-SPECIFIC QUERY AND LOG
# ------------------------------------------------------------

cat("\n[2] Running logged query\n")

test_query <- "Select number of variants in NEK1"

if (DB_MODE == "synthetic") {
  
  expected_table <- "varInfo_synthetic"
  
} else {
  
  expected_table <- "varInfo"
}

res <- log_query_execution(
  test_query,
  con,
  verbose = FALSE
)

if (!is.null(res$error)) {
  stop(
    "Logged query failed: ",
    res$error
  )
}

cat("Generated SQL:\n")
print(res$sql)

cat("\nReturned data:\n")
print(res$data)


# ------------------------------------------------------------
# 3. RETURN STRUCTURE
# ------------------------------------------------------------

cat("\n[3] Validating return structure\n")

if (
  !is.list(res) ||
  !all(c("data", "sql", "error") %in% names(res))
) {
  stop(
    "log_query_execution() returned an unexpected structure."
  )
}

if (
  is.null(res$sql) ||
  length(res$sql) != 1 ||
  is.na(res$sql) ||
  !nzchar(res$sql)
) {
  stop("No usable SQL was returned.")
}

if (!grepl(
  expected_table,
  res$sql,
  fixed = TRUE
)) {
  stop(
    "Logged SQL does not reference expected table: ",
    expected_table
  )
}

cat(
  "Expected table:",
  expected_table,
  "\n"
)

cat("Return structure valid\n")


# ------------------------------------------------------------
# 4. LOG CREATION AND STRUCTURE
# ------------------------------------------------------------

cat("\n[4] Checking log entry\n")

log_df <- get_query_log()

if (
  is.null(log_df) ||
  nrow(log_df) != 1
) {
  stop(
    "Expected exactly one log entry."
  )
}

expected_cols <- c(
  "timestamp",
  "user_query",
  "sql_query",
  "rows_returned",
  "result_preview",
  "status",
  "error_message",
  "model",
  "model_parameters",
  "model_capability",
  "model_temperature",
  "time_total_sec"
)

missing_cols <- setdiff(
  expected_cols,
  colnames(log_df)
)

if (length(missing_cols) > 0) {
  stop(
    "Missing log column(s): ",
    paste(missing_cols, collapse = ", ")
  )
}

cat("Log structure valid\n")


# ------------------------------------------------------------
# 5. STATUS AND MODEL METADATA
# ------------------------------------------------------------

cat("\n[5] Checking status and model metadata\n")

if (log_df$status[1] != "PASS") {
  stop(
    "Expected PASS log status, received: ",
    log_df$status[1]
  )
}

if (log_df$user_query[1] != test_query) {
  stop("Logged user query does not match input.")
}

if (log_df$sql_query[1] != res$sql) {
  stop("Logged SQL does not match returned SQL.")
}

if (
  is.na(log_df$model[1]) ||
  log_df$model[1] != model_name
) {
  stop(
    "Logged model does not match configured model."
  )
}

cat("Status: PASS\n")
cat("Model:", log_df$model[1], "\n")
cat("Model capability:", log_df$model_capability[1], "\n")
cat("Model temperature:", log_df$model_temperature[1], "\n")


# ------------------------------------------------------------
# 6. EXECUTION TIMING
# ------------------------------------------------------------

cat("\n[6] Checking execution timing\n")

if (
  is.na(log_df$time_total_sec[1]) ||
  log_df$time_total_sec[1] <= 0
) {
  stop("Invalid execution timing in log.")
}

cat(
  "Execution time:",
  round(log_df$time_total_sec[1], 2),
  "seconds\n"
)


# ------------------------------------------------------------
# 7. MULTIPLE LOG ENTRIES
# ------------------------------------------------------------

cat("\n[7] Testing multiple log entries\n")

queries <- c(
  "count rows",
  "show variants",
  "list genes"
)

for (q in queries) {
  
  tmp <- log_query_execution(
    q,
    con,
    verbose = FALSE
  )
  
  if (!is.null(tmp$error)) {
    stop(
      "Logged query failed: ",
      q,
      " | ",
      tmp$error
    )
  }
}

log_df_multi <- get_query_log()

expected_entries <- 1 + length(queries)

if (
  is.null(log_df_multi) ||
  nrow(log_df_multi) != expected_entries
) {
  stop(
    "Expected ",
    expected_entries,
    " log entries."
  )
}

if (any(log_df_multi$status != "PASS")) {
  stop(
    "One or more logged queries did not have PASS status."
  )
}

cat(
  "Log entries:",
  nrow(log_df_multi),
  "\n"
)

cat("Multiple-entry logging validated\n")


# ------------------------------------------------------------
# 8. CLEAR LOG
# ------------------------------------------------------------

cat("\n[8] Testing log clearing\n")

clear_query_log()

if (!is.null(get_query_log())) {
  stop("Log was not cleared successfully.")
}

cat("Log cleared successfully\n")


# ------------------------------------------------------------
# 9. FINAL STATUS AND CLEANUP
# ------------------------------------------------------------

cat("
=====================================
LOGGING PIPELINE CHECK PASSED
=====================================
")

cat("Mode:", DB_MODE, "\n")
cat("Model:", model_name, "\n")

close_connection()