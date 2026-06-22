# ------------------------------------------------------------
# 31_run_triage_executor.R
#
# PURPOSE
# -------
# Execute reproducible LLM triage pipeline:
# - Multiple models
# - Multiple queries
# - Multiple runs (N_RUNS)
# - PASS/FAIL evaluation
#
# OUTPUT
# ------
# 1) data/triage/*.rds
# 2) triage_raw_metrics.csv
# 3) triage_decision_matrix.csv
# ------------------------------------------------------------

library(DBI)
library(here)


# ------------------------------------------------------------
# OPTIONAL: override DB mode for this run
#           uncomment before running script to override
# ------------------------------------------------------------ 
#Sys.setenv(RVAT_DB_MODE = "full_gdb")

# ------------------------------------------------------------
# LOAD DEPENDENCIES
# ------------------------------------------------------------

source(here("R", "01_db_connection.R"))
source(here("R", "02_ollama_config.R"))
source(here("scripts", "30_stage_triage_llm.R"))


# ------------------------------------------------------------
# CONFIGURATION
# ------------------------------------------------------------

models_to_test <- c(
  "qwen3:8b",
  "qwen2.5-coder:latest",
  "mistral:latest"
)

queries <- c(
  "Select number of variants in NEK1",
  "What is the variant with the highest allele frequency?"
)

N_RUNS <- 5
MAX_TIME <- 180  # seconds

ctx <- get_active_context()

dir.create(here("data", "triage"), recursive = TRUE, showWarnings = FALSE)

date_tag <- format(Sys.Date(), "%Y%m%d")

all_results <- list()
counter <- 1

cat("\n=========== TRIAGE START ===========\n")

# ------------------------------------------------------------
# MAIN LOOP
# ------------------------------------------------------------

for (model_name in models_to_test) {
  
  cat("\n--- MODEL:", model_name, "---\n")
  
  for (run_id in 1:N_RUNS) {
    
    for (q in queries) {
      
      cat("[Run", run_id, "] Query:", q, "\n")
      
      start_time <- Sys.time()
      
      res <- tryCatch({
        generate_sql_ollama_triage(q, con, ctx, model_name)
      }, error = function(e) {
        list(
          sql = NA,
          metrics = data.frame(
            model = model_name,
            query = q,
            error = e$message,
            stringsAsFactors = FALSE
          )
        )
      })
      
      elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
      
      # ------------------------------------------------------
      # PASS / FAIL LOGIC
      # ------------------------------------------------------
      
      status <- "PASS"
      
      if (is.na(res$sql)) status <- "FAIL_sql_null"
      if (elapsed > MAX_TIME) status <- "FAIL_timeout"
      
      metrics <- res$metrics
      metrics$time_total_sec <- elapsed
      metrics$status <- status
      metrics$sql <- res$sql
      metrics$run_id <- run_id
      metrics$run_date <- date_tag
      
      all_results[[counter]] <- metrics
      counter <- counter + 1
      
      cat("Time:", round(elapsed, 2), "| Status:", status, "\n")
    }
  }
}

# ------------------------------------------------------------
# FLATTEN RESULTS
# ------------------------------------------------------------

raw_df <- do.call(rbind, all_results)

# Ensure correct types (optional but recommended)
raw_df$model <- as.factor(raw_df$model)
raw_df$status <- as.factor(raw_df$status)

# ------------------------------------------------------------
# SAVE RAW METRICS
# ------------------------------------------------------------

write.csv(
  raw_df,
  here("data", "triage", "triage_raw_metrics.csv"),
  row.names = FALSE
)

cat("✅ Saved: triage_raw_metrics.csv\n")

# ------------------------------------------------------------
# DECISION MATRIX
# ------------------------------------------------------------

decision_matrix <- aggregate(
  status ~ model,
  data = raw_df,
  function(x) ifelse(all(x == "PASS"), "PASS", "FAIL")
)

decision_matrix$explanation <- paste(
  "PASS = all runs completed within 180 seconds and produced valid SQL.",
  "FAIL = timeout or invalid SQL.",
  "Metrics used:",
  "prompt_tokens (input size),",
  "generated_tokens (output size),",
  "eval_duration_sec (generation time),",
  "total_duration_sec (end-to-end latency),",
  "tokens_per_sec (efficiency),",
  "time_total_sec (decision threshold)."
)

write.csv(
  decision_matrix,
  here("data", "triage", "triage_decision_matrix.csv"),
  row.names = FALSE
)

cat("✅ Saved: triage_decision_matrix.csv\n")

# ------------------------------------------------------------
# SAVE PER MODEL RDS (EVIDENCE LAYER)
# ------------------------------------------------------------

split_models <- split(raw_df, raw_df$model)

for (m in names(split_models)) {
  
  model_safe <- gsub(":", "_", m)
  
  file_path <- here(
    "data",
    "triage",
    paste0("log_", model_safe, "_", date_tag, ".rds")
  )
  
  saveRDS(split_models[[m]], file = file_path)
  
  cat("✅ Saved:", file_path, "\n")
}

cat("\n=========== TRIAGE COMPLETED ===========\n")