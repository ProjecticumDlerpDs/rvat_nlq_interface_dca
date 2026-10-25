# ------------------------------------------------------------
# 37_B_EX_performance_and_significance.R
#
# PURPOSE
# -------
# Create a presentation-quality figure combining:
#
# - EX performance per model
# - Kruskal-Wallis significance
# - Pairwise Wilcoxon significance
#
# INPUT
# -----
# 35_question_level.csv
# 37_A_question_type_kruskal_wallis.csv
# 37_A_question_type_pairwise_wilcoxon.csv
#
# OUTPUT
# ------
# data/analysis/visualisations/
#
# 37_B_EX_performance_and_significance.png
#
# ------------------------------------------------------------

library(here)
library(readr)
library(dplyr)
library(ggplot2)
library(scales)

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
  "37_A_question_type_kruskal_wallis.csv"
)

PAIRWISE_FILE <- here(
  "data",
  "analysis",
  "results",
  "37_A_question_type_pairwise_wilcoxon.csv"
)

OUTPUT_FILE <- here(
  "data",
  "analysis",
  "visualisations",
  "37_B_EX_performance_and_significance.png"
)

# ------------------------------------------------------------
# PREPARE OUTPUT DIRECTORY
# ------------------------------------------------------------
dir.create(
  here(
    "data",
    "analysis",
    "visualisations"
  ),
  recursive = TRUE,
  showWarnings = FALSE
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
    "Missing required file(s): ",
    paste(missing_files, collapse = ", ")
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

print(names(pairwise))

# ------------------------------------------------------------
# STANDARDISE PAIRWISE COLUMN NAMES
# ------------------------------------------------------------

if ("Freq" %in% names(pairwise)) {
  
  names(pairwise)[
    names(pairwise) == "Freq"
  ] <- "adjusted_p_value"
}

if (!"adjusted_p_value" %in% names(pairwise)) {
  
  stop(
    paste(
      "Unable to locate adjusted p-value column.",
      "Columns found:",
      paste(names(pairwise), collapse = ", ")
    )
  )
}

# ------------------------------------------------------------
# REMOVE EMPTY COMPARISONS
# ------------------------------------------------------------

pairwise <- pairwise |>
  dplyr::filter(
    !is.na(adjusted_p_value)
  )

# ------------------------------------------------------------
# CONVERT P-VALUES TO SIGNIFICANCE LABELS
# ------------------------------------------------------------

pairwise$stars <- dplyr::case_when(
  
  pairwise$adjusted_p_value < 0.001 ~ "***",
  
  pairwise$adjusted_p_value < 0.01 ~ "**",
  
  pairwise$adjusted_p_value < 0.05 ~ "*",
  
  TRUE ~ "ns"
)


# ------------------------------------------------------------
# BUILD EX PERFORMANCE TABLE
# ------------------------------------------------------------

performance <- question_level |>
  group_by(
    question_type,
    db_mode,
    model
  ) |>
  summarise(
    EX_mean = mean(
      EX_rate,
      na.rm = TRUE
    ),
    .groups = "drop"
  )
# ------------------------------------------------------------
# BUILD ANNOTATIONS
# ------------------------------------------------------------
pairwise$stars <- ifelse(
  pairwise$adjusted_p_value < 0.001,
  "",
  ifelse(
    pairwise$adjusted_p_value < 0.01,
    "",
    ifelse(
      pairwise$adjusted_p_value < 0.05,
      "",
      "ns"
    )
  )
)


labels <- list()
question_types <- unique(
  performance$question_type
)
db_modes <- unique(
  performance$db_mode
)
for (current_type in question_types) {
  for (current_db_mode in db_modes) {
    perf_subset <- performance |>
      filter(
        question_type == current_type,
        db_mode == current_db_mode
      )
    pair_subset <- pairwise |>
      filter(
        question_type == current_type,
        db_mode == current_db_mode
      )
    text_lines <- c()
    for (i in seq_len(nrow(pair_subset))) {
      m1 <- pair_subset$model_1[i]
      m2 <- pair_subset$model_2[i]
      p1 <- mean(
        perf_subset$EX_mean[
          perf_subset$model == m1
        ]
      )
      p2 <- mean(
        perf_subset$EX_mean[
          perf_subset$model == m2
        ]
      )
      significance <- pair_subset$stars[i]
      if (significance == "ns") {
        next
      }
      if (is.na(p1) || is.na(p2)) {
        next
      }
      if (p1 > p2) {
        line <- paste(
          m1,
          ">",
          m2,
          significance
        )
      } else {
        line <- paste(
          m2,
          ">",
          m1,
          significance
        )
      }
      text_lines <- c(
        text_lines,
        line
      )
    }
    if (length(text_lines) == 0) {
      text_lines <- "No significant pairwise differences"
    }
    kw_p <- kw$p_value[
      kw$question_type == current_type &
        kw$db_mode == current_db_mode
    ]
    annotation_key <- paste(
      current_type,
      current_db_mode,
      sep = "::"
    )
    labels[[annotation_key]] <- paste(
      paste0(
        current_db_mode,
        "\nKW p=",
        signif(
          kw_p,
          3
        )
      ),
      paste(
        text_lines,
        collapse = "\n"
      ),
      sep = "\n"
    )
  }
}

# ------------------------------------------------------------
# CREATE ANNOTATION DATA
# ------------------------------------------------------------
annotation_data <- performance |>
  group_by(
    question_type,
    db_mode
  ) |>
  summarise(
    y_position =
      max(EX_mean) + 0.15,
    .groups = "drop"
  )
annotation_data$key <- paste(
  annotation_data$question_type,
  annotation_data$db_mode,
  sep = "::"
)
annotation_data$label <- vapply(
  annotation_data$key,
  function(x) {
    if (x %in% names(labels)) {
      labels[[x]]
    } else {
      ""
    }
  },
  character(1)
)


# ------------------------------------------------------------
# CREATE DISPLAY LABELS
# ------------------------------------------------------------
performance$question_db <- paste(
  performance$question_type,
  performance$db_mode,
  sep = "\n"
)
annotation_data$question_db <- paste(
  annotation_data$question_type,
  annotation_data$db_mode,
  sep = "\n"
)
# ------------------------------------------------------------
# ORDER QUESTION TYPES
# ------------------------------------------------------------
question_order <- c(
  "Lookup Queries\nfull_gdb",
  "Lookup Queries\nsynthetic",
  "Analytical Queries\nfull_gdb",
  "Analytical Queries\nsynthetic",
  "Unanswerable Questions\nfull_gdb",
  "Unanswerable Questions\nsynthetic",
  "Advanced Tests (RVAT Required)\nfull_gdb",
  "Advanced Tests (RVAT Required)\nsynthetic"
)
performance$question_db <- factor(
  performance$question_db,
  levels = question_order
)
annotation_data$question_db <- factor(
  annotation_data$question_db,
  levels = question_order
)

# ------------------------------------------------------------
# CREATE FIGURE
# ------------------------------------------------------------

p <- ggplot(
  performance,
  aes(
    x = question_db,
    y = EX_mean,
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
      label = percent(
        EX_mean,
        accuracy = 1
      )
    ),
    position = position_dodge(
      width = 0.8
    ),
    vjust = -0.3,
    size = 4
  ) +
  geom_text(
    data = annotation_data,
    aes(
      x = question_db,
      y = y_position,
      label = label
    ),
    inherit.aes = FALSE,
    size = 3.2,
    fontface = "bold"
  ) +
  scale_y_continuous(
    labels = percent_format(),
    limits = c(
      0,
      1.25
    )
  ) +
  labs(
    title =
      "EX Performance and Statistical Significance",
    subtitle =
      "Question Type × Database Mode",
    x = "Question Type / Database Mode",
    y = "Mean EX Rate",
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

print(head(annotation_data))
print(dim(annotation_data))
print(file.exists(dirname(OUTPUT_FILE)))


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

print(file.exists(OUTPUT_FILE))

# ------------------------------------------------------------
# VERIFY OUTPUT
# ------------------------------------------------------------

if (!file.exists(OUTPUT_FILE)) {
  
  stop(
    "Output figure not created."
  )
}

# ------------------------------------------------------------
# FINAL REPORT
# ------------------------------------------------------------

cat("\n=========================================\n")
cat("37_B PERFORMANCE + SIGNIFICANCE COMPLETED\n")
cat("=========================================\n")

cat(
  "Saved:\n",
  OUTPUT_FILE,
  "\n"
)

cat("=========================================\n")