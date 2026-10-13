process MDS_CLUSTERING {
    tag "$meta.id"
    label 'process_single'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        '/juno/bic/depot/singularity/bic_rnaseq_modules/tag/2.0.2/bic_rnaseq_modules_2.0.2.simg' :
        '/juno/bic/depot/singularity/bic_rnaseq_modules/tag/2.0.2/bic_rnaseq_modules_2.0.2.simg' }"

    input:
    tuple val(meta), path(norm)         // normalized counts
    tuple val(contrast_val), path(sample_key) // DE results file 


    output:
    path '*/png/plot_MDS.png' , emit: plot
    path "versions.yml" , emit: versions

    script:
    def args = task.ext.args ?: ''
    def out_prefix = "${contrast_val}/png/plot"

    """
    mkdir -p \$(dirname ${out_prefix})

    Rscript /rnaseq_analysis_modules/sample_clustering.R \
    --norm_counts ${norm} \
    --key_file ${sample_key} \
    --out_prefix ${out_prefix} \
    --method MDS \
    --file_type png \
    ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        r-base: \$(echo \$(R --version 2>&1) | sed 's/^.*R version //; s/ .*\$//')
        rnaseq_analysis_modules: \$(cat /rnaseq_analysis_modules/VERSION.txt)
    END_VERSIONS
    """

}