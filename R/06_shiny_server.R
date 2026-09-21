# ------------------------------------------------------------
# 06_shiny_server.R
#
# PURPOSE
# -------
# Shiny server logic for NL → SQL pipeline
#
# FEATURES:
# ---------
# - Executes queries via logging pipeline
# - Displays SQL and results
# - Tracks execution status
# - Saves query logs to file
# - Handles async execution safely
#
# DEPENDENCIES:
# -------------
# - 04_logging_pipeline.R
# - 03_query_execution.R
# - 02_ollama_config.R
# - 01_db_connection.R
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
  result_sql  <- reactiveVal(NULL)
  status_msg  <- reactiveVal("Ready")
  
  
  # ----------------------------------------------------------
  # STATUS OUTPUT
  # ----------------------------------------------------------
  
  output$status <- renderUI({
    
    msg <- status_msg()
    
    color <- switch(
      msg,
      "Running..."      = "orange",
      "Completed"       = "green",
      "Error occurred"  = "red",
      "Ready"           = "gray",
      "gray"
    )
    
    tags$div(
      style = paste0("font-weight: bold; color:", color, ";"),
      paste("Status:", msg)
    )
  })
  
  
  # ----------------------------------------------------------
  # RUN QUERY
  # ----------------------------------------------------------
  
  observeEvent(input$run_query, {
    
    req(input$user_query)
    
    status_msg("Running...")
    
    query <- input$user_query
    
    later::later(function() {
      
      tryCatch({
        
        res <- log_query_execution(query, con, verbose = FALSE)
        
        result_data(res$data)
        result_sql(res$sql)
        
        if (is.null(res$error)) {
          status_msg("Completed")
        } else {
          status_msg("Error occurred")
          showNotification(res$error, type = "error")
        }
        
      }, error = function(e) {
        
        status_msg("Error occurred")
        
        showNotification(
          paste("Unexpected error:", e$message),
          type = "error"
        )
      })
      
    }, delay = 0.1)
    
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
    result_sql() %||% "No query executed yet"
  })
  
  
  # ----------------------------------------------------------
  # SAVE LOGS (ENHANCED)
  # ----------------------------------------------------------
  
  observeEvent(input$save_chat, {
    
    df_new <- get_query_log()
    
    if (is.null(df_new)) {
      showNotification("No logs to save.", type = "warning")
      return(NULL)
    }
    
    dir.create(here("data", "raw"), recursive = TRUE, showWarnings = FALSE)
    
    model_name_safe <- gsub("[:/]", "_", unique(df_new$model)[1])
    ts <- format(Sys.time(), "%Y%m%d_%H%M%S")
    
    # Snapshot
    snapshot_file <- here::here(
      "data", "raw",
      paste0("query_log_", model_name_safe, "_", ts, ".rds")
    )
    saveRDS(df_new, snapshot_file)
    
    # Cumulative
    cumulative_file <- here::here(
      "data", "raw",
      paste0("query_log_", model_name_safe, "_ALL.rds")
    )
    
    if (file.exists(cumulative_file)) {
      df_existing <- readRDS(cumulative_file)
      df_combined <- rbind(df_existing, df_new)
    } else {
      df_combined <- df_new
    }
    
    saveRDS(df_combined, cumulative_file)
    
    # ✅ Clear memory
    clear_query_log()
    
    showNotification(
      paste("Saved snapshot + updated cumulative:",
            basename(snapshot_file)),
      type = "message"
    )
  })
  
}  # ✅ ONLY ONE closing bracket for server.  
#Remove remark after tripple checked!