#!/bin/bash
# User Database Setup Script
# Sets up personal metagenome database structure when admin access is not available

set -e

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
USER_DB="$HOME/.metagenome_db"
CURRENT_DB="/db"  # Current shared DB location

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

print_header() {
    echo
    echo "========================================="
    echo "   Personal Metagenome DB Setup        "
    echo "========================================="
    echo
    echo "This script creates a personal database structure"
    echo "that integrates with existing shared databases."
    echo
}

create_directory_structure() {
    log_info "Creating personal DB directory structure..."
    
    # Create main directories
    mkdir -p "$USER_DB"/{reference,metagenome,specialized}
    
    # Reference databases (existing data)
    mkdir -p "$USER_DB/reference"/{genomes,annotations,indices}
    
    # Metagenome-specific databases
    mkdir -p "$USER_DB/metagenome"/{busco,gtdbtk,kraken2,checkm,eggnog}
    
    # Specialized analysis databases
    mkdir -p "$USER_DB/specialized"/{amr,virulence,plasmid,phage}
    mkdir -p "$USER_DB/specialized/amr"/{card,resfinder,amrfinderplus}
    
    # Create cache and work directories
    mkdir -p "$USER_DB"/{cache,work,logs}
    
    log_info "Directory structure created ✓"
}

link_existing_databases() {
    log_info "Linking existing shared databases..."
    
    LINKED=0
    MISSING=0
    
    # Link reference genomes
    if [ -d "$CURRENT_DB/genomes" ]; then
        ln -sfn "$CURRENT_DB/genomes" "$USER_DB/reference/genomes"
        log_info "✓ Linked reference genomes"
        ((LINKED++))
    else
        log_warn "○ Reference genomes not found at $CURRENT_DB/genomes"
        ((MISSING++))
    fi
    
    # Link annotations
    if [ -d "$CURRENT_DB/annotations" ]; then
        ln -sfn "$CURRENT_DB/annotations" "$USER_DB/reference/annotations"
        log_info "✓ Linked annotations"
        ((LINKED++))
    else
        log_warn "○ Annotations not found at $CURRENT_DB/annotations"
        ((MISSING++))
    fi
    
    # Link indices
    if [ -d "$CURRENT_DB/indices" ]; then
        ln -sfn "$CURRENT_DB/indices" "$USER_DB/reference/indices"
        log_info "✓ Linked indices"
        ((LINKED++))
    else
        log_warn "○ Indices not found at $CURRENT_DB/indices"
        ((MISSING++))
    fi
    
    # Link BUSCO (if exists in tool_specific_db)
    if [ -d "$CURRENT_DB/tool_specific_db/busco" ]; then
        ln -sfn "$CURRENT_DB/tool_specific_db/busco" "$USER_DB/metagenome/busco/existing"
        # Create 'latest' symlink
        ln -sfn "$USER_DB/metagenome/busco/existing" "$USER_DB/metagenome/busco/latest"
        log_info "✓ Linked BUSCO database"
        ((LINKED++))
    else
        log_warn "○ BUSCO not found at $CURRENT_DB/tool_specific_db/busco"
        ((MISSING++))
    fi
    
    log_info "Database linking completed: $LINKED linked, $MISSING missing"
}

create_database_registry() {
    log_info "Creating database registry..."
    
    cat > "$USER_DB/registry.yaml" << EOF
# Personal Metagenome Database Registry
# Generated: $(date)
# Location: $USER_DB

structure_version: "1.0"
owner: $(whoami)
created: $(date -Iseconds)

databases:
  reference:
    genomes:
      path: "reference/genomes"
      source: "/db/genomes"
      type: "symlink"
      description: "Reference genome sequences"
      
    annotations:
      path: "reference/annotations" 
      source: "/db/annotations"
      type: "symlink"
      description: "Genome annotations"
      
    indices:
      path: "reference/indices"
      source: "/db/indices" 
      type: "symlink"
      description: "Pre-built sequence indices"
  
  metagenome:
    busco:
      path: "metagenome/busco/latest"
      version: "v5"
      type: "symlink"
      description: "BUSCO single-copy ortholog database"
      
    gtdbtk:
      path: "metagenome/gtdbtk/latest"
      version: "r220"
      type: "placeholder"
      description: "GTDB-Tk taxonomic database"
      
    kraken2:
      path: "metagenome/kraken2/latest"
      version: "standard_2024"
      type: "placeholder" 
      description: "Kraken2 taxonomic classification database"
      
    checkm:
      path: "metagenome/checkm/latest"
      version: "v1.2.2"
      type: "placeholder"
      description: "CheckM genome quality assessment"
  
  specialized:
    amr:
      card:
        path: "specialized/amr/card"
        version: "3.2.7"
        type: "placeholder"
        description: "CARD antibiotic resistance database"
        
      resfinder:
        path: "specialized/amr/resfinder"  
        version: "4.4.2"
        type: "placeholder"
        description: "ResFinder resistance gene database"

configuration:
  auto_update: false
  cache_enabled: true
  cache_size_limit: "50GB"
  log_level: "INFO"

# Placeholder directories for databases to be downloaded
placeholders:
  - "metagenome/gtdbtk"
  - "metagenome/kraken2" 
  - "metagenome/checkm"
  - "specialized/amr/card"
  - "specialized/amr/resfinder"
EOF

    log_info "Database registry created ✓"
}

create_environment_file() {
    log_info "Creating environment configuration..."
    
    cat > "$HOME/.metagenome_db_env" << EOF
# Metagenome Database Environment Configuration
# Generated: $(date)

# =============================================================================
# DATABASE ROOT PATHS
# =============================================================================

# Personal DB root (fallback when no shared access)
export PERSONAL_DB_ROOT="$USER_DB"

# Auto-detect best available DB root
if [ -d "/data/shared" ]; then
    export DB_ROOT="/data/shared"
    export DB_TYPE="shared"
elif [ -d "/db" ] && [ -w "/db" ]; then
    export DB_ROOT="/db" 
    export DB_TYPE="legacy_writable"
elif [ -d "/db" ]; then
    export DB_ROOT="\$PERSONAL_DB_ROOT"
    export DB_TYPE="personal"
    export DB_REFERENCE="/db"  # Read-only reference
else
    export DB_ROOT="\$PERSONAL_DB_ROOT"
    export DB_TYPE="standalone"
fi

# =============================================================================
# REFERENCE DATABASES (existing shared data)
# =============================================================================

export REFERENCE_DB_ROOT="\$DB_ROOT/reference"
export REFERENCE_GENOMES="\$REFERENCE_DB_ROOT/genomes"
export REFERENCE_ANNOTATIONS="\$REFERENCE_DB_ROOT/annotations" 
export REFERENCE_INDICES="\$REFERENCE_DB_ROOT/indices"

# =============================================================================
# METAGENOME DATABASES
# =============================================================================

export METAGENOME_DB_ROOT="\$DB_ROOT/metagenome"

# Core metagenome tools
export BUSCO_DB="\$METAGENOME_DB_ROOT/busco/latest"
export GTDBTK_DB="\$METAGENOME_DB_ROOT/gtdbtk/latest"
export KRAKEN2_DB="\$METAGENOME_DB_ROOT/kraken2/latest"
export CHECKM_DB="\$METAGENOME_DB_ROOT/checkm/latest"
export EGGNOG_DB="\$METAGENOME_DB_ROOT/eggnog/latest"

# =============================================================================
# SPECIALIZED DATABASES  
# =============================================================================

export SPECIALIZED_DB_ROOT="\$DB_ROOT/specialized"

# Antibiotic resistance
export AMR_DB_ROOT="\$SPECIALIZED_DB_ROOT/amr"
export CARD_DB="\$AMR_DB_ROOT/card"
export RESFINDER_DB="\$AMR_DB_ROOT/resfinder"
export AMRFINDERPLUS_DB="\$AMR_DB_ROOT/amrfinderplus"

# Virulence factors
export VIRULENCE_DB_ROOT="\$SPECIALIZED_DB_ROOT/virulence"

# Plasmids
export PLASMID_DB_ROOT="\$SPECIALIZED_DB_ROOT/plasmid"

# =============================================================================
# CACHE AND WORK DIRECTORIES
# =============================================================================

export METAGENOME_CACHE_DIR="\$DB_ROOT/cache"
export METAGENOME_WORK_DIR="\$DB_ROOT/work"
export METAGENOME_LOG_DIR="\$DB_ROOT/logs"

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Check database status
check_db_status() {
    echo "========================================="
    echo "    Metagenome Database Status          "
    echo "========================================="
    echo
    echo "Configuration:"
    echo "  DB Type: \$DB_TYPE"
    echo "  DB Root: \$DB_ROOT"
    echo "  Cache: \$METAGENOME_CACHE_DIR"
    echo
    
    echo "Reference Databases:"
    [ -e "\$REFERENCE_GENOMES" ] && echo "  ✓ Genomes: \$(readlink -f \$REFERENCE_GENOMES 2>/dev/null || echo \$REFERENCE_GENOMES)" || echo "  ✗ Genomes: Not available"
    [ -e "\$REFERENCE_ANNOTATIONS" ] && echo "  ✓ Annotations: \$(readlink -f \$REFERENCE_ANNOTATIONS 2>/dev/null || echo \$REFERENCE_ANNOTATIONS)" || echo "  ✗ Annotations: Not available"  
    [ -e "\$REFERENCE_INDICES" ] && echo "  ✓ Indices: \$(readlink -f \$REFERENCE_INDICES 2>/dev/null || echo \$REFERENCE_INDICES)" || echo "  ✗ Indices: Not available"
    echo
    
    echo "Metagenome Databases:"
    [ -e "\$BUSCO_DB" ] && echo "  ✓ BUSCO: \$(readlink -f \$BUSCO_DB 2>/dev/null || echo \$BUSCO_DB)" || echo "  ○ BUSCO: Not configured"
    [ -e "\$GTDBTK_DB" ] && echo "  ✓ GTDB-Tk: \$(readlink -f \$GTDBTK_DB 2>/dev/null || echo \$GTDBTK_DB)" || echo "  ○ GTDB-Tk: Not configured"
    [ -e "\$KRAKEN2_DB" ] && echo "  ✓ Kraken2: \$(readlink -f \$KRAKEN2_DB 2>/dev/null || echo \$KRAKEN2_DB)" || echo "  ○ Kraken2: Not configured"
    [ -e "\$CHECKM_DB" ] && echo "  ✓ CheckM: \$(readlink -f \$CHECKM_DB 2>/dev/null || echo \$CHECKM_DB)" || echo "  ○ CheckM: Not configured"
    echo
    
    echo "Specialized Databases:" 
    [ -e "\$CARD_DB" ] && echo "  ✓ CARD: \$(readlink -f \$CARD_DB 2>/dev/null || echo \$CARD_DB)" || echo "  ○ CARD: Not configured"
    [ -e "\$RESFINDER_DB" ] && echo "  ✓ ResFinder: \$(readlink -f \$RESFINDER_DB 2>/dev/null || echo \$RESFINDER_DB)" || echo "  ○ ResFinder: Not configured"
    echo
    
    # Disk usage
    if [ -d "\$DB_ROOT" ]; then
        echo "Storage Usage:"
        du -sh "\$DB_ROOT"/* 2>/dev/null | sort -hr || true
    fi
    echo "========================================="
}

# Download missing databases
download_db() {
    local db_name=\$1
    echo "Downloading \$db_name database..."
    
    case \$db_name in
        "gtdbtk")
            echo "GTDB-Tk database download would go here"
            echo "Estimated size: ~70GB"
            ;;
        "kraken2")
            echo "Kraken2 standard database download would go here" 
            echo "Estimated size: ~100GB"
            ;;
        "checkm")
            echo "CheckM database download would go here"
            echo "Estimated size: ~1.4GB"
            ;;
        "card")
            echo "CARD database download would go here"
            echo "Estimated size: ~1GB"
            ;;
        *)
            echo "Unknown database: \$db_name"
            echo "Available: gtdbtk, kraken2, checkm, card"
            ;;
    esac
}

# Setup database shortcuts
setup_db_shortcuts() {
    echo "Setting up database shortcuts..."
    
    # Create convenient aliases
    alias db-status='check_db_status'
    alias db-download='download_db'
    alias db-root='echo \$DB_ROOT'
    alias goto-db='cd \$DB_ROOT'
    
    echo "Shortcuts created:"
    echo "  db-status    - Check database status"
    echo "  db-download  - Download missing databases" 
    echo "  db-root      - Show database root path"
    echo "  goto-db      - Navigate to database root"
}

# Initialize on load
setup_db_shortcuts

# Show current status on first load
if [ -z "\$METAGENOME_DB_LOADED" ]; then
    export METAGENOME_DB_LOADED=1
    echo "🧬 Metagenome database environment loaded (\$DB_TYPE mode)"
    echo "💡 Run 'check_db_status' to see configuration"
fi
EOF

    log_info "Environment configuration created ✓"
}

update_bashrc() {
    log_info "Updating ~/.bashrc..."
    
    # Check if already added
    if grep -q "metagenome_db_env" "$HOME/.bashrc"; then
        log_warn "Environment already configured in .bashrc"
        return
    fi
    
    # Add to bashrc
    cat >> "$HOME/.bashrc" << 'EOF'

# =============================================================================
# Metagenome Database Environment
# =============================================================================
if [ -f ~/.metagenome_db_env ]; then
    source ~/.metagenome_db_env
fi
EOF
    
    log_info "Updated .bashrc ✓"
}

create_readme() {
    log_info "Creating README file..."
    
    cat > "$USER_DB/README.md" << EOF
# Personal Metagenome Database

This directory contains a personal metagenome database structure that integrates with the existing shared databases while providing space for metagenome-specific tools.

## Structure

\`\`\`
$USER_DB/
├── reference/          # Links to existing shared data
│   ├── genomes/       # → /db/genomes
│   ├── annotations/   # → /db/annotations  
│   └── indices/       # → /db/indices
├── metagenome/        # Metagenome-specific databases
│   ├── busco/         # → /db/tool_specific_db/busco
│   ├── gtdbtk/        # (to be downloaded)
│   ├── kraken2/       # (to be downloaded)
│   └── checkm/        # (to be downloaded)
├── specialized/       # Specialized analysis databases
│   ├── amr/           # Antibiotic resistance
│   ├── virulence/     # Virulence factors
│   └── plasmid/       # Plasmid detection
├── cache/             # Temporary files
├── work/              # Working directory
└── logs/              # Log files
\`\`\`

## Usage

\`\`\`bash
# Check status
check_db_status

# Navigate to database
goto-db

# Download missing databases
download_db gtdbtk
download_db kraken2
\`\`\`

## Environment Variables

The following variables are automatically set:

- \`DB_ROOT\`: Root database directory
- \`BUSCO_DB\`: BUSCO database path
- \`GTDBTK_DB\`: GTDB-Tk database path  
- \`REFERENCE_GENOMES\`: Reference genomes path

## Migration Path

When full shared access becomes available, this structure can be migrated to \`/data/shared/\` with minimal disruption to existing workflows.

Created: $(date)
By: $(whoami)
EOF
    
    log_info "README created ✓"
}

verify_setup() {
    log_info "Verifying setup..."
    
    local errors=0
    
    # Check directory structure
    if [ ! -d "$USER_DB" ]; then
        log_error "Main directory not created"
        ((errors++))
    fi
    
    # Check environment file
    if [ ! -f "$HOME/.metagenome_db_env" ]; then
        log_error "Environment file not created" 
        ((errors++))
    fi
    
    # Check bashrc update
    if ! grep -q "metagenome_db_env" "$HOME/.bashrc"; then
        log_error ".bashrc not updated"
        ((errors++))
    fi
    
    # Test environment loading
    if source "$HOME/.metagenome_db_env" 2>/dev/null; then
        log_info "Environment file loads correctly ✓"
    else
        log_error "Environment file has syntax errors"
        ((errors++))
    fi
    
    if [ $errors -eq 0 ]; then
        log_info "Verification passed ✓"
        return 0
    else
        log_error "Verification failed with $errors errors"
        return 1
    fi
}

print_summary() {
    echo
    echo "========================================="
    echo "     Personal DB Setup Complete!       " 
    echo "========================================="
    echo
    echo "📁 Database Location: $USER_DB"
    echo "📋 Registry: $USER_DB/registry.yaml"
    echo "⚙️  Environment: ~/.metagenome_db_env"
    echo "📖 Documentation: $USER_DB/README.md"
    echo
    echo "Next Steps:"
    echo "1. Load environment: source ~/.bashrc"
    echo "2. Check status: check_db_status"  
    echo "3. Download databases: download_db <name>"
    echo
    echo "When shared access is available:"
    echo "- Contact admin for /data/shared migration"
    echo "- Run migration script from metagenome-pipeline-benchmark"
    echo
    log_info "Setup completed successfully! 🎉"
}

# Main execution
main() {
    print_header
    
    # Check if already exists
    if [ -d "$USER_DB" ]; then
        log_warn "Personal DB directory already exists at $USER_DB"
        read -p "Continue and overwrite? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Setup cancelled"
            exit 0
        fi
    fi
    
    create_directory_structure
    link_existing_databases
    create_database_registry
    create_environment_file
    update_bashrc
    create_readme
    
    if verify_setup; then
        print_summary
    else
        log_error "Setup completed with errors - please check manually"
        exit 1
    fi
}

# Run main function
main "$@"