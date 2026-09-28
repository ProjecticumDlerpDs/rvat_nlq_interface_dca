# ------------------------------------------------------------
# 01_db_connection.R
#
# PURPOSE
# -------
# Configure database access for the RVAT NL -> SQL pipeline.
#
# RESPONSIBILITIES:
# -----------------
# - Resolve the active database mode:
# * synthetic
# * full_gdb
# - Connect to the RVAT SQLite database supplied by rvatData
# - Invoke mode-specific preparation through
# scripts/10_data_preparation.R
# - Provide the active database context used by downstream
# pipeline components
# - Provide controlled database connection cleanup
#
# DATABASE MODES:
# ---------------
# synthetic
# - prepares/uses varInfo_synthetic
# - restricts the active context to that table
# - intended for smaller, controlled NL -> SQL queries
#
# full_gdb
# - uses the full RVAT database connection
# - does not create or restrict the full database context
# - exposes available tables through get_active_context()
# - table/relationship restrictions presented to the LLM are
# defined separately in 02_ollama_config.R
#
# CONFIGURATION:
# --------------
# - DB_MODE_DEFAULT defines the repository default
# - RVAT_DB_MODE can override the default at runtime
#
# DESIGN:
# -------
# - Database connection and context only
# - No LLM logic
# - No SQL-generation logic
# - No query-execution logic
# - No logging logic
# - No Shiny/UI logic
#
# USED BY:
# --------
# - 02_ollama_config.R
# - 03_query_execution.R
# - production Shiny application
# - diagnostic /utils scripts
#
# DEPENDENCIES:
# -------------
# - rvat
# - rvatData
# - DBI / RSQLite
# - scripts/10_data_preparation.R
# ------------------------------------------------------------

library(DBI)
library(RSQLite)
library(rvat)
library(rvatData)
library(here)

# ------------------------------------------------------------
# USER CONFIGURATION
# ------------------------------------------------------------

# ✅ Choose how the database is used:
#
# "synthetic"
# - Creates 'varInfo_synthetic' if it does not exist
# - Based on reproducible R-based augmentation of 'varInfo'
# - Uses a fixed random seed during synthetic data generation
# 
#
# "full_gdb"
# - Uses the full database as-is
# - Performs no schema or data modifications
#
#
# ------------------------------------------------------------
# DEFAULT MODE (CHANGE FOR PRODUCTION)
# ------------------------------------------------------------

# Development default:
# DB_MODE_DEFAULT <- "synthetic"

# 👉 For production, switch to:
DB_MODE_DEFAULT <- "full_gdb"

# ------------------------------------------------------------
# RESOLVE DB MODE
# ------------------------------------------------------------

# 1. Start with repository default
DB_MODE <- DB_MODE_DEFAULT

# 2. Override via environment variable if explicitly set
env_mode <- Sys.getenv("RVAT_DB_MODE", unset = NA_character_)

if (!is.na(env_mode) && nzchar(env_mode)) {
  DB_MODE <- tolower(env_mode)
}

# 3. Validate resolved mode
if (!DB_MODE %in% c("synthetic", "full_gdb")) {
  stop(
    "Invalid DB_MODE: ",
    DB_MODE,
    ". Use 'synthetic' or 'full_gdb'."
  )
}

# 4. Log resolved mode
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

con <- DBI::dbConnect(
  RSQLite::SQLite(),
  gdbpath
)

if (!DBI::dbIsValid(con)) {
  stop("Invalid database connection.")
}

# ------------------------------------------------------------
# PREPARE DATABASE (IMPORTANT STEP)
# ------------------------------------------------------------

# ✅ This loads the preparation logic
source(here("scripts", "10_data_preparation.R"))

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

# OPTIONAL SYNTHETIC-MODE HELPER
#
# Creates a temporary active_varInfo view when explicitly called.
# The current production pipeline does not require this function.
# Retained as an optional helper for compatible downstream usage.
#
#
# create_active_view <- function() {
#   
#   ctx <- get_active_context()
#   
#   if (ctx$restriction) {
#     
#     DBI::dbExecute(con, "DROP VIEW IF EXISTS active_varInfo")
#     
#     DBI::dbExecute(con, paste0("
#       CREATE TEMP VIEW active_varInfo AS
#       SELECT * FROM ", ctx$table
#     ))
#     
#   } else {
#     message("full_gdb mode: using full database schema")
#   }
# }

# ------------------------------------------------------------
# CONNECTION CLEANUP
# ------------------------------------------------------------
#
# Safely closes the active database connection.
#
# - Not executed automatically
# - Utility/diagnostic scripts should call this function when
# database access is complete
# - The current Shiny application manages a connection created
# during application initialization; session-level connection
# cleanup is not implemented here
#
# NOTE:
# Do not attach per-session cleanup without first reviewing
# connection scope, because 'con' is created at application
# initialization rather than inside individual Shiny sessions.
# ------------------------------------------------------------

close_connection <- function() {
  if (dbIsValid(con)) {
    dbDisconnect(con)
    message("✅ Database connection closed.")
  }
}
