## Are moderate and high-impact mutations in TARDBP enriched in cases versus controls?
This can be interpreted differently. For example, does it count the number of variants or the number of carriers? There is not one "correct" answer. However, the chatbot should be able to explain which interpretation it uses and should be able to come up with a reasonable answer based on the data in the table. Below are two possible interpretations and answers.

```R
## 1: Count the number of variants in cases versus controls
query <- ("
WITH TARDBP_variants_ALS AS (
    SELECT VAR_id
    FROM varInfo_synthetic
    WHERE gene_name = 'TARDBP' AND (ModerateImpact = 1 OR HighImpact = 1) AND (ALS_1 != 0 OR ALS_2 != 0 OR ALS_3 != 0 OR ALS_4 != 0 OR ALS_5 != 0)
),

TARDBP_variants_control AS (
    SELECT VAR_id
    FROM varInfo_synthetic
    WHERE gene_name = 'TARDBP' AND (ModerateImpact = 1 OR HighImpact = 1) AND (Control_1 != 0 OR Control_2 != 0 OR Control_3 != 0 OR Control_4 != 0 OR Control_5 != 0)
)
    SELECT
  (SELECT COUNT(*) FROM TARDBP_variants_ALS) AS n_variants_ALS,
  (SELECT COUNT(*) FROM TARDBP_variants_control) AS n_variants_control
")

dbGetQuery(gdb, query)
```
In both ALS and Controls there are 15 moderate or high impact variants in TARDBP

```R
## 2: Count the number of effect alleles in cases versus controls
query <- ("
SELECT
    SUM(ALS_1 + ALS_2 + ALS_3 + ALS_4 + ALS_5) AS ALS_burden,
    SUM(Control_1 + Control_2 + Control_3 + Control_4 + Control_5) AS Control_burden
FROM varInfo_synthetic
WHERE gene_name = 'TARDBP'
  AND (ModerateImpact = 1 OR HighImpact = 1)
  ")

dbGetQuery(gdb, query)
```

The burden in ALS cases is 80 and in controls 85

## In which gene has patient "ALS_1" the most pathogenic mutations

pathogenic mutations can be interpreted differently, but it should be something like CADD > 20, PolyPhen = D and SIFT = D.

```R
query <- ("
 WITH ALS_1_pathogenic_variants AS (
    SELECT gene_name, ALS_1, CADDphred, PolyPhen, SIFT
    FROM varInfo_synthetic
    WHERE ALS_1 != 0 AND (CADDphred > 20 OR PolyPhen = 'D' OR SIFT = 'D'))

    SELECT gene_name, SUM(ALS_1) AS total_pathogenic_mutations
    FROM ALS_1_pathogenic_variants
    GROUP BY gene_name
    ORDER BY total_pathogenic_mutations DESC

")

dbGetQuery(gdb, query)
```

Patient "ALS_1" has the most pathogenic mutations in the ABCA4 gene (321). (note that this is the allele count, so if the patient is homozygous for a variant it counts as 2, if the patient is heterozygous it counts as 1)

## In which genes are more variants present in cases compared to controls (and what is the ratio)?

```R
query <- ("
  SELECT
      gene_name,
      SUM(ALS_1+ ALS_2 + ALS_3 + ALS_4 + ALS_5) AS case_dosage,
      SUM(Control_1 + Control_2 + Control_3 + Control_4 + Control_5) AS control_dosage,
      (SUM(ALS_1+ ALS_2 + ALS_3 + ALS_4 + ALS_5) + 1.0) / (SUM(Control_1 + Control_2 + Control_3 + Control_4 + Control_5) + 1.0) AS dosage_ratio

  FROM varInfo_synthetic
  GROUP BY gene_name
  ORDER BY dosage_ratio DESC;
")

dbGetQuery(gdb, query)
```

There are more case carriers then controls in TARDBP, PEX5, ABCA4, SOD1, and IL3RA.

---