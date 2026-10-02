# ------------------------------------------------------------
# 02_ollama_config.R
#
# PURPOSE
# -------
# Configure Ollama for NL -> SQL generation in the RVAT
# application.
#
# RESPONSIBILITIES:
# -----------------
# - Check availability of the local Ollama service
# - Detect locally installed Ollama models
# - Select the configured model used by the application
# - Provide model metadata used by the logging pipeline
# - Build database-mode-specific prompts
# - Define the full_gdb tables and relationships provided to
# the LLM
# - Generate SQL from natural-language questions
#
# DATABASE MODES:
# ---------------
# synthetic
# - uses the restricted table context supplied by
# 01_db_connection.R
# - provides varInfo_synthetic and its columns to the LLM
#
# full_gdb
# - uses the database context supplied by 01_db_connection.R
# - provides the defined production tables and their columns
# to the LLM
# - provides explicitly defined database relationships
# - excludes varInfo_synthetic from the full_gdb prompt
#
# CONFIGURATION:
# --------------
# - model_name defines the model used by the application
# - the selected model must be installed in Ollama
#
# DESIGN:
# -------
# - Builds prompts from the active database context
# - Returns generated SQL as a character string
# - Does not execute generated SQL against the database
# - Does not implement query logging
# - Does not contain Shiny/UI logic
#
# USED BY:
# --------
# - 03_query_execution.R
# - 04_logging_pipeline.R through model metadata functions
# - production Shiny application
# ------------------------------------------------------------

library(ollamar)
library(httr2)
library(DBI)
library(httr)

# ------------------------------------------------------------
# CHECK OLLAMA CONNECTION
# ------------------------------------------------------------

cat("
=====================================
OLLAMA CONFIGURATION
=====================================
")

test_connection("http://localhost:11434")


# ------------------------------------------------------------
# LIST AVAILABLE MODELS
# ------------------------------------------------------------
#
# ollamar::list_models() returns the models installed in the
# local Ollama environment.
#
# The production pipeline uses the model configured through
# model_name below. Other installed models remain available
# for separate evaluation workflows.
# ------------------------------------------------------------

models <- ollamar::list_models()

model_list <- models$model

if (is.null(model_list)) {
  model_list <- models$name
}


# ------------------------------------------------------------
# VALIDATE MODELS EXIST
# ------------------------------------------------------------

if (length(model_list) == 0) {
  stop(
    "No Ollama models found. Run: ollama pull <model>"
  )
}


# ------------------------------------------------------------
# REPORT MODEL ENVIRONMENT
# ------------------------------------------------------------

if (length(model_list) <= 1) {
  
  message(
    "ℹ️ One Ollama model is installed"
  )
  
} else {
  
  message(
    "ℹ️ Multiple Ollama models are installed; ",
    "production will use the configured model below"
  )
}


# ------------------------------------------------------------
# DISPLAY MODELS
# ------------------------------------------------------------

cat("\nAvailable models:\n")

print(model_list)


# ------------------------------------------------------------
# HELPER FUNCTIONS: MODEL METADATA
# ------------------------------------------------------------

extract_params <- function(model_name) {
  
  idx <- match(
    model_name,
    models$name
  )
  
  if (
    is.na(idx) ||
    !"parameter_size" %in% names(models)
  ) {
    return(NA_character_)
  }
  
  value <- models$parameter_size[idx]
  
  if (
    length(value) == 0 ||
    is.na(value) ||
    !nzchar(value)
  ) {
    return(NA_character_)
  }
  
  return(as.character(value))
}


infer_capability <- function(model_name) {
  
  if (
    grepl(
      "coder|sqlcoder",
      model_name,
      ignore.case = TRUE
    )
  ) {
    return("High (code/SQL optimized)")
  }
  
  if (
    grepl(
      "qwen|llama|gemma|phi",
      model_name,
      ignore.case = TRUE
    )
  ) {
    return("High (general reasoning)")
  }
  
  if (
    grepl(
      "mistral",
      model_name,
      ignore.case = TRUE
    )
  ) {
    return("Medium (fast inference)")
  }
  
  return("Unknown")
}


get_temperature <- function(model) {
  
  tryCatch({
    
    res <- httr::POST(
      "http://localhost:11434/api/show",
      body = list(
        name = model
      ),
      encode = "json"
    )
    
    result <- httr::content(
      res,
      "parsed"
    )
    
    mf <- result$modelfile
    
    if (is.null(mf)) {
      return(NA)
    }
    
    temp_line <- grep(
      "PARAMETER[[:space:]]+temperature",
      mf,
      value = TRUE
    )
    
    if (length(temp_line) == 0) {
      return(NA)
    }
    
    numeric_part <- sub(
      ".*temperature[[:space:]=]+([0-9.]+).*",
      "\\1",
      temp_line
    )
    
    value <- as.numeric(numeric_part)
    
    if (is.na(value)) {
      return(NA)
    }
    
    return(value)
    
  }, error = function(e) {
    
    return(NA)
    
  })
}

# ------------------------------------------------------------
# MODEL CONFIGURATION
# ------------------------------------------------------------

model_name <- "qwen2.5-coder:latest"

cat(
  "\n✅ Selected model:",
  model_name,
  "\n"
)

cat(
  "👉 To change model, edit 'model_name' in this script\n"
)


# ------------------------------------------------------------
# MODEL INFO
# ------------------------------------------------------------

model_params <- extract_params(
  model_name
)

model_capability <- infer_capability(
  model_name
)

model_temp <- get_temperature(
  model_name
)


cat("\n[Model Info]\n")

cat(
  "Model:",
  model_name,
  "\n"
)

cat(
  "Parameters:",
  ifelse(
    is.na(model_params),
    "Unknown",
    model_params
  ),
  "\n"
)

cat(
  "Capability:",
  model_capability,
  "\n"
)

cat("Temperature:\n")

if (is.na(model_temp)) {
  
  cat(
    "- Not explicitly defined in model\n"
  )
  
  cat(
    "- Using Ollama default behavior\n"
  )
  
} else {
  
  cat(
    "- Defined in model:",
    model_temp,
    "\n"
  )
}


# ------------------------------------------------------------
# PROMPT BUILDER
# ------------------------------------------------------------

build_prompt <- function(
    user_query,
    con,
    ctx
) {
  
# ----------------------------------------------------------
# SYNTHETIC MODE
# ----------------------------------------------------------
  
if (ctx$restriction) {
    
  cols <- DBI::dbListFields(
    con,
    ctx$table
  )
    
  return(
    paste(
      "You are a SQLite SQL generator.",
      paste0("Use table: ", ctx$table),
      paste(
        "Columns:",
        paste(cols, collapse = ", ")
      ),
      "Generate a SQLite query using ONLY the table and columns defined above.",
      "Return ONLY a valid SQLite SELECT statement.",
      "Do not return explanations or markdown.",
      "",
      "User question:",
      user_query
    )
  )
}
  
# ----------------------------------------------------------
# FULL_GDB MODE
# ----------------------------------------------------------
  
available_tables <- DBI::dbListTables(con)
  
# Expose the real full-GDB tables to the NL -> SQL model.
# varInfo_synthetic is intentionally excluded because it is
# an application-generated development table, not part of the
# production full-GDB schema.
full_gdb_tables <- c(
  "varInfo",
  "var",
  "dosage",
  "pheno",
  "SM",
  "anno",
  "cohort",
  "meta",
  "var_ranges"
)
  
full_gdb_tables <- full_gdb_tables[
  full_gdb_tables %in% available_tables
]
  
if (length(full_gdb_tables) == 0) {
  stop("No expected full_gdb tables were found.")
}
  
  
# ----------------------------------------------------------
# BUILD TABLE SCHEMA
# ----------------------------------------------------------
  
schema_parts <- lapply(
  full_gdb_tables,
  function(tbl) {
    
    cols <- DBI::dbListFields(
      con,
      tbl
    )
      
    paste0(
      "Table: ",
      tbl,
      "\nColumns: ",
      paste(cols, collapse = ", ")
    )
  }
)
  
schema_text <- paste(
  unlist(schema_parts),
  collapse = "\n\n"
)
  
  
# ----------------------------------------------------------
# KNOWN DATABASE RELATIONSHIPS
# ----------------------------------------------------------
  
relationship_text <- paste(
  "Known relationships:",
  "varInfo.VAR_id = var.VAR_id",
  "varInfo.VAR_id = dosage.VAR_id",
  "var.VAR_id = dosage.VAR_id",
  "SM.IID = pheno.IID",
  sep = "\n"
)
  
  
# ----------------------------------------------------------
# BUILD FULL_GDB PROMPT
# ----------------------------------------------------------
  
return(
  paste(
    "You are a SQLite SQL generator.",
    "",
    "The database contains the following tables and columns:",
    "",
    schema_text,
    "",
    relationship_text,
   "",
    "Rules:",
    "Use only tables and columns defined above.",
    "Use only the explicitly stated relationships when joining tables.",
    "Do not infer joins merely because columns have similar names.",
    "Do not join phenotype/sample data to dosage or variant data unless an explicit relationship is provided.",
    "The GT column in dosage is a BLOB and must not be interpreted as a conventional relational column.",
    "Prefer the smallest number of tables necessary to answer the question.",
    "For gene and variant annotation questions, prefer varInfo when it contains all required information.",
    "Return ONLY a valid SQLite SELECT statement.",
    "Do not return explanations or markdown.",
    "",
    "User question:",
    user_query
  )
)
}

# ------------------------------------------------------------
# SQL GENERATOR
# ------------------------------------------------------------

generate_sql_ollama <- function(user_query, con, ctx) {
  
  prompt <- build_prompt(user_query, con, ctx)
  
  resp <- ollamar::chat(
    model = model_name,
    messages = list(
      list(
        role = "user",
        content = prompt
      )
    )
  )
  
  parsed <- resp |> httr2::resp_body_json()
  sql <- parsed$message$content
  
  prompt_tokens <- parsed$prompt_eval_count
  generated_tokens <- parsed$eval_count
  
  sql <- gsub(
    "```sql",
    "",
    sql,
    ignore.case = TRUE
  )
  
  sql <- gsub(
    "```",
    "",
    sql
  )
  
  sql <- sub(
    ".*?(SELECT)",
    "\\1",
    sql,
    ignore.case = TRUE
  )
  
  sql <- trimws(sql)
  
  if (nchar(sql) == 0) {
    stop("No SQL returned from model")
  }
  
  attr(sql, "prompt_tokens") <- if (is.null(prompt_tokens)) {
    NA_integer_
  } else {
    as.integer(prompt_tokens)
  }
  
  attr(sql, "generated_tokens") <- if (is.null(generated_tokens)) {
    NA_integer_
  } else {
    as.integer(generated_tokens)
  }  
  
  return(sql)
}