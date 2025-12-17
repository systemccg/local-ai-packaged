#!/bin/bash
#
# Server Migration Export Script
# Exports all data, configs, and databases for server migration
#
# Usage: ./export_for_migration.sh [output_directory]
#

set -e  # Exit on error

MIGRATION_DIR="${1:-/root/migration_$(date +%Y%m%d_%H%M%S)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "Server Migration Export Script"
echo "=========================================="
echo "Migration directory: $MIGRATION_DIR"
echo "Project root: $PROJECT_ROOT"
echo ""

# Create migration directory structure
mkdir -p "$MIGRATION_DIR"/{configs,workflows,databases,volumes,secrets}

# Function to log progress
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check if container is running
container_running() {
    docker ps --format '{{.Names}}' | grep -q "^$1$"
}

# ==========================================
# Phase 1: Export n8n Workflows
# ==========================================
log "📋 Phase 1: Exporting n8n workflows..."

if container_running "n8n"; then
    # Export all workflows
    log "  - Exporting all workflows to JSON..."
    docker exec n8n n8n export:workflow --all --output=/tmp/workflows_export.json 2>/dev/null || true
    docker cp n8n:/tmp/workflows_export.json "$MIGRATION_DIR/workflows/all_workflows.json" 2>/dev/null || true

    # Also export individual workflow files from backup directory
    if [ -d "$PROJECT_ROOT/n8n/backup/workflows" ]; then
        log "  - Copying workflow backup files..."
        cp -r "$PROJECT_ROOT/n8n/backup/workflows" "$MIGRATION_DIR/workflows/backup_files"
    fi

    # Export credentials (encrypted)
    log "  - Exporting credentials (encrypted)..."
    docker exec n8n n8n export:credentials --all --output=/tmp/credentials_export.json 2>/dev/null || true
    docker cp n8n:/tmp/credentials_export.json "$MIGRATION_DIR/workflows/credentials_encrypted.json" 2>/dev/null || true

    log "  ✅ n8n workflows exported"
else
    log "  ⚠️  n8n container not running - skipping workflow export"
fi

# ==========================================
# Phase 2: Export Databases
# ==========================================
log "📊 Phase 2: Exporting databases..."

# Supabase PostgreSQL
if container_running "supabase-db"; then
    log "  - Dumping Supabase PostgreSQL (this may take a few minutes)..."
    docker exec supabase-db pg_dumpall -U postgres > "$MIGRATION_DIR/databases/supabase_full_dump.sql"
    gzip "$MIGRATION_DIR/databases/supabase_full_dump.sql"
    log "  ✅ Supabase database exported ($(du -h "$MIGRATION_DIR/databases/supabase_full_dump.sql.gz" | cut -f1))"
else
    log "  ⚠️  Supabase DB not running - skipping"
fi

# n8n SQLite Database
if container_running "n8n"; then
    log "  - Exporting n8n SQLite database..."
    docker exec n8n sqlite3 /home/node/.n8n/database.sqlite ".dump" > "$MIGRATION_DIR/databases/n8n_database.sql" 2>/dev/null || true

    # Also copy the binary database file
    docker cp n8n:/home/node/.n8n/database.sqlite "$MIGRATION_DIR/databases/n8n_database.sqlite" 2>/dev/null || true

    if [ -f "$MIGRATION_DIR/databases/n8n_database.sqlite" ]; then
        gzip "$MIGRATION_DIR/databases/n8n_database.sql"
        log "  ✅ n8n SQLite database exported ($(du -h "$MIGRATION_DIR/databases/n8n_database.sqlite" | cut -f1))"
    fi
else
    log "  ⚠️  n8n not running - skipping SQLite export"
fi

# Langfuse PostgreSQL
if container_running "local-ai-packaged-langfuse-postgres-1"; then
    log "  - Dumping Langfuse PostgreSQL..."
    docker exec local-ai-packaged-langfuse-postgres-1 pg_dump -U postgres langfuse > "$MIGRATION_DIR/databases/langfuse_postgres.sql" 2>/dev/null || true
    if [ -f "$MIGRATION_DIR/databases/langfuse_postgres.sql" ]; then
        gzip "$MIGRATION_DIR/databases/langfuse_postgres.sql"
        log "  ✅ Langfuse database exported"
    fi
else
    log "  ⚠️  Langfuse Postgres not running - skipping"
fi

# ==========================================
# Phase 3: Backup Docker Volumes
# ==========================================
log "💾 Phase 3: Backing up Docker volumes..."

# Critical volumes to backup
CRITICAL_VOLUMES=(
    "n8n_storage"
    "local-ai-packaged_n8n_storage"
    "supabase_db-config"
    "graphiti_neo4j_data"
    "local-ai-packaged_qdrant_storage"
    "local-ai-packaged_langfuse_postgres_data"
    "local-ai-packaged_langfuse_clickhouse_data"
    "local-ai-packaged_langfuse_minio_data"
)

for VOLUME in "${CRITICAL_VOLUMES[@]}"; do
    # Check if volume exists
    if docker volume inspect "$VOLUME" >/dev/null 2>&1; then
        log "  - Backing up volume: $VOLUME..."
        docker run --rm \
            -v "$VOLUME:/source:ro" \
            -v "$MIGRATION_DIR/volumes:/backup" \
            alpine tar czf "/backup/${VOLUME}.tar.gz" -C /source . 2>/dev/null

        SIZE=$(du -h "$MIGRATION_DIR/volumes/${VOLUME}.tar.gz" | cut -f1)
        log "    ✅ $VOLUME backed up ($SIZE)"
    else
        log "    ⚠️  Volume $VOLUME not found - skipping"
    fi
done

# ==========================================
# Phase 4: Copy Configuration Files
# ==========================================
log "⚙️  Phase 4: Copying configuration files..."

cd "$PROJECT_ROOT"

# Copy main configs (excluding .git and node_modules)
log "  - Copying docker-compose files..."
cp docker-compose.yml "$MIGRATION_DIR/configs/" 2>/dev/null || true
cp docker-compose.override.yml "$MIGRATION_DIR/configs/" 2>/dev/null || true

log "  - Copying Caddyfile..."
cp Caddyfile "$MIGRATION_DIR/configs/" 2>/dev/null || true

log "  - Copying documentation..."
cp CLAUDE.md "$MIGRATION_DIR/configs/" 2>/dev/null || true
cp README.md "$MIGRATION_DIR/configs/" 2>/dev/null || true
cp -r n8n/docs "$MIGRATION_DIR/configs/n8n_docs" 2>/dev/null || true

log "  - Copying scripts..."
cp -r scripts "$MIGRATION_DIR/configs/" 2>/dev/null || true

log "  - Copying Supabase configs..."
mkdir -p "$MIGRATION_DIR/configs/supabase"
cp -r supabase/docker/*.yml "$MIGRATION_DIR/configs/supabase/" 2>/dev/null || true

log "  ✅ Configuration files copied"

# ==========================================
# Phase 5: Export Secrets (Encrypted Archive)
# ==========================================
log "🔐 Phase 5: Exporting secrets (SECURE)..."

# Copy .env files
log "  - Copying .env files..."
cp "$PROJECT_ROOT/.env" "$MIGRATION_DIR/secrets/env_main" 2>/dev/null || log "    ⚠️  Main .env not found"
cp "$PROJECT_ROOT/supabase/docker/.env" "$MIGRATION_DIR/secrets/env_supabase" 2>/dev/null || log "    ⚠️  Supabase .env not found"

# Create .env.example for GitHub
grep -v -E '^[A-Z_]+=.+' "$PROJECT_ROOT/.env" > "$MIGRATION_DIR/configs/.env.example" 2>/dev/null || true
awk -F= '{if($1 ~ /^[A-Z_]+$/) print $1"=CHANGEME"}' "$PROJECT_ROOT/.env" >> "$MIGRATION_DIR/configs/.env.example" 2>/dev/null || true

# Create encrypted secrets archive
cd "$MIGRATION_DIR/secrets"
SECRETS_ARCHIVE="../secrets_$(date +%Y%m%d_%H%M%S).tar.gz"
tar czf "$SECRETS_ARCHIVE" * 2>/dev/null
cd - >/dev/null

log "  ✅ Secrets archived: $(basename "$SECRETS_ARCHIVE")"
log "  ⚠️  IMPORTANT: This archive contains sensitive data!"
log "     Transfer it securely (scp, encrypted USB, etc.)"

# ==========================================
# Phase 6: Create Checksums
# ==========================================
log "✔️  Phase 6: Creating checksums..."

cd "$MIGRATION_DIR"
find . -type f -exec sha256sum {} \; > checksums.txt
log "  ✅ Checksums created"

# ==========================================
# Summary
# ==========================================
log ""
log "=========================================="
log "✅ Export Complete!"
log "=========================================="
log ""
log "📁 Migration data location: $MIGRATION_DIR"
log ""
log "📊 Exported Data:"
ls -lh "$MIGRATION_DIR/databases/" 2>/dev/null | tail -n +2 | awk '{printf "  - %-40s %s\n", $9, $5}'
log ""
log "💾 Volume Backups:"
ls -lh "$MIGRATION_DIR/volumes/" 2>/dev/null | tail -n +2 | awk '{printf "  - %-40s %s\n", $9, $5}'
log ""
log "📦 Total Size:"
du -sh "$MIGRATION_DIR" | awk '{print "  " $1}'
log ""
log "🔐 Secrets Archive:"
ls -lh "$MIGRATION_DIR"/../secrets_*.tar.gz 2>/dev/null | awk '{printf "  - %s (%s)\n", $9, $5}'
log ""
log "=========================================="
log "Next Steps:"
log "=========================================="
log "1. Review exported files in: $MIGRATION_DIR"
log "2. Verify checksums after transfer: sha256sum -c checksums.txt"
log "3. Securely transfer secrets archive"
log "4. Push configs to GitHub (see configs/ directory)"
log "5. On new server, use restore_from_migration.sh"
log ""
log "⚠️  CRITICAL: Keep secrets archive secure!"
log "   DO NOT commit secrets to GitHub!"
log ""
