# ------------------------------------------------------------
# 03_query_execution.R
#
# PURPOSE
# -------
# Core NL → SQL → DB → Result pipeline
#
# INPUT:
#   - user_query (string)
#
# OUTPUT:
#   - list:
#       $data  → query result (data.frame)
#       $sql   → generated SQL
#       $error → error message (if any)
#
# DESIGN:
# -------
# - Pure execution layer
# - No sourcing of dependencies
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

execute_query <- function(user_query, con, verbose = TRUE) {
  
  if (missing(user_query) || nchar(user_query) == 0) {
    stop("❌ 'user_query' must be a non-empty string")
  }
  
  ctx <- get_active_context()
  
  sql <- NA
  data <- NULL
  error_msg <- NULL
  
  # ----------------------------------------------------------
  # GENERATE SQL
  # ----------------------------------------------------------
  
  sql <- tryCatch({
    generate_sql_ollama(user_query, con, ctx)
  }, error = function(e) {
    error_msg <<- paste("SQL generation failed:", e$message)
    return(NA)
  })
  
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