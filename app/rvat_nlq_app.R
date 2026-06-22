# ------------------------------------------------------------
# rvat_nlq_app.R
#
# PURPOSE
# -------
# Entry point for the RVAT NL → SQL Shiny application
# -----------------
# - Load all pipeline components
# - Initialize application environment
# - Launch Shiny app
#
# USAGE:
# ------
# source("app/rvat_nlq_app.R")
#
# OR:
# shiny::runApp("app")
# ------------------------------------------------------------

# ------------------------------------------------------------
# LOAD DEPENDENCIES
# ------------------------------------------------------------

library(shiny)
library(here)


# ------------------------------------------------------------
# STARTUP MESSAGE
# ------------------------------------------------------------

message("Starting RVAT NLQ application...")


# ------------------------------------------------------------
# LOAD PIPELINE COMPONENTS
# ------------------------------------------------------------


source(here("R", "01_db_connection.R"))
source(here("R", "02_ollama_config.R"))
source(here("R", "03_query_execution.R"))
source(here("R", "04_logging_pipeline.R"))
source(here("R", "05_shiny_ui.R"))
source(here("R", "06_shiny_server.R"))


# ------------------------------------------------------------
# LAUNCH APPLICATION
# ------------------------------------------------------------

shinyApp(ui = ui, server = server)
#
