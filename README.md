RVAT NLQ Interface
================
Version: 0.4 \
Date:    2026.09.21


A Natural Language Query (NLQ) interface for exploring RVAT genetic
variant data using locally hosted Large Language Models (LLMs).


================

# Introduction

## RVAT Natural Language Query (NLQ) Interface

### Project Objective
This project evaluates whether Large Language Models (LLM's) can effectively 
translate natural language questions into executable SQL queries for scientific 
analysis and research of datasets against the RVAT database.

**RVAT** (Rare Variant Association Toolkit) was developed by 
[Kevin Kenna and Paul Hop](https://kennalab.github.io/rvat/articles/basics.html) 
and is an R package and command-line toolkit designed for large-scale genetic 
association testing using rare genomic variants.

The RVAT NLQ Interface allows users to interact with a database using natural 
language rather than writing SQL manually. 

A user's question is translated into SQL by an Ollama-hosted LLM, executed 
against the target database, and the results are returned through a Shiny-based 
web interface.

### Research Question

The primary objective is to assess:

To what extent can a locally hosted Large Language Model (LLM), integrated within an 
R environment, translate natural language queries into accurate SQL queries and 
use them to retrieve relevant data from an ALS-specific RVAT database, as evaluated 
using predefined benchmark questions?


The project establishes three core technical objectives:

•  be used as an evaluation framework for Natural Language → SQL generation; \
•  serve as a reference implementation of a local, privacy-preserving LLM-driven query interface; \
•  demonstrate reproducible R/Shiny application that can be deployed in research or server environments. \

------------------------------------------------------------------------


# Architecture Overview

The application consists of six main components, grouped under /R folder:

| Script                  | Purpose                                |
| ----------------------- | -------------------------------------- |
| `01_db_connection.R`    | Database connection management         |
| `02_ollama_config.R`    | Ollama and LLM configuration           |
| `03_query_execution.R`  | Natural language → SQL execution logic |
| `04_logging_pipeline.R` | Query logging and metadata capture     |
| `05_shiny_ui.R`         | User interface                         |
| `06_shiny_server.R`     | Application server logic               |


These components are orchestrated through:
"/app/rvat_nlq_app.R""

This is the **only script that end users need to run **.
All other scripts are loaded automatically.

------------------------------------------------------------------------



# System Requirements

## Hardware and Software Specifications

**Server Environment (Recommended)**

For full reproducibility:

• Linux Server (x86_64-pc-linux-gnu)                \
• 32 CPU cores                                      \
• 64 GB RAM (~49GB memory available)                \
• R version 4.5.0 (2025-04-11)                      \ 
• RStudio 2025.05.0 Build 496.pro5, Posit Software  \
• Ollama installed (version 0.21.0)                 \
👉 https://ollama.com/                              \
• One or more LLM's (default: qwen2.5-coder:latest)             

This configuration was used throughout development and validation.


**Local Laptop Environment**\
Experimental trial:\
Local execution is supported although very experimental at this stage and much dependent on available hardware.

Please 
Smaller models generally perform well:

mistral:latest    \
qwen2.5-coder:latest    

Large models may experience reduced performance or even freeze:

qwen3:8b    \
sqlcoder:latest   

Depending on available CPU and RAM these models may:

- require several minutes to respond
- consume substantial resources
- produce unstable behaviour during long-running requests

This behaviour is related to hardware constraints rather than application logic.

Laptop Reference Specifications:\
• Dell Latitude 5220                                    \
• Windows 11 Pro (x64)                                  \
• CPU: 4 cores                                          \
• 8GB RAM (available memory 7.5GB)                      \
• Disk space to download Ollama/LLM's locally           


**Windows & Bioconductor Note**
RStudio and R do not natively require Bioconductor on Windows. However, core genomic dependencies used in this project (such as `SummarizedExperiment`, required upstream by `rvat`) frequently fail to resolve automatically on Windows via standard `install.packages()`. 

While macOS and Linux typically handle these upstream Bioconductor dependencies dynamically, Windows environments require explicit initialization of `BiocManager` to register the necessary repositories and build binary packages smoothly.

**Setup Script for Laptop Users**
To streamline setup and resolve cross-platform dependency issues (especially on Windows), an automated setup script is included in the project root: `/scripts/00_renv_setup.R`.

This script automatically:
* Verifies and installs `renv` and `BiocManager` (ensuring correct Bioconductor repository mapping).
* Restores the exact project dependencies via `renv::restore()`.
* Conducts post-installation checks to ensure core packages (`shiny`, `dplyr`, `DBI`, `RSQLite`, `rvat`, `ollamar`) are ready.


---
# Getting Started

Before starting, ensure you have met the (minimum) 'Hardware and Software Specifications' described above.
This Getting Started instructions are meant for **Server Environment (Recommended)**. 

For **Local Laptop Environment**, see above.   


### Creating a Copy of this Project 

1.	Clone the Github repository
2.	Make a corresponding R project in Rstudio(Posit)
3.	Run renv::restore() in console


### Verify Package Dependencies (optional)

4. Run `/scripts/00_renv_setup.R` to verify the restored environment

### Configure LLM (optional) 
If using another LLM than default (= qwen2.5-coder:latest), configure chosen LLM as follows before running app:

5. Open `/R/02_ollama_config.R` and edit the following line of code accordingly: \
model_name <- "qwen2.5-coder:latest" (line 131, under [MODEL CONFIGURATION (USER EDITABLE)])

### Database Usage Mode (optional)
By default, database mode is set to "synthetic" as defined in `R/01_db_connection.R`, which uses an augmented, subset of the database
based on the `varInfo` table. To use all the full RVAT geodatabase schema (e.g. varInfo, var, pheno, anno, meta, dosage, etc.),
switch to `full_gdb` before running the application by:

6. Open `/R/01_db_connection.R`, follow the instructions and edit lines 44-48 under 
[DEFAULT MODE (CHANGE FOR PRODUCTION)] by commenting / un-commenting desired setting.    

### Run the Application

7. Run "/app/rvat_nlq_app.R"


## Utilities and Trobleshooting
The `/utils/` directory contains standalone validation and troubleshooting scripts for testing individual layers of the application. 
The scripts follow the application pipeline sequentially and are intended for development and troubleshooting, not production use.

| Script | Purpose | Use case |
|---|---|---|
| `100_check_db_connection.R` | Validates database connectivity, schema access, queries, and basic performance. | Run first to verify the database and active table are accessible and functioning correctly. |
| `200_check_ollama_config.R` | Validates Ollama connectivity, model availability, prompt construction, and SQL generation. | Use when configuring or troubleshooting the local LLM and NL → SQL generation. |
| `300_check_query_execution.R` | Validates the complete NL → SQL → database execution layer, including output structure and error handling. | Use to verify that natural-language queries can be converted to SQL and executed successfully. |
| `400_check_logging_pipeline.R` | Validates query logging, model metadata, execution timing, and log management. | Use to confirm that query execution is correctly captured by the logging pipeline. |
| `500_check_shiny_ui.R` | Performs static validation of the Shiny UI structure, required components, and supporting files. | Use after UI changes to check that required inputs, outputs, and resources are present. |
| `600_check_shiny_server.R` | Validates Shiny server logic and its integration with query execution, logging, and log saving. | Use to test backend integration without launching the full Shiny application. |


