# ------------------------------------------------------------
# 500_check_shiny_ui.R
#
# PURPOSE
# -------
# Validate Shiny UI structure for 05_shiny_ui.R
#
# This script checks:
# 1. UI loads without errors
# 2. UI object structure is valid
# 3. Required input IDs exist
# 4. Required output IDs exist
# 5. Markdown greeting file is accessible
#
# NOTE:
# -----
# - Static validation only (no server logic)
# - Uses structural traversal (robust)
# ------------------------------------------------------------

library(shiny)
library(bslib)
library(DT)

cat("
=====================================
 SHINY UI CHECK
=====================================
Starting validation...
")


# ------------------------------------------------------------
# 1. LOAD UI SCRIPT
# ------------------------------------------------------------

cat("\n[1] Loading UI script...\n")

source("R/05_shiny_ui.R")

if (!exists("ui")) {
  stop("❌ UI object not found after sourcing script")
}

cat("✅ UI object loaded\n")


# ------------------------------------------------------------
# 2. VALIDATE UI STRUCTURE
# ------------------------------------------------------------

cat("\n[2] Checking UI structure...\n")

ui_class <- class(ui)
print(ui_class)

if (!inherits(ui, "shiny.tag") && !inherits(ui, "shiny.tag.list")) {
  warning("⚠ UI is not a standard shiny.tag / shiny.tag.list object")
}

cat("✅ UI structure appears valid\n")


# ------------------------------------------------------------
# 3. HELPER: RECURSIVE ID EXTRACTION
# ------------------------------------------------------------

cat("\n[3] Extracting UI element IDs...\n")

find_ids <- function(x) {
  ids <- character()
  
  # Case 1: shiny tag
  if (inherits(x, "shiny.tag")) {
    
    if (!is.null(x$attribs$id)) {
      ids <- c(ids, x$attribs$id)
    }
    
    if (!is.null(x$children)) {
      for (child in x$children) {
        ids <- c(ids, find_ids(child))
      }
    }
  }
  
  # Case 2: list (compound UI objects)
  if (is.list(x)) {
    for (item in x) {
      ids <- c(ids, find_ids(item))
    }
  }
  
  return(ids)
}

ui_ids <- unique(find_ids(ui))

cat("Detected UI IDs:\n")
print(ui_ids)

cat("✅ ID extraction complete\n")


# ------------------------------------------------------------
# 4. VALIDATE REQUIRED INPUT IDs
# ------------------------------------------------------------

cat("\n[4] Checking required input components...\n")

required_inputs <- c(
  "user_query",
  "run_query",
  "save_chat"
)

missing_inputs <- setdiff(required_inputs, ui_ids)

if (length(missing_inputs) > 0) {
  stop("❌ Missing input IDs: ", paste(missing_inputs, collapse = ", "))
}

cat("✅ All input components present\n")


# ------------------------------------------------------------
# 5. VALIDATE REQUIRED OUTPUT IDs
# ------------------------------------------------------------

cat("\n[5] Checking required output components...\n")

required_outputs <- c(
  "sql",
  "table",
  "status"
)

missing_outputs <- setdiff(required_outputs, ui_ids)

if (length(missing_outputs) > 0) {
  stop("❌ Missing output IDs: ", paste(missing_outputs, collapse = ", "))
}

cat("✅ All output components present\n")


# ------------------------------------------------------------
# 6. CHECK GREETING MARKDOWN FILE
# ------------------------------------------------------------

cat("\n[6] Checking greeting markdown file...\n")

greeting_path <- "app/rvat_greeting.md"

if (!file.exists(greeting_path)) {
  stop("❌ Greeting file not found at: ", greeting_path)
}

cat("\nPreview of greeting (first 5 lines):\n")
cat("-------------------------------------\n")
cat(readLines(greeting_path, n = 5), sep = "\n")
cat("\n-------------------------------------\n")

cat("✅ Greeting file accessible\n")


# ------------------------------------------------------------
# 7. STATIC UI RENDER CHECK
# ------------------------------------------------------------

cat("\n[7] Testing UI render (static)...\n")

# Simply accessing/printing UI ensures no runtime construction errors
print(ui)

cat("✅ UI rendered without errors\n")


# ------------------------------------------------------------
# FINAL STATUS
# ------------------------------------------------------------

cat("
=====================================
 ✅ ALL CHECKS COMPLETED
=====================================
")