# ------------------------------------------------------------
# 600_check_shiny_server.R
#
# PURPOSE
# -------
# Validate server integration for:
# - synthetic
# - full_gdb
#
# Checks:
# 1. Production pipeline and server load
# 2. Mode-specific query through the server's core pipeline
# 3. Result structure
# 4. Logging integration
# 5. full_gdb multi-table regression
# 6. RDS save and cleanup
#
# NOTE
# ----
# - Does not launch an interactive Shiny session
# - Validates the functions used by 06_shiny_server.R
# - Interactive UI behavior is validated separately by
# running the actual application
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

if (!is.null(res$error)) {
  stop(
    "Server-core query failed: ",
    res$error
  )
}

cat("Generated SQL:\n")
print(res$sql)

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
# 5. FULL_GDB MULTI-TABLE REGRESSION
# ------------------------------------------------------------

cat("\n[5] Checking mode-specific server behavior\n")

if (DB_MODE == "full_gdb") {
  
  test_query_multitable <-
    "How many samples occur in both SM and pheno?"
  
  res_multi <- log_query_execution(
    test_query_multitable,
    con,
    verbose = FALSE
  )
  
  if (!is.null(res_multi$error)) {
    stop(
      "Multi-table server test failed: ",
      res_multi$error
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
  
  cat("Generated multi-table SQL:\n")
  print(res_multi$sql)
  
  cat("\nReturned multi-table result:\n")
  print(res_multi$data)
  
  cat(
    "full_gdb multi-table regression passed\n"
  )
  
} else {
  
  cat(
    "Synthetic mode: multi-table regression skipped.\n"
  )
}


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