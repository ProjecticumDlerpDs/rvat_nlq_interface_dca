# ------------------------------------------------------------
# 06_shiny_server.R
#
# PURPOSE
# -------
# Implement Shiny server behaviour for the RVAT NL -> SQL
# application.
#
# RESPONSIBILITIES:
# -----------------
# - Receive natural-language queries from the UI
# - Execute queries through the logging pipeline
# - Display generated SQL and query results
# - Track query execution status
# - Display query and application errors to the user
# - Save in-memory query history to RDS files
# - Clear in-memory history after successful saving
#
# QUERY STATES:
# -------------
# Ready
# - no query is currently running
#
# Running...
# - query execution has started
#
# Completed
# - query execution completed without an execution error
#
# Error occurred
# - the query pipeline returned an error or an unexpected
# application error occurred
#
# DESIGN:
# -------
# - Executes queries through 04_logging_pipeline.R
# - Does not generate SQL directly
# - Does not execute SQL directly against the database
# - Does not modify generated SQL
# - Defers query execution through later()
# - Uses the active Shiny session for user notifications
#
# USED BY:
# --------
# - rvat_nlq_app.R
# ------------------------------------------------------------


library(shiny)
library(DT)
library(later)
library(here)


# ------------------------------------------------------------
# SERVER LOGIC
# ------------------------------------------------------------

server <- function(input, output, session) {
  
# ----------------------------------------------------------
# REACTIVE STATE
# ----------------------------------------------------------
  
result_data <- reactiveVal(NULL)
result_sql <- reactiveVal(NULL)
status_msg <- reactiveVal("Ready")
  
  
# ----------------------------------------------------------
# STATUS OUTPUT
# ----------------------------------------------------------
  
output$status <- renderUI({
    
  msg <- status_msg()
    
  color <- switch(
    msg,
    "Running..." = "orange",
    "Completed" = "green",
    "Error occurred" = "red",
    "Ready" = "gray",
    "gray"
    )
    
  tags$div(
    style = paste0(
      "font-weight: bold; color:",
      color,
      ";"
    ),
    paste(
    "Status:",
    msg
    )
  )
})
  
  
# ----------------------------------------------------------
# RUN QUERY
# ----------------------------------------------------------

observeEvent(input$run_query, {
  
  req(input$user_query)
  
  status_msg("Running...")
  result_data(NULL)
  result_sql(NULL)
  
  query <- input$user_query
  
  later::later(
    function() {
      
      tryCatch(
        {
          
          res <- log_query_execution(
            query,
            con,
            verbose = FALSE
          )
          
          result_data(res$data)
          result_sql(res$sql)
          
          if (is.null(res$error)) {
            
            status_msg("Completed")
            
          } else {
            
            status_msg("Error occurred")
            
            shiny::showNotification(
              res$error,
              type = "error",
              session = session
            )
          }
          
        },
        error = function(e) {
          
          status_msg("Error occurred")
          
          shiny::showNotification(
            paste(
              "Unexpected error:",
              e$message
            ),
            type = "error",
            session = session
          )
        }
      )
      
    },
    delay = 0.1
  )
  
})
  
  
# ----------------------------------------------------------
# DISPLAY TABLE
# ----------------------------------------------------------
  
output$table <- DT::renderDataTable({
    
  req(result_data())
    
  DT::datatable(
    result_data(),
    options = list(
      pageLength = 10,
      scrollX = TRUE
    )
  )
})
  
  
# ----------------------------------------------------------
# DISPLAY SQL
# ----------------------------------------------------------
  
output$sql <- renderText({
    
  result_sql() %||%
    "No query executed yet"
})
  
  
# ----------------------------------------------------------
# SAVE QUERY HISTORY
# ----------------------------------------------------------
  
observeEvent(input$save_chat, {
    
  df_new <- get_query_log()
    
  if (is.null(df_new)) {
      
    shiny::showNotification(
      "No logs to save.",
      type = "warning",
      session = session
    )
      
    return(NULL)
  }
    
    
# --------------------------------------------------------
# OUTPUT DIRECTORY
# --------------------------------------------------------
    
  dir.create(
    here("data", "raw"),
    recursive = TRUE,
    showWarnings = FALSE
  )
    
    
# --------------------------------------------------------
# FILE IDENTIFIERS
# --------------------------------------------------------
    
  model_name_safe <- gsub(
    "[:/]",
    "_",
    unique(df_new$model)[1]
  )
    
  ts <- format(
    Sys.time(),
    "%Y%m%d_%H%M%S"
  )
    
    
# --------------------------------------------------------
# SNAPSHOT
# --------------------------------------------------------
    
snapshot_file <- here::here(
  "data",
  "raw",
  paste0(
    "query_log_",
    model_name_safe,
    "_",
    ts,
    ".rds"
  )
)
    
saveRDS(
  df_new,
  snapshot_file
)
    
    
# --------------------------------------------------------
# CUMULATIVE HISTORY
# --------------------------------------------------------
    
cumulative_file <- here::here(
  "data",
  "raw",
  paste0(
    "query_log_",
    model_name_safe,
    "_ALL.rds"
  )
)
  
if (file.exists(cumulative_file)) {
    
  df_existing <- readRDS(
    cumulative_file
  )
    
  df_combined <- rbind(
    df_existing,
    df_new
  )
      
} else {
      
  df_combined <- df_new
}
    
saveRDS(
  df_combined,
  cumulative_file
)
    
    
# --------------------------------------------------------
# CLEAR IN-MEMORY LOG
# --------------------------------------------------------
    
clear_query_log()
    
    
# --------------------------------------------------------
# USER NOTIFICATION
# --------------------------------------------------------
    
shiny::showNotification(
  paste(
    "Saved snapshot + updated cumulative:",
    basename(snapshot_file)
  ),
  type = "message",
  session = session
  )
 })
}