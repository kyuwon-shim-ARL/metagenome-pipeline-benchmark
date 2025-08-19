#!/bin/bash
# Production Metagenome Database Setup
# Creates shared database structure for immediate use with future team expansion capability

set -e

# Configuration
SHARED_DB="/data/shared/metagenome-db"
CURRENT_DB="/db"
BACKUP_DIR="$HOME/db_setup_backup_$(date +%Y%m%d_%H%M%S)"

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo
    echo "================================================================="
    echo "    🚀 Production Metagenome Database Setup"
    echo "================================================================="
    echo
    echo "This script will create a production-ready shared database"
    echo "structure that's immediately usable and team-expansion ready."
    echo
}

check_prerequisites() {
    log_step "Checking prerequisites..."
    
    # Check if running as user with sudo access
    if ! sudo -n true 2>/dev/null; then
        log_error "This script requires sudo access for directory creation"
        echo "Please run: sudo -v"
        exit 1
    fi
    
    # Check if current DB exists
    if [ ! -d "$CURRENT_DB" ]; then
        log_warn "Current database directory $CURRENT_DB not found"
        log_info "Will create structure without existing DB links"
    fi
    
    # Check available disk space
    REQUIRED_SPACE=50  # GB
    AVAILABLE_SPACE=$(df /data 2>/dev/null | awk 'NR==2 {print int($4/1048576)}' || echo 100)
    
    # Handle empty AVAILABLE_SPACE
    if [ -z "$AVAILABLE_SPACE" ] || [ "$AVAILABLE_SPACE" = "" ]; then
        AVAILABLE_SPACE=100
    fi
    
    if [ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE" ]; then
        log_warn "Low disk space. Available: ${AVAILABLE_SPACE}GB, Recommended: ${REQUIRED_SPACE}GB"
        read -p "Continue? (y/N) " -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
    fi
    
    log_info "Prerequisites check passed ✓"
}

create_backup() {
    log_step "Creating configuration backup..."
    
    mkdir -p "$BACKUP_DIR"
    
    # Backup existing environment file
    [ -f ~/.metagenome_db_env ] && cp ~/.metagenome_db_env "$BACKUP_DIR/"
    
    # Backup project configs
    [ -f ~/metagenome-resistance-tracker/nextflow.config ] && \
        cp ~/metagenome-resistance-tracker/nextflow.config "$BACKUP_DIR/"
    
    # Create restore script
    cat > "$BACKUP_DIR/restore.sh" << EOF
#!/bin/bash
# Restore script for database setup

echo "Restoring previous configuration..."

# Remove shared structure
sudo rm -rf $SHARED_DB

# Restore configs
[ -f $BACKUP_DIR/.metagenome_db_env ] && cp $BACKUP_DIR/.metagenome_db_env ~/.metagenome_db_env
[ -f $BACKUP_DIR/nextflow.config ] && cp $BACKUP_DIR/nextflow.config ~/metagenome-resistance-tracker/nextflow.config

echo "Restoration completed"
EOF
    chmod +x "$BACKUP_DIR/restore.sh"
    
    log_info "Backup created at $BACKUP_DIR ✓"
}

create_shared_structure() {
    log_step "Creating shared database structure..."
    
    # Create main directory with proper permissions
    sudo mkdir -p "$SHARED_DB"
    sudo chown kyuwon:kyuwon "$SHARED_DB"
    sudo chmod 755 "$SHARED_DB"
    
    # Create subdirectories
    mkdir -p "$SHARED_DB"/{reference,metagenome,specialized,cache,logs,work}
    
    # Reference databases (existing data)
    mkdir -p "$SHARED_DB/reference"/{genomes,annotations,indices}
    
    # Metagenome-specific databases
    mkdir -p "$SHARED_DB/metagenome"/{busco,gtdbtk,kraken2,checkm,eggnog}
    
    # Specialized analysis databases
    mkdir -p "$SHARED_DB/specialized"/{amr,virulence,plasmid,phage}
    mkdir -p "$SHARED_DB/specialized/amr"/{card,resfinder,amrfinderplus,ncbi}
    mkdir -p "$SHARED_DB/specialized/virulence"/{vfdb,victors}
    mkdir -p "$SHARED_DB/specialized/plasmid"/{plsdb,plasmidfinder}
    
    # Working directories
    chmod 777 "$SHARED_DB"/{cache,work}  # Allow writes for all users
    
    log_info "Directory structure created ✓"
}

link_existing_databases() {
    log_step "Linking existing databases..."
    
    LINKED=0
    MISSING=0
    
    if [ -d "$CURRENT_DB" ]; then
        # Link reference databases
        for db_type in genomes annotations indices; do
            if [ -d "$CURRENT_DB/$db_type" ]; then
                ln -sfn "$CURRENT_DB/$db_type" "$SHARED_DB/reference/$db_type"
                log_info "✓ Linked $db_type"
                ((LINKED++))
            else
                log_warn "○ $db_type not found"
                ((MISSING++))
            fi
        done
        
        # Link existing tool-specific databases
        if [ -d "$CURRENT_DB/tool_specific_db/busco" ]; then
            ln -sfn "$CURRENT_DB/tool_specific_db/busco" "$SHARED_DB/metagenome/busco/v5"
            ln -sfn "$SHARED_DB/metagenome/busco/v5" "$SHARED_DB/metagenome/busco/latest"
            log_info "✓ Linked BUSCO database"
            ((LINKED++))
        else
            log_warn "○ BUSCO not found"
            ((MISSING++))
        fi
        
        log_info "Linked $LINKED databases, $MISSING missing"
    else
        log_warn "No existing database directory found - creating clean structure"
    fi
}

create_database_registry() {
    log_step "Creating database registry..."
    
    cat > "$SHARED_DB/registry.yaml" << EOF
# Production Metagenome Database Registry
# Created: $(date)
# Structure: shared_production

structure_version: "2.0"
deployment_type: "production_shared"
created: $(date -Iseconds)
owner: $(whoami)
admin_contact: $(whoami)@$(hostname)

databases:
  reference:
    genomes:
      path: "reference/genomes"
      source: "/db/genomes"
      type: "symlink"
      description: "Reference genome sequences"
      status: $([ -e "$SHARED_DB/reference/genomes" ] && echo "active" || echo "pending")
      
    annotations:
      path: "reference/annotations"
      source: "/db/annotations"
      type: "symlink"
      description: "Genome annotations and features"
      status: $([ -e "$SHARED_DB/reference/annotations" ] && echo "active" || echo "pending")
      
    indices:
      path: "reference/indices"
      source: "/db/indices"
      type: "symlink"
      description: "Pre-built sequence indices"
      status: $([ -e "$SHARED_DB/reference/indices" ] && echo "active" || echo "pending")
  
  metagenome:
    busco:
      path: "metagenome/busco/latest"
      version: "v5"
      type: "symlink"
      description: "BUSCO single-copy ortholog database"
      status: $([ -e "$SHARED_DB/metagenome/busco/latest" ] && echo "active" || echo "pending")
      download_command: "busco --download_path metagenome/busco"
      
    gtdbtk:
      path: "metagenome/gtdbtk/latest"
      version: "r220"
      type: "downloadable"
      description: "GTDB-Tk taxonomic database"
      status: "pending"
      size_estimate: "~70GB"
      download_command: "download_db.sh gtdb"
      
    kraken2:
      path: "metagenome/kraken2/latest"
      version: "standard_2024"
      type: "downloadable"
      description: "Kraken2 taxonomic classification database"
      status: "pending"
      size_estimate: "~100GB"
      download_command: "kraken2-build --standard --db metagenome/kraken2"
      
    checkm:
      path: "metagenome/checkm/latest"
      version: "v1.2.2"
      type: "downloadable"
      description: "CheckM genome quality assessment database"
      status: "pending"
      size_estimate: "~1.4GB"
      download_command: "checkm data setRoot metagenome/checkm"
  
  specialized:
    amr:
      card:
        path: "specialized/amr/card"
        version: "3.2.7"
        type: "downloadable"
        description: "CARD antibiotic resistance gene database"
        status: "pending"
        download_command: "rgi load --card_json specialized/amr/card/card.json"
        
      resfinder:
        path: "specialized/amr/resfinder"
        version: "4.4.2"
        type: "downloadable"
        description: "ResFinder resistance gene database"
        status: "pending"

system:
  storage:
    root: "$SHARED_DB"
    cache: "$SHARED_DB/cache"
    work: "$SHARED_DB/work"
    logs: "$SHARED_DB/logs"
    
  permissions:
    owner: $(whoami)
    group: $(id -gn)
    mode: "755"
    
  backup:
    location: "$BACKUP_DIR"
    restore_script: "$BACKUP_DIR/restore.sh"

usage_stats:
  creation_date: $(date)
  projects_using:
    - "metagenome-pipeline-benchmark"
    - "metagenome-resistance-tracker"
  
maintenance:
  last_update: $(date -Iseconds)
  next_check: $(date -d "+1 month" -Iseconds)
  update_frequency: "monthly"
EOF
    
    log_info "Database registry created ✓"
}

create_production_environment() {
    log_step "Creating production environment configuration..."
    
    cat > ~/.metagenome_db_env << 'EOF'
# Production Metagenome Database Environment
# Auto-generated configuration for shared production database

# =============================================================================
# PRODUCTION DATABASE CONFIGURATION
# =============================================================================

export METAGENOME_DB_ROOT="/data/shared/metagenome-db"
export DB_TYPE="shared_production"
export DB_MODE="production"

# =============================================================================
# REFERENCE DATABASES
# =============================================================================

export REFERENCE_DB_ROOT="$METAGENOME_DB_ROOT/reference"
export REFERENCE_GENOMES="$REFERENCE_DB_ROOT/genomes"
export REFERENCE_ANNOTATIONS="$REFERENCE_DB_ROOT/annotations"
export REFERENCE_INDICES="$REFERENCE_DB_ROOT/indices"

# =============================================================================
# METAGENOME DATABASES
# =============================================================================

# Core metagenome analysis tools
export BUSCO_DB="$METAGENOME_DB_ROOT/metagenome/busco/latest"
export GTDBTK_DB="$METAGENOME_DB_ROOT/metagenome/gtdbtk/latest"
export KRAKEN2_DB="$METAGENOME_DB_ROOT/metagenome/kraken2/latest"
export CHECKM_DB="$METAGENOME_DB_ROOT/metagenome/checkm/latest"
export EGGNOG_DB="$METAGENOME_DB_ROOT/metagenome/eggnog/latest"

# =============================================================================
# SPECIALIZED DATABASES
# =============================================================================

# Antibiotic resistance
export AMR_DB_ROOT="$METAGENOME_DB_ROOT/specialized/amr"
export CARD_DB="$AMR_DB_ROOT/card"
export RESFINDER_DB="$AMR_DB_ROOT/resfinder"
export AMRFINDERPLUS_DB="$AMR_DB_ROOT/amrfinderplus"

# Virulence factors
export VIRULENCE_DB_ROOT="$METAGENOME_DB_ROOT/specialized/virulence"
export VFDB="$VIRULENCE_DB_ROOT/vfdb"

# Plasmid databases
export PLASMID_DB_ROOT="$METAGENOME_DB_ROOT/specialized/plasmid"
export PLSDB="$PLASMID_DB_ROOT/plsdb"

# =============================================================================
# WORKING DIRECTORIES
# =============================================================================

export METAGENOME_CACHE="$METAGENOME_DB_ROOT/cache"
export METAGENOME_WORK="$METAGENOME_DB_ROOT/work"  
export METAGENOME_LOGS="$METAGENOME_DB_ROOT/logs"

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

check_production_db() {
    echo "================================================================="
    echo "    🧬 Production Metagenome Database Status"
    echo "================================================================="
    echo
    echo "Configuration:"
    echo "  Type: $DB_TYPE ($DB_MODE mode)"
    echo "  Root: $METAGENOME_DB_ROOT"
    echo "  Owner: $(stat -c %U $METAGENOME_DB_ROOT 2>/dev/null || echo 'unknown')"
    echo
    
    echo "📁 Reference Databases:"
    check_db_path "Genomes" "$REFERENCE_GENOMES"
    check_db_path "Annotations" "$REFERENCE_ANNOTATIONS"
    check_db_path "Indices" "$REFERENCE_INDICES"
    echo
    
    echo "🧬 Metagenome Databases:"
    check_db_path "BUSCO" "$BUSCO_DB"
    check_db_path "GTDB-Tk" "$GTDBTK_DB"
    check_db_path "Kraken2" "$KRAKEN2_DB"
    check_db_path "CheckM" "$CHECKM_DB"
    echo
    
    echo "🦠 Specialized Databases:"
    check_db_path "CARD" "$CARD_DB"
    check_db_path "ResFinder" "$RESFINDER_DB"
    check_db_path "VFDB" "$VFDB"
    echo
    
    echo "💾 Storage Usage:"
    if [ -d "$METAGENOME_DB_ROOT" ]; then
        du -sh "$METAGENOME_DB_ROOT"/* 2>/dev/null | sort -hr | head -8
        echo "  Total: $(du -sh "$METAGENOME_DB_ROOT" 2>/dev/null | cut -f1)"
    fi
    echo
    
    echo "🔧 Working Directories:"
    check_db_path "Cache" "$METAGENOME_CACHE" "$(du -sh "$METAGENOME_CACHE" 2>/dev/null | cut -f1)"
    check_db_path "Work" "$METAGENOME_WORK" "$(du -sh "$METAGENOME_WORK" 2>/dev/null | cut -f1)"
    check_db_path "Logs" "$METAGENOME_LOGS" "$(find "$METAGENOME_LOGS" -name "*.log" 2>/dev/null | wc -l) logs"
    
    echo "================================================================="
}

check_db_path() {
    local name="$1"
    local path="$2"
    local extra="$3"
    
    if [ -e "$path" ]; then
        if [ -L "$path" ]; then
            echo "  ✓ $name: $path → $(readlink "$path")"
        else
            echo "  ✓ $name: $path"
        fi
        [ -n "$extra" ] && echo "    ↳ $extra"
    else
        echo "  ○ $name: Not configured"
    fi
}

download_missing_db() {
    local db_name="$1"
    echo "📥 Download instructions for $db_name:"
    
    case "$db_name" in
        "gtdbtk"|"gtdb")
            echo "  wget https://data.gtdb.ecogenomic.org/releases/latest/auxillary_files/gtdbtk_data.tar.gz"
            echo "  tar -xzf gtdbtk_data.tar.gz -C $GTDBTK_DB/../"
            ;;
        "kraken2")
            echo "  kraken2-build --standard --threads 16 --db $KRAKEN2_DB/../standard"
            echo "  (Warning: Downloads ~100GB, takes several hours)"
            ;;
        "checkm")
            echo "  checkm data setRoot $CHECKM_DB"
            ;;
        "card")
            echo "  wget https://card.mcmaster.ca/latest/data"
            echo "  rgi load --card_json card.json --local"
            ;;
        *)
            echo "  Available databases: gtdbtk, kraken2, checkm, card"
            echo "  Usage: download-db <database_name>"
            ;;
    esac
}

# Create convenient aliases and functions
setup_production_aliases() {
    alias db-status='check_production_db'
    alias db-download='download_missing_db'
    alias db-root='echo $METAGENOME_DB_ROOT'
    alias goto-db='cd $METAGENOME_DB_ROOT'
    alias db-cache='cd $METAGENOME_CACHE'
    alias db-work='cd $METAGENOME_WORK'
    alias db-logs='cd $METAGENOME_LOGS'
    
    # Export functions for use in subshells
    export -f check_production_db
    export -f check_db_path
    export -f download_missing_db
}

# Team expansion functions
add_team_member() {
    local username="$1"
    if [ -z "$username" ]; then
        echo "Usage: add_team_member <username>"
        return 1
    fi
    
    echo "Adding team member: $username"
    
    # Add to metagenome group (create if doesn't exist)
    sudo groupadd -f metagenome
    sudo usermod -a -G metagenome "$username"
    
    # Set group ownership
    sudo chgrp -R metagenome "$METAGENOME_DB_ROOT"
    sudo chmod -R g+w "$METAGENOME_DB_ROOT"/{cache,work,logs}
    
    # Copy environment file to new user
    sudo cp ~/.metagenome_db_env "/home/$username/"
    sudo chown "$username:$username" "/home/$username/.metagenome_db_env"
    
    echo "✓ $username added to metagenome team"
}

# Initialize production environment
setup_production_aliases

# Show status on first load
if [ -z "$METAGENOME_PRODUCTION_LOADED" ]; then
    export METAGENOME_PRODUCTION_LOADED=1
    echo "🚀 Production metagenome database environment loaded"
    echo "💡 Run 'db-status' to see current configuration"
    echo "📥 Run 'db-download <name>' for database download instructions"
fi
EOF
    
    log_info "Production environment created ✓"
}

update_project_configs() {
    log_step "Updating project configurations..."
    
    # Update resistance-tracker nextflow.config
    RESISTANCE_CONFIG="$HOME/metagenome-resistance-tracker/nextflow.config"
    if [ -f "$RESISTANCE_CONFIG" ]; then
        # Backup original
        cp "$RESISTANCE_CONFIG" "${RESISTANCE_CONFIG}.backup.$(date +%Y%m%d)"
        
        # Create updated config
        cat > "$RESISTANCE_CONFIG" << 'EOF'
// nextflow.config - Production Database Configuration
// Auto-updated for shared database structure

params {
    // Input/Output
    input = 'sample_sheet_public.csv'
    outdir = './results_public'
    
    // Production Database Paths (environment-based with fallbacks)
    busco_reference_path = System.getenv('BUSCO_DB') ?: '/data/shared/metagenome-db/metagenome/busco/latest'
    gtdb_path = System.getenv('GTDBTK_DB') ?: '/data/shared/metagenome-db/metagenome/gtdbtk/latest'
    kraken2_db = System.getenv('KRAKEN2_DB') ?: '/data/shared/metagenome-db/metagenome/kraken2/latest'
    checkm_path = System.getenv('CHECKM_DB') ?: '/data/shared/metagenome-db/metagenome/checkm/latest'
    
    // AMR-specific databases
    card_db = System.getenv('CARD_DB') ?: '/data/shared/metagenome-db/specialized/amr/card'
    resfinder_db = System.getenv('RESFINDER_DB') ?: '/data/shared/metagenome-db/specialized/amr/resfinder'
}

profiles {
    standard {
        executor.name = 'local'
        executor.cpus = 16
        executor.memory = '64 GB'
    }
    
    singularity {
        singularity.enabled = true
        singularity.autoMounts = true
        singularity.cacheDir = System.getenv('METAGENOME_CACHE') ?: "${launchDir}/.singularity"
        
        // Use production cache directory
        workDir = System.getenv('METAGENOME_WORK') ?: "${launchDir}/work"
    }
    
    production {
        includeConfig 'singularity'
        
        // Production-optimized settings
        process.cache = 'lenient'
        process.errorStrategy = 'retry'
        process.maxRetries = 2
        
        // Use shared work directory
        workDir = System.getenv('METAGENOME_WORK') ?: '/data/shared/metagenome-db/work'
    }
}

process {
    // Default resources
    cpus = 2
    memory = '8 GB'
    time = '4 h'
    
    // High-memory processes
    withName: '.*SPADES' {
        cpus = 16
        memory = '150 GB'
        time = '24 h'
    }
    
    withName: '.*MEGAHIT' {
        cpus = 8
        memory = '32 GB'
        time = '12 h'
    }
    
    // BUSCO configuration
    withName: 'NFCORE_MAG:MAG:BUSCO_QC:BUSCO' {
        stageInMode = 'copy'
        memory = '16 GB'
    }
    
    // Database-dependent processes
    withName: '.*GTDBTK.*' {
        memory = '32 GB'
        time = '12 h'
    }
    
    withName: '.*KRAKEN2.*' {
        memory = '64 GB'
        cpus = 8
    }
}

// Reporting configuration
report {
    enabled = true
    file = "${params.outdir}/pipeline_info/execution_report.html"
}

timeline {
    enabled = true
    file = "${params.outdir}/pipeline_info/execution_timeline.html"
}

trace {
    enabled = true
    file = "${params.outdir}/pipeline_info/execution_trace.txt"
}
EOF
        
        log_info "✓ Updated resistance-tracker configuration"
    else
        log_warn "resistance-tracker config not found - skipping"
    fi
    
    # Create benchmark configuration for resistance-tracker
    BENCHMARK_DIR="$HOME/metagenome-resistance-tracker/.benchmark"
    mkdir -p "$BENCHMARK_DIR"
    
    cat > "$BENCHMARK_DIR/config.yaml" << 'EOF'
# Resistance Tracker Benchmark Configuration
# Auto-generated for production database

benchmark:
  project:
    name: "resistance-tracker"
    type: "amr-detection"
    description: "TARA ocean samples antibiotic resistance analysis"
    focus: "antibiotic-resistance"
    
  central_hub:
    url: "http://localhost:8501"
    api_url: "http://localhost:8000"
    auto_upload: false
    
  databases:
    use_production: true
    root: "/data/shared/metagenome-db"
    
  pipelines:
    - name: "nfcore_mag"
      version: "3.1.0"
      config: "../nextflow.config"
      profile: "production"
      focus: ["assembly", "binning", "taxonomy"]
      
    - name: "nfcore_funcscan"
      version: "1.1.0"
      focus: ["amr_genes", "functional_annotation"]
      databases: ["card", "resfinder", "amrfinderplus"]
      
  evaluation:
    primary_metrics:
      - amr_sensitivity
      - amr_specificity
      - assembly_quality
      - taxonomic_accuracy
    secondary_metrics:
      - runtime
      - memory_usage
      - storage_footprint
    thresholds:
      min_sensitivity: 0.85
      max_runtime: "24h"
      max_memory: "150GB"
      
  output:
    results_dir: ".benchmark/results"
    cache_dir: "/data/shared/metagenome-db/cache/resistance-tracker"
    reports_dir: ".benchmark/reports"
EOF
    
    log_info "✓ Created benchmark configuration"
}

update_bashrc() {
    log_step "Updating shell configuration..."
    
    # Remove old metagenome_db_env references
    if grep -q "metagenome_db_env" ~/.bashrc 2>/dev/null; then
        # Create backup
        cp ~/.bashrc ~/.bashrc.backup.$(date +%Y%m%d)
        # Remove old lines and add new
        grep -v "metagenome_db_env" ~/.bashrc > ~/.bashrc.tmp
        mv ~/.bashrc.tmp ~/.bashrc
    fi
    
    # Add production environment
    cat >> ~/.bashrc << 'EOF'

# =============================================================================
# Production Metagenome Database Environment
# =============================================================================
if [ -f ~/.metagenome_db_env ]; then
    source ~/.metagenome_db_env
fi
EOF
    
    log_info "Updated ~/.bashrc ✓"
}

verify_production_setup() {
    log_step "Verifying production setup..."
    
    local errors=0
    
    # Check main directory
    if [ ! -d "$SHARED_DB" ]; then
        log_error "Shared database directory not created"
        ((errors++))
    fi
    
    # Check permissions
    if [ "$(stat -c %U "$SHARED_DB" 2>/dev/null)" != "kyuwon" ]; then
        log_error "Incorrect ownership on shared database"
        ((errors++))
    fi
    
    # Check environment file
    if [ ! -f ~/.metagenome_db_env ]; then
        log_error "Environment configuration not created"
        ((errors++))
    fi
    
    # Check if environment loads
    if ! source ~/.metagenome_db_env 2>/dev/null; then
        log_error "Environment file has syntax errors"
        ((errors++))
    fi
    
    # Test database check function
    if source ~/.metagenome_db_env && ! check_production_db &>/dev/null; then
        log_warn "Database check function may have issues"
    fi
    
    if [ $errors -eq 0 ]; then
        log_info "Production setup verification passed ✓"
        return 0
    else
        log_error "Verification failed with $errors errors"
        return 1
    fi
}

print_completion_summary() {
    echo
    echo "================================================================="
    echo "    ✅ Production Database Setup Complete!"
    echo "================================================================="
    echo
    echo "📁 Database Location: $SHARED_DB"
    echo "📋 Registry: $SHARED_DB/registry.yaml"
    echo "⚙️  Environment: ~/.metagenome_db_env"
    echo "💾 Backup: $BACKUP_DIR"
    echo
    echo "🚀 Next Steps:"
    echo "1. Load environment: source ~/.bashrc"
    echo "2. Check status: db-status"
    echo "3. Download databases: db-download <name>"
    echo "4. Test pipeline: cd ~/metagenome-resistance-tracker && ./scripts/run_nf_mag_public.sh"
    echo
    echo "👥 Team Expansion:"
    echo "• Add members: add_team_member <username>"
    echo "• Share environment: cp ~/.metagenome_db_env /home/<user>/"
    echo
    echo "🔧 Maintenance:"
    echo "• Monitor storage: du -sh $SHARED_DB/*"
    echo "• Clean cache: rm -rf $SHARED_DB/cache/*"
    echo "• View logs: ls $SHARED_DB/logs/"
    echo
    echo "📊 Benchmarking:"
    echo "• Dashboard: streamlit run ~/metagenome-pipeline-benchmark/dashboard/app.py"
    echo "• Run benchmark: cd ~/metagenome-resistance-tracker && benchmark run"
    echo
    log_info "Production database ready for immediate use! 🎉"
}

create_maintenance_scripts() {
    log_step "Creating maintenance scripts..."
    
    SCRIPTS_DIR="$SHARED_DB/../scripts"
    mkdir -p "$SCRIPTS_DIR"
    
    # Cleanup script
    cat > "$SCRIPTS_DIR/cleanup_cache.sh" << 'EOF'
#!/bin/bash
# Database cache cleanup script

CACHE_DIR="/data/shared/metagenome-db/cache"
WORK_DIR="/data/shared/metagenome-db/work"

echo "Cleaning metagenome database cache..."

# Clean cache older than 7 days
find "$CACHE_DIR" -type f -mtime +7 -delete 2>/dev/null
find "$WORK_DIR" -type d -mtime +7 -exec rm -rf {} + 2>/dev/null

echo "Cache cleanup completed"
du -sh "$CACHE_DIR" "$WORK_DIR"
EOF
    
    chmod +x "$SCRIPTS_DIR/cleanup_cache.sh"
    
    # Health check script
    cat > "$SCRIPTS_DIR/health_check.sh" << 'EOF'
#!/bin/bash
# Database health check script

source ~/.metagenome_db_env
check_production_db

echo -e "\n🔍 Additional Health Checks:"

# Check disk space
USAGE=$(df $METAGENOME_DB_ROOT | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$USAGE" -gt 80 ]; then
    echo "⚠️  Disk usage high: $USAGE%"
else
    echo "✓ Disk usage OK: $USAGE%"
fi

# Check permissions
if [ -w "$METAGENOME_DB_ROOT" ]; then
    echo "✓ Write permissions OK"
else
    echo "⚠️  Write permissions issue"
fi

# Check recent activity
RECENT_FILES=$(find "$METAGENOME_DB_ROOT" -type f -mtime -1 | wc -l)
echo "📈 Recent activity: $RECENT_FILES files modified in last 24h"
EOF
    
    chmod +x "$SCRIPTS_DIR/health_check.sh"
    
    log_info "Maintenance scripts created in $SCRIPTS_DIR ✓"
}

# Main execution
main() {
    print_header
    
    # Get user confirmation
    echo "This will create a production shared database structure."
    echo "Continue? (y/N)"
    read -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && { echo "Setup cancelled"; exit 0; }
    
    check_prerequisites
    create_backup
    create_shared_structure
    link_existing_databases
    create_database_registry
    create_production_environment
    update_project_configs
    update_bashrc
    create_maintenance_scripts
    
    if verify_production_setup; then
        print_completion_summary
    else
        log_error "Setup completed with errors. Check logs above."
        echo "To restore previous state: $BACKUP_DIR/restore.sh"
        exit 1
    fi
}

# Run main function
main "$@"