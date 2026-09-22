#DEMO_4: Safe Query Wrapper (SQL Hook)

# ---- OPTIONAL: MEASURE SQL EXECUTION TIME ONLY ----

measure_sql_execution <- function(con, sql_query) {
  
  start_time <- Sys.time()
  error_msg <- NA_character_
  
  data <- tryCatch({
    DBI::dbGetQuery(con, sql_query)
  }, error = function(e) {
    error_msg <- e$message
    message("SQL ERROR: ", e$message)
    NULL
  })
  
  end_time <- Sys.time()
  
  list(
    data = data,
    start_time = start_time,
    end_time = end_time,
    latency_sql = as.numeric(end_time - start_time),
    error_msg = error_msg
  )
}



# ---- Checks and validations 2 ----

sql <- "SELECT * FROM varInfo LIMIT 5"

res <- measure_sql_execution(con, sql)

str(res)
head(res$data)

# ---- error handeling
bad_sql <- "SELECT * FROM non_existing_table"
res <- measure_sql_execution(con, bad_sql)

res$error_msg

# ---- latency
res$latency_sql


# ---- Checks and validations ----

sql <- "SELECT * FROM varInfo LIMIT 5"

res <- measure_sql_execution(con, sql)

str(res)
``

#
head(res$result)

#
res$latency_sql

#
bad_sql <- "SELECT * FROM non_existing_table"

res <- measure_sql_execution(con, bad_sql)

res$error

#
log_query_timing(
  user_query = "test",
  sql_query = sql,
  start_time = start,
  llm_end_time = llm_end,
  end_time = sql_result$end_time,
  error_msg = sql_result$error
)

