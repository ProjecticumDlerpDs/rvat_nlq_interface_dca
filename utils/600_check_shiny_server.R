# ------------------------------------------------------------
# 600_check_shiny_server.R
#
# PURPOSE
# -------
# Validate the production functions and integration used by
# 06_shiny_server.R.
#
# CHECKS:
# -------
# 1. Production pipeline and server function load
# 2. Simple mode-specific query through the logging pipeline
# 3. Query return structure and result
# 4. Logging integration
# 5. full_gdb integration:
# - known multi-table query
# - complex query and execution outcome
# 6. RDS save and read-back
# 7. Test-state cleanup
#
# SCOPE:
# ------
# - Supports synthetic and full_gdb modes
# - Interactive server behaviour is validated by running the
# production application after this check passes
# ------------------------------------------------------------

library(shiny)
library(DT)
library(here)

cat("
=====================================
SHINY SERVER CHECK
=====================================
")


# ------------------------------------------------------------
# 1. LOAD PIPELINE
# ------------------------------------------------------------

cat("\n[1] Loading server pipeline\n")

source(here("R", "01_db_connection.R"))
source(here("R", "02_ollama_config.R"))
source(here("R", "03_query_execution.R"))
source(here("R", "04_logging_pipeline.R"))
source(here("R", "06_shiny_server.R"))

if (!DB_MODE %in% c("synthetic", "full_gdb")) {
  stop(
    "Unsupported DB_MODE: ",
    DB_MODE
  )
}

if (!exists("con") || !DBI::dbIsValid(con)) {
  stop(
    "Database connection is not valid."
  )
}

if (!exists("server") || !is.function(server)) {
  stop(
    "server function was not created by 06_shiny_server.R."
  )
}

if (
  !exists("log_query_execution") ||
  !is.function(log_query_execution)
) {
  stop(
    "log_query_execution() is not available."
  )
}

clear_query_log()

cat("DB_MODE:", DB_MODE, "\n")
cat("Pipeline loaded successfully\n")


# ------------------------------------------------------------
# 2. MODE-SPECIFIC SERVER CORE TEST
# ------------------------------------------------------------

cat("\n[2] Running server-core query\n")

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

cat("\nGenerated SQL:\n")
cat("-------------------------------------\n")
print(res$sql)
cat("-------------------------------------\n")

if (!is.null(res$error)) {
  cat("\nExecution error:\n")
  cat(res$error, "\n")
  stop(
    "Server-core query failed. ",
    "See generated SQL above."
  )
}

cat("\nReturned data:\n")
print(res$data)


# ------------------------------------------------------------
# 3. RESULT VALIDATION
# ------------------------------------------------------------

cat("\n[3] Validating result\n")

if (
  !is.list(res) ||
  !all(c("data", "sql", "error") %in% names(res))
) {
  stop(
    "Server-core query returned an unexpected structure."
  )
}

if (
  is.null(res$sql) ||
  length(res$sql) != 1 ||
  is.na(res$sql) ||
  !nzchar(res$sql)
) {
  stop(
    "Server-core query returned no usable SQL."
  )
}

if (!grepl(
  "^SELECT\\b",
  trimws(res$sql),
  ignore.case = TRUE
)) {
  stop(
    "Generated SQL is not a SELECT statement: ",
    res$sql
  )
}

if (!grepl(
  expected_table,
  res$sql,
  fixed = TRUE
)) {
  stop(
    "Generated SQL does not reference expected table: ",
    expected_table
  )
}

if (
  is.null(res$data) ||
  !is.data.frame(res$data) ||
  nrow(res$data) == 0
) {
  stop(
    "Server-core query returned no usable data."
  )
}

cat(
  "Expected table:",
  expected_table,
  "\n"
)

cat(
  "Rows returned:",
  nrow(res$data),
  "\n"
)

cat("Result validation passed\n")


# ------------------------------------------------------------
# 4. LOGGING INTEGRATION
# ------------------------------------------------------------

cat("\n[4] Validating logging integration\n")

log_df <- get_query_log()

if (
  is.null(log_df) ||
  nrow(log_df) != 1
) {
  stop(
    "Expected exactly one log entry after server-core test."
  )
}

expected_log_cols <- c(
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

missing_log_cols <- setdiff(
  expected_log_cols,
  names(log_df)
)

if (length(missing_log_cols) > 0) {
  stop(
    "Server log is missing column(s): ",
    paste(
      missing_log_cols,
      collapse = ", "
    )
  )
}

if (log_df$status[1] != "PASS") {
  stop(
    "Expected PASS log status, received: ",
    log_df$status[1]
  )
}

if (log_df$user_query[1] != test_query) {
  stop(
    "Logged user query does not match input."
  )
}

if (log_df$sql_query[1] != res$sql) {
  stop(
    "Logged SQL does not match returned SQL."
  )
}

cat("Logging integration passed\n")


# ------------------------------------------------------------
# 5. FULL_GDB TESTS
# ------------------------------------------------------------

cat("\n[5] Checking mode-specific server behavior\n")

if (DB_MODE == "full_gdb") {

# ----------------------------------------------------------
# 5A. KNOWN MULTI-TABLE QUERY
# ----------------------------------------------------------
  
  cat("\n[5A] Running known full_gdb multi-table query\n")  
  test_query_multitable <-
    "How many samples occur in both SM and pheno?"
  
  res_multi <- log_query_execution(
    test_query_multitable,
    con,
    verbose = FALSE
  )
  
  cat("\nGenerated multi-table SQL:\n")
  cat("-------------------------------------\n")
  print(res_multi$sql)
  cat("-------------------------------------\n")
  
  if (!is.null(res_multi$error)) {
    cat("\nExecution error:\n")
    cat(res_multi$error, "\n")
    stop(
      "Multi-table server test failed. ",
      "See generated SQL above."
    )
  }
  
  if (
    is.null(res_multi$sql) ||
    is.na(res_multi$sql) ||
    !nzchar(res_multi$sql)
  ) {
    stop(
      "Multi-table test returned no usable SQL."
    )
  }
  
  required_sql_terms <- c(
    "SM",
    "pheno",
    "IID"
  )
  
  missing_terms <- required_sql_terms[
    !vapply(
      required_sql_terms,
      function(x) {
        grepl(
          x,
          res_multi$sql,
          fixed = TRUE
        )
      },
      logical(1)
    )
  ]
  
  if (length(missing_terms) > 0) {
    stop(
      "Multi-table SQL is missing expected term(s): ",
      paste(
        missing_terms,
        collapse = ", "
      )
    )
  }
  
  if (
    is.null(res_multi$data) ||
    !is.data.frame(res_multi$data) ||
    nrow(res_multi$data) == 0
  ) {
    stop(
      "Multi-table query returned no usable data."
    )
  }
  
  
  cat("\nReturned multi-table result:\n")
  print(res_multi$data)
  
  cat(
    "full_gdb multi-table passed\n"
  )
  
} else {
  
  cat(
    "Synthetic mode: multi-table skipped.\n"
  )
}

if (DB_MODE == "full_gdb") {
  
  # ----------------------------------------------------------
  # 5A. KNOWN MULTI-TABLE QUERY
  # ----------------------------------------------------------
  
  cat("full_gdb multi-table passed\n")
  
  
  # ----------------------------------------------------------
  # 5B. COMPLEX FULL_GDB QUERY
  # ----------------------------------------------------------
  
  cat(
    "Complex-query log status:",
    complex_log_entry$status[1],
    "\n"
  )
  
} else {
  
  cat(
    "Synthetic mode: full_gdb integration tests skipped.\n"
  )
}

# --------------------------------------------------------
# DISPLAY COMPLEX QUERY OUTPUT
# --------------------------------------------------------

cat("\nGenerated complex-query SQL:\n")
cat("-------------------------------------\n")
print(complex_res$sql)
cat("-------------------------------------\n")
cat("\nReturned error:\n")
print(complex_res$error)
cat("\nReturned data:\n")
print(complex_res$data)

# --------------------------------------------------------
# VALIDATE RETURN CONTRACT
# --------------------------------------------------------
if (
  !is.list(complex_res) ||
  !all(
    c("data", "sql", "error") %in%
    names(complex_res)
  )
) {
  stop(
    "Complex server-core query returned an unexpected structure."
  )
}

# --------------------------------------------------------
# REPORT COMPLEX QUERY OUTCOME
# --------------------------------------------------------
if (
  is.null(complex_res$sql) ||
    length(complex_res$sql) != 1 ||
    is.na(complex_res$sql) ||
    !nzchar(complex_res$sql)
  ) {
  cat(
    "\nComplex-query outcome: ",
    "CONTROLLED SQL-GENERATION FAILURE\n",
    sep = ""
  )
  cat(
    "Error:",
    complex_res$error,
    "\n"
  )
} else if (is.null(complex_res$error)) {
  cat(
    "\nComplex-query outcome: SUCCESS\n"
  )
  cat(
    "Rows returned:",
    ifelse(
      is.null(complex_res$data),
      NA,
      nrow(complex_res$data)
    ),
    "\n"
  )
} else {
  cat(
    "\nComplex-query outcome: ",
    "CONTROLLED FAILURE\n",
    sep = ""
  )
  cat(
    "Execution error:",
    complex_res$error,
    "\n"
  )
  cat(
    "Generated SQL and execution error were retained ",
    "by the logging pipeline.\n",
    sep = ""
  )
}

# --------------------------------------------------------
# VALIDATE COMPLEX QUERY LOG ENTRY
# --------------------------------------------------------
complex_log <- get_query_log()
complex_log_entry <- complex_log[
 complex_log$user_query == complex_query,
   drop = FALSE
  ]
if (nrow(complex_log_entry) != 1) {
  stop(
    "Expected exactly one log entry for the complex query."
  )
}
if (is.null(complex_res$error)) {
  if (complex_log_entry$status[1] != "PASS") {
    stop(
      "Successful complex query was not logged as PASS."
    )
  }
} else {
  if (complex_log_entry$status[1] != "FAIL") {
    stop(
      "Failed complex query was not logged as FAIL."
    )
  }
  if (
    is.na(complex_log_entry$error_message[1]) ||
    !nzchar(complex_log_entry$error_message[1])
  ) {
    stop(
      "Complex-query failure was logged without an error message."
    )
  }
}
cat(
  "Complex-query log status:",
  complex_log_entry$status[1],
  "\n"
)

# ------------------------------------------------------------
# 6. RDS SAVE AND READ-BACK TEST
# ------------------------------------------------------------

cat("\n[6] Testing RDS save functionality\n")

log_df_save <- get_query_log()

if (
  is.null(log_df_save) ||
  nrow(log_df_save) == 0
) {
  stop(
    "No log data available for save test."
  )
}

output_dir <- here(
  "data",
  "raw"
)

dir.create(
  output_dir,
  recursive = TRUE,
  showWarnings = FALSE
)

filename <- here(
  "data",
  "raw",
  paste0(
    "test_log_",
    format(
      Sys.time(),
      "%Y%m%d_%H%M%S"
    ),
    ".rds"
  )
)

saveRDS(
  log_df_save,
  filename
)

if (!file.exists(filename)) {
  stop(
    "Failed to create RDS test file."
  )
}

saved_log <- readRDS(
  filename
)

if (
  !is.data.frame(saved_log) ||
  nrow(saved_log) != nrow(log_df_save)
) {
  stop(
    "Saved RDS content does not match log data."
  )
}

if (!identical(
  names(saved_log),
  names(log_df_save)
)) {
  stop(
    "Saved RDS column structure does not match log data."
  )
}

cat(
  "RDS save/read-back passed\n"
)


# ------------------------------------------------------------
# 7. CLEANUP
# ------------------------------------------------------------

cat("\n[7] Cleaning up test state\n")

removed <- file.remove(
  filename
)

if (
  !removed ||
  file.exists(filename)
) {
  stop(
    "Failed to remove RDS test file."
  )
}

clear_query_log()

if (!is.null(get_query_log())) {
  stop(
    "Query log was not cleared."
  )
}

cat("Cleanup passed\n")


# ------------------------------------------------------------
# 8. FINAL STATUS
# ------------------------------------------------------------

cat("
=====================================
SHINY SERVER CHECK PASSED
=====================================
")

cat("Mode:", DB_MODE, "\n")
cat("Model:", model_name, "\n")

close_connection()