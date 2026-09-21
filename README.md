---
output:
  html_document: default
  word_document: default
  pdf_document: default
---
RVAT NLQ Interface
================
Version: 0.3.1 \
Date:    2026.09.04


A Natural Language Query (NLQ) interface for exploring RVAT genetic
variant data using locally hosted Large Language Models (LLMs).


================

# Introduction

## RVAT Natural Language Querey (NLQ) Interface

### Project Objective
This project evaluates whether Large Language Models (LLMs) can effectively 
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

The application consists of six main components:

| Script                  | Purpose                                |
| ----------------------- | -------------------------------------- |
| `01_db_connection.R`    | Database connection management         |
| `02_ollama_config.R`    | Ollama and LLM configuration           |
| `03_query_execution.R`  | Natural language → SQL execution logic |
| `04_logging_pipeline.R` | Query logging and metadata capture     |
| `05_shiny_ui.R`         | User interface                         |
| `06_shiny_server.R`     | Application server logic               |


These components are orchestrated through:
"/aap/rvat_nlq_app.R""

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


## Creating a Copy of this Project 

1.	Clone the Github repository
2.	Make a corresponding R project in Rstudio(Posit)
3.	Run renv::restore() in console


## Verify package dependencies (optional)

4. Run "/scripts/00_renv_setup.R" to verify the restored environment

## Configure LLM (optional) 
If using another LLM than default (=qwen2.5-coder:latest), configure chosen LLM.

5. Open "/R/02_ollama_config.R"and change the following line of code:
model_name <- "qwen2.5-coder:latest" (line 131, under MODEL CONFIGURATION (USER EDITABLE))


## Run the application

6. Run "/app/rvat_nlq_app.R"


# Utilities and Trobleshooting
(coming soon)
