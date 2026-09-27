# ------------------------------------------------------------
# 200_check_ollama_config.R
#
# PURPOSE
# -------
# Validate Ollama and NL -> SQL generation for:
# - synthetic
# - full_gdb
#
# Checks:
# 1. Ollama availability
# 2. Installed and selected model
# 3. Database context
# 4. Mode-specific prompt content
# 5. SQL generation
# 6. SQL execution
# 7. Generation timing
# ------------------------------------------------------------

library(DBI)
library(ollamar)
library(here)

source(here("R", "01_db_connection.R"))
source(here("R", "02_ollama_config.R"))


cat("
=====================================
OLLAMA CONFIG CHECK
=====================================
")


# ------------------------------------------------------------
# 1. OLLAMA AND DATABASE CONNECTION
# ------------------------------------------------------------

cat("\n[1] Checking connections\n")

if (!exists("con") || !DBI::dbIsValid(con)) {
  stop("Database connection is not valid.")
}

test_connection("http://localhost:11434")

cat("Database connection valid\n")
cat("Ollama connection valid\n")
cat("DB_MODE:", DB_MODE, "\n")


# ------------------------------------------------------------
# 2. AVAILABLE AND SELECTED MODEL
# ------------------------------------------------------------

cat("\n[2] Checking models\n")

models <- ollamar::list_models()

model_list <- models$model

if (is.null(model_list)) {
  model_list <- models$name
}

if (length(model_list) == 0) {
  stop("No Ollama models are installed.")
}

print(model_list)

if (!model_name %in% model_list) {
  stop(
    "Selected model is not installed: ",
    model_name
  )
}

cat("Selected model:", model_name, "\n")


# ------------------------------------------------------------
# 3. DATABASE CONTEXT
# ------------------------------------------------------------

cat("\n[3] Checking database context\n")

ctx <- get_active_context()

str(ctx)

if (DB_MODE == "synthetic") {
  
  if (
    is.null(ctx$table) ||
    ctx$table != "varInfo_synthetic"
  ) {
    stop(
      "Synthetic mode returned an unexpected context."
    )
  }
  
} else if (DB_MODE == "full_gdb") {
  
  if (
    is.null(ctx$tables) ||
    length(ctx$tables) == 0
  ) {
    stop(
      "full_gdb mode returned no database tables."
    )
  }
  
} else {
  
  stop("Unsupported DB_MODE: ", DB_MODE)
}

cat("Context valid for:", DB_MODE, "\n")


# ------------------------------------------------------------
# 4. MODE-SPECIFIC PROMPT CHECK
# ------------------------------------------------------------

cat("\n[4] Testing prompt construction\n")

test_query <- "show first 5 rows"

prompt <- build_prompt(
  test_query,
  con,
  ctx
)


# ----------------------------------------------------------
# SYNTHETIC PROMPT
# ----------------------------------------------------------

if (DB_MODE == "synthetic") {
  
  required_terms <- c(
    "varInfo_synthetic",
    "VAR_id",
    "gene_name"
  )
  
  missing_terms <- required_terms[
    !vapply(
      required_terms,
      function(x) {
        grepl(x, prompt, fixed = TRUE)
      },
      logical(1)
    )
  ]
  
  if (length(missing_terms) > 0) {
    stop(
      "Synthetic prompt is missing expected content: ",
      paste(missing_terms, collapse = ", ")
    )
  }
  
  cat("Synthetic schema context validated\n")
}


# ----------------------------------------------------------
# FULL_GDB PROMPT
# ----------------------------------------------------------

if (DB_MODE == "full_gdb") {
  
  required_schema_terms <- c(
    "Table: varInfo",
    "Table: var",
    "Table: dosage",
    "Table: pheno",
    "Table: SM",
    "Table: anno",
    "Table: cohort",
    "Table: meta",
    "Table: var_ranges"
  )
  
  missing_schema_terms <- required_schema_terms[
    !vapply(
      required_schema_terms,
      function(x) {
        grepl(x, prompt, fixed = TRUE)
      },
      logical(1)
    )
  ]
  
  if (length(missing_schema_terms) > 0) {
    stop(
      "Full-GDB prompt is missing table schema: ",
      paste(missing_schema_terms, collapse = ", ")
    )
  }
  
  required_relationships <- c(
    "varInfo.VAR_id = var.VAR_id",
    "varInfo.VAR_id = dosage.VAR_id",
    "var.VAR_id = dosage.VAR_id",
    "SM.IID = pheno.IID"
  )
  
  missing_relationships <- required_relationships[
    !vapply(
      required_relationships,
      function(x) {
        grepl(x, prompt, fixed = TRUE)
      },
      logical(1)
    )
  ]
  
  if (length(missing_relationships) > 0) {
    stop(
      "Full-GDB prompt is missing relationship context: ",
      paste(missing_relationships, collapse = ", ")
    )
  }
  
  # varInfo_synthetic must not be advertised in full_gdb.
  if (grepl(
    "Table: varInfo_synthetic",
    prompt,
    fixed = TRUE
  )) {
    stop(
      "Full-GDB prompt incorrectly exposes varInfo_synthetic."
    )
  }
  
  cat("Full-GDB schema and relationships validated\n")
}


# ------------------------------------------------------------
# 5. SQL GENERATION
# ------------------------------------------------------------

cat("\n[5] Testing NL -> SQL generation\n")

sql <- generate_sql_ollama(
  test_query,
  con,
  ctx
)

if (
  length(sql) != 1 ||
  is.na(sql) ||
  !nzchar(sql)
) {
  stop("SQL generation returned no usable SQL.")
}

if (!grepl(
  "^SELECT\\b",
  trimws(sql),
  ignore.case = TRUE
)) {
  stop(
    "Generated SQL is not a SELECT statement: ",
    sql
  )
}

cat("\nGenerated SQL:\n")
cat("-------------------------------------\n")
cat(sql, "\n")
cat("-------------------------------------\n")

cat("SQL generation successful\n")


# ------------------------------------------------------------
# 6. SQL EXECUTION
# ------------------------------------------------------------

cat("\n[6] Testing SQL execution\n")

result <- DBI::dbGetQuery(
  con,
  sql
)

print(result)

cat(
  "Rows returned:",
  nrow(result),
  "\n"
)

cat("SQL execution successful\n")


# ------------------------------------------------------------
# 7. GENERATION PERFORMANCE
# ------------------------------------------------------------

cat("\n[7] Measuring NL -> SQL generation time\n")

elapsed <- system.time({
  
  generate_sql_ollama(
    "count rows",
    con,
    ctx
  )
  
})

cat(
  "Elapsed:",
  round(
    as.numeric(elapsed["elapsed"]),
    2
  ),
  "seconds\n"
)


# ------------------------------------------------------------
# 8. FINAL STATUS AND CLEANUP
# ------------------------------------------------------------

cat("
=====================================
OLLAMA CONFIG CHECK PASSED
=====================================
")

cat("Mode:", DB_MODE, "\n")
cat("Model:", model_name, "\n")

close_connection()