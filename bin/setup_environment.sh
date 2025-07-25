#!/bin/bash
set -euo pipefail

# Setup script for metagenome pipeline benchmarking environment
# Uses conda for bioinformatics tools and uv for Python packages

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "🚀 Setting up Metagenome Pipeline Benchmarking Environment"
echo "Project directory: $PROJECT_DIR"

# Check if conda is available
if ! command -v conda &> /dev/null; then
    echo "❌ Error: conda is not installed or not in PATH"
    echo "Please install miniconda or anaconda first"
    exit 1
fi

echo "📦 Creating conda environment..."
cd "$PROJECT_DIR"

# Create or update conda environment
if conda env list | grep -q "metagenome-benchmark"; then
    echo "Environment 'metagenome-benchmark' already exists. Updating..."
    conda env update -f environment.yml
else
    echo "Creating new environment 'metagenome-benchmark'..."
    conda env create -f environment.yml
fi

echo "🐍 Activating environment and installing Python packages with uv..."

# Activate environment and install Python packages with uv
source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate metagenome-benchmark

# Verify uv is available
if ! command -v uv &> /dev/null; then
    echo "❌ Error: uv is not available in the conda environment"
    echo "Installing uv via conda..."
    conda install -c conda-forge uv -y
fi

# Install Python packages with uv (much faster than pip)
echo "Installing Python packages with uv..."
uv pip install -r requirements.txt

# Install development dependencies if requested
if [[ "${INSTALL_DEV:-}" == "true" ]]; then
    echo "Installing development dependencies..."
    uv pip install -e ".[dev,viz,workflow]"
else
    echo "Installing core dependencies..."
    uv pip install -e .
fi

echo "🧪 Running basic tests..."
python -c "import pandas, numpy, matplotlib, plotly; print('✅ Core packages imported successfully')"
python -c "import multiqc, Bio; print('✅ Bioinformatics packages imported successfully')"

# Check bioinformatics tools
echo "🔧 Checking bioinformatics tools..."
nextflow -version
singularity --version || apptainer --version || echo "⚠️  Warning: Neither singularity nor apptainer found"
checkm -h > /dev/null && echo "✅ CheckM available" || echo "⚠️  Warning: CheckM not found"

echo "✅ Environment setup complete!"
echo ""
echo "To activate the environment:"
echo "  conda activate metagenome-benchmark"
echo ""
echo "To run benchmarks:"
echo "  ./bin/run_benchmark.sh --help"
echo ""
echo "To install development dependencies:"
echo "  INSTALL_DEV=true ./bin/setup_environment.sh"