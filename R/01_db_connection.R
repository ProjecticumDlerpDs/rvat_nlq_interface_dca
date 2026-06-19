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
# "multi"
#   - uses the full database (varInfo, var, pheno)
#   - allows joins and more complex queries
#
DB_MODE <- "synthetic"

# Optional override via environment variable:
# Sys.setenv(RVAT_DB_MODE = "multi")

env_mode <- Sys.getenv("RVAT_DB_MODE", unset = NA)
if (!is.na(env_mode)) DB_MODE <- tolower(env_mode)

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
  
  if (DB_MODE == "multi") {
    return(list(
      restriction = FALSE,
      tables = DBI::dbListTables(con)
    ))
  }
  
  stop("Invalid DB_MODE")
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
    message("Multi mode: using full database schema")
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
