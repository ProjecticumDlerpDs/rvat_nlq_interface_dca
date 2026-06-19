# ------------------------------------------------------------
# checks_troubleshooting_scripts.R
# Purpose: Validate database connection and schema
# ------------------------------------------------------------

source("R/01_db_connection.R")

cat("
=====================================
 RVAT DATABASE CHECK
=====================================
Starting validation...
")


# ------------------------------------------------------------
# 1. Check connection validity
# ------------------------------------------------------------
cat("Checking connection...\n")
print(DBI::dbIsValid(con))

# ------------------------------------------------------------
# 2. List available tables
# ------------------------------------------------------------
cat("\nAvailable tables:\n")
print(DBI::dbListTables(con))

# ------------------------------------------------------------
# 3. Check active table
# ------------------------------------------------------------
active_table <- get_active_table()
cat("\nActive table:", active_table, "\n")

# ------------------------------------------------------------
# 4. Inspect schema
# ------------------------------------------------------------
cat("\nSchema preview:\n")
schema <- DBI::dbGetQuery(con, paste0(
  "PRAGMA table_info(", active_table, ")"
))
print(schema)

# ------------------------------------------------------------
# 5. Run simple query
# ------------------------------------------------------------
cat("\nRunning test query...\n")

test_query <- paste0("
  SELECT *
  FROM ", active_table, "
  LIMIT 5
")

result <- tryCatch({
  DBI::dbGetQuery(con, test_query)
}, error = function(e) {
  cat("ERROR:", e$message, "\n")
  return(NULL)
})

print(result)

# ------------------------------------------------------------
# 6. Aggregation sanity check
# ------------------------------------------------------------
cat("\nRunning aggregation test...\n")

agg_query <- paste0("
  SELECT gene_name, COUNT(*) as n
  FROM ", active_table, "
  GROUP BY gene_name
  LIMIT 5
")

agg_result <- tryCatch({
  DBI::dbGetQuery(con, agg_query)
}, error = function(e) {
  cat("ERROR:", e$message, "\n")
  return(NULL)
})

print(agg_result)

# ------------------------------------------------------------
# 7. Performance check
# ------------------------------------------------------------
cat("\nRunning performance timing...\n")

time <- system.time({
  DBI::dbGetQuery(con, paste0("
    SELECT COUNT(*) FROM ", active_table
  ))
})

print(time)

cat("\n✅ All checks completed.\n")
