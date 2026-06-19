# ------------------------------------------------------------
# 10_data_preparation.R
#
# PURPOSE
# -------
# Prepare the RVAT SQLite database for use in the application.
#
# This script is:
# ✅ Automatically called by R/01_db_connection.R
# ✅ Responsible for creating the synthetic dataset if needed
#
# USERS:
# ------
# You normally DO NOT need to run this script manually.
# It is executed automatically during database connection.
#
# MODES:
# ------
# "synthetic"
#   - Creates 'varInfo_synthetic' if it does not exist
#   - Based on R-based augmentation of 'varInfo'
#
# "multi"
#   - Uses full database as-is
#   - No modifications performed
#
# ------------------------------------------------------------

prepare_database <- function(con, mode = "synthetic") {
  
  # ----------------------------------------------------------
  # VALIDATION
  # ----------------------------------------------------------
  if (!mode %in% c("synthetic", "multi")) {
    stop("Invalid mode. Must be 'synthetic' or 'multi'.")
  }
  
  message("Preparing database (mode = ", mode, ")")
  
  # ----------------------------------------------------------
  # SYNTHETIC MODE → CREATE TABLE IF NEEDED
  # ----------------------------------------------------------
  if (mode == "synthetic") {
    
    tables <- DBI::dbListTables(con)
    
    # ✅ Check if already exists
    if ("varInfo_synthetic" %in% tables) {
      message("✅ varInfo_synthetic already exists — no action needed")
      return(invisible(TRUE))
    }
    
    message("⚙️ Creating varInfo_synthetic (R-based augmentation)...")
    
    # ---- STEP 1: READ BASE TABLE ----
    vi <- DBI::dbGetQuery(con, "SELECT * FROM varInfo")
    
    if (nrow(vi) == 0) {
      stop("varInfo table is empty — cannot create synthetic dataset")
    }
    
    # ---- STEP 2: GENERATE SYNTHETIC DATA ----
    set.seed(123)  # ✅ reproducibility
    
    n <- nrow(vi)
    
    geno_als <- replicate(5, sample(0:2, n, replace = TRUE))
    colnames(geno_als) <- paste0("ALS_", 1:5)
    
    geno_control <- replicate(5, sample(0:2, n, replace = TRUE))
    colnames(geno_control) <- paste0("Control_", 1:5)
    
    # ---- STEP 3: AUGMENT DATA ----
    vi_updated <- cbind(vi, geno_als, geno_control)
    
    # ---- STEP 4: WRITE TABLE ----
    DBI::dbWriteTable(
      con,
      "varInfo_synthetic",
      vi_updated,
      overwrite = TRUE
    )
    
    message("✅ varInfo_synthetic successfully created")
  }
  
  # ----------------------------------------------------------
  # MULTI MODE → NO MODIFICATIONS
  # ----------------------------------------------------------
  if (mode == "multi") {
    message("✅ Full database mode — no preparation required")
  }
  
  # ----------------------------------------------------------
  # FINAL VALIDATION
  # ----------------------------------------------------------
  # Helpful confirmation for debugging
  # (safe, lightweight, useful for reproducibility)
  
  tables <- DBI::dbListTables(con)
  
  message("Available tables: ", paste(tables, collapse = ", "))
  
  return(invisible(TRUE))
}