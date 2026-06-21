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

run_sql_pipeline <- function(user_query, con, verbose = TRUE) {

  if (missing(user_query) || nchar(user_query) == 0) {
    stop("❌ 'user_query' must be a non-empty string")
  }

  ctx <- get_active_context()

  # ----------------------------------------------------------
  # GENERATE SQL
  # ----------------------------------------------------------

  sql <- tryCatch({
    generate_sql_ollama(user_query, con, ctx)
  }, error = function(e) {
    return(list(
      data  = NULL,
      sql   = NA,
      error = paste("SQL generation failed:", e$message)
    ))
  })

  if (is.list(sql)) return(sql)

  if (verbose) {
    cat("\nGenerated SQL:\n")
    cat("-------------------------------------\n")
    cat(sql, "\n")
    cat("-------------------------------------\n")
  }

  # ----------------------------------------------------------
  # EXECUTE SQL
  # ----------------------------------------------------------

  result <- tryCatch({
    DBI::dbGetQuery(con, sql)
  }, error = function(e) {
    return(list(
      data  = NULL,
      sql   = sql,
      error = paste("SQL execution failed:", e$message)
    ))
  })

  if (is.list(result)) return(result)

  return(list(
    data  = result,
    sql   = sql,
    error = NULL
  ))
}