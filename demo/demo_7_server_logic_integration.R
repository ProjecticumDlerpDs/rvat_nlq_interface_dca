#DEMO_7: Server Logic (Core Integration)

server <- function(input, output, session) {
  
  # ---- REACTIVE STORAGE ----
  result_df  <- reactiveVal(NULL)
  result_sql <- reactiveVal(NULL)
  
  # ---- DISPLAY CONTEXT ----
  output$context <- renderText({
    extended_message
  })
  
  # ---- RUN QUERY ----
  observeEvent(input$run_query, {
    
    req(input$user_query)
    
    # ✅ Use FULL pipeline (demo_5)
    res <- log_query_execution(con, input$user_query)
    
    # ✅ Update UI
    result_df(res$data)
    result_sql(res$sql)
  })
  
  # ---- DISPLAY TABLE ----
  output$table <- DT::renderDataTable({
    req(result_df())
    result_df()
  })
  
  # ---- DISPLAY SQL ----
  output$sql <- renderText({
    result_sql() %||% "No query yet"
  })
  
  # ---- SAVE LOGS ----
  observeEvent(input$save_chat, {
    
    df <- get_timing_log()
    
    df <- df %>%
      mutate(
        model = model_name %||% "ollama",
        total_queries = n()
      )
    
    dir.create("data/raw", recursive = TRUE, showWarnings = FALSE)
    saveRDS(df, "data/raw/querychat_raw.rds")
    
    message("Timing log saved.")
  })
}
``