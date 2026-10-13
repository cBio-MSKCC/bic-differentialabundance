process GSEA_GSEA_PRERANKED {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/gsea:4.3.2--hdfd78af_0':
        'biocontainers/gsea:4.3.2--hdfd78af_0' }"

    input:
    tuple val(meta), path(differential), path(gene_sets), path(chip)

    output:
    tuple val(meta), path("*.rpt")                                   , emit: rpt
    tuple val(meta), path("*index.html")                             , emit: index_html
    tuple val(meta), path("*gsea_report_for_na_neg.tsv")  , emit: report_tsvs_ref
    tuple val(meta), path("*gsea_report_for_na_neg.html") , emit: report_htmls_ref
    tuple val(meta), path("*gsea_report_for_na_pos.tsv")     , emit: report_tsvs_target
    tuple val(meta), path("*gsea_report_for_na_pos.html")    , emit: report_htmls_target
    tuple val(meta), path("*ranked_gene_list*.tsv")                  , emit: ranked_gene_list
    tuple val(meta), path("*gene_set_sizes.tsv")                     , emit: gene_set_sizes
    tuple val(meta), path("*global_es_histogram.png")                , emit: histogram
    tuple val(meta), path("*pvalues_vs_nes_plot.png")                , emit: pvalues_vs_nes_plot
    tuple val(meta), path("gene_sets_*.tsv")                         , emit: gene_set_tsv, optional: true
    tuple val(meta), path("gene_sets_*.html")                        , emit: gene_set_html, optional: true
    tuple val(meta), path("gene_sets_*.png")                         , emit: gene_set_heatmap, optional: true
    tuple val(meta), path("*_snapshot*.html")                        , emit: snapshot, optional: true
    tuple val(meta), path("*enplot*.png")                            , emit: gene_set_enplot, optional: true
    tuple val(meta), path("*gset_rnd_es_dist*.png")                  , emit: gene_set_dist, optional: true
    tuple val(meta), path("*.zip")                                   , emit: archive, optional: true
    path "versions.yml"                                              , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def VERSION = '4.3.2' // WARN: Version information not provided by tool on CLI. Please update this string when bumping container versions.
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    // Remove any trailing dots from prefix when passed as report label, so
    // GSEA doesn't produce double-dotted top-level outputs
    def rpt_label = prefix.replaceAll('\\.$', '')

    def chip_command = chip ? "-chip $chip -collapse Collapse" : ''
    """
    # make rnk file
    # Extract the column indices for the headers
    col1=\$(head -1 "${differential}" | tr '\\t' '\\n' | nl | grep -w "GeneID" | head -n 1 | awk '{print \$1}')
    col2=\$(head -1 "${differential}" | tr '\\t' '\\n' | nl | grep -w "log2FoldChange" | awk '{print \$1}')

    # Check if columns were found
    if [[ -z "\$col1" || -z "\$col2" ]]; then
        echo "Error: Required headers 'GeneID' or 'log2FoldChange' not found in the input file." >&2
        exit 1
    fi

    # Extract the sample key
    cut -f\$col1,\$col2 "${differential}" | tail -n+2 | grep -v ^__ > ranking.rnk

    # Run GSEA

    export HOME="\$PWD"
    export JVM_MEM_OPTS="-Xmx8g"

    gsea-cli GSEAPreranked \\
        -rnk ranking.rnk \\
        -gmx_list $gene_sets \\
        $chip_command \\
        -out . \\
        -rpt_label $rpt_label \\
        $args

    # Un-timestamp the outputs for path consistency
    mv ${rpt_label}.GseaPreranked.*/* .
    timestamp=\$(cat *.rpt | grep producer_timestamp | awk '{print \$2}')

    for pattern in _\${timestamp} .\${timestamp}; do
        find . -name "*\${pattern}*" | sed "s|^\\./||" | while read -r f; do
            mv \$f \${f//\$pattern/}
        done
    done
    sed -i.bak "s/[_\\.]\$timestamp//g" *.rpt *.html && rm *.bak

    # Prefix files that currently lack it
    ls -p | grep -v / | grep -v "$prefix" | while read -r f; do
        mv \$f ${prefix}\${f}
        sed -i.bak "s/\$f/${prefix}\${f}/g" *.rpt *.html && rm *.bak
    done

    # Prefix per-gene-set outputs with "gene_sets_" so they can be referenced by the output channels
    rename_files() {
        local pattern=\$1
        local exclude_patterns=\$2

        find . -type f -name "\$pattern" | while read -r file; do
            if ! echo "\$file" | grep -qE "\$exclude_patterns"; then
                mv "\$file" "\$(dirname "\$file")/gene_sets_\$(basename "\$file")"
            fi
        done
    }

    rename_files "*.tsv" "gene_set_size|gsea_report|ranked_gene_list"
    rename_files "*.html" "gsea_report|index|pos_snapshot|neg_snapshot"
    rename_files "*.png" "enplot|global_es_histogram|gset_rnd_es_dist|pvalues_vs_nes_plot"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gsea: $VERSION
    END_VERSIONS
    """
}
