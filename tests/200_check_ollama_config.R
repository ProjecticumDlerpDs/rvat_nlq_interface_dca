# ------------------------------------------------------------
# 200_check_ollama_config.R
#
# PURPOSE
# -------
# Validate Ollama configuration and NL → SQL generation
#
# This script checks:
# 1. Ollama availability
# 2. Installed models
# 3. Selected model functionality
# 4. Prompt construction
# 5. SQL generation
# 6. (Optional) SQL execution against DB
#
# NOTE:
# -----
# - Troubleshooting / validation script
# - NOT used in production pipeline
# ------------------------------------------------------------

library(DBI)
library(ollamar)
library(httr2)

# ------------------------------------------------------------
# LOAD CORE COMPONENTS
# ------------------------------------------------------------

source("R/01_db_connection.R")
source("R/02_ollama_config.R")

cat("
=====================================
 OLLAMA CONFIG CHECK
=====================================
Starting validation...
")

# ------------------------------------------------------------
# 1. CHECK OLLAMA CONNECTION
# ------------------------------------------------------------
cat("\n[1] Checking Ollama connection...\n")

tryCatch({
  test_connection("http://localhost:11434")
  cat("✅ Ollama connection successful\n")
}, error = function(e) {
  stop("❌ Ollama connection failed: ", e$message)
})


# ------------------------------------------------------------
# 2. LIST AVAILABLE MODELS
# ------------------------------------------------------------
cat("\n[2] Listing available models...\n")

models <- ollamar::list_models()

model_list <- models$model
if (is.null(model_list)) model_list <- models$name

print(model_list)

if (length(model_list) == 0) {
  stop("❌ No Ollama models found. Run: ollama pull <model>")
}

cat("✅ Models detected\n")


# ------------------------------------------------------------
# 3. VALIDATE SELECTED MODEL
# ------------------------------------------------------------
cat("\n[3] Checking selected model...\n")

if (!(model_name %in% model_list)) {
  warning("⚠ Selected model not found in local Ollama registry")
} else {
  cat("✅ Selected model is available:", model_name, "\n")
}


# ------------------------------------------------------------
# 4. CONTEXT CHECK
# ------------------------------------------------------------
cat("\n[4] Checking database context...\n")

ctx <- get_active_context()

print(ctx)

cat("✅ Context successfully retrieved\n")


# ------------------------------------------------------------
# 5. PROMPT GENERATION TEST
# ------------------------------------------------------------
cat("\n[5] Testing prompt generation...\n")

test_query <- "show first 5 rows"

prompt <- build_prompt(test_query, con, ctx)

cat("\nGenerated prompt:\n")
cat("-------------------------------------\n")
cat(prompt)
cat("\n-------------------------------------\n")

cat("✅ Prompt generation successful\n")


# ------------------------------------------------------------
# 6. SQL GENERATION TEST
# ------------------------------------------------------------
cat("\n[6] Testing NL → SQL generation...\n")

sql <- tryCatch({
  generate_sql_ollama(test_query, con, ctx)
}, error = function(e) {
  stop("❌ SQL generation failed: ", e$message)
})

cat("\nGenerated SQL:\n")
cat("-------------------------------------\n")
cat(sql)
cat("\n-------------------------------------\n")

cat("✅ SQL generation successful\n")


# ------------------------------------------------------------
# 7. SQL EXECUTION TEST (OPTIONAL BUT RECOMMENDED)
# ------------------------------------------------------------
cat("\n[7] Testing SQL execution...\n")

result <- tryCatch({
  DBI::dbGetQuery(con, sql)
}, error = function(e) {
  cat("⚠ SQL execution produced error (acceptable in some cases):\n")
  cat(e$message, "\n")
  return(NULL)
})

print(result)

cat("✅ SQL execution test completed\n")


# ------------------------------------------------------------
# 8. PERFORMANCE CHECK
# ------------------------------------------------------------
cat("\n[8] Measuring response time...\n")

time <- system.time({
  generate_sql_ollama("count rows", con, ctx)
})

elapsed_sec <- as.numeric(time["elapsed"])

cat("\n=====================================\n")
cat(" PERFORMANCE MEASUREMENT\n")
cat("=====================================\n")

cat("End-to-end latency:", round(elapsed_sec, 2), "seconds\n")
cat("Meaning: end-to-end NL → SQL pipeline time\n")
cat("Includes: prompt construction, Ollama API call, LLM inference, and response parsing\n")

cat("\nSystem time breakdown:\n")

cat(
  "User CPU time:",
  round(time["user.self"], 2),
  "seconds\n"
)

cat(
  "System CPU time:",
  round(time["sys.self"], 2),
  "seconds\n"
)

cat("✅ Performance check completed\n")

# ------------------------------------------------------------
# FINAL STATUS
# ------------------------------------------------------------

cat("
=====================================
 ✅ ALL CHECKS COMPLETED
=====================================
")