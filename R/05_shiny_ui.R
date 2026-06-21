# ------------------------------------------------------------
# 05_shiny_ui.R
#
# PURPOSE
# -------
# Shiny UI for NL → SQL query interface
#
# FEATURES:
# ---------
# - Natural language query input
# - SQL transparency
# - Result table display
# - Context/guidance panel
# - Save query history
# - Execution status indicator
#
# NOTES:
# ------
# - Uses rvat_greeting.md for context
# - Server logic handled in 06_shiny_server.R
# ------------------------------------------------------------

library(shiny)
library(bslib)
library(DT)

# ------------------------------------------------------------
# UI DEFINITION
# ------------------------------------------------------------

ui <- page_sidebar(
  
  title = "RVAT NL Query Interface",
  
  sidebar = tagList(
    
    textAreaInput(
      "user_query",
      "Ask a question (NL → SQL):",
      height = "120px",
      placeholder = "e.g. Show the top 10 variants by impact..."
    ),
    
    actionButton(
      "run_query",
      "▶ Run Query",
      class = "btn-primary"
    ),
    
    tags$br(),
    tags$br(),
    
    actionButton(
      "save_chat",
      "💾 Save History",
      class = "btn-success"
    ),
    
    tags$hr(),
    
    # ✅ STATUS INDICATOR
    uiOutput("status")
  ),
  
  # ----------------------------------------------------------
  # MAIN PANELS
  # ----------------------------------------------------------
  
  layout_column_wrap(
    
    width = 1,
    
    # --------------------------------------------------------
    # CONTEXT PANEL
    # --------------------------------------------------------
    card(
      card_header("About this tool"),
      includeMarkdown("app/rvat_greeting.md")
    ),
    
    # --------------------------------------------------------
    # SQL PANEL
    # --------------------------------------------------------
    card(
      card_header("Generated SQL"),
      verbatimTextOutput("sql")
    ),
    
    # --------------------------------------------------------
    # RESULT PANEL
    # --------------------------------------------------------
    card(
      card_header("Query Results"),
      DT::dataTableOutput("table")
    )
  )
)