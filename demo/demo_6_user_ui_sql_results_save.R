#DEMO_6: UI (SQL Transparency + Results + Save)

library(shiny)
library(bslib)
library(DT)

ui <- page_sidebar(
  sidebar = tagList(
    textAreaInput("user_query", "Ask a question:", height = "100px"),
    actionButton("run_query", "Run"),
    actionButton("save_chat", "💾 Save Chat History")
  ),
  
  # ✅ NEW: CONTEXT PANEL
  card(
    card_header("About this tool"),
    verbatimTextOutput("context")
  ),
  
  card(
    card_header("Generated SQL"),
    verbatimTextOutput("sql")
  ),
  
  card(
    card_header("Query Results"),
    DT::dataTableOutput("table")
  )
)


# ---- Checks and Controls ----
ui

# ----
shinyApp(ui = ui, server = function(input, output) {})

# ---- 
verbatimTextOutput("context")

# ----
names(ui)


#removed
#ui <- page_sidebar(
#sidebar = tagList(
# qc$sidebar(), #this was removed, causing "Error in if: argument is of length zero"
#actionButton("save_chat", "💾 Save Chat History")
#) ...
