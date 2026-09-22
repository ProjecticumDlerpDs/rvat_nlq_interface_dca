#DEMO_3: Timing + Query Logging Layer

library(tibble)
library(dplyr)

`%||%` <- function(a, b) if (!is.null(a)) a else b

# ---- STORAGE ----
.timing_log <- new.env()
.timing_log$data <- tibble()

# ---- LOG FUNCTION ----
log_query_timing <- function(
    user_query,
    sql_query,
    start_time,
    llm_end_time,
    end_time,
    error_msg
) {
  .timing_log$data <- bind_rows(
    .timing_log$data,
    tibble(
      user_query = as.character(user_query),
      sql_query = as.character(sql_query %||% NA_character_),
      tool_error = as.character(error_msg %||% NA_character_),
      
      start_time = start_time,
      llm_end_time = llm_end_time,
      end_time = end_time,
      
      latency_llm = as.numeric(llm_end_time - start_time),
      latency_sql = as.numeric(end_time - llm_end_time),
      latency_total = as.numeric(end_time - start_time),
      
      timestamp = Sys.time()
    )
  )
}

# ---- GET LOG ----
get_timing_log <- function() {
  .timing_log$data
}



# ---- Checks and controls 3 ----
# ---- function definition
body(log_query_timing)

# ---- re-run:
start <- Sys.time()
llm_end <- start + 2
end <- llm_end + 1

log_query_timing(
  user_query = "test",
  sql_query = "SELECT 1",
  start_time = start,
  llm_end_time = llm_end,
  end_time = end,
  error_msg = NA
)

get_timing_log()

# ---- Checks and controls 2 ----
exists("con")
exists("model_name")
exists("generate_sql_ollama")
exists("run_sql_query")
exists("log_query_timing")

#
DBI::dbIsValid(con)

#
DBI::dbGetQuery(con, "PRAGMA table_info(varInfo)")

# ----  Validate LLM → SQL (core dependency) ----
sql <- generate_sql_ollama("show first 5 rows")
cat(sql)

# validate SQL execution
res <- run_sql_query(con, sql)
head(res)


# ---- Validate logging (real pipeline simulation) ----
start <- Sys.time()

sql <- generate_sql_ollama("show first 5 rows")

llm_end <- Sys.time()

res <- run_sql_query(con, sql)

end <- Sys.time()

log_query_timing(
  user_query = "show first 5 rows",
  sql_query = sql,
  start_time = start,
  llm_end_time = llm_end,
  end_time = end,
  error_msg = NA
)

get_timing_log()


# -----Check data types (important for export later) ----
str(get_timing_log())


# ---- UI message sanity (demo_2) ----
cat(extended_message)



# ---- Checks and Controls ----
start <- Sys.time()
llm_end <- start + 2   # simulate
end <- llm_end + 1

log_query_timing(
  user_query = "test",
  sql_query = "SELECT 1",
  start_time = start,
  llm_end_time = llm_end,
  end_time = end,
  error_msg = NA
)

#
args(log_query_timing)
#function (user_query, sql_query, start_time, llm_end_time, end_time, 
#error_msg) 
#NULL

#
start <- Sys.time()
llm_end <- start + 2
end <- llm_end + 1

log_query_timing(
  user_query = "test",
  sql_query = "SELECT 1",
  start_time = start,
  llm_end_time = llm_end,
  end_time = end,
  error_msg = NA
)

get_timing_log()
