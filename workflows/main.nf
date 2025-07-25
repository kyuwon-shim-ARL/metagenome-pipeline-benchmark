#!/usr/bin/env nextflow

/*
========================================================================================
    METAGENOME PIPELINE BENCHMARKING FRAMEWORK
========================================================================================
    Main workflow for comprehensive pipeline benchmarking
    Github : https://github.com/your-org/metagenome-pipeline-benchmark
----------------------------------------------------------------------------------------
*/

nextflow.enable.dsl = 2

/*
========================================================================================
    PARAMETER VALIDATION & SETUP
========================================================================================
*/

// Validate parameters
if (!params.pipelines_to_test) {
    error "Please specify pipelines to test with --pipelines_to_test"
}

if (!params.datasets) {
    error "Please specify datasets to use for benchmarking"
}

// Print parameter summary
log.info """
        ========================================
         METAGENOME PIPELINE BENCHMARK v${workflow.manifest.version}
        ========================================
        Pipelines to test    : ${params.pipelines_to_test}
        Output directory     : ${params.outdir}
        Datasets             : ${params.datasets.keySet()}
        
        Evaluation Settings:
        - CheckM             : ${params.evaluation.checkm_enabled}
        - BUSCO              : ${params.evaluation.busco_enabled}
        - AMBER              : ${params.evaluation.amber_enabled}
        - GTDB-Tk            : ${params.evaluation.gtdbtk_enabled}
        - EggNOG             : ${params.evaluation.eggnog_enabled}
        ========================================
        """

/*
========================================================================================
    IMPORT MODULES AND SUBWORKFLOWS
========================================================================================
*/

include { PIPELINE_RUNNER }     from './pipeline_runner'
include { EVALUATION_PIPELINE } from './evaluation_pipeline'
include { COMPARISON_WORKFLOW } from './comparison_workflow'

/*
========================================================================================
    MAIN WORKFLOW
========================================================================================
*/

workflow {
    
    // Create channels for datasets and pipelines
    datasets_ch = Channel.from(params.datasets.keySet())
    pipelines_ch = Channel.from(params.pipelines_to_test)
    
    // Create combinations of datasets and pipelines
    dataset_pipeline_combinations = datasets_ch
        .combine(pipelines_ch)
        .map { dataset, pipeline -> 
            [dataset, pipeline, params.datasets[dataset]]
        }
    
    // Run each pipeline on each dataset
    pipeline_results = PIPELINE_RUNNER(
        dataset_pipeline_combinations
    )
    
    // Evaluate pipeline results
    evaluation_results = EVALUATION_PIPELINE(
        pipeline_results
    )
    
    // Perform comparative analysis
    COMPARISON_WORKFLOW(
        evaluation_results.collect()
    )
}

/*
========================================================================================
    WORKFLOW COMPLETION
========================================================================================
*/

workflow.onComplete {
    log.info """
        ========================================
        Pipeline completed at: ${new Date()}
        Execution status: ${workflow.success ? 'OK' : 'failed'}
        Execution duration: ${workflow.duration}
        Results directory: ${params.outdir}
        ========================================
        """
    
    if (workflow.success) {
        log.info """
        
        📊 Benchmark Results Available:
        - HTML Report: ${params.outdir}/reports/benchmark_report.html
        - Summary Tables: ${params.outdir}/tables/
        - Comparison Plots: ${params.outdir}/figures/
        
        """
    }
}