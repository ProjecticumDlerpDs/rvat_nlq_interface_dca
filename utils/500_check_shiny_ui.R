# ------------------------------------------------------------
# 500_check_shiny_ui.R
#
# PURPOSE
# -------
# Validate the static Shiny UI defined in 05_shiny_ui.R.
#
# Checks:
# 1. UI loads successfully
# 2. UI structure is valid
# 3. Required input IDs exist
# 4. Required output IDs exist
# 5. Greeting markdown is available
# 6. UI can be rendered
#
# NOTE
# ----
# - Independent of database mode
# - Static UI validation only
# - Server behavior is tested in 600_check_shiny_server.R
# ------------------------------------------------------------

library(shiny)
library(bslib)
library(DT)
library(here)


cat("
=====================================
SHINY UI CHECK
=====================================
")


# ------------------------------------------------------------
# 1. LOAD UI
# ------------------------------------------------------------

cat("\n[1] Loading UI\n")

source(here("R", "05_shiny_ui.R"))

if (!exists("ui")) {
  stop(
    "UI object was not created by 05_shiny_ui.R."
  )
}

if (
  !inherits(ui, "shiny.tag") &&
  !inherits(ui, "shiny.tag.list")
) {
  stop(
    "UI is not a valid shiny.tag or shiny.tag.list object."
  )
}

cat(
  "UI loaded:",
  paste(class(ui), collapse = ", "),
  "\n"
)


# ------------------------------------------------------------
# 2. EXTRACT UI IDS
# ------------------------------------------------------------

cat("\n[2] Extracting UI element IDs\n")

find_ids <- function(x) {
  
  ids <- character()
  
  if (inherits(x, "shiny.tag")) {
    
    if (!is.null(x$attribs$id)) {
      ids <- c(
        ids,
        x$attribs$id
      )
    }
    
    if (!is.null(x$children)) {
      
      for (child in x$children) {
        ids <- c(
          ids,
          find_ids(child)
        )
      }
    }
  }
  
  if (is.list(x)) {
    
    for (item in x) {
      ids <- c(
        ids,
        find_ids(item)
      )
    }
  }
  
  unique(ids)
}

ui_ids <- unique(
  find_ids(ui)
)

if (length(ui_ids) == 0) {
  stop("No UI element IDs were detected.")
}

print(ui_ids)


# ------------------------------------------------------------
# 3. REQUIRED INPUTS
# ------------------------------------------------------------

cat("\n[3] Checking required inputs\n")

required_inputs <- c(
  "user_query",
  "run_query",
  "save_chat"
)

missing_inputs <- setdiff(
  required_inputs,
  ui_ids
)

if (length(missing_inputs) > 0) {
  stop(
    "Missing required input ID(s): ",
    paste(
      missing_inputs,
      collapse = ", "
    )
  )
}

cat(
  "Required inputs:",
  paste(required_inputs, collapse = ", "),
  "\n"
)


# ------------------------------------------------------------
# 4. REQUIRED OUTPUTS
# ------------------------------------------------------------

cat("\n[4] Checking required outputs\n")

required_outputs <- c(
  "sql",
  "table",
  "status"
)

missing_outputs <- setdiff(
  required_outputs,
  ui_ids
)

if (length(missing_outputs) > 0) {
  stop(
    "Missing required output ID(s): ",
    paste(
      missing_outputs,
      collapse = ", "
    )
  )
}

cat(
  "Required outputs:",
  paste(required_outputs, collapse = ", "),
  "\n"
)


# ------------------------------------------------------------
# 5. GREETING MARKDOWN
# ------------------------------------------------------------

cat("\n[5] Checking greeting markdown\n")

greeting_path <- here(
  "app",
  "rvat_greeting.md"
)

if (!file.exists(greeting_path)) {
  stop(
    "Greeting file not found: ",
    greeting_path
  )
}

greeting_info <- file.info(
  greeting_path
)

if (
  is.na(greeting_info$size) ||
  greeting_info$size == 0
) {
  stop(
    "Greeting file exists but is empty."
  )
}

cat(
  "Greeting file:",
  greeting_path,
  "\n"
)


# ------------------------------------------------------------
# 6. STATIC RENDER CHECK
# ------------------------------------------------------------

cat("\n[6] Testing static UI rendering\n")

rendered_ui <- htmltools::renderTags(
  ui
)

if (
  is.null(rendered_ui$html) ||
  !nzchar(rendered_ui$html)
) {
  stop(
    "UI rendering produced no HTML."
  )
}

cat("UI rendered successfully\n")


# ------------------------------------------------------------
# 7. FINAL STATUS
# ------------------------------------------------------------

cat("
=====================================
SHINY UI CHECK PASSED
=====================================
")

cat(
  "Inputs validated:",
  length(required_inputs),
  "\n"
)

cat(
  "Outputs validated:",
  length(required_outputs),
  "\n"
)