# ------------------------------------------------------------
# 01_db_connection.R
#
# PURPOSE
# -------
# This script:
# 1. Connects to the RVAT SQLite database (included via rvatData)
# 2. Optionally prepares a synthetic working dataset
# 3. Defines how the database is used in the app
#
# ✅ End users DO NOT need to manually download a database
# ✅ Everything is handled automatically
#
# ------------------------------------------------------------

library(DBI)
library(RSQLite)
library(rvat)
library(rvatData)

# ------------------------------------------------------------
# USER CONFIGURATION
# ------------------------------------------------------------

# ✅ Choose how the database is used:
#
# "synthetic" (DEFAULT)
#   - creates/uses a smaller, augmented dataset
#   - faster and more stable for NL→SQL queries
# 
#
# "full_gdb"
#   - uses the full RVAT geodatabase schema
#   - includes all tables available in the database (e.g. varInfo, var, pheno, anno, meta, dosage, etc.)
#   - allows complex queries and joins across multiple tables
#   - LLM prompting focuses on core tables (varInfo, var, pheno) but is not restricted to them
#
#
# ------------------------------------------------------------
# DEFAULT MODE (CHANGE FOR PRODUCTION)
# ------------------------------------------------------------

# Development default:
DB_MODE_DEFAULT <- "synthetic"

# 👉 For production, switch to:
# DB_MODE_DEFAULT <- "full_gdb"

# ------------------------------------------------------------
# RESOLVE DB MODE
# ------------------------------------------------------------

# 1. Start with default
DB_MODE <- DB_MODE_DEFAULT

# 2. Override via environment variable (if set)
env_mode <- Sys.getenv("RVAT_DB_MODE", unset = NA)

if (!is.na(env_mode) && nzchar(env_mode)) {
  DB_MODE <- tolower(env_mode)
}

# 3. LOG RESOLVED MODE
cat("✅ DB_MODE resolved to:", DB_MODE, "\n")


# ------------------------------------------------------------
# CONNECT TO DATABASE
# ------------------------------------------------------------

# ✅ The RVAT database is provided via rvatData
# No manual file download required

gdbpath <- rvat_example("rvatData.gdb")

if (!file.exists(gdbpath)) {
  stop("Database not found: ", gdbpath)
}

con <- DBI::dbConnect(SQLite(), gdbpath)

if (!dbIsValid(con)) stop("Invalid connection")

# ------------------------------------------------------------
# PREPARE DATABASE (IMPORTANT STEP)
# ------------------------------------------------------------

# ✅ This loads the preparation logic
source("scripts/10_data_preparation.R")

# ✅ This ensures the chosen mode is ready
# If DB_MODE = "synthetic":
#   → varInfo_synthetic is created automatically (if missing)
prepare_database(con, mode = DB_MODE)

# ------------------------------------------------------------
# CONTEXT (HOW THE DB IS USED)
# ------------------------------------------------------------

get_active_context <- function() {
  
  if (DB_MODE == "synthetic") {
    return(list(
      restriction = TRUE,
      table = "varInfo_synthetic"
    ))
  }
  
  if (DB_MODE == "full_gdb") {
    return(list(
      restriction = FALSE,
      tables = DBI::dbListTables(con)
    ))
  }
  
  stop("Invalid DB_MODE. Use 'synthetic' or 'full_gdb'")
}

# ------------------------------------------------------------
# OPTIONAL: VIEW FOR SIMPLER QUERIES
# ------------------------------------------------------------

# ✅ This creates a stable table name for the app / LLM
# Only used in synthetic mode
create_active_view <- function() {
  
  ctx <- get_active_context()
  
  if (ctx$restriction) {
    
    DBI::dbExecute(con, "DROP VIEW IF EXISTS active_varInfo")
    
    DBI::dbExecute(con, paste0("
      CREATE TEMP VIEW active_varInfo AS
      SELECT * FROM ", ctx$table
    ))
    
  } else {
    message("full_gdb mode: using full database schema")
  }
}

# ------------------------------------------------------------
# CLEANUP (IMPORTANT)
# ------------------------------------------------------------
# This function safely closes the database connection.
#
# ✅ Not executed automatically
# ✅ Should be called:
#    - at the end of scripts
#    - when stopping Shiny app
#
# Prevents:
#   - locked database files
#   - memory leaks
# ------------------------------------------------------------

close_connection <- function() {
  if (dbIsValid(con)) {
    dbDisconnect(con)
    message("✅ Database connection closed.")
  }
}


# ------------------------------------------------------------
# DEBUG / TROUBLESHOOTING (Optional)
# ------------------------------------------------------------
# These lines can be uncommented if something is not working
# as expected (e.g., missing tables, empty results).
#
# Not executed during normal app usage.

# Example 1: Check available tables
# DBI::dbListTables(con)

# Example 2: Preview active dataset
# ctx <- get_active_context()
# if (!is.null(ctx$table)) {
#   DBI::dbGetQuery(con, paste0(
#     "SELECT * FROM ", ctx$table, " LIMIT 5"
#   ))
# }
