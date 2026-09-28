# ------------------------------------------------------------
# 300_check_query_execution.R
#
# PURPOSE
# -------
# Validate the NL -> SQL -> database execution layer for:
# - synthetic
# - full_gdb
#
# Checks:
# 1. execute_query() availability
# 2. Mode-specific query execution
# 3. Return structure
# 4. Generated SQL
# 5. Returned data
# 6. Database error handling
# 7. Multiple NL queries
# 8. Execution timing
#
# Logging is tested separately in 400_check_logging_pipeline.R.
# ------------------------------------------------------------

library(DBI)
library(here)

source(here("R", "01_db_connection.R"))
source(here("R", "02_ollama_config.R"))
source(here("R", "03_query_execution.R"))


cat("
=====================================
QUERY EXECUTION CHECK
=====================================
")


# ------------------------------------------------------------
# 1. MODE, CONNECTION AND FUNCTION
# ------------------------------------------------------------

cat("\n[1] Checking execution environment\n")

if (!DB_MODE %in% c("synthetic", "full_gdb")) {
  stop("Unsupported DB_MODE: ", DB_MODE)
}

if (!exists("con") || !DBI::dbIsValid(con)) {
  stop("Database connection is not valid.")
}

if (!exists("execute_query") || !is.function(execute_query)) {
  stop("execute_query() is not available.")
}

cat("DB_MODE:", DB_MODE, "\n")
cat("Connection valid: TRUE\n")
cat("execute_query() available\n")


# ------------------------------------------------------------
# 2. MODE-SPECIFIC VALID QUERY
# ------------------------------------------------------------

cat("\n[2] Running valid NL query\n")

if (DB_MODE == "synthetic") {
  
  test_query <- "Select number of variants in NEK1"
  expected_table <- "varInfo_synthetic"
  
} else {
  
  test_query <- paste(
    "Which high-impact variants have at least one ALS patient",
    "that is homozygous for this variant?"
  )
  expected_table <- "varInfo"
}

res <- execute_query(
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
    "Query execution failed. See generated SQL above."
  )
}

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
    "execute_query() returned an unexpected structure."
  )
}

cat("Return structure valid\n")


# ------------------------------------------------------------
# 4. SQL VALIDATION
# ------------------------------------------------------------

cat("\n[4] Validating generated SQL\n")

if (
  length(res$sql) != 1 ||
  is.na(res$sql) ||
  !nzchar(res$sql)
) {
  stop("No usable SQL was returned.")
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

# if (!grepl(
#   expected_table,
#   res$sql,
#   fixed = TRUE
# )) {
#   stop(
#     "Generated SQL does not reference expected table: ",
#     expected_table
#   )
#}

cat(
  "Expected table:",
  expected_table,
  "\n"
)

cat("SQL validation passed\n")


# ------------------------------------------------------------
# 5. DATA VALIDATION
# ------------------------------------------------------------

cat("\n[5] Validating returned data\n")

if (is.null(res$data)) {
  stop("Query returned NULL data.")
}

if (!is.data.frame(res$data)) {
  stop("Query result is not a data.frame.")
}

if (nrow(res$data) == 0) {
  stop("Query returned no rows.")
}

cat(
  "Rows returned:",
  nrow(res$data),
  "\n"
)

cat("Data validation passed\n")


# ------------------------------------------------------------
# 6. DETERMINISTIC DATABASE ERROR TEST
# ------------------------------------------------------------

cat("\n[6] Testing database error handling\n")

bad_sql <- "SELECT * FROM table_that_does_not_exist"

error_captured <- tryCatch(
  {
    
    DBI::dbGetQuery(
      con,
      bad_sql
    )
    
    FALSE
    
  },
  error = function(e) {
    
    cat(
      "Expected database error captured:",
      e$message,
      "\n"
    )
    
    TRUE
  }
)

if (!error_captured) {
  stop(
    "Database error-handling test unexpectedly succeeded."
  )
}

cat("Database error handling validated\n")


# ------------------------------------------------------------
# 7. MULTIPLE NL QUERY TEST
# ------------------------------------------------------------

cat("\n[7] Running multiple NL queries\n")

queries <- c(
  "count rows",
  "list genes",
  "show variants"
)

for (q in queries) {
  
  tmp <- execute_query(
    q,
    con,
    verbose = FALSE
  )
  
  if (!is.null(tmp$error)) {
    stop(
      "Query failed: ",
      q,
      " | ",
      tmp$error
    )
  }
  
  if (
    is.null(tmp$sql) ||
    is.na(tmp$sql) ||
    !grepl(
      "^SELECT\\b",
      trimws(tmp$sql),
      ignore.case = TRUE
    )
  ) {
    stop(
      "Invalid SQL generated for query: ",
      q
    )
  }
  
  cat(
    "Query:",
    q,
    "| Rows:",
    ifelse(
      is.null(tmp$data),
      NA,
      nrow(tmp$data)
    ),
    "\n"
  )
}

cat("Multiple query test passed\n")


# ------------------------------------------------------------
# 8. PERFORMANCE CHECK
# ------------------------------------------------------------

cat("\n[8] Measuring execution time\n")

elapsed <- system.time({
  
  perf_result <- execute_query(
    "count rows",
    con,
    verbose = FALSE
  )
  
})

if (!is.null(perf_result$error)) {
  stop(
    "Performance query failed: ",
    perf_result$error
  )
}

cat(
  "Elapsed:",
  round(
    as.numeric(elapsed["elapsed"]),
    2
  ),
  "seconds\n"
)


# ------------------------------------------------------------
# 9. FINAL STATUS AND CLEANUP
# ------------------------------------------------------------

cat("
=====================================
QUERY EXECUTION CHECK PASSED
=====================================
")

cat("Mode:", DB_MODE, "\n")
cat("Model:", model_name, "\n")

close_connection()