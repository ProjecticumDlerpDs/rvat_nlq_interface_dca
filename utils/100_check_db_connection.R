# ------------------------------------------------------------
# 100_check_db_connection.R
#
# PURPOSE
# -------
# Validate basic database access for both supported modes:
# - synthetic
# - full_gdb
#
# Checks:
# 1. Resolved database mode
# 2. Database connection
# 3. Available tables
# 4. Active database context
# 5. Diagnostic table and schema
# 6. Basic SELECT query
# 7. Basic COUNT query and timing
#
# Detailed full_gdb schema and relationship checks are handled
# by 110_check_full_gdb_relationships.R.
# ------------------------------------------------------------

library(here)

source(here("R", "01_db_connection.R"))


# ------------------------------------------------------------
# 1. MODE AND CONNECTION
# ------------------------------------------------------------

cat("
=====================================
RVAT DATABASE CHECK
=====================================
")

cat("\n[1] Database mode and connection\n")
cat("DB_MODE:", DB_MODE, "\n")

if (!DB_MODE %in% c("synthetic", "full_gdb")) {
  stop("Unsupported DB_MODE: ", DB_MODE)
}

if (!exists("con") || !DBI::dbIsValid(con)) {
  stop("Database connection is not valid.")
}

cat("Connection valid: TRUE\n")


# ------------------------------------------------------------
# 2. AVAILABLE TABLES
# ------------------------------------------------------------

cat("\n[2] Available tables\n")

tables <- DBI::dbListTables(con)

if (length(tables) == 0) {
  stop("Database contains no accessible tables.")
}

print(tables)


# ------------------------------------------------------------
# 3. ACTIVE CONTEXT
# ------------------------------------------------------------

cat("\n[3] Active context\n")

ctx <- get_active_context()

str(ctx)


# ------------------------------------------------------------
# 4. MODE-SPECIFIC CONNECTION TEST TABLE
# ------------------------------------------------------------

cat("\n[4] Selecting table for basic read test\n")

if (DB_MODE == "synthetic") {
  
  if (
    is.null(ctx$table) ||
    length(ctx$table) != 1 ||
    !ctx$table %in% tables
  ) {
    stop(
      "Synthetic mode did not return a valid active table."
    )
  }
  
  connection_test_table <- ctx$table
  
} else if (DB_MODE == "full_gdb") {
  
  if (
    is.null(ctx$tables) ||
    length(ctx$tables) == 0
  ) {
    stop(
      "full_gdb mode did not return available tables."
    )
  }
  
  if (!"varInfo" %in% tables) {
    stop(
      "Expected connection test table 'varInfo' was not found."
    )
  }
  
  # varInfo is used only to verify that a normal table in
  # full_gdb can be read. It does not restrict full_gdb scope.
  connection_test_table <- "varInfo"
}

cat(
  "Table used for basic read test:",
  connection_test_table,
  "\n"
)

# ------------------------------------------------------------
# 5. SCHEMA ACCESS
# ------------------------------------------------------------

cat("\n[5] Checking schema access\n")

fields <- DBI::dbListFields(
  con,
  connection_test_table
)

if (length(fields) == 0) {
  stop(
    "No fields found in diagnostic table: ",
    connection_test_table
  )
}

cat("Number of fields:", length(fields), "\n")

print(fields)


# ------------------------------------------------------------
# 6. BASIC READ TEST
# ------------------------------------------------------------

cat("\n[6] Running basic SELECT test\n")

quoted_table <- DBI::dbQuoteIdentifier(
  con,
  connection_test_table
)

test_query <- paste0(
  "SELECT * FROM ",
  quoted_table,
  " LIMIT 5"
)

cat("SQL:", test_query, "\n")

result <- DBI::dbGetQuery(
  con,
  test_query
)

print(result)

cat(
  "Rows returned:",
  nrow(result),
  "\n"
)


# ------------------------------------------------------------
# 7. COUNT AND PERFORMANCE TEST
# ------------------------------------------------------------

cat("\n[7] Running COUNT test\n")

count_query <- paste0(
  "SELECT COUNT(*) AS n FROM ",
  quoted_table
)

count_result <- NULL

elapsed <- system.time({
  
  count_result <- DBI::dbGetQuery(
    con,
    count_query
  )
  
})

print(count_result)

cat(
  "Elapsed:",
  round(
    as.numeric(elapsed["elapsed"]),
    3
  ),
  "seconds\n"
)


# ------------------------------------------------------------
# 8. FINAL STATUS AND CLEANUP
# ------------------------------------------------------------

cat("
=====================================
DATABASE CHECK PASSED
=====================================
")

cat("Mode:", DB_MODE, "\n")
cat("Diagnostic table:", connection_test_table, "\n")
cat("Database tables:", length(tables), "\n")

close_connection()