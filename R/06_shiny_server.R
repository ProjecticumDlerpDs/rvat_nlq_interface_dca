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
  # RUN QUERY (FIXED VERSION)
  # ----------------------------------------------------------
  
  observeEvent(input$run_query, {
    
    req(input$user_query)
    
    # ✅ Update status immediately
    status_msg("Running...")
    
    # ✅ Capture reactive value BEFORE async call
    query <- input$user_query
    
    # ✅ Async execution (non-blocking UI)
    later::later(function() {
      
      tryCatch({
        
        res <- log_query_execution(query, con, verbose = FALSE)
        
        # ✅ Update results
        result_data(res$data)
        result_sql(res$sql)
        
        # ✅ Update status
        if (is.null(res$error)) {
          status_msg("Completed")
        } else {
          status_msg("Error occurred")
          showNotification(res$error, type = "error")
        }
        
      }, error = function(e) {
        
        # ✅ Catch unexpected failures
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
  # SAVE LOGS
  # ----------------------------------------------------------
  
  observeEvent(input$save_chat, {
    
    df <- get_query_log()
    
    if (is.null(df)) {
      showNotification("No logs to save.", type = "warning")
      return(NULL)
    }
    
    dir.create("data/raw", recursive = TRUE, showWarnings = FALSE)
    
    filename <- paste0(
      "data/raw/query_log_",
      format(Sys.time(), "%Y%m%d_%H%M%S"),
      ".rds"
    )
    
    saveRDS(df, filename)
    
    showNotification(
      paste("Log saved:", basename(filename)),
      type = "message"
    )
  })
}