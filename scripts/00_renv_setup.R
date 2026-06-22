# ----------------------------------------
# renv setup script (for collaborators)
# ----------------------------------------

message("Starting project setup...\n")

# Install renv if not available
message("Checking 'renv' installation...")

if (!requireNamespace("renv", quietly = TRUE)) {
  message("→ 'renv' not found. Installing now...")
  install.packages("renv")
  message("'renv' successfully installed ✅\n")
} else {
  message("→ 'renv' already available ✅\n")
}

# Restore project environment
message("Restoring project environment (this may take a few minutes)...\n")

renv::restore()

message("\nEnvironment restore complete ✅")

# Optional: verify key packages load
required_pkgs <- c(
  "shiny", "dplyr", "DBI", "RSQLite", "querychat"
)

missing <- required_pkgs[!sapply(required_pkgs, requireNamespace, quietly = TRUE)]

if (length(missing) > 0) {
  warning("Some packages failed to install: ", paste(missing, collapse = ", "))
} else {
  message("All required packages are available ✅")
}

# Notes:
# - Installs all required packages with exact versions based on renv.lock
# - No manual installation required
#
# - You may see warnings like:
#     "packages out of sync [lockfile != library]"
#   for packages such as 'mgcv' or 'lattice'.
#
#   These are base/recommended R packages that can vary slightly
#   depending on your R version and operating system.
#   ✅ This is expected and NOT a problem if the application runs correctly.

message("\nEnvironment setup complete ✅")
message("Next step: run source('app/rvat_nlq_app.R') to start the application 🚀")