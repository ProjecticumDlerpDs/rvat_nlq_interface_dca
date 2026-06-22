# ------------------------------------------------------------
# 600_check_shiny_server.R
#
# PURPOSE
# -------
# Validate server logic for 06 script loads# Validate server logic for 06_shiny_server.R
# 2. Required functions exist
# 3. Query execution via server pipeline
# 4. Logging integration works
# 5. Log saving works
#
# NOTE:
# -----
# - Does NOT run full Shiny app
# - Simulates server behavior
# ------------------------------------------------------------

library(shiny)
library(DT)
library(here)

cat("
=====================================
 SHINY SERVER CHECK
=====================================
Starting validation...
")

# ------------------------------------------------------------
# LOAD DEPENDENCIES
# ------------------------------------------------------------

cat("\n[1] Loading full pipeline...\n")

source(here("R", "01_db_connection.R"))
source(here("R", "02_ollama_config.R"))
source(here("R", "03_query_execution.R"))
source(here("R", "04_logging_pipeline.R"))
source(here("R", "06_shiny_server.R"))


# ------------------------------------------------------------
# VALIDATE DATABASE CONNECTION
# ------------------------------------------------------------

if (!exists("con")) {
  stop("Database connection object 'con' was not created.")
}

if (!DBI::dbIsValid(con)) {
  stop("Database connection exists but is not valid.")
}

cat("✅ Pipeline loaded\n")

# ------------------------------------------------------------
# CHECK SERVER FUNCTION
# ------------------------------------------------------------

cat("\n[2] Checking server function...\n")

if (!exists("server")) {
  stop("❌ server function not found")
}

print(typeof(server))

cat("✅ server function available\n")

# ------------------------------------------------------------
# SIMULATE PIPELINE THROUGH SERVER CORE
# ------------------------------------------------------------

cat("\n[3] Simulating server execution logic...\n")

test_query <- "show first 5 rows"

res <- tryCatch({
  log_query_execution(test_query, con, verbose = FALSE)
}, error = function(e) {
  stop("❌ Server pipeline execution failed: ", e$message)
})

cat("✅ Query executed via pipeline\n")

# ------------------------------------------------------------
# VALIDATE RESULT STRUCTURE
# ------------------------------------------------------------

cat("\n[4] Validating result structure...\n")

stopifnot(is.list(res))
stopifnot(all(c("data", "sql", "error") %in% names(res)))

print(res$sql)
print(head(res$data))
print(res$error)

cat("✅ Result structure valid\n")

# ------------------------------------------------------------
# VALIDATE LOGGING
# ------------------------------------------------------------

cat("\n[5] Validating logging layer...\n")

log_df <- get_query_log()

if (is.null(log_df) || nrow(log_df) == 0) {
  stop("❌ No log entries found")
}

print(log_df)

cat("✅ Logging working\n")

# ------------------------------------------------------------
# VALIDATE SAVE FUNCTIONALITY
# ------------------------------------------------------------

cat("\n[6] Testing save functionality...\n")

output_dir <- here("data", "raw")

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

filename <- here(
  "data",
  "raw",
  paste0("test_log_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".rds")
)

saveRDS(log_df, filename)

if (!file.exists(filename)) {
  stop("❌ Failed to save log file")
}

cat("Saved file:", filename, "\n")

cat("✅ Save functionality works\n")

# ------------------------------------------------------------
# CLEAN-UP TEST FILE
# ------------------------------------------------------------

cat("\n[7] Cleaning up test file...\n")

file.remove(filename)

cat("✅ Cleanup completed\n")

# ------------------------------------------------------------
# FINAL STATUS
# ------------------------------------------------------------

cat("
=====================================
 ✅ ALL CHECKS COMPLETED
=====================================
")
#
# This script checks:
