# ------------------------------------------------------------
# 04_logging_pipeline.R
#
# PURPOSE
# -------
# Logging wrapper around query execution (NL → SQL → DB).
#
# Captures:
# - user query
# - generated SQL
# - result (rows returned)
# - status (PASS / FAIL)
# - error message (if any)
# - model metadata (model, parameters, capability, temperature)
# - total execution time (end-to-end latency)
#
# DESIGN:
# -------
# - Calls execute_query() from 03_query_execution.R
# - No DB or LLM logic implemented here
# - No UI logic
# - No file writing (handled externally via "Save history")
#
# STORAGE:
# -------
# - Logs stored in-memory per session
# - Persisted only when user triggers save
# ------------------------------------------------------------


# ------------------------------------------------------------
# INTERNAL STORAGE (SESSION-LEVEL)
# ------------------------------------------------------------

.query_log_env <- new.env(parent = emptyenv())
.query_log_env$log <- list()


# ------------------------------------------------------------
# MAIN FUNCTION
# ------------------------------------------------------------

log_query_execution <- function(user_query, con, verbose = TRUE) {
  
  # ----------------------------------------------------------
  # VALIDATION
  # ----------------------------------------------------------
  
  if (missing(user_query) || nchar(user_query) == 0) {
    stop("❌ 'user_query' must be a non-empty string")
  }
  
  # ----------------------------------------------------------
  # START TIMING (USER CLICK → RESULT READY)
  # ----------------------------------------------------------
  
  start_time <- Sys.time()
  
  # ----------------------------------------------------------
  # EXECUTE QUERY PIPELINE
  # ----------------------------------------------------------
  
  result <- tryCatch({
    
    execute_query(user_query, con, verbose = verbose)
    
  }, error = function(e) {
    
    list(
      data  = NULL,
      sql   = NA,
      error = e$message
    )
  })
  
  # ----------------------------------------------------------
  # END TIMING
  # ----------------------------------------------------------
  
  end_time <- Sys.time()
  
  time_total_sec <- as.numeric(
    difftime(end_time, start_time, units = "secs")
  )
  
  # ----------------------------------------------------------
  # RESULT PROCESSING
  # ----------------------------------------------------------
  
  status <- ifelse(is.null(result$error), "PASS", "FAIL")
  
  rows_returned <- ifelse(
    is.null(result$data),
    NA,
    nrow(result$data)
  )
  
  # Optional lightweight preview (safe for logs)
  result_preview <- if (!is.null(result$data)) {
    paste(capture.output(utils::head(result$data, 3)), collapse = " | ")
  } else {
    NA
  }
  
  # ----------------------------------------------------------
  # MODEL METADATA (FROM CONFIG)
  # ----------------------------------------------------------
  
  model_used <- tryCatch(model_name, error = function(e) NA)
  
  model_parameters <- tryCatch(
    extract_params(model_name),
    error = function(e) NA
  )
  
  model_capability <- tryCatch(
    infer_capability(model_name),
    error = function(e) NA
  )
  
  model_temperature <- tryCatch(
    get_temperature(model_name),
    error = function(e) NA
  )
  
  # ----------------------------------------------------------
  # LOG ENTRY (STRUCTURED)
  # ----------------------------------------------------------
  
  log_entry <- data.frame(
    timestamp          = as.character(start_time),
    
    user_query         = user_query,
    sql_query          = ifelse(is.null(result$sql), NA, result$sql),
    
    rows_returned      = rows_returned,
    result_preview     = result_preview,
    
    status             = status,
    error_message      = ifelse(is.null(result$error), NA, result$error),
    
    model              = model_used,
    model_parameters   = ifelse(is.na(model_parameters), "Unknown", model_parameters),
    model_capability   = ifelse(is.na(model_capability), "Unknown", model_capability),
    model_temperature  = ifelse(is.na(model_temperature), "Not defined", model_temperature),
    
    time_total_sec     = time_total_sec,
    
    stringsAsFactors = FALSE
  )
  
  
  # ----------------------------------------------------------
  # STORE LOG IN MEMORY (SESSION)
  # ----------------------------------------------------------
  
  .query_log_env$log[[length(.query_log_env$log) + 1]] <- log_entry
  
  
  # ----------------------------------------------------------
  # OPTIONAL CONSOLE OUTPUT
  # ----------------------------------------------------------
  
  if (verbose) {
    cat("\n✅ Query logged\n")
    cat("Status:", status, "\n")
    cat("Rows returned:", rows_returned, "\n")
    cat("Total time:", round(time_total_sec, 2), "seconds\n")
  }
  
  # ----------------------------------------------------------
  # RETURN RESULT (FOR UI OR DOWNSTREAM USE)
  # ----------------------------------------------------------
  
  return(list(
    data  = result$data,
    sql   = result$sql,
    error = result$error
  ))
}


# ------------------------------------------------------------
# ACCESS LOGS
# ------------------------------------------------------------

get_query_log <- function() {
  if (length(.query_log_env$log) == 0) {
    return(NULL)
  }
  do.call(rbind, .query_log_env$log)
}


# ------------------------------------------------------------
# CLEAR LOGS
# ------------------------------------------------------------

clear_query_log <- function() {
  .query_log_env$log <- list()
  cat("✅ Query log cleared\n")
}