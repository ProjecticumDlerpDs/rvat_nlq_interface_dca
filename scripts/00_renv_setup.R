# ----------------------------------------
# renv setup script (for collaborators)
# ----------------------------------------

# Install renv if not available
if (!requireNamespace("renv", quietly = TRUE)) {
  install.packages("renv")
}

# Restore project environment
renv::restore()

# Notes:
# - Installs all required packages with exact versions
# - Based on renv.lock
# - No manual install needed

# Optional: verify key packages load
required_pkgs <- c(
  "shiny", "dplyr", "DBI", "RSQLite", "querychat"
)

missing <- required_pkgs[!sapply(required_pkgs, requireNamespace, quietly = TRUE)]

if (length(missing) > 0) {
  warning("Some packages failed to install: ", paste(missing, collapse = ", "))
} else {
  message("Environment successfully restored ✅")
}