# ------------------------------------------------------------
# 39_B_VES_performance_and_significance.R
#
# PURPOSE
# -------
# Create a presentation-quality visualisation combining:
#
# - VES performance per model
# - Kruskal-Wallis significance
# - Pairwise Wilcoxon significance
#
# INPUT
# -----
# 35_question_level.csv
# 39_A_question_type_kruskal_wallis.csv
# 39_A_question_type_pairwise_wilcoxon.csv
#
# OUTPUT
# ------
# data/analysis/visualisations/
#
# 39_B_VES_performance_and_significance.png
#
# ------------------------------------------------------------

library(here)
library(readr)
library(dplyr)
library(ggplot2)

# ------------------------------------------------------------
# CONFIGURATION
# ------------------------------------------------------------

QUESTION_FILE <- here(
  "data",
  "analysis",
  "results",
  "35_question_level.csv"
)

KW_FILE <- here(
  "data",
  "analysis",
  "results",
  "39_A_question_type_kruskal_wallis.csv"
)

PAIRWISE_FILE <- here(
  "data",
  "analysis",
  "results",
  "39_A_question_type_pairwise_wilcoxon.csv"
)

OUTPUT_FILE <- here(
  "data",
  "analysis",
  "visualisations",
  "39_B_VES_performance_and_significance.png"
)

# ------------------------------------------------------------
# VALIDATE INPUTS
# ------------------------------------------------------------

required_files <- c(
  QUESTION_FILE,
  KW_FILE,
  PAIRWISE_FILE
)

missing_files <- required_files[
  !file.exists(required_files)
]

if (length(missing_files) > 0) {
  
  stop(
    paste(
      "Missing required file(s):",
      paste(missing_files, collapse = ", ")
    )
  )
}

# ------------------------------------------------------------
# LOAD DATA
# ------------------------------------------------------------

question_level <- read_csv(
  QUESTION_FILE,
  show_col_types = FALSE
)

kw <- read_csv(
  KW_FILE,
  show_col_types = FALSE
)

pairwise <- read_csv(
  PAIRWISE_FILE,
  show_col_types = FALSE
)

# ------------------------------------------------------------
# BUILD PERFORMANCE TABLE
# ------------------------------------------------------------

performance <- question_level |>
  group_by(
    question_type,
    model
  ) |>
  summarise(
    
    VES_mean =
      mean(
        VES_mean_sec,
        na.rm = TRUE
      ),
    
    .groups = "drop"
  )

# ------------------------------------------------------------
# SIGNIFICANCE LABELS
# ------------------------------------------------------------

pairwise <- pairwise |>
  filter(
    !is.na(adjusted_p_value)
  )

pairwise$stars <- dplyr::case_when(
  
  pairwise$adjusted_p_value < 0.001 ~ "***",
  
  pairwise$adjusted_p_value < 0.01 ~ "**",
  
  pairwise$adjusted_p_value < 0.05 ~ "*",
  
  TRUE ~ "ns"
)

# ------------------------------------------------------------
# BUILD ANNOTATIONS
# ------------------------------------------------------------

annotations <- list()

question_types <- unique(
  performance$question_type
)

for (current_type in question_types) {
  
  perf_subset <- performance |>
    filter(
      question_type == current_type
    )
  
  pair_subset <- pairwise |>
    filter(
      question_type == current_type &
        stars != "ns"
    )
  
  lines <- c()
  
  for (i in seq_len(nrow(pair_subset))) {
    
    m1 <- pair_subset$model_1[i]
    m2 <- pair_subset$model_2[i]
    
    v1 <- perf_subset$VES_mean[
      perf_subset$model == m1
    ]
    
    v2 <- perf_subset$VES_mean[
      perf_subset$model == m2
    ]
    
    sig <- pair_subset$stars[i]
    
    if (sig == "ns") {
      
      next
    }
    
    if (v1 < v2) {
      
      line <- paste(
        m1,
        ">",
        m2,
        sig
      )
      
    } else {
      
      line <- paste(
        m2,
        ">",
        m1,
        sig
      )
      
    }
    
    lines <- c(
      lines,
      line
    )
  }
  
  if (length(lines) == 0) {
    
    lines <- "No significant pairwise differences"
  }
  
  p_value <- kw$p_value[
    kw$question_type == current_type
  ]
  
  annotations[[as.character(current_type)]] <- paste(
    paste0(
      "KW p=",
      signif(
        p_value,
        3
      )
    ),
    paste(
      lines,
      collapse = "\n"
    ),
    sep = "\n"
  )
}

annotation_data <- performance |>
  group_by(
    question_type
  ) |>
  summarise(
    
    y = max(VES_mean) * 1.25,
    
    .groups = "drop"
  )

annotation_data$label <- unlist(
  annotations[
    as.character(
      annotation_data$question_type
    )
  ]
)

# ------------------------------------------------------------
# ORDER QUESTION TYPES
# ------------------------------------------------------------

question_order <- c(
  "Lookup Queries",
  "Analytical Queries",
  "Unanswerable Questions",
  "Advanced Tests (RVAT Required)"
)

performance$question_type <- factor(
  performance$question_type,
  levels = question_order
)

annotation_data$question_type <- factor(
  annotation_data$question_type,
  levels = question_order
)

# ------------------------------------------------------------
# CREATE VISUALISATION
# ------------------------------------------------------------

p <- ggplot(
  performance,
  aes(
    x = question_type,
    y = VES_mean,
    fill = model
  )
) +
  
  geom_col(
    position = position_dodge(
      width = 0.8
    ),
    width = 0.7
  ) +
  
  geom_text(
    aes(
      label = sprintf(
        "%.1f s",
        VES_mean
      )
    ),
    position = position_dodge(
      width = 0.8
    ),
    vjust = -0.4,
    size = 3.5
  ) +
  
  geom_text(
    data = annotation_data,
    aes(
      x = question_type,
      y = y,
      label = label
    ),
    inherit.aes = FALSE,
    size = 3.2,
    fontface = "bold"
  ) +
  
  labs(
    title =
      "VES Performance and Statistical Significance",
    
    subtitle =
      "Kruskal-Wallis and Pairwise Wilcoxon Results",
    
    x = "Question Type",
    
    y = "Mean Execution Time (seconds)",
    
    fill = "LLM"
  ) +
  
  theme_minimal(
    base_size = 12
  ) +
  
  theme(
    legend.position = "top",
    panel.grid.major.x = element_blank(),
    axis.text.x = element_text(
      angle = 15,
      hjust = 1
    )
  )

# ------------------------------------------------------------
# SAVE FIGURE
# ------------------------------------------------------------

ggsave(
  filename = OUTPUT_FILE,
  plot = p,
  width = 14,
  height = 8,
  dpi = 300
)

# ------------------------------------------------------------
# VERIFY OUTPUT
# ------------------------------------------------------------

if (!file.exists(OUTPUT_FILE)) {
  
  stop(
    "Output figure was not created."
  )
}

# ------------------------------------------------------------
# FINAL REPORT
# ------------------------------------------------------------

cat("\n=========================================\n")
cat("39_B VES PERFORMANCE + SIGNIFICANCE COMPLETED\n")
cat("=========================================\n")

cat(
  "Saved:\n",
  OUTPUT_FILE,
  "\n"
)

cat("=========================================\n")