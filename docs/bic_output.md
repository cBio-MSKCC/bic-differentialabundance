# nf-core/differentialabundance: Output

## Introduction

This document describes the output produced by the pipeline. The directories listed below will be created in the results directory after the pipeline has finished. All paths are relative to the top-level results directory.

## Report

This directory contains the main reporting output of the workflow.

<details markdown="1">
<summary>Output files</summary>

- `report/`
  - `*.html`: an HTML report file named according to the value of `params.study_name`, containing graphical and tabular summary results for the workflow run.
  - `*.zip`: a zip file containing an R markdown file with parameters set and all necessary input files to open and customise the reporting.
  - `gsea/`
    - `[contrast]/gmx_list/[contrast].gmx_list.index.html`: index page that shows gsea results.

</details>

## Plots

Stand-alone graphical outputs are placed in this directory. They may be useful in external reporting, publication preparation etc.

<details markdown="1">
<summary>Output files</summary>

- `plots/`
  - `qc/`: Directory containing quality control plots from initial processing e.g. DESeq2
    - `*.dispersion.png`: Plot of the per-gene dispersion estimates together with the fitted mean-dispersion relationship
    - `*.MA_plot.png`: MA plot of comparison using DESeq2's plotMA command
  - `exploratory/`: Directory containing standalone plots from exploratory analysis. Plots are stored in directories named for the main coloring variable used.
    - `[contrast_variable]/png/sample_to_sample_distance.png`: Sample to sample distance heatmap
    - `[contrast_variable]/png/pc_loading.png`: PC loading of the first two principle components of samples using normalized counts
    - `[contrast_variable]/png/plot_MDS.png`: Multidimensional scaling plot of normalized counts
    - `[contrast_variable]/png/boxplot.png`: Boxplot visualisation of abundance distributions
    - `[contrast_variable]/png/density.png`: Density visualisation of abundance distributions
    - `[contrast_variable]/png/pca2d.png`: 2-dimensional PCA plot
    - `[contrast_variable]/png/pca3d.png`: 3-dimensional PCA plot
    - `[contrast_variable]/png/sample_dendrogram.png`: A sample clustering dendrogram
    - `[contrast_variable]/png/mad_correlation.png`: Outlier prediction plots using median absolute deviation (MAD)
  - `differential/`: Directory containing standalone plots from differential analysis. Plots are stored in directories named for the associated contrast.
    - `[contrast]/png/volcano.png`: Volcano plots of -log(10) p value agains log(2) fold changes
    - `[contrast]/png/heatmap.png`: Heatmap of 50 highly differentially expressed genes

</details>

Most plots are included in the HTML report (see above), but are also included in static files in this folder to facilitate use in external reporting.

## Tables

<details markdown="1">
<summary>Output files</summary>

- `tables/`
  - `processed_abundance/`: Directory containing processed abundance values from initial processing from e.g. DESeq2 or Affy:
    - `all.normalised_counts.tsv`: Normalised counts table (DESeq2)
    - `all.vst.tsv`: Normalised counts table with a variance-stabilising transform (DESeq2)
  - `differential/`: Directory containing tables of differential statistics reported by differential modules such as DESeq2
    - `[contrast].deseq2.de_results.tsv`: Results of DESeq2 differential analyis (RNA-seq)
    - `[contrast].deseq2.de_results_filtered.tsv`: Results of DESeq2 differential analyis (RNA-seq) filtered to cutoff thresholds

</details>

The `differential` folder is likely to be the core result set for most users, containing the main tables of differential statistics.


## Frequently asked questions

### Why are no genes flagged as differentially expressed?

#### 1. Low replication:

**Problem:** The number of replicates in your RNA-seq experiment may be insufficient to detect statistically significant differential expression.

**Suggested course of action:** Consider increasing the number of replicates to improve the statistical power of your analysis. Repeating the experiment with greater replication allows for better estimation of biological variation and increases the chances of observing significant differential expression. Consult with experimental design experts or statisticians to determine the appropriate sample size calculation based on your specific research question and resources.

#### 2. Subtle effect:

**Problem:** The experimental intervention may have a relatively subtle impact on gene expression, making it challenging to detect differential expression using default thresholds.

**Suggested course of action:** Adjust the analysis parameters to improve sensitivity in capturing smaller changes in gene expression. Try reducing the `differential_min_fold_change` parameter to include genes with smaller fold changes. Additionally, consider increasing the `differential_max_qval` parameter to relax the significance threshold and capture a broader range of significant p-values or q-values. By fine-tuning these parameters, you increase the likelihood of identifying genes with subtle but biologically relevant changes in expression.

#### 3. Genuinely no differential expression:

**Problem:** It is possible that the experimental intervention has not significantly impacted gene expression, resulting in the absence of differentially expressed genes.

**Suggested course of action:** Evaluate the experimental design and the perturbation itself. If the intervention is expected to induce changes in gene expression but no differential expression is observed, revisit the experimental design, biological perturbation, or underlying hypothesis. Consider reassessing the experimental conditions or exploring alternative approaches to investigate other aspects of the biological system.

#### 4. Unaccounted sources of variance:

**Problem:** Other factors outside the main treatment may introduce variance in gene expression, leading to a decrease in power to detect differential expression.

**Suggested course of action:** Examine the PCA (Principal Component Analysis) and metadata association plots generated by the workflow. Identify variables associated with components that contribute significantly to the variance in your data. Include these variables as covariates in the contrasts table's blocking column to account for their effects on gene expression. By incorporating these unaccounted sources of variance into your analysis, you improve the accuracy and power to detect differential expression.

#### 5. Biological complexity and pathway-level effects:

**Problem:** The experimental intervention may not lead to observable differential expression at the individual gene level, but there may be coordinated changes at the pathway or functional level.

**Suggested course of action:** Utilize pathway analysis tools such as Gene Set Enrichment Analysis (GSEA), available in this workflow. These tools evaluate the enrichment of gene sets or functional annotations to identify broader biological processes influenced by the experimental intervention. By focusing on pathway-level analysis, you can capture the overall impact of the intervention on biological processes, even if differential expression at the individual gene level is not apparent.

#### 6. Limited options for normalization:

**Problem:** The nf-core differential abundance workflow currently offers a limited set of normalization methods, which may not fully address the specific normalization requirements of your experiment.

**Suggested course of action:** If the existing options do not adequately address your experiment's normalization challenges, consider developing custom normalization modules tailored to your needs. By contributing these modules to the nf-core community, you can expand the range of normalization options available to researchers. Your contributions will help researchers in similar situations and contribute to the continuous improvement and customization of the workflow.

#### 7. Technical variability and batch effects:

**Problem:** Technical variability and batch effects can introduce noise and confound the detection of differential expression.

**Suggested course of action:** Address technical variability and batch effects in the experimental design and data analysis. Randomize sample collection, incorporate control samples, and balance samples across different experimental batches. These measures minimize technical variation, enhance the robustness of the analysis, and increase the chances of detecting true differential expression.

#### 8. Workflow issues or bugs:

**Problem:** Potential issues or bugs in the nf-core differential abundance workflow can affect the detection of differential expression or data analysis.

**Suggested course of action:** Report any issues or suspected bugs by emailing bioinformatics core at bicrequest@mskcc.org
