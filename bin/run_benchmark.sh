#!/bin/bash
set -euo pipefail

# Main benchmark execution script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Default values
CONFIG_FILE="${PROJECT_DIR}/configs/benchmark.config"
PROFILE="standard"
RESUME=""
WORK_DIR="${PROJECT_DIR}/work"
HELP=false

# Function to show help
show_help() {
    cat << EOF
Metagenome Pipeline Benchmarking Framework

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -c, --config FILE       Configuration file (default: configs/benchmark.config)
    -p, --profile PROFILE   Execution profile (default: standard)
                           Available: standard, slurm, singularity
    -r, --resume           Resume previous run
    -w, --work-dir DIR     Work directory (default: work/)
    -h, --help             Show this help message

EXAMPLES:
    # Basic benchmark run
    $0

    # Run with singularity containers
    $0 --profile singularity

    # Resume previous run
    $0 --resume

    # Custom configuration
    $0 --config my_custom.config --profile slurm

    # Full example
    $0 --config configs/benchmark.config --profile singularity --resume

PROFILES:
    standard    - Local execution
    slurm       - SLURM cluster execution  
    singularity - Use Singularity containers

For more information, see: docs/tutorials/running_benchmarks.md
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -p|--profile)
            PROFILE="$2"
            shift 2
            ;;
        -r|--resume)
            RESUME="-resume"
            shift
            ;;
        -w|--work-dir)
            WORK_DIR="$2"
            shift 2
            ;;
        -h|--help)
            HELP=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

if [[ "$HELP" == "true" ]]; then
    show_help
    exit 0
fi

# Validate inputs
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ Error: Configuration file not found: $CONFIG_FILE"
    exit 1
fi

echo "🚀 Starting Metagenome Pipeline Benchmark"
echo "📝 Configuration: $CONFIG_FILE"
echo "🏃 Profile: $PROFILE"
echo "📁 Work directory: $WORK_DIR"

# Check if Nextflow is available
if ! command -v nextflow &> /dev/null; then
    echo "❌ Error: Nextflow is not installed or not in PATH"
    echo "Please install Nextflow or activate the conda environment:"
    echo "  conda activate metagenome-benchmark"
    exit 1
fi

# Change to project directory
cd "$PROJECT_DIR"

# Create necessary directories
mkdir -p results/{reports,figures,tables}
mkdir -p data/{raw,processed,reference}

echo "🔥 Executing benchmark workflow..."

# Run the benchmark
nextflow run workflows/main.nf \
    -c "$CONFIG_FILE" \
    -profile "$PROFILE" \
    -work-dir "$WORK_DIR" \
    $RESUME \
    -with-report results/reports/execution_report.html \
    -with-timeline results/reports/execution_timeline.html \
    -with-trace results/reports/execution_trace.txt \
    -with-dag results/reports/pipeline_dag.html

# Check if execution was successful
if [[ $? -eq 0 ]]; then
    echo "✅ Benchmark completed successfully!"
    echo ""
    echo "📊 Results available at:"
    echo "  - Main report: results/reports/benchmark_report.html"
    echo "  - Execution report: results/reports/execution_report.html"
    echo "  - Timeline: results/reports/execution_timeline.html"
    echo ""
    echo "🔍 To view results:"
    echo "  open results/reports/benchmark_report.html"
    echo ""
else
    echo "❌ Benchmark failed. Check the logs for details."
    echo "📋 Execution trace: results/reports/execution_trace.txt"
    exit 1
fi