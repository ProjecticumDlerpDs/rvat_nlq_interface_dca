# ------------------------------------------------------------
# 300_check_query_execution.R
#
# PURPOSE
# -------
# Validate the NL -> SQL -> database execution layer for:
# - synthetic
# - full_gdb
#
# CHECKS:
# -------
# 1. Execution environment and database mode
# 2. Simple mode-specific NL query
# 3. Simple-query return structure, SQL, and data
# 4. Complex full_gdb NL query and execution outcome
# 5. Database error response
# 6. Multiple NL queries
# 7. Execution timing
#
# INTERPRETATION:
# ---------------
# - The simple query is a mandatory execution test.
# - The complex full_gdb query is observational:
#     * executable SQL is reported as SUCCESS
#     * non-executable SQL is reported as CONTROLLED FAILURE
# - A controlled SQL execution failure does not fail this
#   diagnostic if execute_query() correctly returns the SQL
#   and error information.
# - An unexpected return structure or R-level failure does fail
#   the diagnostic.
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
# 1. EXECUTION ENVIRONMENT
# ------------------------------------------------------------

cat("\n[1] Checking execution environment\n")

if (!DB_MODE %in% c("synthetic", "full_gdb")) {
  stop(
    "Unsupported DB_MODE: ",
    DB_MODE
  )
}

if (
  !exists("con") ||
  !DBI::dbIsValid(con)
) {
  stop(
    "Database connection is not valid."
  )
}

if (
  !exists("execute_query") ||
  !is.function(execute_query)
) {
  stop(
    "execute_query() is not available."
  )
}

cat("DB_MODE:", DB_MODE, "\n")
cat("Connection valid: TRUE\n")
cat("execute_query() available\n")


# ------------------------------------------------------------
# 2. SIMPLE MODE-SPECIFIC NL QUERY
# ------------------------------------------------------------

cat("\n[2] Running simple mode-specific NL query\n")

simple_query <- "Select number of variants in NEK1"

if (DB_MODE == "synthetic") {
  
  expected_table <- "varInfo_synthetic"
  
} else {
  
  expected_table <- "varInfo"
}

cat("Question:", simple_query, "\n")

simple_res <- execute_query(
  simple_query,
  con,
  verbose = FALSE
)


# ------------------------------------------------------------
# DISPLAY SIMPLE QUERY OUTPUT
# ------------------------------------------------------------

cat("\nGenerated SQL:\n")
cat("-------------------------------------\n")
print(simple_res$sql)
cat("-------------------------------------\n")

if (!is.null(simple_res$error)) {
  
  cat("\nExecution error:\n")
  cat(simple_res$error, "\n")
  
  stop(
    "Simple query execution failed. ",
    "See generated SQL above."
  )
}

cat("\nReturned data:\n")
print(simple_res$data)


# ------------------------------------------------------------
# 3. VALIDATE SIMPLE QUERY
# ------------------------------------------------------------

cat("\n[3] Validating simple-query result\n")


# ----------------------------------------------------------
# RETURN STRUCTURE
# ----------------------------------------------------------

if (
  !is.list(simple_res) ||
  !all(
    c("data", "sql", "error") %in%
    names(simple_res)
  )
) {
  stop(
    "execute_query() returned an unexpected structure."
  )
}


# ----------------------------------------------------------
# GENERATED SQL
# ----------------------------------------------------------

if (
  length(simple_res$sql) != 1 ||
  is.na(simple_res$sql) ||
  !nzchar(simple_res$sql)
) {
  stop(
    "Simple query returned no usable SQL."
  )
}

if (!grepl(
  "^SELECT\\b",
  trimws(simple_res$sql),
  ignore.case = TRUE
)) {
  stop(
    "Simple query did not generate a SELECT statement: ",
    simple_res$sql
  )
}

if (!grepl(
  expected_table,
  simple_res$sql,
  fixed = TRUE
)) {
  stop(
    "Simple-query SQL does not reference expected table: ",
    expected_table
  )
}


# ----------------------------------------------------------
# RETURNED DATA
# ----------------------------------------------------------

if (is.null(simple_res$data)) {
  stop(
    "Simple query returned NULL data."
  )
}

if (!is.data.frame(simple_res$data)) {
  stop(
    "Simple query result is not a data.frame."
  )
}

if (nrow(simple_res$data) == 0) {
  stop(
    "Simple query returned no rows."
  )
}


cat("Return structure valid\n")
cat("Expected table:", expected_table, "\n")
cat(
  "Rows returned:",
  nrow(simple_res$data),
  "\n"
)
cat("Simple query validation passed\n")


# ------------------------------------------------------------
# 4. COMPLEX FULL_GDB NL QUERY
# ------------------------------------------------------------

if (DB_MODE == "full_gdb") {
  
  cat("\n[4] Running complex full_gdb NL query\n")
  
  complex_query <- paste(
    "Which high-impact variants have at least one ALS patient",
    "that is homozygous for this variant?"
  )
  
  cat("Question:", complex_query, "\n")
  
  complex_res <- execute_query(
    complex_query,
    con,
    verbose = FALSE
  )
  
  
  # ----------------------------------------------------------
  # DISPLAY COMPLEX QUERY OUTPUT
  # ----------------------------------------------------------
  
  cat("\nGenerated SQL:\n")
  cat("-------------------------------------\n")
  print(complex_res$sql)
  cat("-------------------------------------\n")
  
  cat("\nReturned error:\n")
  print(complex_res$error)
  
  cat("\nReturned data:\n")
  print(complex_res$data)
  
  
  # ----------------------------------------------------------
  # VALIDATE RETURN CONTRACT
  # ----------------------------------------------------------
  
  if (
    !is.list(complex_res) ||
    !all(
      c("data", "sql", "error") %in%
      names(complex_res)
    )
  ) {
    stop(
      "Complex query returned an unexpected structure."
    )
  }
  
  
  # ----------------------------------------------------------
  # VALIDATE GENERATED SQL IS RETAINED
  # ----------------------------------------------------------
  
  if (
    is.null(complex_res$sql) ||
    length(complex_res$sql) != 1 ||
    is.na(complex_res$sql) ||
    !nzchar(complex_res$sql)
  ) {
    
    cat(
      "\nComplex-query execution outcome: ",
      "CONTROLLED SQL-GENERATION FAILURE\n",
      sep = ""
    )
    
    cat(
      "Error:",
      complex_res$error,
      "\n"
    )
    
  } else {
    
    cat(
      "\nGenerated SQL retained: TRUE\n"
    )
    
    
    # --------------------------------------------------------
    # REPORT EXECUTION OUTCOME
    # --------------------------------------------------------
    
    if (is.null(complex_res$error)) {
      
      cat(
        "Complex-query execution outcome: SUCCESS\n"
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
        "Complex-query execution outcome: ",
        "CONTROLLED FAILURE\n",
        sep = ""
      )
      
      cat(
        "Execution error:",
        complex_res$error,
        "\n"
      )
      
      cat(
        "Generated SQL and execution error were ",
        "returned by execute_query().\n",
        sep = ""
      )
    }
  }
  
} else {
  
  cat(
    "\n[4] Complex full_gdb NL query skipped ",
    "(DB_MODE = synthetic)\n",
    sep = ""
  )
}


# ------------------------------------------------------------
# 5. DATABASE ERROR RESPONSE
# ------------------------------------------------------------

cat("\n[5] Testing database error response\n")

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
    "Database error-response test unexpectedly succeeded."
  )
}

cat(
  "Database error response validated\n"
)


# ------------------------------------------------------------
# 6. MULTIPLE NL QUERY TEST
# ------------------------------------------------------------

cat("\n[6] Running multiple NL queries\n")

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
    
    cat("\nGenerated SQL:\n")
    print(tmp$sql)
    
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

cat(
  "Multiple-query test passed\n"
)


# ------------------------------------------------------------
# 7. EXECUTION TIMING
# ------------------------------------------------------------

cat("\n[7] Measuring execution time\n")

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
# 8. FINAL STATUS AND CLEANUP
# ------------------------------------------------------------

cat("
=====================================
QUERY EXECUTION CHECK PASSED
=====================================
")

cat("Mode:", DB_MODE, "\n")
cat("Model:", model_name, "\n")

close_connection()