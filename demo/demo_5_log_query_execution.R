#DEMO_5: Log Query Execution 

# ---- FULL QUERY EXECUTION + LOGGING ----# ---- FULL QUERY EXEC Sys.time()

log_query_execution <- function(con, user_query) {
  
  # ---- INITIALIZE ----
  start_time <- Sys.time()
  error_msg  <- NA_character_
  
  sql_query <- NULL
  sql_result <- NULL
  llm_end_time <- NULL
  
  # ---- EXECUTION PIPELINE ----
  pipeline_result <- tryCatch({
    
    # ---- STEP 1: LLM GENERATES SQL ----
    sql_query <- generate_sql_ollama(user_query)
    llm_end_time <- Sys.time()
    
    # ---- STEP 2: EXECUTE SQL ----
    sql_result <- measure_sql_execution(con, sql_query)
    
    list(
      sql_query = sql_query,
      sql_result = sql_result,
      llm_end_time = llm_end_time,
      error_msg = NA_character_
    )
    
  }, error = function(e) {
    
    message("PIPELINE ERROR: ", e$message)
    
    list(
      sql_query = sql_query,
      sql_result = NULL,
      llm_end_time = Sys.time(),
      error_msg = e$message
    )
  })
  
  # ---- EXTRACT RESULTS ----
  sql_query    <- pipeline_result$sql_query
  sql_result   <- pipeline_result$sql_result
  llm_end_time <- pipeline_result$llm_end_time
  error_msg    <- pipeline_result$error_msg
  
  # ---- FINAL TIME ----
  end_time <- if (!is.null(sql_result)) {
    sql_result$end_time
  } else {
    Sys.time()
  }
  
  # ---- LOGGING ----
  log_query_timing(
    user_query   = user_query,
    sql_query    = sql_query,
    start_time   = start_time,
    llm_end_time = llm_end_time,
    end_time     = end_time,
    error_msg    = if (!is.null(sql_result)) {
      sql_result$error_msg
    } else {
      error_msg
    }
  )
  
  # ---- RETURN RESULT ----
  if (!is.null(sql_result)) {
    return(list(
      data  = sql_result$data,
      sql   = sql_query,
      error = sql_result$error_msg
    ))
  } else {
    return(list(
      data  = NULL,
      sql   = sql_query,
      error = error_msg
    ))
  }
}


# ----- Checks and Controls -----
# ----Verify Syntax ----
log_query_execution
``
# ---- Test function ----
res <- log_query_execution(con, "show first 5 rows")

cat(res$sql)
head(res$data)

