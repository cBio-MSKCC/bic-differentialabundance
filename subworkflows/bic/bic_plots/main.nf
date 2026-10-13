//
// Subworkflow to run bic rnaseq analysis plots
//

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { HEATMAP } from '../../../modules/bic/rnaseq_analysis_modules/heatmap/main'
include { SAMPLE_TO_SAMPLE_DISTANCE } from '../../../modules/bic/rnaseq_analysis_modules/sample_to_sample_distance/main'
include { PC_LOADING } from '../../../modules/bic/rnaseq_analysis_modules/pc_loading/main'
include { CREATE_SAMPLE_KEY } from '../../../modules/bic/bic_utils/create_sample_key'
include { MDS_CLUSTERING } from '../../../modules/bic/rnaseq_analysis_modules/mds_clustering'

workflow BIC_PLOTS {

    take:
    ch_input  // channel [meta, input.csv]  used in creating sample key
    ch_gene_map // value channel gene_map used in creating gene map
    ch_vst    // channel [meta, vst]
    ch_norm   // channel [meta, normalized counts]
    ch_diff   // channel [key, meta(id,variable,reference,target,blocking), diff_results]
    ch_contrast_variables // channel [meta, variable]

    main:
    ch_versions = Channel.empty()

    // need to make sample key from input.csv
    CREATE_SAMPLE_KEY(ch_contrast_variables, ch_input)
    ch_sample_key = CREATE_SAMPLE_KEY.out.sample_key // tuple [variable, sample_key_file]
    ch_versions = ch_versions.mix(CREATE_SAMPLE_KEY.out.versions)

    // Sample to sample distance
    SAMPLE_TO_SAMPLE_DISTANCE(ch_vst.first(), ch_sample_key)
    ch_versions = ch_versions.mix(SAMPLE_TO_SAMPLE_DISTANCE.out.versions)

    // merge diff results with sample key where the contrast variables match in the meta
    ch_contrast_diff = ch_diff.combine(ch_sample_key)
    .filter { key, meta, results, variable_val, sample_key -> meta.variable == variable_val }
    .map { key, meta, results, variable_val, sample_key ->
        [meta, results, variable_val, sample_key]
    }

    // DE heatmaps
    HEATMAP(ch_norm.first(), ch_contrast_diff, ch_gene_map)
    ch_versions = ch_versions.mix(HEATMAP.out.versions)

    //PC loadings
    PC_LOADING(ch_vst.first(), ch_sample_key, ch_gene_map)
    ch_versions = ch_versions.mix(PC_LOADING.out.versions)

    //MDS clustering
    MDS_CLUSTERING(ch_norm, ch_sample_key)
    ch_versions = ch_versions.mix(MDS_CLUSTERING.out.versions)

    emit:
    versions    = ch_versions

}
