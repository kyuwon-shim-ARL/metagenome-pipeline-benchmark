#!/bin/bash
# Continue Production DB Setup - Resume from where it stopped

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

SHARED_DB="/data/shared/metagenome-db"

echo "🔄 Continuing Production Database Setup..."

# Check current state
if [ ! -d "$SHARED_DB" ]; then
    echo "❌ Shared database not found. Please run setup_production_db.sh first"
    exit 1
fi

log_info "Found existing structure at $SHARED_DB"

# Continue from where it stopped - link remaining databases
log_step "Completing database linking..."

CURRENT_DB="/db"

# Link annotations
if [ -d "$CURRENT_DB/annotations" ] && [ ! -L "$SHARED_DB/reference/annotations/annotations" ]; then
    ln -sfn "$CURRENT_DB/annotations" "$SHARED_DB/reference/annotations/annotations"
    log_info "✓ Linked annotations"
fi

# Link indices  
if [ -d "$CURRENT_DB/indices" ] && [ ! -L "$SHARED_DB/reference/indices/indices" ]; then
    ln -sfn "$CURRENT_DB/indices" "$SHARED_DB/reference/indices/indices"
    log_info "✓ Linked indices"
fi

# Fix BUSCO linking
if [ -d "$CURRENT_DB/tool_specific_db/busco" ]; then
    ln -sfn "$CURRENT_DB/tool_specific_db/busco" "$SHARED_DB/metagenome/busco/v5"
    ln -sfn "$SHARED_DB/metagenome/busco/v5" "$SHARED_DB/metagenome/busco/latest"
    log_info "✓ Fixed BUSCO database linking"
fi

# Create registry if not exists
if [ ! -f "$SHARED_DB/registry.yaml" ]; then
    log_step "Creating database registry..."
    
    cat > "$SHARED_DB/registry.yaml" << EOF
# Production Metagenome Database Registry
# Created: $(date)

structure_version: "2.0"
deployment_type: "production_shared"
created: $(date -Iseconds)
owner: $(whoami)

databases:
  reference:
    genomes:
      path: "reference/genomes/genomes"
      source: "/db/genomes"
      type: "symlink"
      status: "active"
      
    annotations:
      path: "reference/annotations/annotations"  
      source: "/db/annotations"
      type: "symlink"
      status: "active"
      
    indices:
      path: "reference/indices/indices"
      source: "/db/indices"
      type: "symlink"
      status: "active"
  
  metagenome:
    busco:
      path: "metagenome/busco/latest"
      version: "v5"
      type: "symlink"
      status: "active"
      
    gtdbtk:
      path: "metagenome/gtdbtk/latest"
      version: "r220"
      type: "downloadable"
      status: "pending"
      
    kraken2:
      path: "metagenome/kraken2/latest"
      version: "standard_2024"
      type: "downloadable"  
      status: "pending"

system:
  root: "$SHARED_DB"
  cache: "$SHARED_DB/cache"
  work: "$SHARED_DB/work"
  logs: "$SHARED_DB/logs"
EOF
    
    log_info "✓ Created registry"
fi

# Create environment file
log_step "Creating environment configuration..."

cat > ~/.metagenome_db_env << 'EOF'
# Production Metagenome Database Environment

export METAGENOME_DB_ROOT="/data/shared/metagenome-db"
export DB_TYPE="shared_production"

# Reference databases
export REFERENCE_DB_ROOT="$METAGENOME_DB_ROOT/reference"
export REFERENCE_GENOMES="$REFERENCE_DB_ROOT/genomes/genomes"
export REFERENCE_ANNOTATIONS="$REFERENCE_DB_ROOT/annotations/annotations"
export REFERENCE_INDICES="$REFERENCE_DB_ROOT/indices/indices"

# Metagenome databases
export BUSCO_DB="$METAGENOME_DB_ROOT/metagenome/busco/latest"
export GTDBTK_DB="$METAGENOME_DB_ROOT/metagenome/gtdbtk/latest"
export KRAKEN2_DB="$METAGENOME_DB_ROOT/metagenome/kraken2/latest"
export CHECKM_DB="$METAGENOME_DB_ROOT/metagenome/checkm/latest"

# Specialized databases
export AMR_DB_ROOT="$METAGENOME_DB_ROOT/specialized/amr"
export CARD_DB="$AMR_DB_ROOT/card"
export RESFINDER_DB="$AMR_DB_ROOT/resfinder"

# Working directories
export METAGENOME_CACHE="$METAGENOME_DB_ROOT/cache"
export METAGENOME_WORK="$METAGENOME_DB_ROOT/work"
export METAGENOME_LOGS="$METAGENOME_DB_ROOT/logs"

# Status check function
check_production_db() {
    echo "🧬 Production Metagenome Database Status"
    echo "Root: $METAGENOME_DB_ROOT"
    echo "Type: $DB_TYPE"
    echo
    
    echo "Reference Databases:"
    [ -L "$REFERENCE_GENOMES" ] && echo "  ✓ Genomes: $(readlink $REFERENCE_GENOMES)" || echo "  ✗ Genomes"
    [ -L "$REFERENCE_ANNOTATIONS" ] && echo "  ✓ Annotations: $(readlink $REFERENCE_ANNOTATIONS)" || echo "  ✗ Annotations"
    [ -L "$REFERENCE_INDICES" ] && echo "  ✓ Indices: $(readlink $REFERENCE_INDICES)" || echo "  ✗ Indices"
    echo
    
    echo "Metagenome Databases:"
    [ -L "$BUSCO_DB" ] && echo "  ✓ BUSCO: $(readlink $BUSCO_DB)" || echo "  ○ BUSCO: Not configured"
    [ -d "$GTDBTK_DB" ] && echo "  ✓ GTDB-Tk" || echo "  ○ GTDB-Tk: Not downloaded"
    [ -d "$KRAKEN2_DB" ] && echo "  ✓ Kraken2" || echo "  ○ Kraken2: Not downloaded"
    echo
    
    echo "Storage Usage:"
    du -sh $METAGENOME_DB_ROOT/* 2>/dev/null | head -5
}

# Aliases
alias db-status='check_production_db'
alias goto-db='cd $METAGENOME_DB_ROOT'
alias db-cache='cd $METAGENOME_CACHE'

export -f check_production_db

# Initialize
echo "🚀 Production metagenome database environment loaded"
EOF

log_info "✓ Created environment file"

# Update bashrc
log_step "Updating shell configuration..."

if ! grep -q "metagenome_db_env" ~/.bashrc 2>/dev/null; then
    cat >> ~/.bashrc << 'EOF'

# Production Metagenome Database Environment
if [ -f ~/.metagenome_db_env ]; then
    source ~/.metagenome_db_env
fi
EOF
    log_info "✓ Updated ~/.bashrc"
else
    log_info "✓ Shell configuration already updated"
fi

# Update resistance-tracker config
log_step "Updating project configurations..."

RESISTANCE_CONFIG="$HOME/metagenome-resistance-tracker/nextflow.config"
if [ -f "$RESISTANCE_CONFIG" ]; then
    # Backup
    cp "$RESISTANCE_CONFIG" "${RESISTANCE_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Update config to use new paths
    cat > "$RESISTANCE_CONFIG" << 'EOF'
// nextflow.config - Production Database Configuration

params {
    // Input/Output
    input = 'sample_sheet_public.csv'
    outdir = './results_public'
    
    // Production Database Paths
    busco_reference_path = System.getenv('BUSCO_DB') ?: '/data/shared/metagenome-db/metagenome/busco/latest'
    gtdb_path = System.getenv('GTDBTK_DB') ?: '/data/shared/metagenome-db/metagenome/gtdbtk/latest'
    kraken2_db = System.getenv('KRAKEN2_DB') ?: '/data/shared/metagenome-db/metagenome/kraken2/latest'
    checkm_path = System.getenv('CHECKM_DB') ?: '/data/shared/metagenome-db/metagenome/checkm/latest'
}

profiles {
    singularity {
        singularity.enabled = true
        singularity.autoMounts = true
        singularity.cacheDir = System.getenv('METAGENOME_CACHE') ?: '/home/kyuwon/.singularity/cache'
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
    
    log_info "✓ Updated resistance-tracker configuration"
fi

# Test environment
log_step "Testing configuration..."

# Source environment and test
source ~/.metagenome_db_env

echo
echo "✅ Production Database Setup Complete!"
echo
echo "📁 Database Location: $SHARED_DB"
echo "📋 Registry: $SHARED_DB/registry.yaml"
echo "⚙️  Environment: ~/.metagenome_db_env"
echo
echo "🚀 Next Steps:"
echo "1. Load environment: source ~/.bashrc"
echo "2. Check status: db-status"
echo "3. Test pipeline: cd ~/metagenome-resistance-tracker"
echo
echo "🎉 Ready to use!"