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