# ------------------------------------------------------------
# 400_check_logging_pipeline.R
#
# PURPOSE
# -------
# Validate NL → SQL execution + logging pipeline
#
# This script checks:
# 1. Full execution using log_query_execution()
# 2. Correct return structure (data, SQL, error)
# 3. Log storage (in-memory)
# 4. Log structure and fields
# 5. Model metadata capture
# 6. Timing (end-to-end latency)
#
# NOTE:
# -----
# - Troubleshooting / validation script
# - NOT part of production pipeline
# - Assumes execution layer is already validated (see 300_check_query_execution.R)
# ------------------------------------------------------------

library(DBI)
library(here)

# ------------------------------------------------------------
# LOAD PIPELINE COMPONENTS
# ------------------------------------------------------------

source(here("R", "01_db_connection.R"))
source(here("R", "02_ollama_config.R"))
source(here("R", "03_query_execution.R"))
source(here("R", "04_logging_pipeline.R"))

# ------------------------------------------------------------
# VALIDATE DATABASE CONNECTION
# ------------------------------------------------------------

if (!exists("con")) {
  stop("Database connection object 'con' was not created.")
}

if (!DBI::dbIsValid(con)) {
  stop("Database connection exists but is not valid.")
}

cat("
=====================================
 LOGGING PIPELINE CHECK
=====================================
Starting validation...
")

# ------------------------------------------------------------
# 1. INITIAL STATE CHECK
# ------------------------------------------------------------
cat("\n[1] Checking initial log state...\n")

print(get_query_log())

cat("✅ Initial log (expected NULL or empty)\n")

# ------------------------------------------------------------
# 2. RUN TEST QUERY
# ------------------------------------------------------------
cat("\n[2] Running test query...\n")

test_query <- "show first 5 rows"

res <- log_query_execution(test_query, con)

cat("\nReturned SQL:\n")
print(res$sql)

cat("\nReturned data preview:\n")
print(head(res$data))

cat("\nReturned error (if any):\n")
print(res$error)

cat("✅ Query execution completed\n")

# ------------------------------------------------------------
# 3. VALIDATE RETURN STRUCTURE
# ------------------------------------------------------------
cat("\n[3] Validating return structure...\n")

stopifnot(is.list(res))
stopifnot(all(c("data", "sql", "error") %in% names(res)))

cat("✅ Return structure valid\n")

# ------------------------------------------------------------
# 4. CHECK LOG STORAGE
# ------------------------------------------------------------
cat("\n[4] Checking in-memory log...\n")

log_df <- get_query_log()

print(log_df)

if (is.null(log_df)) {
  stop("❌ Log is NULL — expected at least one entry")
}

cat("✅ Log entry stored\n")

# ------------------------------------------------------------
# 5. VALIDATE LOG STRUCTURE
# ------------------------------------------------------------
cat("\n[5] Validating log structure...\n")

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

missing_cols <- setdiff(expected_cols, colnames(log_df))

if (length(missing_cols) > 0) {
  stop("❌ Missing columns: ", paste(missing_cols, collapse = ", "))
}

cat("✅ Log structure valid\n")

# ------------------------------------------------------------
# 6. VALIDATE METADATA
# ------------------------------------------------------------
cat("\n[6] Checking model metadata...\n")

print(log_df[, c(
  "model",
  "model_parameters",
  "model_capability",
  "model_temperature"
)])

cat("✅ Metadata present\n")

# ------------------------------------------------------------
# 7. VALIDATE TIMING
# ------------------------------------------------------------
cat("\n[7] Checking execution time...\n")

print(log_df$time_total_sec)

if (any(is.na(log_df$time_total_sec))) {
  stop("❌ Missing timing values")
}

if (any(log_df$time_total_sec <= 0)) {
  warning("⚠ Non-positive timing detected")
}

cat("✅ Timing values valid\n")

# ------------------------------------------------------------
# 8. MULTIPLE QUERY TEST
# ------------------------------------------------------------
cat("\n[8] Running multiple queries...\n")

queries <- c(
  "count rows",
  "show variants",
  "list genes"
)

for (q in queries) {
  log_query_execution(q, con, verbose = FALSE)
}

log_df_multi <- get_query_log()

cat("\nLog after multiple queries:\n")
print(log_df_multi)

cat("✅ Multiple entries recorded\n")

# ------------------------------------------------------------
# 9. CLEAR LOG TEST
# ------------------------------------------------------------
cat("\n[9] Testing log clearing...\n")

clear_query_log()

log_after_clear <- get_query_log()
print(log_after_clear)

cat("✅ Log cleared successfully\n")

# ------------------------------------------------------------
# FINAL STATUS
# ------------------------------------------------------------

cat("
=====================================
 ✅ ALL CHECKS COMPLETED
=====================================
")