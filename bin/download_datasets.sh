#!/bin/bash
set -euo pipefail

# Dataset download script for metagenome pipeline benchmarking
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Default options
DOWNLOAD_CAMI2=true
DOWNLOAD_METASUB=true
SMALL_TEST=false
FORCE_DOWNLOAD=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Function to show help
show_help() {
    cat << EOF
Dataset Download Script for Metagenome Pipeline Benchmarking

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --cami2-only        Download CAMI-2 datasets only
    --metasub-only      Download MetaSUB datasets only
    --small-test        Download small test datasets only
    --force             Force re-download existing files
    -h, --help          Show this help message

EXAMPLES:
    # Download all datasets
    $0

    # Download only CAMI-2 data
    $0 --cami2-only

    # Download small test datasets for development
    $0 --small-test

    # Force re-download all datasets
    $0 --force

STORAGE REQUIREMENTS:
    - CAMI-2 full: ~150 GB
    - MetaSUB full: ~300 GB  
    - Small test: ~5 GB
    - Total full: ~450 GB

Make sure you have sufficient disk space before proceeding.
EOF
}

# Function to check available disk space
check_disk_space() {
    local required_gb=$1
    local available_gb=$(df -BG "$PROJECT_DIR" | awk 'NR==2 {print $4}' | sed 's/G//')
    
    if [ "$available_gb" -lt "$required_gb" ]; then
        print_error "Insufficient disk space. Required: ${required_gb}GB, Available: ${available_gb}GB"
        exit 1
    fi
    
    print_info "Disk space check passed. Available: ${available_gb}GB, Required: ${required_gb}GB"
}

# Function to create necessary directories
setup_directories() {
    print_info "Creating directory structure..."
    
    mkdir -p "$PROJECT_DIR/data/raw/cami2"
    mkdir -p "$PROJECT_DIR/data/raw/metasub"
    mkdir -p "$PROJECT_DIR/data/reference/cami2"
    mkdir -p "$PROJECT_DIR/data/processed"
    
    print_success "Directory structure created"
}

# Function to download CAMI-2 datasets
download_cami2() {
    print_info "Downloading CAMI-2 datasets..."
    
    local cami2_dir="$PROJECT_DIR/data/raw/cami2"
    local ref_dir="$PROJECT_DIR/data/reference/cami2"
    
    # Check if already downloaded and not forcing
    if [ -f "$cami2_dir/samplesheet.csv" ] && [ "$FORCE_DOWNLOAD" = false ]; then
        print_warning "CAMI-2 data already exists. Use --force to re-download."
        return 0
    fi
    
    if [ "$SMALL_TEST" = true ]; then
        print_info "Downloading CAMI-2 test datasets (small)..."
        
        # Download small test files (you'll need to replace with actual URLs)
        # This is a placeholder - replace with actual CAMI-2 URLs
        cat > "$cami2_dir/samplesheet.csv" << EOF
sample,short_reads_1,short_reads_2,ground_truth
cami2_test,data/raw/cami2/test_R1.fastq.gz,data/raw/cami2/test_R2.fastq.gz,data/reference/cami2/test_truth.txt
EOF
        
        # Create placeholder test files
        print_warning "Creating placeholder test files (replace with actual CAMI-2 downloads)"
        touch "$cami2_dir/test_R1.fastq.gz"
        touch "$cami2_dir/test_R2.fastq.gz"
        touch "$ref_dir/test_truth.txt"
        
    else
        print_info "Downloading full CAMI-2 datasets..."
        
        # Full CAMI-2 download (replace URLs with actual CAMI-2 links)
        print_warning "CAMI-2 download URLs need to be configured"
        print_info "Please visit https://data.cami-challenge.org/ to get download links"
        print_info "Then update this script with actual URLs"
        
        # Placeholder samplesheet
        cat > "$cami2_dir/samplesheet.csv" << EOF
sample,short_reads_1,short_reads_2,ground_truth
cami2_sample1,data/raw/cami2/sample1_R1.fastq.gz,data/raw/cami2/sample1_R2.fastq.gz,data/reference/cami2/sample1_truth.txt
cami2_sample2,data/raw/cami2/sample2_R1.fastq.gz,data/raw/cami2/sample2_R2.fastq.gz,data/reference/cami2/sample2_truth.txt
EOF
    fi
    
    print_success "CAMI-2 dataset setup completed"
}

# Function to download MetaSUB datasets
download_metasub() {
    print_info "Downloading MetaSUB datasets..."
    
    local metasub_dir="$PROJECT_DIR/data/raw/metasub"
    
    # Check if already downloaded and not forcing
    if [ -f "$metasub_dir/samplesheet.csv" ] && [ "$FORCE_DOWNLOAD" = false ]; then
        print_warning "MetaSUB data already exists. Use --force to re-download."
        return 0
    fi
    
    # Check if SRA toolkit is available
    if ! command -v fastq-dump &> /dev/null && ! command -v fasterq-dump &> /dev/null; then
        print_error "SRA toolkit not found. Please install sra-tools:"
        print_info "  conda install -c bioconda sra-tools"
        return 1
    fi
    
    if [ "$SMALL_TEST" = true ]; then
        print_info "Downloading MetaSUB test datasets (small)..."
        
        # Download a small test sample
        local test_accession="SRR8650234"  # Example accession
        
        if command -v fasterq-dump &> /dev/null; then
            fasterq-dump --split-files --skip-technical "$test_accession" -O "$metasub_dir/" || true
            gzip "$metasub_dir"/*.fastq || true
        else
            fastq-dump --split-files --gzip "$test_accession" -O "$metasub_dir/" || true
        fi
        
        # Create test samplesheet
        cat > "$metasub_dir/samplesheet.csv" << EOF
sample,short_reads_1,short_reads_2,environment,location,complexity
metasub_test,data/raw/metasub/${test_accession}_1.fastq.gz,data/raw/metasub/${test_accession}_2.fastq.gz,subway,test,medium
EOF
        
    else
        print_info "Downloading full MetaSUB datasets..."
        
        # List of MetaSUB accessions (examples - replace with actual ones)
        local accessions=(
            "SRR8650234"  # NYC Subway
            "SRR8650235"  # Boston Park
            "SRR8650236"  # SF Beach
        )
        
        for accession in "${accessions[@]}"; do
            print_info "Downloading $accession..."
            
            if command -v fasterq-dump &> /dev/null; then
                fasterq-dump --split-files --skip-technical "$accession" -O "$metasub_dir/"
                gzip "$metasub_dir"/*.fastq
            else
                fastq-dump --split-files --gzip "$accession" -O "$metasub_dir/"
            fi
        done
        
        # Create full samplesheet
        cat > "$metasub_dir/samplesheet.csv" << EOF
sample,short_reads_1,short_reads_2,environment,location,complexity
metasub_subway_nyc,data/raw/metasub/SRR8650234_1.fastq.gz,data/raw/metasub/SRR8650234_2.fastq.gz,subway,NYC,high
metasub_park_boston,data/raw/metasub/SRR8650235_1.fastq.gz,data/raw/metasub/SRR8650235_2.fastq.gz,park,Boston,medium
metasub_beach_sf,data/raw/metasub/SRR8650236_1.fastq.gz,data/raw/metasub/SRR8650236_2.fastq.gz,beach,SF,low
EOF
    fi
    
    print_success "MetaSUB dataset setup completed"
}

# Function to validate downloads
validate_downloads() {
    print_info "Validating downloaded datasets..."
    
    local errors=0
    
    # Check CAMI-2 files
    if [ "$DOWNLOAD_CAMI2" = true ]; then
        if [ ! -f "$PROJECT_DIR/data/raw/cami2/samplesheet.csv" ]; then
            print_error "CAMI-2 samplesheet not found"
            ((errors++))
        fi
    fi
    
    # Check MetaSUB files
    if [ "$DOWNLOAD_METASUB" = true ]; then
        if [ ! -f "$PROJECT_DIR/data/raw/metasub/samplesheet.csv" ]; then
            print_error "MetaSUB samplesheet not found"
            ((errors++))
        fi
    fi
    
    if [ $errors -eq 0 ]; then
        print_success "All datasets validated successfully"
    else
        print_error "$errors validation errors found"
        return 1
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --cami2-only)
            DOWNLOAD_CAMI2=true
            DOWNLOAD_METASUB=false
            shift
            ;;
        --metasub-only)
            DOWNLOAD_CAMI2=false
            DOWNLOAD_METASUB=true
            shift
            ;;
        --small-test)
            SMALL_TEST=true
            shift
            ;;
        --force)
            FORCE_DOWNLOAD=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Main execution
main() {
    print_info "Starting dataset download process..."
    
    # Estimate required space
    local required_space=5  # Default for small test
    if [ "$SMALL_TEST" = false ]; then
        if [ "$DOWNLOAD_CAMI2" = true ] && [ "$DOWNLOAD_METASUB" = true ]; then
            required_space=450
        elif [ "$DOWNLOAD_CAMI2" = true ]; then
            required_space=150
        elif [ "$DOWNLOAD_METASUB" = true ]; then
            required_space=300
        fi
    fi
    
    # Check disk space
    check_disk_space $required_space
    
    # Setup directories
    setup_directories
    
    # Download datasets
    if [ "$DOWNLOAD_CAMI2" = true ]; then
        download_cami2
    fi
    
    if [ "$DOWNLOAD_METASUB" = true ]; then
        download_metasub
    fi
    
    # Validate downloads
    validate_downloads
    
    print_success "Dataset download completed successfully!"
    print_info ""
    print_info "Next steps:"
    print_info "1. Review the samplesheets in data/raw/"
    print_info "2. Run benchmark: ./bin/run_benchmark.sh"
    print_info "3. Check results in results/"
}

# Run main function
main