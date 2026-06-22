# ------------------------------------------------------------
# 02_ollama_config.R
#
# PURPOSE
# -------
# Configure Ollama LLM for NL → SQL generation
# Includes:
# - Model selection
# - Prompt building
# - SQL generation
# - Model metadata extraction (parameters, capability, temperature)
#
# ------------------------------------------------------------

library(ollamar)
library(httr2)
library(DBI)
library(httr)

# ------------------------------------------------------------
# CHECK OLLAMA CONNECTION
# ------------------------------------------------------------

cat("
=====================================
 OLLAMA CONFIGURATION
=====================================
")

test_connection("http://localhost:11434")

# ------------------------------------------------------------
# LIST AVAILABLE MODELS
# ------------------------------------------------------------

# NOTE:
# -----
# `ollamar::list_models()` returns locally installed Ollama models.
# This is only meaningful if multiple models have been installed.
#
# In the standard setup, users are instructed to install a single
# recommended model (e.g. qwen3:8b), so this will typically return
# a single entry.
#
# For model comparison or triage workflows, multiple models must
# be installed manually via:
#   ollama pull <model_name>
#
# Example:
#   ollama pull qwen3:8b
#   ollama pull llama3
#
# Use this function mainly for:
# - model benchmarking
# - triage workflows
# - exploratory comparisons

models <- ollamar::list_models()

model_list <- models$model
if (is.null(model_list)) model_list <- models$name

if (length(model_list) == 0) {
  stop("No Ollama models found. Run: ollama pull <model>")
}

cat("\nAvailable models:\n")
print(model_list)

# ------------------------------------------------------------
# HELPER FUNCTIONS (MODEL METADATA)
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
    return("Medium (fast inference)")
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
    value <- as.numeric(numeric_part)
    
    if (is.na(value)) return(NA)
    return(value)
    
  }, error = function(e) {
    return(NA)
  })
}

# ------------------------------------------------------------
# MODEL CONFIGURATION (USER EDITABLE)
# ------------------------------------------------------------

model_name <- "qwen3:8b"

cat("\n✅ Selected model:", model_name, "\n")
cat("👉 To change model, edit 'model_name' in this script\n")

# ------------------------------------------------------------
# MODEL INFO (ACTUAL VALUES)
# ------------------------------------------------------------

model_params <- extract_params(model_name)
model_capability <- infer_capability(model_name)
model_temp <- get_temperature(model_name)

cat("\n[Model Info]\n")
cat("Model:", model_name, "\n")
cat("Parameters:", ifelse(is.na(model_params), "Unknown", model_params), "\n")
cat("Capability:", model_capability, "\n")

cat("Temperature:\n")
if (is.na(model_temp)) {
  cat("- Not explicitly defined in model\n")
  cat("- Using Ollama default behavior\n")
} else {
  cat("- Defined in model:", model_temp, "\n")
}

cat("- Recommended for SQL tasks: 0.0 – 0.2\n")

# ------------------------------------------------------------
# PROMPT BUILDER
# ------------------------------------------------------------

build_prompt <- function(user_query, con, ctx) {
  
  if (ctx$restriction) {
    
    cols <- DBI::dbGetQuery(
      con, paste0("PRAGMA table_info(", ctx$table, ")")
    )$name
    
    paste(
      "You are a SQLite expert.",
      paste0("Use table: ", ctx$table),
      paste("Columns:", paste(cols, collapse = ", ")),
      "Return ONLY a valid SQLite SELECT statement.",
      "Avoid explanations or markdown.",
      "",
      "Task:",
      user_query
    )
    
  } else {
    
    paste(
      "You are a SQLite expert.",
      "full_gdb mode → full schema available",
      "Use valid joins where needed.",
      "Return ONLY a valid SQLite SELECT statement.",
      "Avoid explanations or markdown.",
      "",
      "Task:",
      user_query
    )
  }
}

# ------------------------------------------------------------
# SQL GENERATOR
# ------------------------------------------------------------

generate_sql_ollama <- function(user_query, con, ctx) {
  
  prompt <- build_prompt(user_query, con, ctx)
  
  resp <- ollamar::chat(
    model = model_name,
    messages = list(list(role = "user", content = prompt))
  )
  
  parsed <- resp |> httr2::resp_body_json()
  sql <- parsed$message$content
  
  sql <- gsub("```sql", "", sql, ignore.case = TRUE)
  sql <- gsub("```", "", sql)
  sql <- sub(".*?(SELECT)", "\\1", sql, ignore.case = TRUE)
  sql <- trimws(sql)
  
  if (nchar(sql) == 0) stop("No SQL returned from model")
  
  return(sql)
}