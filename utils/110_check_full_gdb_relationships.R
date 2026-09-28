# ------------------------------------------------------------
# 110_check_full_gdb_relationships.R
#
# PURPOSE
# -------
# Validate the schema and relationship definitions used by
# full_gdb production mode.
#
# CHECKS:
# -------
# 1. full_gdb mode and database connection
# 2. Required production tables
# 3. Table schemas and primary keys
# 4. Declared foreign keys and indexes
# 5. Required relationship columns
# 6. Production relationship definitions
# 7. Table row counts
# 8. Absence of a direct dosage/pheno relational key
#
# SCOPE:
# ------
# - full_gdb only
# - Read-only
# - Does not call Ollama
# - Does not modify database schema or data
# ------------------------------------------------------------

library(DBI)
library(here)

source(here("R", "01_db_connection.R"))


cat("
=====================================
FULL_GDB RELATIONSHIP CHECK
=====================================
")


# ------------------------------------------------------------
# 1. MODE AND CONNECTION
# ------------------------------------------------------------

cat("\n[1] Checking full_gdb environment\n")

if (DB_MODE != "full_gdb") {
  stop(
    "110 requires DB_MODE = 'full_gdb'. ",
    "Current mode: ",
    DB_MODE
  )
}

if (!exists("con") || !DBI::dbIsValid(con)) {
  stop("Database connection is not valid.")
}

cat("DB_MODE: full_gdb\n")
cat("Connection valid: TRUE\n")


# ------------------------------------------------------------
# 2. REQUIRED TABLES
# ------------------------------------------------------------

cat("\n[2] Checking required tables\n")

tables <- DBI::dbListTables(con)

required_tables <- c(
  "varInfo",
  "var",
  "dosage",
  "pheno",
  "SM",
  "anno",
  "cohort",
  "meta",
  "var_ranges"
)

missing_tables <- setdiff(
  required_tables,
  tables
)

if (length(missing_tables) > 0) {
  stop(
    "Missing required full_gdb table(s): ",
    paste(missing_tables, collapse = ", ")
  )
}

cat(
  "Required tables present:",
  paste(required_tables, collapse = ", "),
  "\n"
)

# Synthetic table may physically exist in the database,
# but is intentionally excluded from full_gdb production context.
if ("varInfo_synthetic" %in% tables) {
  cat(
    "Note: varInfo_synthetic exists but is not a ",
    "full_gdb production table.\n",
    sep = ""
  )
}


# ------------------------------------------------------------
# 3. SCHEMAS AND PRIMARY KEYS
# ------------------------------------------------------------

cat("\n[3] Inspecting schemas and primary keys\n")

schema_info <- list()

for (tbl in required_tables) {
  
  info <- DBI::dbGetQuery(
    con,
    paste0(
      "PRAGMA table_info(",
      DBI::dbQuoteIdentifier(con, tbl),
      ")"
    )
  )
  
  if (nrow(info) == 0) {
    stop(
      "No schema information returned for table: ",
      tbl
    )
  }
  
  schema_info[[tbl]] <- info
  
  pk_cols <- info$name[
    !is.na(info$pk) & info$pk > 0
  ]
  
  cat(
    "\nTable:",
    tbl,
    "\nColumns:",
    paste(info$name, collapse = ", "),
    "\n"
  )
  
  cat(
    "Primary key(s):",
    if (
      length(pk_cols) == 0
    ) {
      "none declared"
    } else {
      paste(pk_cols, collapse = ", ")
    },
    "\n"
  )
}


# ------------------------------------------------------------
# 4. DECLARED FOREIGN KEYS AND INDEXES
# ------------------------------------------------------------

cat("\n[4] Checking foreign keys and indexes\n")

foreign_keys_found <- FALSE

for (tbl in required_tables) {
  
  fk <- DBI::dbGetQuery(
    con,
    paste0(
      "PRAGMA foreign_key_list(",
      DBI::dbQuoteIdentifier(con, tbl),
      ")"
    )
  )
  
  if (nrow(fk) > 0) {
    foreign_keys_found <- TRUE
    cat("\nForeign keys for", tbl, ":\n")
    print(fk)
  }
}

if (!foreign_keys_found) {
  cat("No explicit SQLite foreign keys declared.\n")
}

for (tbl in required_tables) {
  
  idx <- DBI::dbGetQuery(
    con,
    paste0(
      "PRAGMA index_list(",
      DBI::dbQuoteIdentifier(con, tbl),
      ")"
    )
  )
  
  if (nrow(idx) > 0) {
    cat("\nIndexes for", tbl, ":\n")
    print(idx)
  }
}


# ------------------------------------------------------------
# 5. REQUIRED JOIN COLUMNS
# ------------------------------------------------------------

cat("\n[5] Checking required join columns\n")

required_columns <- list(
  varInfo = c("VAR_id"),
  var = c("VAR_id"),
  dosage = c("VAR_id", "GT"),
  SM = c("IID"),
  pheno = c("IID")
)

for (tbl in names(required_columns)) {
  
  fields <- DBI::dbListFields(
    con,
    tbl
  )
  
  missing_columns <- setdiff(
    required_columns[[tbl]],
    fields
  )
  
  if (length(missing_columns) > 0) {
    stop(
      "Table ",
      tbl,
      " is missing required column(s): ",
      paste(missing_columns, collapse = ", ")
    )
  }
  
  cat(
    tbl,
    ":",
    paste(required_columns[[tbl]], collapse = ", "),
    "\n"
  )
}


# ------------------------------------------------------------
# 6. KNOWN PRODUCTION RELATIONSHIPS
# ------------------------------------------------------------

cat("\n[6] Checking production relationship columns\n")

relationships <- data.frame(
  left_table = c(
    "varInfo",
    "varInfo",
    "var",
    "SM"
  ),
  left_column = c(
    "VAR_id",
    "VAR_id",
    "VAR_id",
    "IID"
  ),
  right_table = c(
    "var",
    "dosage",
    "dosage",
    "pheno"
  ),
  right_column = c(
    "VAR_id",
    "VAR_id",
    "VAR_id",
    "IID"
  ),
  stringsAsFactors = FALSE
)

for (i in seq_len(nrow(relationships))) {
  
  rel <- relationships[i, ]
  
  left_fields <- DBI::dbListFields(
    con,
    rel$left_table
  )
  
  right_fields <- DBI::dbListFields(
    con,
    rel$right_table
  )
  
  if (
    !rel$left_column %in% left_fields ||
    !rel$right_column %in% right_fields
  ) {
    stop(
      "Required relationship is not supported by schema: ",
      rel$left_table,
      ".",
      rel$left_column,
      " = ",
      rel$right_table,
      ".",
      rel$right_column
    )
  }
  
  cat(
    rel$left_table,
    ".",
    rel$left_column,
    " = ",
    rel$right_table,
    ".",
    rel$right_column,
    "\n",
    sep = ""
  )
}


# ------------------------------------------------------------
# 7. TABLE ROW COUNTS
# ------------------------------------------------------------

cat("\n[7] Checking table row counts\n")

row_counts <- data.frame(
  table = required_tables,
  rows = NA_real_,
  stringsAsFactors = FALSE
)

for (i in seq_along(required_tables)) {
  
  tbl <- required_tables[i]
  
  quoted_table <- DBI::dbQuoteIdentifier(
    con,
    tbl
  )
  
  row_counts$rows[i] <- DBI::dbGetQuery(
    con,
    paste0(
      "SELECT COUNT(*) AS n FROM ",
      quoted_table
    )
  )$n[1]
}

print(row_counts)

if (any(is.na(row_counts$rows))) {
  stop("One or more table row counts could not be determined.")
}


# ------------------------------------------------------------
# 8. FULL_GDB SAFETY BOUNDARY
# ------------------------------------------------------------

cat("\n[8] Checking relationship safety boundary\n")

dosage_fields <- DBI::dbListFields(
  con,
  "dosage"
)

pheno_fields <- DBI::dbListFields(
  con,
  "pheno"
)

shared_dosage_pheno_columns <- intersect(
  dosage_fields,
  pheno_fields
)

if (length(shared_dosage_pheno_columns) == 0) {
  
  cat(
    "No shared column name exists between dosage ",
    "and pheno.\n",
    sep = ""
  )
  
  cat(
    "No direct dosage <-> pheno relationship is defined ",
    "in the production relationship context.\n",
    sep = ""
  )
  
} else {
  
  cat(
    "WARNING: dosage and pheno share column(s): ",
    paste(
      shared_dosage_pheno_columns,
      collapse = ", "
    ),
    "\n"
  )
}


# ------------------------------------------------------------
# 9. FINAL STATUS AND CLEANUP
# ------------------------------------------------------------

cat("
=====================================
FULL_GDB RELATIONSHIP CHECK PASSED
=====================================
")

cat("Tables validated:", length(required_tables), "\n")
cat(
  "Relationship definitions checked:",
  nrow(relationships),
  "\n"
)

close_connection()