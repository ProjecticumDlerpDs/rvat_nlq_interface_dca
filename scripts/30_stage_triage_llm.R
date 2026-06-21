# ------------------------------------------------------------
# 30_stage_triage_llm.R
#
# PURPOSE
# -------
# LLM triage utility:
# - Generate SQL from NL queries
# - Capture performance metrics
# - Clean SQL output
#
# NOTE:
# -----
# - NO loops
# - NO file writing
# - Used by 31_run_triage_executor.R
# ------------------------------------------------------------

library(DBI)
library(ollamar)
library(httr2)

# ------------------------------------------------------------
# INTERNAL HELPER
# ------------------------------------------------------------
`%||%` <- function(a, b) if (!is.null(a)) a else b


# ------------------------------------------------------------
# FUNCTION: generate_sql_ollama_triage
# ------------------------------------------------------------
generate_sql_ollama_triage <- function(user_query, con, ctx, model_name) {
  
  # ---- BUILD PROMPT ----
  prompt <- build_prompt(user_query, con, ctx)
  
  # ---- CALL MODEL ----
  resp <- ollamar::chat(
    model = model_name,
    messages = list(list(role = "user", content = prompt))
  )
  
  parsed <- resp |> httr2::resp_body_json()
  
  sql_raw <- parsed$message$content
  
  # ----------------------------------------------------------
  # METRICS
  # ----------------------------------------------------------
  metrics <- data.frame(
    model              = model_name,
    query              = user_query,
    table              = ifelse(ctx$restriction, ctx$table, "multi"),
    
    prompt_tokens      = parsed$prompt_eval_count %||% NA,
    generated_tokens   = parsed$eval_count %||% NA,
    
    eval_duration_sec  = (parsed$eval_duration %||% NA) / 1e9,
    total_duration_sec = (parsed$total_duration %||% NA) / 1e9,
    
    stringsAsFactors   = FALSE
  )
  
  metrics$tokens_per_sec <- ifelse(
    !is.na(metrics$eval_duration_sec) &&
      metrics$eval_duration_sec > 0,
    metrics$generated_tokens / metrics$eval_duration_sec,
    NA
  )
  
  # ----------------------------------------------------------
  # CLEAN SQL
  # ----------------------------------------------------------
  sql <- gsub("```sql", "", sql_raw, ignore.case = TRUE)
  sql <- gsub("```", "", sql)
  sql <- sub(".*?(SELECT)", "\\1", sql, ignore.case = TRUE)
  sql <- trimws(sql)
  
  if (is.null(sql) || nchar(sql) == 0) {
    sql <- NA
  }
  
  # ----------------------------------------------------------
  # RETURN
  # ----------------------------------------------------------
  return(list(
    sql = sql,
    metrics = metrics
  ))
}