/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def checkPathParamList = [ params.input ]
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

// Check mandatory parameters
def exp_meta = [ "id": params.study_name  ]
if (params.input) { ch_input = Channel.of([ exp_meta, file(params.input, checkIfExists: true) ]) } else { exit 1, 'Input samplesheet not specified!' }

if (params.study_type == 'affy_array'){
    if (params.affy_cel_files_archive) {
        ch_celfiles = Channel.of([ exp_meta, file(params.affy_cel_files_archive, checkIfExists: true) ])
    } else {
        error("CEL files archive not specified!")
    }
} else if (params.study_type == 'maxquant') {

        // Should the user have enabled --gsea_run, throw an error
        if (params.gsea_run) {
            error("Cannot run GSEA for maxquant data; please set --gsea_run to false.")
        }
        if (params.gprofiler2_run){
            error("gprofiler2 pathway analysis is not yet possible with maxquant input data; please set --gprofiler2_run false and rerun pipeline!")
        }
        if (!params.matrix) {
            error("Input matrix not specified!")
        }
        matrix_file = file(params.matrix, checkIfExists: true)

        // Make channel for proteus
        proteus_in = Channel.of([ file(params.input), matrix_file ])
} else if (params.study_type == 'geo_soft_file'){

    // To pull SOFT files from a GEO a GSE study identifer must be provided

    if (params.querygse && params.features_metadata_cols) {
        ch_querygse = Channel.of([exp_meta, params.querygse])
    } else {
        error("Query GSE not specified or features metadata columns not specified")
    }
} else {
    // If this is not microarray data or maxquant output, and this an RNA-seq dataset,
    // then assume we're reading from a matrix

    if (params.study_type == "rnaseq" && params.matrix) {
        matrix_file = file(params.matrix, checkIfExists: true)
        ch_in_raw = Channel.of([ exp_meta, matrix_file])
    } else {
        error("Input matrix not specified!")
    }

}

// Check optional parameters
if (params.transcript_length_matrix) { ch_transcript_lengths = Channel.of([ exp_meta, file(params.transcript_length_matrix, checkIfExists: true)]).first() } else { ch_transcript_lengths = [[],[]] }
if (params.control_features) { ch_control_features = Channel.of([ exp_meta, file(params.control_features, checkIfExists: true)]).first() } else { ch_control_features = [[],[]] }

def run_gene_set_analysis = params.gsea_run || params.gprofiler2_run

if (run_gene_set_analysis) {
    if (params.gene_sets_files) {
        gene_sets_files = params.gene_sets_files.split(",")
        ch_gene_sets = Channel.of(gene_sets_files).map { file(it, checkIfExists: true) }
        if (params.gprofiler2_run && (!params.gprofiler2_token && !params.gprofiler2_organism) && gene_sets_files.size() > 1) {
            error("gprofiler2 can currently only work with a single gene set file")
        }
    } else if (params.gsea_run) {
        error("GSEA activated but gene set file not specified!")
    } else if (params.gprofiler2_run) {
        if (!params.gprofiler2_token && !params.gprofiler2_organism) {
            error("To run gprofiler2, please provide a run token, GMT file or organism!")
        }
    } else {
        ch_gene_sets = []    // For methods that can run without gene sets
    }
}

report_file = file(params.report_file, checkIfExists: true)
logo_file = file(params.logo_file, checkIfExists: true)
css_file = file(params.css_file, checkIfExists: true)
citations_file = file(params.citations_file, checkIfExists: true)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { TABULAR_TO_GSEA_CHIP } from '../modules/local/tabular_to_gsea_chip'
include { FILTER_DIFFTABLE } from '../modules/local/filter_difftable'

// bic modules
include { BIC_PLOTS } from '../subworkflows/bic/bic_plots'
include { CREATE_GENE_MAP } from '../modules/bic/bic_utils/create_gene_map'
include { GSEA_GSEA_PRERANKED } from '../modules/bic/gsea/gsea_preranked'
include { getFullConditionList } from '../modules/bic/bic_utils/general'
include { MOVE_INPUT_FILES } from '../modules/bic/bic_utils/move_input_files'
include { PREFORMAT_INPUT } from '../modules/bic/preformat_input/main'
include { REFORMAT_DE } from '../modules/bic/bic_utils/reformat_de'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { GUNZIP as GUNZIP_GTF                              } from '../modules/nf-core/gunzip/main'
include { UNTAR                                             } from '../modules/nf-core/untar/main.nf'
include { SHINYNGS_APP                                      } from '../modules/nf-core/shinyngs/app/main'
include { SHINYNGS_STATICEXPLORATORY as PLOT_EXPLORATORY    } from '../modules/nf-core/shinyngs/staticexploratory/main'
include { SHINYNGS_STATICDIFFERENTIAL as PLOT_DIFFERENTIAL  } from '../modules/nf-core/shinyngs/staticdifferential/main'
include { SHINYNGS_VALIDATEFOMCOMPONENTS as VALIDATOR       } from '../modules/nf-core/shinyngs/validatefomcomponents/main'
include { DESEQ2_DIFFERENTIAL as DESEQ2_NORM                } from '../modules/nf-core/deseq2/differential/main'
include { DESEQ2_DIFFERENTIAL                               } from '../modules/nf-core/deseq2/differential/main'
include { LIMMA_DIFFERENTIAL                                } from '../modules/nf-core/limma/differential/main'
include { CUSTOM_MATRIXFILTER                               } from '../modules/nf-core/custom/matrixfilter/main'
include { ATLASGENEANNOTATIONMANIPULATION_GTF2FEATUREANNOTATION as GTF_TO_TABLE } from '../modules/nf-core/atlasgeneannotationmanipulation/gtf2featureannotation/main'
include { GSEA_GSEA                                         } from '../modules/nf-core/gsea/gsea/main'
include { GPROFILER2_GOST                                   } from '../modules/nf-core/gprofiler2/gost/main'
include { CUSTOM_TABULARTOGSEAGCT                           } from '../modules/nf-core/custom/tabulartogseagct/main'
include { CUSTOM_TABULARTOGSEACLS                           } from '../modules/nf-core/custom/tabulartogseacls/main'
include { RMARKDOWNNOTEBOOK                                 } from '../modules/nf-core/rmarkdownnotebook/main'
include { AFFY_JUSTRMA as AFFY_JUSTRMA_RAW                  } from '../modules/nf-core/affy/justrma/main'
include { AFFY_JUSTRMA as AFFY_JUSTRMA_NORM                 } from '../modules/nf-core/affy/justrma/main'
include { PROTEUS_READPROTEINGROUPS as PROTEUS              } from '../modules/nf-core/proteus/readproteingroups/main'
include { GEOQUERY_GETGEO                                   } from '../modules/nf-core/geoquery/getgeo/main'
include { ZIP as MAKE_REPORT_BUNDLE                         } from '../modules/nf-core/zip/main'
include { softwareVersionsToYAML                            } from '../subworkflows/nf-core/utils_nfcore_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow DIFFERENTIALABUNDANCE {

    // Set up some basic variables
    ch_versions = Channel.empty()
    // Channel for the contrasts file
    ch_contrasts_file = Channel.from([[exp_meta, file(params.contrasts)]])

    // Move the input files to the workdir
    MOVE_INPUT_FILES(
        ch_input,
        ch_contrasts_file,
        ch_in_raw
    )
    ch_versions = ch_versions.mix(MOVE_INPUT_FILES.out.versions)

    // Now that input and constrasts files hare created - we can preformat the input file
    PREFORMAT_INPUT(
        ch_input,
        ch_contrasts_file,
        ch_in_raw
    )
    ch_input = PREFORMAT_INPUT.out.updated_input
    ch_in_raw = PREFORMAT_INPUT.out.updated_counts
    ch_versions = ch_versions.mix(PREFORMAT_INPUT.out.versions)

    // If we have affy array data in the form of CEL files we'll be deriving
    // matrix and annotation from them

    if (params.study_type == 'affy_array'){

        // Uncompress the CEL files archive

        UNTAR ( ch_celfiles )

        ch_affy_input = ch_input
            .join(UNTAR.out.untar)

        // Run affy to derive the matrix. Reset the meta so it can be used to
        // define a prefix for different matrix flavours

        AFFY_JUSTRMA_RAW (
            ch_affy_input,
            [[],[]]
        )
        AFFY_JUSTRMA_NORM (
            ch_affy_input,
            [[],[]]
        )

        // Fetch affy outputs and reset the meta

        ch_in_raw = AFFY_JUSTRMA_RAW.out.expression
        ch_in_norm = AFFY_JUSTRMA_NORM.out.expression

        ch_affy_platform_features = AFFY_JUSTRMA_RAW.out.annotation

        ch_versions = ch_versions
            .mix(AFFY_JUSTRMA_RAW.out.versions)

    } else if (params.study_type == 'maxquant'){

        // We'll be running Proteus once per unique contrast variable to generate plots
        // TODO: there should probably be a separate plotting module in proteus to simplify this

        ch_contrast_variables = ch_contrasts_file
            .splitCsv ( header:true, sep:(params.contrasts.endsWith('tsv') ? '\t' : ','))
            .map{ it.tail().first() }
            .map{
                tuple('id': it.variable)
            }
            .unique()   // uniquify to keep each contrast variable only once (in case it exists in multiple lines for blocking etc.)

        // Run proteus to import protein abundances
        PROTEUS(
            ch_contrast_variables.combine(proteus_in)
        )

        // Re-map the proteus output tables to the study ID as the tables are the same across contrasts, only one norm table will be necessary
        ch_in_raw = PROTEUS.out.raw_tab
            .first()
            .map{ meta, matrix -> tuple(exp_meta, matrix) }
        ch_in_norm = PROTEUS.out.norm_tab
            .first()
            .map{ meta, matrix -> tuple(exp_meta, matrix) }

        ch_versions = ch_versions.mix(PROTEUS.out.versions)
    } else if(params.study_type == 'geo_soft_file'){

        GEOQUERY_GETGEO(ch_querygse)
        ch_in_norm = GEOQUERY_GETGEO.out.expression
        ch_soft_features = GEOQUERY_GETGEO.out.annotation

        ch_versions = ch_versions
            .mix(GEOQUERY_GETGEO.out.versions)
    }
    //// Fetch or derive a feature annotation table

    // If user has provided a feature annotation table, use that
    if (params.features){
        ch_features = Channel.of([ exp_meta, file(params.features, checkIfExists: true)])
    } else if (params.study_type == 'affy_array'){
        ch_features = ch_affy_platform_features
    } else if(params.study_type == 'geo_soft_file') {
        ch_features = ch_soft_features
    } else if (params.gtf){
        // Get feature annotations from a GTF file, gunzip if necessary

        file_gtf_in = file(params.gtf)
        file_gtf = [ [ "id": file_gtf_in.simpleName ], file_gtf_in ]

        if ( params.gtf.endsWith('.gz') ){
            GUNZIP_GTF(file_gtf)
            file_gtf = GUNZIP_GTF.out.gunzip
            ch_versions = ch_versions.mix(GUNZIP_GTF.out.versions)
        }

        // Get a features table from the GTF and combine with the matrix and sample
        // annotation (fom = features/ observations/ matrix)

        GTF_TO_TABLE( file_gtf, [[ "id":""], []])
        ch_features = GTF_TO_TABLE.out.feature_annotation
            .map{
                tuple( exp_meta, it[1])
            }

        // Record the version of the GTF -> table tool

        ch_versions = ch_versions
            .mix(GTF_TO_TABLE.out.versions)
    }
    else{

        // Otherwise we can just use the matrix input; save it to the workdir so that it does not
        // just appear wherever the user runs the pipeline
        matrix_as_anno_filename = "${workflow.workDir}/matrix_as_anno.${matrix_file.getExtension()}"
        if (params.study_type == 'maxquant'){
            ch_features_matrix = ch_in_norm
        } else {
            ch_features_matrix = ch_in_raw
        }
        ch_features = ch_features_matrix
            .map{ meta, matrix ->
                matrix.copyTo(matrix_as_anno_filename)
                [ meta, file(matrix_as_anno_filename) ]
            }
    }

    // Check compatibility of FOM elements and contrasts
    if (params.study_type == 'affy_array' || params.study_type == 'maxquant'){
        ch_matrices_for_validation = ch_in_raw
            .join(ch_in_norm)
            .map{tuple(it[0], [it[1], it[2]])}
    }
    else if (params.study_type == 'geo_soft_file'){
        ch_matrices_for_validation = ch_in_norm
    }
    else{
        ch_matrices_for_validation = ch_in_raw
    }

    VALIDATOR(
        ch_input.join(ch_matrices_for_validation),
        ch_features,
        ch_contrasts_file
    )

    // For Affy, we've validated multiple input matrices for raw and norm,
    // we'll separate them out again here

    if (params.study_type == 'affy_array' || params.study_type == 'maxquant'){
        ch_validated_assays = VALIDATOR.out.assays
            .transpose()
            .branch {
                raw: it[1].name.contains('raw')
                normalised: it[1].name =~ /normali[sz]ed/
            }
        ch_raw = ch_validated_assays.raw
        ch_norm = ch_validated_assays.normalised
    }
    else if (params.study_type == 'geo_soft_file') {
        ch_norm = VALIDATOR.out.assays
    }

    if(params.study_type != 'rnaseq') {
        ch_matrix_for_differential = ch_norm
    }
    else{
        ch_raw = VALIDATOR.out.assays
        ch_matrix_for_differential = ch_raw
    }

    // Split the contrasts up so we can run differential analyses and
    // downstream plots separately.
    // Replace NA strings that might have snuck into the blocking column

    ch_contrasts = VALIDATOR.out.contrasts
        .map{it[1]}
        .splitCsv ( header:true, sep:'\t' )
        .map{
            it.blocking = it.blocking.replace('NA', '')
            if (!it.id){
                it.id = it.values().join('_')
            }
            tuple(it, it.variable, it.reference, it.target)
        }

    // Firstly Filter the input matrix

    CUSTOM_MATRIXFILTER(
        ch_matrix_for_differential,
        VALIDATOR.out.sample_meta
    )

    // Prepare inputs for differential processes

    ch_samples_and_matrix = VALIDATOR.out.sample_meta
        .join(CUSTOM_MATRIXFILTER.out.filtered)     // -> meta, samplesheet, filtered matrix
        .first()

    if (params.study_type == 'affy_array' || params.study_type == 'geo_soft_file' || params.study_type == 'maxquant'){

        LIMMA_DIFFERENTIAL (
            ch_contrasts,
            ch_samples_and_matrix
        )
        ch_differential = LIMMA_DIFFERENTIAL.out.results
        ch_model = LIMMA_DIFFERENTIAL.out.model

        ch_versions = ch_versions
            .mix(LIMMA_DIFFERENTIAL.out.versions)

        ch_processed_matrices = ch_norm
            .map{ it.tail() }
            .first()
    }
    else{

        DESEQ2_NORM (
            ch_contrasts.first(),
            ch_samples_and_matrix,
            ch_control_features,
            ch_transcript_lengths
        )

        // Run the DESeq differential module, which doesn't take the feature
        // annotations

        DESEQ2_DIFFERENTIAL (
            ch_contrasts,
            ch_samples_and_matrix,
            ch_control_features,
            ch_transcript_lengths
        )

        // Let's make the simplifying assumption that the processed matrices from
        // the DESeq runs are the same across contrasts. We run the DESeq process
        // with matrices once for each contrast because DESeqDataSetFromMatrix()
        // takes the model, and the model can vary between contrasts if the
        // blocking factors included differ. But the normalised and
        // variance-stabilised matrices are not (IIUC) impacted by the model.

        ch_norm = DESEQ2_NORM.out.normalised_counts
        ch_differential = DESEQ2_DIFFERENTIAL.out.results
        ch_model = DESEQ2_DIFFERENTIAL.out.model

        ch_versions = ch_versions
            .mix(DESEQ2_DIFFERENTIAL.out.versions)

        ch_processed_matrices = ch_norm
        if ('rlog' in params.deseq2_vs_method){
            ch_processed_matrices = ch_processed_matrices.join(DESEQ2_NORM.out.rlog_counts)
        }
        if ('vst' in params.deseq2_vs_method){
            ch_processed_matrices = ch_processed_matrices.join(DESEQ2_NORM.out.vst_counts)
        }
        ch_processed_matrices = ch_processed_matrices
            .map{ it.tail() }
    }

    // We'll use a local module to filter the differential tables and create output files that contain only differential features
    ch_logfc = Channel.value([ params.differential_fc_column, params.differential_min_fold_change ])
    ch_padj = Channel.value([ params.differential_qval_column, params.differential_max_qval ])

    FILTER_DIFFTABLE(
        ch_differential,
        ch_logfc,
        ch_padj
    )

    // Run a gene set analysis where directed

    // Currently, we're letting GSEA work on the expression data. In future we
    // will allow use of GSEA preranked instead, which will work with the fold
    // changes/ p values from DESeq2

    if (params.gsea_run){

        // For GSEA, we need to convert normalised counts to a GCT format for
        // input, and process the sample sheet to generate class definitions
        // (CLS) for the variable used in each contrast

        CUSTOM_TABULARTOGSEAGCT ( ch_norm )

        // TODO: update CUSTOM_TABULARTOGSEACLS for value channel input per new
        // guidlines (rather than meta usage employed here)

        ch_contrasts_and_samples = ch_contrasts
            .map{it[0]} // revert back to contrasts meta map
            .combine( VALIDATOR.out.sample_meta.map { it[1] } )

        CUSTOM_TABULARTOGSEACLS(ch_contrasts_and_samples)

        TABULAR_TO_GSEA_CHIP(
            VALIDATOR.out.feature_meta.map{ it[1] },
            [params.features_id_col, params.features_name_col]
        )

        ch_versions = ch_versions
            .mix(TABULAR_TO_GSEA_CHIP.out.versions)

        // If any group has < 3 samples, run GSEA_GSEA_PRERANKED instead of GSEA_GSEA
        // Check that the conditions have at least 3 samples
        def run_prerank = false
        def cond_list = getFullConditionList()

        // Get unique conditions
        def unique_cond = cond_list.unique(false)

        // Iterate over the unique conditions and check sample sizes
        for (cndtn in unique_cond) {
            if (cond_list.findAll { it == cndtn }.size() < 3) {
                log.warn "Condition ${cndtn} has less than 3 samples. Prerank will run for ALL comparisons."
                run_prerank = true
                break
            }
        }

        if(run_prerank) {
            GSEA_GSEA_PRERANKED(
                ch_differential,
                ch_gene_sets.first(),
                TABULAR_TO_GSEA_CHIP.out.chip.first())

            ch_gsea_results = GSEA_GSEA_PRERANKED.out.report_tsvs_ref
                .join(GSEA_GSEA_PRERANKED.out.report_tsvs_target)

            // Record GSEA versions
            ch_versions = ch_versions
                .mix(GSEA_GSEA_PRERANKED.out.versions)
        } else {

            // The normalised matrix does not always have a contrast meta, so we
            // need a combine rather than a join here
            // Also add file name to metamap for easy access from modules.config

            ch_gsea_inputs = CUSTOM_TABULARTOGSEAGCT.out.gct
                .map{ it.tail() }
                .combine(CUSTOM_TABULARTOGSEACLS.out.cls)
                .map{ tuple(it[1], it[0], it[2]) }
                .combine(ch_gene_sets)

            GSEA_GSEA(
                ch_gsea_inputs,
                ch_gsea_inputs.map{ tuple(it[0].reference, it[0].target) }, // *
                TABULAR_TO_GSEA_CHIP.out.chip.first()
            )


            // * Note: GSEA module currently uses a value channel for the mandatory
            // non-file arguments used to define contrasts, hence the indicated
            // usage of map to perform that transformation. An active subject of
            // debate

            ch_gsea_results = GSEA_GSEA.out.report_tsvs_ref
                .join(GSEA_GSEA.out.report_tsvs_target)

            // Record GSEA versions
            ch_versions = ch_versions
                .mix(GSEA_GSEA.out.versions)

        }
    }

    if (params.gprofiler2_run) {

        // For gprofiler2, use only features that are considered differential
        ch_filtered_diff = FILTER_DIFFTABLE.out.filtered

        if (!params.gprofiler2_background_file) {
            // If deactivated, use empty list as "background"
            ch_background = []
        } else if (params.gprofiler2_background_file == "auto") {
            // If auto, use input matrix as background
            ch_background = CUSTOM_MATRIXFILTER.out.filtered.map{it.tail()}.first()
        } else {
            ch_background = Channel.from(file(params.gprofiler2_background_file, checkIfExists: true))
        }

        // For gprofiler2, token and organism have priority and will override a gene_sets file

        GPROFILER2_GOST(
            ch_filtered_diff,
            ch_gene_sets.first(),
            ch_background
        )
    }

    // The exploratory plots are made by coloring by every unique variable used
    // to define contrasts

    ch_contrast_variables = ch_contrasts
        .map{
            [ "id": it[1] ]
        }
        .unique()

    // For geoquery we've done no matrix processing and been supplied with the
    // normalised matrix, which can be passed through to downstream analysis

    if(params.study_type == "geo_soft_file") {
        ch_mat = ch_norm
    }else{
        ch_mat = ch_raw.combine(ch_processed_matrices)
    }

    ch_all_matrices = VALIDATOR.out.sample_meta                 // meta, samples
        .join(VALIDATOR.out.feature_meta)                       // meta, samples, features
        .join(ch_mat)                                           // meta, samples, features, raw, norm (or just norm)
        .map{
            tuple(it[0], it[1], it[2], it[3..it.size()-1])
        }
        .first()

    PLOT_EXPLORATORY(
        ch_contrast_variables
            .combine(ch_all_matrices.map{ it.tail() })
    )

    // Differential analysis using the results of DESeq2

    PLOT_DIFFERENTIAL(
        ch_differential,
        ch_all_matrices
    )

    // BIC SPECIFIC
    // need to make gene map from counts file
    CREATE_GENE_MAP(ch_in_raw)
    ch_gene_map = CREATE_GENE_MAP.out.gene_map.first()
    ch_versions = ch_versions.mix(CREATE_GENE_MAP.out.versions)

    // ch_differential is DESEQ output.
    ch_de_data = ch_differential.join(FILTER_DIFFTABLE.out.filtered).join(DESEQ2_DIFFERENTIAL.out.rdata)
    REFORMAT_DE(
        ch_de_data,
        ch_gene_map
    )

    ch_vst = DESEQ2_NORM.out.vst_counts
    BIC_PLOTS(
        ch_input,             // channel [meta, input.csv]
        ch_gene_map,          // value channel gene map
        ch_vst,               // channel [meta, vst]
        ch_norm,              // channel [meta, normalized counts]
        ch_differential,      // channel [meta, diff results]
        ch_contrast_variables // channel [meta]
    )

    // Gather software versions

    ch_versions = ch_versions
        .mix(VALIDATOR.out.versions)
        .mix(PLOT_EXPLORATORY.out.versions)
        .mix(PLOT_DIFFERENTIAL.out.versions)
        .mix(BIC_PLOTS.out.versions)

    //
    // Collate and save software versions
    //

    ch_collated_versions = softwareVersionsToYAML(ch_versions)
        .collectFile(storeDir: "${params.outdir}/pipeline_info", name: 'collated_versions.yml', sort: true, newLine: true)

    // Generate a list of files that will be used by the markdown report

    ch_report_file = Channel.from(report_file)
        .map{ tuple(exp_meta, it) }

    ch_logo_file = Channel.from(logo_file)
    ch_css_file = Channel.from(css_file)
    ch_citations_file = Channel.from(citations_file)

    ch_report_input_files = ch_all_matrices
        .map{ it.tail() }
        .map{it.flatten()}
        .combine(VALIDATOR.out.contrasts.map{it.tail()})
        .combine(ch_collated_versions)
        .combine(ch_logo_file)
        .combine(ch_css_file)
        .combine(ch_citations_file)
        .combine(ch_differential.map{it[1]}.toList())
        .combine(ch_model.map{it[1]}.toList())

    if (params.gsea_run){
        ch_report_input_files = ch_report_input_files
            .combine(ch_gsea_results
                .map{it.tail()}.flatMap().toList()
            )
    }

    if (params.gprofiler2_run){
        ch_report_input_files = ch_report_input_files
            .combine(GPROFILER2_GOST.out.plot_html.map{it[1]}.flatMap().toList())
            .combine(GPROFILER2_GOST.out.all_enrich.map{it[1]}.flatMap().toList())
            .combine(GPROFILER2_GOST.out.sub_enrich.map{it[1]}.flatMap().toList())
        GPROFILER2_GOST.out.plot_html
    }

    if (params.shinyngs_build_app){

        // Make (and optionally deploy) the shinyngs app

        // Make a new contrasts file from the differential metas to guarantee the
        // same order as the differential results

        ch_app_differential = ch_differential.first().map{it[0].keySet().join(',')}
            .concat(
                ch_differential.map{it[0].values().join(',')}
            )
            .collectFile(name: 'contrasts.csv', newLine: true, sort: false)
            .map{
                tuple(exp_meta, it)
            }
            .combine(ch_differential.map{it[1]}.collect().map{[it]})

        SHINYNGS_APP(
            ch_all_matrices,     // meta, samples, features, [  matrices ]
            ch_app_differential, // meta, contrasts, [differential results]
            params.exploratory_assay_names.split(',').findIndexOf { it == params.exploratory_final_assay } + 1
        )
        ch_versions = ch_versions.mix(SHINYNGS_APP.out.versions)
    }

    // Make a params list - starting with the input matrices and the relevant
    // params to use in reporting

    def report_file_names = [ 'observations', 'features' ] +
        params.exploratory_assay_names.split(',').collect { "${it}_matrix".toString() } +
        [ 'contrasts_file', 'versions_file', 'logo', 'css', 'citations' ]

    // Condition params reported on study type

    def params_pattern = "report|gene_sets|study|observations|features|filtering|exploratory|differential"
    if (params.study_type == 'rnaseq'){
        params_pattern += "|deseq2"
    }
    if (params.study_type == 'affy_array' || params.study_type == 'geo_soft_file'){
        params_pattern += "|affy|limma"
    }
    if (params.study_type == 'maxquant'){
        params_pattern += "|proteus|limma"
    }
    if (params.gprofiler2_run){
        params_pattern += "|gprofiler2"
    }
    if (params.gsea_run){
        params_pattern += "|gsea"
    }
    params_pattern = ~/(${params_pattern}).*/

    ch_report_params = ch_report_input_files
        .map{
            params.findAll{ k,v -> k.matches(params_pattern) } +
            [report_file_names, it.collect{ f -> f.name}].transpose().collectEntries()
        }

    // Render the final report
    RMARKDOWNNOTEBOOK(
        ch_report_file,
        ch_report_params,
        ch_report_input_files
    )

    // Make a report bundle comprising the markdown document and all necessary
    // input files

    MAKE_REPORT_BUNDLE(
        RMARKDOWNNOTEBOOK.out.parameterised_notebook
            .combine(ch_report_input_files)
            .map{[it[0], it[1..-1]]}
    )

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
