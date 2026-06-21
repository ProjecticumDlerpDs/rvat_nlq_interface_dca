# ------------------------------------------------------------
# 20_select_model_guide.R
#
# PURPOSE
# -------
# Help users choose an LLM for the NL → SQL pipeline
# Provides:
# - available models
# - capability overview
# - parameter size
# - temperature (if defined)
#
# ------------------------------------------------------------

library(ollamar)
library(httr)

cat("
=====================================
 MODEL SELECTION GUIDE
=====================================
")

# ------------------------------------------------------------
# CONNECTION CHECK
# ------------------------------------------------------------
cat("\n[1] Checking Ollama connection...\n")

test_connection("http://localhost:11434")
cat("✅ Ollama connection OK\n")

# ------------------------------------------------------------
# LIST MODELS
# ------------------------------------------------------------
cat("\n[2] Available models:\n")

models <- ollamar::list_models()

model_list <- models$model
if (is.null(model_list)) model_list <- models$name

print(model_list)

if (length(model_list) == 0) {
  stop("No models installed. Run: ollama pull <model>")
}

# ------------------------------------------------------------
# HELPER FUNCTIONS
# ------------------------------------------------------------

extract_params <- function(model_name) {
  match <- regmatches(model_name, regexpr("[0-9]+b", model_name))
  if (length(match) == 0 || match == "") return(NA)
  toupper(match)
}

infer_capability <- function(model_name) {
  if (grepl("coder|sqlcoder", model_name, ignore.case = TRUE)) {
    return("High (code/SQL optimized)")
  }
  if (grepl("qwen|llama|gemma|phi", model_name, ignore.case = TRUE)) {
    return("High (general reasoning)")
  }
  if (grepl("mistral", model_name, ignore.case = TRUE)) {
    return("Medium (fast, less precise)")
  }
  return("Unknown")
}

get_temperature <- function(model) {
  tryCatch({
    res <- httr::POST(
      "http://localhost:11434/api/show",
      body = list(name = model),
      encode = "json"
    )
    result <- httr::content(res, "parsed")
    mf <- result$modelfile
    
    if (is.null(mf)) return(NA)
    
    temp_line <- grep("PARAMETER[[:space:]]+temperature", mf, value = TRUE)
    if (length(temp_line) == 0) return(NA)
    
    numeric_part <- sub(".*temperature[[:space:]=]+([0-9.]+).*", "\\1", temp_line)
    as.numeric(numeric_part)
    
  }, error = function(e) NA)
}

# ------------------------------------------------------------
# MODEL TABLE
# ------------------------------------------------------------
cat("\n[3] Model capability overview:\n")

model_table <- data.frame(
  model = model_list,
  parameters = sapply(model_list, extract_params),
  capability = sapply(model_list, infer_capability),
  temperature = sapply(model_list, get_temperature),
  stringsAsFactors = FALSE
)

model_table$temperature <- ifelse(
  is.na(model_table$temperature),
  "Not defined",
  model_table$temperature
)

model_table$parameters <- ifelse(
  is.na(model_table$parameters),
  "Unknown",
  model_table$parameters
)

print(model_table, row.names = FALSE)

# ------------------------------------------------------------
# INTERPRETATION
# ------------------------------------------------------------
cat("\n[4] Interpretation guide:\n")

cat("
- Parameters ≥ 7B → sufficient reasoning capability
- 'coder' models → best for SQL generation
- Temperature:
    • low (≤0.2) → deterministic (preferred)
    • higher     → more variability

Note:
Temperature may not be defined explicitly in all models.
")

# ------------------------------------------------------------
# FINAL GUIDANCE
# ------------------------------------------------------------
cat("\n[5] Recommendation:\n")

cat("
Best choices:
- qwen2.5-coder → highest SQL accuracy
- qwen3:8b      → balanced performance
- mistral       → fastest but less precise

If unsure → start with qwen3:8b
")

cat("\n✅ Model selection guide completed\n")