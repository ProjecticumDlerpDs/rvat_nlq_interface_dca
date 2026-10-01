# ------------------------------------------------------------
# 03_query_execution.R
#
# PURPOSE
# -------
# Execute the core NL -> SQL -> database query pipeline.
#
# RESPONSIBILITIES:
# -----------------
# - Validate the natural-language query input
# - Obtain the active database context
# - Generate SQL through generate_sql_ollama()
# - Execute generated SQL against the active database
# - Capture SQL-generation and SQL-execution errors
# - Return query data, generated SQL, and error information
#
# INPUT:
# ------
# - user_query: non-empty natural-language question
# - con: active database connection
# - verbose: controls console display of generated SQL
#
# OUTPUT:
# -------
# - list containing:
# * data - query result as a data.frame, or NULL
# * sql - generated SQL, or NA if generation failed
# * error - error message, or NULL when execution succeeds
#
# DESIGN:
# -------
# - Uses the database context defined by 01_db_connection.R
# - Uses SQL generation defined by 02_ollama_config.R
# - Does not source dependencies
# - Does not build prompts
# - Does not implement logging
# - Does not contain Shiny/UI logic
# - Assumes:
#     * 'con' exists
#     * 'generate_sql_ollama()' exists
#     * 'get_active_context()' exists
#
# USED BY:
# -------
# - 04_logging_pipeline.R
# - Shiny server (06_shiny_server.R)
# ------------------------------------------------------------

# ------------------------------------------------------------
# MAIN EXECUTION FUNCTION
# ------------------------------------------------------------

execute_query <- function(
    user_query,
    con,
    verbose = TRUE,
    on_sql_generated = NULL
) {
  
  if (missing(user_query) || nchar(user_query) == 0) {
    stop("❌ 'user_query' must be a non-empty string")
  }
  
  ctx <- get_active_context()
  
  sql <- NA_character_
  data <- NULL
  error_msg <- NULL

    
# ----------------------------------------------------------
# GENERATE SQL
# ----------------------------------------------------------
  
  sql <- tryCatch({
    generate_sql_ollama(user_query, con, ctx)
  }, error = function(e) {
    error_msg <<- paste("SQL generation failed:", e$message)
    return(NA_character_)
  })
  
  if (
    !is.na(sql) &&
    is.function(on_sql_generated)
  ) {
    on_sql_generated(sql)
  }
  
  if (!is.na(sql) && verbose) {
    cat("\nGenerated SQL:\n")
    cat("-------------------------------------\n")
    cat(sql, "\n")
    cat("-------------------------------------\n")
  }

# ----------------------------------------------------------
# EXECUTE SQL (only if SQL exists)
# ----------------------------------------------------------
  
if (!is.na(sql) && is.null(error_msg)) {
    
  data <- tryCatch({
    DBI::dbGetQuery(con, sql)
  }, error = function(e) {
    error_msg <<- paste("SQL execution failed:", e$message)
    return(NULL)
  })
}
  
# ----------------------------------------------------------
# FINAL RETURN (ALWAYS CONSISTENT)
# ----------------------------------------------------------
  
return(list(
  data  = data,
  sql   = sql,
  error = error_msg
 ))
}