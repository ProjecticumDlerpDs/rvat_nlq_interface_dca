# ----------------------------------------
# renv setup script (for collaborators)
# ----------------------------------------

message("========================================")
message("RVAT NLQ Project - Environment Setup")
message("========================================\n")

# ------------------------------------------------------------
# Check renv installation
# ------------------------------------------------------------

message("Checking 'renv' installation...")

if (!requireNamespace("renv", quietly = TRUE)) {
  message("→ 'renv' not found. Installing now...")
  install.packages("renv")
  message("→ 'renv' installed successfully ✅\n")
} else {
  message("→ 'renv' already available ✅\n")
}

# ------------------------------------------------------------
# Ensure Bioconductor support (required for some packages)
# ------------------------------------------------------------

message("Checking 'BiocManager' (Bioconductor support)...")

if (!requireNamespace("BiocManager", quietly = TRUE)) {
  message("→ 'BiocManager' not found. Installing now...")
  install.packages("BiocManager")
  message("→ 'BiocManager' installed ✅\n")
} else {
  message("→ 'BiocManager' already available ✅\n")
}

# Set Bioconductor version (adjust if needed)
options(renv.bioconductor.version = "3.22")

# Prevent interactive prompts during restore
options(renv.consent = TRUE)

# ------------------------------------------------------------
# Restore environment
# ------------------------------------------------------------

message("Restoring project environment (this may take several minutes)...")
message("Installing required R and Bioconductor packages...\n")

message("During this process, you may see:")
message("- Package download and installation logs")
message("- A message about GitHub credentials (this can be ignored ✅)")
message("- Compilation messages (this is normal)\n")

message("Please wait until the process completes...\n")

renv::restore()


# ------------------------------------------------------------
# Post-restore checks
# ------------------------------------------------------------

message("\nVerifying required packages...\n")

required_pkgs <- c(
  "shiny", "dplyr", "DBI", "RSQLite", "querychat"
)

missing <- required_pkgs[
  !sapply(required_pkgs, requireNamespace, quietly = TRUE)
]

if (length(missing) > 0) {
  warning("⚠ Some packages failed to install: ",
          paste(missing, collapse = ", "))
} else {
  message("All required packages are available ✅")
}

# ------------------------------------------------------------
# Notes for users
# ------------------------------------------------------------

message("\nNotes:")
message("- Minor warnings about package versions (e.g. 'mgcv', 'lattice') are normal")
message("- These depend on your R version and are usually safe to ignore")
message("- If critical packages fail to install, please check system requirements\n")

# ------------------------------------------------------------
# Completion
# ------------------------------------------------------------

message("========================================")
message("Environment setup complete ✅")
message("Next step:")
message("→ Run source('app/rvat_nlq_app.R') to start the application 🚀")
message("========================================")