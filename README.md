RVAT NLQ Interface
================
A Natural Language Query (NLQ) interface for exploring RVAT genetic
variant data using locally hosted Large Language Models (LLMs) via
Ollama.


Version: 0.2 
Date:    2026.06.25


================

# 🧬 RVAT NL → SQL Query Interface

The project investigates whether natural language can be reliably
translated into SQL while maintaining transparency, reproducibility, and
observability. Users can ask questions in plain language, inspect the
generated SQL, execute queries against a SQLite database, and review
results through a Shiny web interface.

------------------------------------------------------------------------

# 📘 Overview

This repository contains the **RVAT Natural Language Query (NLQ) Interface**, enabling users to translate natural language queries into SQL and retrieve results from the RVAT database via a Shiny application.

This version focuses on:

- ✅ Reproducible environment using `{renv}`  
- ✅ Production-ready application pipeline (migrated from demo workflow)  
- ✅ Clear developer onboarding  
- ⚠️ Separation of application and analysis workflows (analysis excluded)  

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
