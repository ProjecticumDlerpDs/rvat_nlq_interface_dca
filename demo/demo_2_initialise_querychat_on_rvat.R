#DEMO_2: Initialize QueryChat on RVAT Database


#troubleshooting:
exists("con")
exists("model_name")

print(model_name)
DBI::dbIsValid(con)

str(qc)

install.packages("here") #must be added to renv!

# ----START ----

library(here)

# ---- LOAD GREETING ----
greeting <- paste(
  readLines(here("demo", "rvat_greeting.md")),
  collapse = "\n"
)

# ---- EXTENDED CONTEXT FOR UI ----
extended_message <- paste(
  greeting,
  "\n\n## RVAT Database Context",
  "- SQLite database with genetic variant data",
  "- Table: varInfo",
  "",
  "## Example questions:",
  "- Show first 5 rows",
  "- Count variants per chromosome",
  "- Show variants for a specific gene",
  "- What is the distribution of variants?",
  sep = "\n"
)

# ✅ ---- OPTIONAL IMPROVEMENT (ADD HERE) ----

schema_info <- DBI::dbGetQuery(con, "PRAGMA table_info(varInfo)")
columns <- paste(schema_info$name, collapse = ", ")

extended_message <- paste(
  extended_message,
  "\n\n## Columns:",
  columns
)


# ---- Check and troubleshooting ----
cat(greeting)

#
cat(extended_message)

#
file.exists(here::here("demo", "rvat_greeting.md"))
# [1] TRUE

#
schema_info

#
columns

#
generate_sql_ollama()


#qc$chat("Count number of variants in NEK1")
#qc$app() took some 5 minutes to completely load. Ref value. 



# ---- generate once (faster reuse) ----
greeting_text <- qc$generate_greeting(echo = "text")

extended_greeting <- paste(
  greeting_text,
  "\n\n## RVAT Database Context",
  "- Genetic variant data (SQLite-backed)",
  "- Variant annotations and metadata",
  "- Optimized for analytical querying",
  "\n\n## Example questions:",
  "- Count variants per chromosome",
  "- Show variant distribution",
  "- What are the most frequent variants?",
  sep = "\n"
)

writeLines(extended_greeting, "rvat_greeting.md")
