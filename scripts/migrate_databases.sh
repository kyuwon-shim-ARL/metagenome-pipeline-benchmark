#!/bin/bash
# Database Migration Script for Metagenome Projects
# This script migrates databases from resistance-tracker to shared location

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SHARED_DB_ROOT="/data/shared/metagenome-db"
RESISTANCE_TRACKER_DIR="$HOME/metagenome-resistance-tracker"
BACKUP_DIR="$HOME/db_migration_backup_$(date +%Y%m%d_%H%M%S)"

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if resistance-tracker exists
    if [ ! -d "$RESISTANCE_TRACKER_DIR" ]; then
        log_error "resistance-tracker directory not found at $RESISTANCE_TRACKER_DIR"
        exit 1
    fi
    
    # Check disk space
    REQUIRED_SPACE=200  # GB
    AVAILABLE_SPACE=$(df /data 2>/dev/null | awk 'NR==2 {print int($4/1048576)}' || echo 0)
    
    if [ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE" ]; then
        log_warn "Low disk space. Available: ${AVAILABLE_SPACE}GB, Recommended: ${REQUIRED_SPACE}GB"
        read -p "Continue anyway? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    log_info "Prerequisites check passed ✓"
}

create_shared_structure() {
    log_info "Creating shared database structure..."
    
    # Create main directory
    if [ ! -d "$SHARED_DB_ROOT" ]; then
        sudo mkdir -p "$SHARED_DB_ROOT"
        sudo chown -R $(whoami):$(id -gn) "$SHARED_DB_ROOT"
        log_info "Created $SHARED_DB_ROOT"
    else
        log_warn "Shared DB directory already exists"
    fi
    
    # Create registry file
    cat > "$SHARED_DB_ROOT/registry.yaml" << EOF
# Database Registry - Auto-generated $(date)
databases:
  busco:
    version: v5
    path: busco/v5
    size: ~10GB
    last_updated: $(date +%Y-%m-%d)
    
  gtdbtk:
    version: r220
    path: gtdbtk/r220_database
    size: ~70GB
    last_updated: $(date +%Y-%m-%d)
    
  kraken2:
    version: standard_20240601
    path: kraken2/standard
    size: ~100GB
    last_updated: $(date +%Y-%m-%d)
    
  checkm:
    version: v1.2.2
    path: checkm/v1.2.2
    size: ~1.4GB
    last_updated: $(date +%Y-%m-%d)

migration:
  from: resistance-tracker
  date: $(date)
  by: $(whoami)
EOF
    
    log_info "Database structure created ✓"
}

backup_current_state() {
    log_info "Creating backup of current configuration..."
    
    mkdir -p "$BACKUP_DIR"
    
    # Backup config files
    if [ -f "$RESISTANCE_TRACKER_DIR/nextflow.config" ]; then
        cp "$RESISTANCE_TRACKER_DIR/nextflow.config" "$BACKUP_DIR/"
    fi
    
    # Save current DB paths
    cat > "$BACKUP_DIR/original_paths.txt" << EOF
Original DB Locations:
- BUSCO: $RESISTANCE_TRACKER_DIR/shared/databases/busco/
- GTDB-Tk: $RESISTANCE_TRACKER_DIR/shared/databases/gtdbtk/
- Kraken2: $RESISTANCE_TRACKER_DIR/shared/databases/kraken2/
- CheckM: $RESISTANCE_TRACKER_DIR/shared/databases/checkm/

Backup created: $(date)
EOF
    
    log_info "Backup created at $BACKUP_DIR ✓"
}

migrate_databases() {
    log_info "Starting database migration..."
    
    # BUSCO
    if [ -d "$RESISTANCE_TRACKER_DIR/shared/databases/busco" ]; then
        log_info "Migrating BUSCO database..."
        mkdir -p "$SHARED_DB_ROOT/busco"
        mv "$RESISTANCE_TRACKER_DIR/shared/databases/busco/"* "$SHARED_DB_ROOT/busco/" 2>/dev/null || true
        ln -sfn "$SHARED_DB_ROOT/busco" "$RESISTANCE_TRACKER_DIR/shared/databases/busco"
        log_info "BUSCO migrated ✓"
    fi
    
    # GTDB-Tk
    if [ -d "$RESISTANCE_TRACKER_DIR/shared/databases/gtdbtk" ]; then
        log_info "Migrating GTDB-Tk database (this may take a while)..."
        mkdir -p "$SHARED_DB_ROOT/gtdbtk"
        mv "$RESISTANCE_TRACKER_DIR/shared/databases/gtdbtk/"* "$SHARED_DB_ROOT/gtdbtk/" 2>/dev/null || true
        ln -sfn "$SHARED_DB_ROOT/gtdbtk" "$RESISTANCE_TRACKER_DIR/shared/databases/gtdbtk"
        log_info "GTDB-Tk migrated ✓"
    fi
    
    # Kraken2
    if [ -d "$RESISTANCE_TRACKER_DIR/shared/databases/kraken2" ]; then
        log_info "Migrating Kraken2 database (this may take a while)..."
        mkdir -p "$SHARED_DB_ROOT/kraken2"
        mv "$RESISTANCE_TRACKER_DIR/shared/databases/kraken2/"* "$SHARED_DB_ROOT/kraken2/" 2>/dev/null || true
        ln -sfn "$SHARED_DB_ROOT/kraken2" "$RESISTANCE_TRACKER_DIR/shared/databases/kraken2"
        log_info "Kraken2 migrated ✓"
    fi
    
    # CheckM
    if [ -d "$RESISTANCE_TRACKER_DIR/shared/databases/checkm" ]; then
        log_info "Migrating CheckM database..."
        mkdir -p "$SHARED_DB_ROOT/checkm"
        mv "$RESISTANCE_TRACKER_DIR/shared/databases/checkm/"* "$SHARED_DB_ROOT/checkm/" 2>/dev/null || true
        ln -sfn "$SHARED_DB_ROOT/checkm" "$RESISTANCE_TRACKER_DIR/shared/databases/checkm"
        log_info "CheckM migrated ✓"
    fi
    
    # Create 'latest' symlinks
    ln -sfn "$SHARED_DB_ROOT/busco/v5" "$SHARED_DB_ROOT/busco/latest" 2>/dev/null || true
    ln -sfn "$SHARED_DB_ROOT/gtdbtk/r220_database" "$SHARED_DB_ROOT/gtdbtk/latest" 2>/dev/null || true
    ln -sfn "$SHARED_DB_ROOT/kraken2/standard" "$SHARED_DB_ROOT/kraken2/latest" 2>/dev/null || true
    ln -sfn "$SHARED_DB_ROOT/checkm/v1.2.2" "$SHARED_DB_ROOT/checkm/latest" 2>/dev/null || true
    
    log_info "Database migration completed ✓"
}

setup_environment_variables() {
    log_info "Setting up environment variables..."
    
    ENV_FILE="$HOME/.metagenome_db_env"
    
    cat > "$ENV_FILE" << 'EOF'
# Metagenome Database Environment Variables
export METAGENOME_DB_ROOT="/data/shared/metagenome-db"
export BUSCO_DB="${METAGENOME_DB_ROOT}/busco/latest"
export GTDBTK_DB="${METAGENOME_DB_ROOT}/gtdbtk/latest"
export KRAKEN2_DB="${METAGENOME_DB_ROOT}/kraken2/latest"
export CHECKM_DB="${METAGENOME_DB_ROOT}/checkm/latest"

# Helper function to check DB status
check_metagenome_db() {
    echo "Metagenome DB Status:"
    echo "  Root: $METAGENOME_DB_ROOT"
    [ -d "$BUSCO_DB" ] && echo "  ✓ BUSCO: $BUSCO_DB" || echo "  ✗ BUSCO: Not found"
    [ -d "$GTDBTK_DB" ] && echo "  ✓ GTDB-Tk: $GTDBTK_DB" || echo "  ✗ GTDB-Tk: Not found"
    [ -d "$KRAKEN2_DB" ] && echo "  ✓ Kraken2: $KRAKEN2_DB" || echo "  ✗ Kraken2: Not found"
    [ -d "$CHECKM_DB" ] && echo "  ✓ CheckM: $CHECKM_DB" || echo "  ✗ CheckM: Not found"
}
EOF
    
    # Add to bashrc if not already present
    if ! grep -q "metagenome_db_env" "$HOME/.bashrc"; then
        echo "" >> "$HOME/.bashrc"
        echo "# Metagenome Database Environment" >> "$HOME/.bashrc"
        echo "[ -f $ENV_FILE ] && source $ENV_FILE" >> "$HOME/.bashrc"
        log_info "Added environment variables to .bashrc"
    else
        log_warn "Environment variables already in .bashrc"
    fi
    
    # Source immediately
    source "$ENV_FILE"
    
    log_info "Environment variables configured ✓"
}

update_nextflow_config() {
    log_info "Updating Nextflow configuration..."
    
    CONFIG_FILE="$RESISTANCE_TRACKER_DIR/nextflow.config"
    
    if [ -f "$CONFIG_FILE" ]; then
        # Create updated config
        cat > "${CONFIG_FILE}.new" << 'EOF'
// nextflow.config - Updated for shared database structure

params {
    // Input/Output
    input = 'sample_sheet_public.csv'
    outdir = './results_public'
    
    // Database paths - using environment variables with fallbacks
    busco_reference_path = System.getenv('BUSCO_DB') ?: '/data/shared/metagenome-db/busco/latest'
    gtdb_path = System.getenv('GTDBTK_DB') ?: '/data/shared/metagenome-db/gtdbtk/latest'
    kraken2_db = System.getenv('KRAKEN2_DB') ?: '/data/shared/metagenome-db/kraken2/latest'
    checkm_path = System.getenv('CHECKM_DB') ?: '/data/shared/metagenome-db/checkm/latest'
}

profiles {
    standard {
        // Default profile
    }
    singularity {
        singularity.enabled = true
        singularity.autoMounts = true
        singularity.cacheDir = '/home/kyuwon/.singularity/cache'
    }
}

process {
    withName: '.*SPADES' {
        memory = '150.GB'
        cpus = 16
    }
    withName: 'NFCORE_MAG:MAG:BUSCO_QC:BUSCO' {
        stageInMode = 'copy'
    }
}
EOF
        
        # Backup original and replace
        mv "$CONFIG_FILE" "${CONFIG_FILE}.backup"
        mv "${CONFIG_FILE}.new" "$CONFIG_FILE"
        
        log_info "Nextflow config updated ✓"
        log_info "Original config backed up to ${CONFIG_FILE}.backup"
    else
        log_warn "Nextflow config not found"
    fi
}

verify_migration() {
    log_info "Verifying migration..."
    
    ERRORS=0
    
    # Check shared DB exists
    if [ ! -d "$SHARED_DB_ROOT" ]; then
        log_error "Shared DB root not found"
        ((ERRORS++))
    fi
    
    # Check each database
    for db in busco gtdbtk kraken2 checkm; do
        if [ ! -d "$SHARED_DB_ROOT/$db" ]; then
            log_warn "Database $db not found in shared location"
        fi
    done
    
    # Check symlinks
    if [ -L "$RESISTANCE_TRACKER_DIR/shared/databases/busco" ]; then
        log_info "Symlinks verified ✓"
    else
        log_warn "Symlinks may not be properly configured"
    fi
    
    # Check environment variables
    if [ -n "$METAGENOME_DB_ROOT" ]; then
        log_info "Environment variables set ✓"
    else
        log_warn "Environment variables not loaded in current session"
        log_info "Run: source ~/.metagenome_db_env"
    fi
    
    if [ $ERRORS -eq 0 ]; then
        log_info "Migration verification passed ✓"
    else
        log_error "Migration verification failed with $ERRORS errors"
        return 1
    fi
}

print_summary() {
    echo
    echo "========================================="
    echo "     Database Migration Complete!        "
    echo "========================================="
    echo
    echo "📁 Shared DB Location: $SHARED_DB_ROOT"
    echo "📋 Registry: $SHARED_DB_ROOT/registry.yaml"
    echo "💾 Backup: $BACKUP_DIR"
    echo
    echo "Next steps:"
    echo "1. Source environment: source ~/.metagenome_db_env"
    echo "2. Check DB status: check_metagenome_db"
    echo "3. Test pipeline: cd $RESISTANCE_TRACKER_DIR && ./run_nf_mag_public.sh"
    echo
    echo "To rollback:"
    echo "  bash $BACKUP_DIR/rollback.sh"
    echo
}

create_rollback_script() {
    cat > "$BACKUP_DIR/rollback.sh" << EOF
#!/bin/bash
# Rollback script for database migration

echo "Rolling back database migration..."

# Remove symlinks
rm -f $RESISTANCE_TRACKER_DIR/shared/databases/busco
rm -f $RESISTANCE_TRACKER_DIR/shared/databases/gtdbtk
rm -f $RESISTANCE_TRACKER_DIR/shared/databases/kraken2
rm -f $RESISTANCE_TRACKER_DIR/shared/databases/checkm

# Move databases back
mv $SHARED_DB_ROOT/busco/* $RESISTANCE_TRACKER_DIR/shared/databases/busco/ 2>/dev/null || true
mv $SHARED_DB_ROOT/gtdbtk/* $RESISTANCE_TRACKER_DIR/shared/databases/gtdbtk/ 2>/dev/null || true
mv $SHARED_DB_ROOT/kraken2/* $RESISTANCE_TRACKER_DIR/shared/databases/kraken2/ 2>/dev/null || true
mv $SHARED_DB_ROOT/checkm/* $RESISTANCE_TRACKER_DIR/shared/databases/checkm/ 2>/dev/null || true

# Restore config
cp $BACKUP_DIR/nextflow.config $RESISTANCE_TRACKER_DIR/nextflow.config

echo "Rollback completed"
EOF
    chmod +x "$BACKUP_DIR/rollback.sh"
}

# Main execution
main() {
    echo "========================================="
    echo "   Metagenome Database Migration Tool    "
    echo "========================================="
    echo
    
    check_prerequisites
    create_shared_structure
    backup_current_state
    create_rollback_script
    migrate_databases
    setup_environment_variables
    update_nextflow_config
    verify_migration
    print_summary
}

# Run main function
main "$@"