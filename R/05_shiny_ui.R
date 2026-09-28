# ------------------------------------------------------------
# 05_shiny_ui.R
#
# PURPOSE
# -------
# Define the user interface for the RVAT NL -> SQL application.
#
# FEATURES:
# ---------
# - Natural-language query input
# - Run Query action
# - Save History action
# - Execution status display
# - Generated SQL display
# - Query-result table
# - Application information panel
#
# DESIGN:
# -------
# - Defines UI elements and output containers only
# - Does not execute queries
# - Does not generate SQL
# - Does not implement logging or file storage
# - Server behaviour is defined in 06_shiny_server.R
#
# USED BY:
# --------
# - rvat_nlq_app.R
# ------------------------------------------------------------

library(shiny)
library(bslib)
library(DT)
library(here)

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
      includeMarkdown(here("app", "rvat_greeting.md"))
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