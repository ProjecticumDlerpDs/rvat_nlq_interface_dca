# ------------------------------------------------------------
# 300_check_query_execution.R
#
# PURPOSE
# -------
# Validate NL → SQL → DB execution layer
#
# This script checks:
# 1. SQL generation via execute_query()
# 2. SQL execution on database
# 3. Returned data structure
# 4. Error handling
#
# NOTE:
# -----
# - Troubleshooting / validation script
# - Tests execution engine ONLY (no logging layer)
# ------------------------------------------------------------

library(DBI)

# ------------------------------------------------------------
# LOAD COMPONENTS
# ------------------------------------------------------------

source("R/01_db_connection.R")
source("R/02_ollama_config.R")
source("R/03_query_execution.R")

cat("
=====================================
 QUERY EXECUTION CHECK
=====================================
Starting validation...
")

# ------------------------------------------------------------
# 1. FUNCTION AVAILABILITY
# ------------------------------------------------------------
cat("\n[1] Checking function availability...\n")

print(exists("execute_query"))

if (!exists("execute_query")) {
  stop("❌ execute_query() not found")
}

cat("✅ Function available\n")


# ------------------------------------------------------------
# 2. RUN VALID TEST QUERY
# ------------------------------------------------------------
cat("\n[2] Running valid test query...\n")

test_query <- "show first 5 rows"

res <- execute_query(test_query, con)

cat("\nGenerated SQL:\n")
print(res$sql)

cat("\nReturned data preview:\n")
print(head(res$data))

cat("\nError (if any):\n")
print(res$error)

cat("✅ Query executed\n")


# ------------------------------------------------------------
# 3. VALIDATE OUTPUT STRUCTURE
# ------------------------------------------------------------
cat("\n[3] Validating return structure...\n")

stopifnot(is.list(res))
stopifnot(all(c("data", "sql", "error") %in% names(res)))

cat("✅ Structure valid\n")


# ------------------------------------------------------------
# 4. VALIDATE SQL
# ------------------------------------------------------------
cat("\n[4] Checking SQL output...\n")

if (is.na(res$sql)) {
  stop("❌ SQL is NA")
}

if (!grepl("^SELECT", res$sql, ignore.case = TRUE)) {
  warning("⚠ SQL may not be a SELECT statement")
}

cat("✅ SQL looks valid\n")


# ------------------------------------------------------------
# 5. VALIDATE DATA OUTPUT
# ------------------------------------------------------------
cat("\n[5] Checking data output...\n")

if (!is.null(res$data)) {
  print(nrow(res$data))
  cat("✅ Data returned\n")
} else {
  warning("⚠ No data returned")
}


# ------------------------------------------------------------
# 6. ERROR HANDLING TEST
# ------------------------------------------------------------
cat("\n[6] Testing error handling...\n")

bad_query <- "this is not a valid query"

res_bad <- execute_query(bad_query, con)

print(res_bad$error)

if (is.null(res_bad$error)) {
  warning("⚠ Expected an error but none occurred")
} else {
  cat("✅ Error correctly handled\n")
}


# ------------------------------------------------------------
# 7. MULTIPLE QUICK RUNS
# ------------------------------------------------------------
cat("\n[7] Running multiple quick tests...\n")

queries <- c(
  "count rows",
  "list genes",
  "show variants"
)

for (q in queries) {
  tmp <- execute_query(q, con, verbose = FALSE)
  cat("\nQuery:", q, "\n")
  cat("Rows:", ifelse(is.null(tmp$data), NA, nrow(tmp$data)), "\n")
}

cat("✅ Multiple queries executed\n")


# ------------------------------------------------------------
# 8. PERFORMANCE CHECK
# ------------------------------------------------------------
cat("\n[8] Measuring execution time...\n")

time <- system.time({
  execute_query("count rows", con, verbose = FALSE)
})

cat("Elapsed time:", round(time["elapsed"], 2), "seconds\n")

cat("✅ Performance check completed\n")


# ------------------------------------------------------------
# FINAL STATUS
# ------------------------------------------------------------

cat("
=====================================
 ✅ ALL CHECKS COMPLETED
=====================================
")