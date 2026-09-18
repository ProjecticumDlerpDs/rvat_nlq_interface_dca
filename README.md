RVAT NLQ Interface
================
Version: 0.3 \
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

================

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
rvat_nlq_app.R

This is the **only script that end users need to run**.
All other scripts are loaded automatically.
------------------------------------------------------------------------


================

# System Requirements
##Reference Environment 
The application was developed and validated in the following server environment:
- Operating system  : Linux(x86_64)
- R Version         : 4.5.0 (2025-04-11)
- CPU               : 32 cores
- Memory            : 64GB RAM
- Available memory  : ~ 49GB 

##Recommended Hardware
**Server Environment (Recommended)**

For full reproducibility:

• Linux
• 32 CPU cores
• 64 GB RAM
• Ollama installed
• One or more supported LLMs

This configuration was used throughout development and validation.

**Local/Laptop Environment**

Local execution is supported but depends on available hardware.

Smaller models generally perform well:

mistral:latest
qwen2.5-coder:latest

Large models may experience reduced performance or even freeze:

qwen3:8b
sqlcoder:latest

Depending on available CPU and RAM these models may:

- require several minutes to respond
- consume substantial resources
- produce unstable behaviour during long-running requests

This behaviour is related to hardware constraints rather than application logic.

Reference laptop:
• Dell Latitude 5220
• Windows 11 Pro (x64)
• CPU: 4 cores
• 8GB RAM
• Disk space to download Ollama/LLM;s locally (re: 20GB)

---

# ✅ Requirements

Before starting, ensure the following are available on your system:

## System Requirements

- R (≥ 4.x recommended)
- RStudio / Posit
- Git
- Internet connection (for package and model download)

## Required Tools

- **Ollama (mandatory)**  
  👉 https://ollama.com/

- At least one LLM model with tool support  
  Recommended:

```bash
ollama pull qwen3:8b
