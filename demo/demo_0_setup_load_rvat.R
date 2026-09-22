#DEMO_0: Setup & Load RVAT Database

# ---- PACKAGES ----
library(rvat)
library(rvatData)
library(DBI)
library(RSQLite)

# ---- LOAD EXAMPLE DATABASE ----
gdbpath <- rvat_example("rvatData.gdb")

# ---- CHECK DATABASE ----
stopifnot(file.exists(gdbpath))

# ---- CONNECT ----
con <- dbConnect(SQLite(), gdbpath)

# ---- QUICK EXPLORATION ----
dbListTables(con)
dbGetQuery(con, "SELECT * FROM varInfo LIMIT 5")


# ---- Validate connection is alive ---
DBI::dbIsValid(con)

# ---- Inspect schema (important for LLM later) ----
DBI::dbGetQuery(con, "
  PRAGMA table_info(varInfo)
")

# ---- Test a slightly more complex query ----
DBI::dbGetQuery(con, "
  SELECT gene_name, COUNT(*) as n
  FROM varInfo
  GROUP BY gene_name
  LIMIT 5
")

# ---- Store connection path (debug safety) ----
print(gdbpath)

