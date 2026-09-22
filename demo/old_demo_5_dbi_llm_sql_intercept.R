#DEMO_5: Override DBI to Intercept LLM SQL

# ----troubleshooted step ---
.original_dbGetQuery <- DBI::dbGetQuery

assignInNamespace(
  "dbGetQuery",
  function(conn, statement, ...) {
    safe_db_query(conn, statement)
  },
  ns = "DBI"
)