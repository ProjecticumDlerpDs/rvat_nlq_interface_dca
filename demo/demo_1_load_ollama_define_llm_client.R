#DEMO_1: Load Ollama & Define LLM Client

#installed.packages("ollamar")  #add to rev!

# ---- SQL GENERATOR (UPDATED - ROBUST & FAST) ----
library(ollamar)
library(httr2)

# ---- CHECK CONNECTION ----
test_connection("http://localhost:11434")

# ----- List models ----
ollamar::list_models()

# ---- SELECT MODEL ----
model_name <- "qwen2.5-coder"
model_info <- ollamar::show(model_name)

# ---- SQL GENERATOR (CLEAN VERSION) ----
generate_sql_ollama <- function(user_query) {
  
  # ✅ DEFINE columns INSIDE function
  columns <- DBI::dbGetQuery(con, "PRAGMA table_info(varInfo)")$name
  column_text <- paste(columns, collapse = ", ")
  
  prompt <- paste(
    "Write a SQLite query.",
    "Use table: varInfo.",
    paste("Columns:", column_text),
    "Return ONLY SQL.",
    "",
    "Task:",
    user_query
  )
  
  resp <- ollamar::chat(
    model = model_name,
    messages = list(list(role = "user", content = prompt))
  )
  
  parsed <- resp |> httr2::resp_body_json()
  sql <- parsed$message$content
  
  # ---- CLEAN OUTPUT ----
  sql <- gsub("```sql", "", sql, ignore.case = TRUE)
  sql <- gsub("```", "", sql)
  sql <- sub(".*?(SELECT)", "\\1", sql, ignore.case = TRUE)
  sql <- trimws(sql)
  
  # ---- FIX COMMON MODEL ERROR ----
  sql <- gsub("your_table_name", "varInfo", sql)
  
  # ---- VALIDATE ----
  if (is.null(sql) || nchar(sql) == 0) {
    stop("No SQL returned from model")
  }
  
  sql
}

# ---- SQL EXECUTION ----
run_sql_query <- function(con, sql_query) {
  tryCatch({
    DBI::dbGetQuery(con, sql_query)
  }, error = function(e) {
    message("SQL ERROR: ", e$message)
    NULL
  })
}



# ---- Check and Inspect 6 ----
generate_sql_ollama

#
column_text <- paste(columns, collapse = ", ")

#
sql <- generate_sql_ollama("show first 5 rows")
cat(sql)

#
res <- run_sql_query(con, sql)
head(res)

#following (expected) error from above:
sql <- generate_sql_ollama("show first 5 rows")
cat(sql)

sql <- generate_sql_ollama("count variants per chromosome")
cat(sql)

# ---- Check and Inspect 5 ----
columns <- DBI::dbGetQuery(con, "PRAGMA table_info(varInfo)")$name
print(columns)

sql <- generate_sql_ollama("show first 5 rows")
cat(sql)

# ---- Check and Inspect 4 ----
model_info

#
sql <- generate_sql_ollama("show first 5 rows")
cat(sql)
#
res <- run_sql_query(con, sql)
head(res)
#
sql <- generate_sql_ollama("first 5 rows")
res <- run_sql_query(con, sql)

cat(sql)
head(res)
# ---- Check and Inspect 3 ----
# ---- Test SQL execution ----
sql <- generate_sql_ollama("show first 5 rows")
cat(sql)

# ---- Check and Inspect 2 ----
# ---- TEST LLM → SQL ----
sql <- generate_sql_ollama("show first 5 rows")
cat(sql)

# ---- TEST SQL execution ----
res <- run_sql_query(con, sql)
head(res)


# ---- Check and Inspect 1 ----
str(model_info)

# ---- Text Generation Test ----
library(httr2)

resp <- ollamar::chat(
  model = model_name,
  messages = list(
    list(role = "user", content = "Say 'OK' only")
  )
)

parsed <- resp |> resp_body_json()

parsed$message$content

# ---- SQL sanity check ----
resp <- ollamar::chat(
  model = model_name,
  messages = list(
    list(role = "user", content = "
Generate a SQLite query to show first 5 rows from a table named varInfo.
Only output SQL.
")
  )
)

parsed <- resp |> resp_body_json()

cat(parsed$message$content)

# took more than 5 minutes, stoped

# ---- latency sanity check (optional but valuable) ----
system.time({
  ollamar::chat(
    model = model_name,
    messages = list(list(role = "user", content = "test"))
  )
})