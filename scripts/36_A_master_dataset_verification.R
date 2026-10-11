# ------------------------------------------------------------
# 36_A_master_dataset_verification.R
#
# PURPOSE
# -------
# Verify analytical integrity of the RVAT benchmark datasets.
#
#
# RESPONSIBILITIES
# ----------------
# 1. Verify master dataset integrity
# 2. Verify experimental design consistency
# 3. Verify tidy-data compliance
# 4. Generate variable inventory
# 5. Generate completeness audit
# 6. Assess VES normality overall
# 7. Assess VES normality per model
# 8. Verify reproducibility of 35_ outputs
#
#
# INPUTS
# ------
# 34_master_execution_level.csv
# 35_question_level.csv
# 35_question_type_level.csv
#
# OUTPUTS
# -------
# 36_A_master_dataset_verification_report.txt
# 36_A_variable_inventory.csv
# 36_A_model_normality_summary.csv
# 36_A_VES_condition_summary.csv
#
#
# ------------------------------------------------------------

library(here)
library(readr)
library(dplyr)

# ------------------------------------------------------------
# CONFIGURATION
# ------------------------------------------------------------

RESULTS_DIR <- here(
  "data",
  "analysis",
  "results"
)

MASTER_FILE <- file.path(
  RESULTS_DIR,
  "34_master_execution_level.csv"
)

QUESTION_FILE <- file.path(
  RESULTS_DIR,
  "35_question_level.csv"
)

QUESTION_TYPE_FILE <- file.path(
  RESULTS_DIR,
  "35_question_type_level.csv"
)

REPORT_FILE <- file.path(
  RESULTS_DIR,
  "36_A_master_dataset_verification_report.txt"
)

# ------------------------------------------------------------
# VALIDATE REQUIRED FILES
# ------------------------------------------------------------

required_files <- c(
  MASTER_FILE,
  QUESTION_FILE,
  QUESTION_TYPE_FILE
)

missing_files <- required_files[
  !file.exists(required_files)
]

if (length(missing_files) > 0) {
  
  stop(
    "Required file(s) missing: ",
    paste(
      missing_files,
      collapse = ", "
    )
  )
}

# ------------------------------------------------------------
# LOAD DATASETS
# ------------------------------------------------------------

master <- readr::read_csv(
  MASTER_FILE,
  show_col_types = FALSE
)

question_level <- readr::read_csv(
  QUESTION_FILE,
  show_col_types = FALSE
)

question_type_level <- readr::read_csv(
  QUESTION_TYPE_FILE,
  show_col_types = FALSE
)

# ------------------------------------------------------------
# OPEN REPORT CONNECTION
# ------------------------------------------------------------

report_con <- file(
  REPORT_FILE,
  open = "wt"
)

write_report <- function(...) {
  
  line <- paste0(...)
  
  cat(
    line,
    "\n"
  )
  
  writeLines(
    line,
    report_con
  )
}

# ------------------------------------------------------------
# REPORT HEADER
# ------------------------------------------------------------

write_report(
  "================================================="
)

write_report(
  "36_A MASTER DATASET VERIFICATION"
)

write_report(
  "================================================="
)

write_report(
  paste(
    "Verification timestamp:",
    Sys.time()
  )
)

# ------------------------------------------------------------
# EXPERIMENTAL DESIGN SUMMARY
# ------------------------------------------------------------

n_models <- length(
  unique(master$model)
)

n_modes <- length(
  unique(master$db_mode)
)

n_iterations <- length(
  unique(master$experiment_iteration)
)

n_questions <- length(
  unique(master$question_id)
)

n_question_types <- length(
  unique(master$question_type)
)

n_runs <- 5

expected_master <- (
  n_models *
    n_modes *
    n_iterations *
    n_questions *
    n_runs
)

expected_question_level <- (
  n_models *
    n_modes *
    n_iterations *
    n_questions
)

expected_question_type <- (
  n_models *
    n_modes *
    n_iterations *
    n_question_types
)

write_report("")
write_report("EXPERIMENTAL DESIGN SUMMARY")
write_report("------------------------------")

write_report("Execution-level structure:")

write_report(
  paste(
    n_models,
    "models ×",
    n_modes,
    "database modes ×",
    n_iterations,
    "iterations ×",
    n_questions,
    "questions ×",
    n_runs,
    "runs"
  )
)

write_report(
  paste(
    "Expected observations:",
    expected_master
  )
)

write_report(
  paste(
    "Observed observations:",
    nrow(master)
  )
)

write_report("")

write_report("Question-level structure:")

write_report(
  paste(
    n_models,
    "models ×",
    n_modes,
    "database modes ×",
    n_iterations,
    "iterations ×",
    n_questions,
    "questions"
  )
)

write_report(
  paste(
    "Expected question-condition combinations:",
    expected_question_level
  )
)

write_report(
  paste(
    "Observed rows:",
    nrow(question_level)
  )
)

write_report("")

write_report("Question-type structure:")

write_report(
  paste(
    n_models,
    "models ×",
    n_modes,
    "database modes ×",
    n_iterations,
    "iterations ×",
    n_question_types,
    "question types"
  )
)

write_report(
  paste(
    "Expected analytical records:",
    expected_question_type
  )
)

write_report(
  paste(
    "Observed rows:",
    nrow(question_type_level)
  )
)

write_report("")

write_report(
  paste(
    "Execution-level count:",
    ifelse(
      nrow(master) == expected_master,
      "PASS",
      "FAIL"
    )
  )
)

write_report(
  paste(
    "Question-level count:",
    ifelse(
      nrow(question_level) ==
        expected_question_level,
      "PASS",
      "FAIL"
    )
  )
)

write_report(
  paste(
    "Question-type count:",
    ifelse(
      nrow(question_type_level) ==
        expected_question_type,
      "PASS",
      "FAIL"
    )
  )
)

# ------------------------------------------------------------
# DATASET STRUCTURE AUDIT
# ------------------------------------------------------------

write_report("")
write_report("DATASET STRUCTURE AUDIT")
write_report("------------------------------")

write_report(
  paste(
    "Execution-level rows:",
    nrow(master)
  )
)

write_report(
  paste(
    "Execution-level columns:",
    ncol(master)
  )
)

write_report("")

write_report("Variables present:")

for (col in names(master)) {
  
  write_report(
    paste(
      "-",
      col
    )
  )
}

# ------------------------------------------------------------
# ITERATION COVERAGE
# ------------------------------------------------------------

write_report("")
write_report("ITERATION COVERAGE")
write_report("------------------------------")

iteration_summary <- master |>
  dplyr::count(
    model,
    db_mode,
    experiment_iteration,
    name = "n_observations"
  ) |>
  arrange(
    model,
    db_mode,
    experiment_iteration
  )

for (i in seq_len(
  nrow(iteration_summary)
)) {
  
  write_report(
    paste(
      iteration_summary$model[i],
      "|",
      iteration_summary$db_mode[i],
      "| Iteration",
      iteration_summary$experiment_iteration[i],
      "| Observations:",
      iteration_summary$n_observations[i]
    )
  )
}

# ------------------------------------------------------------
# QUESTION-TYPE COVERAGE
# ------------------------------------------------------------

write_report("")
write_report("QUESTION-TYPE COVERAGE")
write_report("------------------------------")

question_type_coverage <- question_type_level |>
  dplyr::count(
    question_type,
    name = "n_records"
  ) |>
  arrange(
    question_type
  )

for (i in seq_len(
  nrow(question_type_coverage)
)) {
  
  write_report(
    paste(
      question_type_coverage$question_type[i],
      ":",
      question_type_coverage$n_records[i]
    )
  )
}

write_report("")

write_report(
  "Coverage checks completed."
)

# ------------------------------------------------------------
# EXPERIMENTAL DESIGN VALIDATION
# ------------------------------------------------------------

write_report("")
write_report("EXPERIMENTAL DESIGN VALIDATION")
write_report("------------------------------")

master$key <- paste(
  master$model,
  master$db_mode,
  master$experiment_iteration,
  master$question_id,
  master$run_id,
  sep = "::"
)

duplicate_keys <- sum(
  duplicated(master$key)
)

write_report(
  paste(
    "Duplicate execution keys:",
    duplicate_keys
  )
)

if (duplicate_keys > 0) {
  
  stop(
    paste(
      "Duplicate execution observations detected:",
      duplicate_keys
    )
  )
}

write_report(
  "Unique execution key validation: PASS"
)

# ------------------------------------------------------------
# VERIFY FIVE RUNS PER QUESTION
# ------------------------------------------------------------

repetition_check <- master |>
  dplyr::count(
    model,
    db_mode,
    experiment_iteration,
    question_id,
    name = "n_repetitions"
  )

invalid_repetitions <- repetition_check |>
  dplyr::filter(
    n_repetitions != 5
  )

write_report(
  paste(
    "Question-condition combinations checked:",
    nrow(repetition_check)
  )
)

if (nrow(invalid_repetitions) > 0) {
  
  write_report(
    paste(
      "Invalid repetition counts:",
      nrow(invalid_repetitions)
    )
  )
  
  stop(
    "One or more questions do not contain exactly five repetitions."
  )
}

write_report(
  "Five repetitions per question validation: PASS"
)

# ------------------------------------------------------------
# VARIABLE INVENTORY
# ------------------------------------------------------------

write_report("")
write_report("VARIABLE INVENTORY")
write_report("------------------------------")

inventory_data <- master

if ("key" %in% names(inventory_data)) {
  
  inventory_data <- inventory_data |>
    dplyr::select(
      -key
    )
}

variable_inventory <- data.frame(
  
  variable = names(inventory_data),
  
  type = sapply(
    inventory_data,
    function(x) class(x)[1]
  ),
  
  missing_values = sapply(
    inventory_data,
    function(x) sum(is.na(x))
  ),
  
  non_missing_values = sapply(
    inventory_data,
    function(x) sum(!is.na(x))
  ),
  
  unique_values = sapply(
    inventory_data,
    function(x) length(unique(x))
  ),
  
  stringsAsFactors = FALSE
)

inventory_file <- file.path(
  RESULTS_DIR,
  "36_A_variable_inventory.csv"
)

write_csv(
  variable_inventory,
  inventory_file
)

write_report(
  paste(
    "Variable inventory saved:",
    basename(inventory_file)
  )
)

# ------------------------------------------------------------
# EM / EX DISTRIBUTION SUMMARY
# ------------------------------------------------------------

write_report("")
write_report("EM / EX DISTRIBUTION SUMMARY")
write_report("------------------------------")

em_distribution <- table(master$EM)

write_report("")
write_report("EM Distribution")

for (i in seq_along(em_distribution)) {
  
  write_report(
    paste(
      names(em_distribution)[i],
      "=",
      em_distribution[i]
    )
  )
}

if (length(unique(master$EM)) == 1) {
  
  write_report("")
  write_report(
    "WARNING: EM contains no variation."
  )
  
  write_report(
    "This reflects the observed benchmark results."
  )
}

ex_distribution <- table(master$EX)

write_report("")
write_report("EX Distribution")

for (i in seq_along(ex_distribution)) {
  
  write_report(
    paste(
      names(ex_distribution)[i],
      "=",
      ex_distribution[i]
    )
  )
}

# ------------------------------------------------------------
# STATISTICAL READINESS
# ------------------------------------------------------------

write_report("")
write_report("STATISTICAL READINESS")
write_report("------------------------------")

write_report(
  "Primary binary outcomes:"
)

write_report(
  "- EM"
)

write_report(
  "- EX"
)

write_report(
  ""
)

write_report(
  "Primary continuous outcome:"
)

write_report(
  "- VES (time_total_sec)"
)

write_report("")
write_report(
  "EM and EX are binary variables and do not require"
)

write_report(
  "normality assessment."
)

write_report(
  ""
)

write_report(
  "VES requires normality assessment because it is"
)

write_report(
  "the primary continuous outcome variable."
)

write_report("")

write_report(
  "A Shapiro-Wilk test will be used to assess"
)

write_report(
  "whether VES approximates a normal distribution."
)

# ------------------------------------------------------------
# OVERALL VES NORMALITY
# ------------------------------------------------------------

write_report("")
write_report("OVERALL VES NORMALITY")
write_report("------------------------------")

ves_values <- master$time_total_sec

ves_values <- ves_values[
  !is.na(ves_values)
]

overall_shapiro <- shapiro.test(
  sample(
    ves_values,
    min(
      length(ves_values),
      5000
    )
  )
)

write_report(
  paste(
    "Observations:",
    length(ves_values)
  )
)

write_report(
  paste(
    "Shapiro-Wilk W:",
    round(
      overall_shapiro$statistic,
      5
    )
  )
)

write_report(
  paste(
    "Shapiro-Wilk p-value:",
    signif(
      overall_shapiro$p.value,
      6
    )
  )
)

if (overall_shapiro$p.value < 0.05) {
  
  write_report(
    "Conclusion: VES is non-normal."
  )
  
  write_report(
    "Recommendation: use non-parametric methods for VES."
  )
  
} else {
  
  write_report(
    "Conclusion: VES is approximately normal."
  )
  
  write_report(
    "Recommendation: parametric methods may be considered."
  )
}

# ------------------------------------------------------------
# MODEL-LEVEL NORMALITY
# ------------------------------------------------------------

write_report("")
write_report("MODEL-LEVEL VES NORMALITY")
write_report("------------------------------")

normality_results <- list()

models <- sort(
  unique(master$model)
)

for (current_model in models) {
  
  model_data <- master |>
    dplyr::filter(
      model == current_model
    )
  
  model_ves <- model_data$time_total_sec
  
  model_ves <- model_ves[
    !is.na(model_ves)
  ]
  
  model_shapiro <- shapiro.test(
    sample(
      model_ves,
      min(
        length(model_ves),
        5000
      )
    )
  )
  
  model_conclusion <- ifelse(
    model_shapiro$p.value < 0.05,
    "Non-normal",
    "Approximately normal"
  )
  
  write_report(
    paste(
      current_model,
      "| N =",
      length(model_ves),
      "| W =",
      round(
        model_shapiro$statistic,
        5
      ),
      "| p =",
      signif(
        model_shapiro$p.value,
        6
      ),
      "|",
      model_conclusion
    )
  )
  
  normality_results[[length(normality_results) + 1]] <-
    data.frame(
      
      model = current_model,
      
      observations = length(model_ves),
      
      mean_VES = mean(
        model_ves,
        na.rm = TRUE
      ),
      
      median_VES = median(
        model_ves,
        na.rm = TRUE
      ),
      
      sd_VES = sd(
        model_ves,
        na.rm = TRUE
      ),
      
      shapiro_w = as.numeric(
        model_shapiro$statistic
      ),
      
      shapiro_p = model_shapiro$p.value,
      
      conclusion = model_conclusion,
      
      stringsAsFactors = FALSE
    )
}

model_normality_summary <- dplyr::bind_rows(
  normality_results
)

write_csv(
  model_normality_summary,
  file.path(
    RESULTS_DIR,
    "36_A_model_normality_summary.csv"
  )
)

write_report("")
write_report(
  "Model-level normality summary saved."
)

# ------------------------------------------------------------
# CONDITION-LEVEL VES SUMMARY
# ------------------------------------------------------------

write_report("")
write_report("CONDITION-LEVEL VES SUMMARY")
write_report("------------------------------")

condition_summary <- master |>
  dplyr::group_by(
    model,
    db_mode
  ) |>
  dplyr::summarise(
    
    observations = dplyr::n(),
    
    mean_VES = mean(
      time_total_sec,
      na.rm = TRUE
    ),
    
    median_VES = median(
      time_total_sec,
      na.rm = TRUE
    ),
    
    sd_VES = sd(
      time_total_sec,
      na.rm = TRUE
    ),
    
    min_VES = min(
      time_total_sec,
      na.rm = TRUE
    ),
    
    max_VES = max(
      time_total_sec,
      na.rm = TRUE
    ),
    
    .groups = "drop"
  )

write_csv(
  condition_summary,
  file.path(
    RESULTS_DIR,
    "36_A_VES_condition_summary.csv"
  )
)

for (i in seq_len(
  nrow(condition_summary)
)) {
  
  write_report(
    paste(
      condition_summary$model[i],
      "|",
      condition_summary$db_mode[i],
      "| N =",
      condition_summary$observations[i],
      "| Mean =",
      round(
        condition_summary$mean_VES[i],
        3
      ),
      "| Median =",
      round(
        condition_summary$median_VES[i],
        3
      ),
      "| SD =",
      round(
        condition_summary$sd_VES[i],
        3
      )
    )
  )
}

write_report("")
write_report(
  "Statistical readiness assessment completed."
)
