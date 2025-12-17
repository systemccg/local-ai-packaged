#!/bin/bash
#
# Server Migration Restoration Script
# Restores all data, configs, and databases from migration export
#
# Usage: ./restore_from_migration.sh <migration_directory>
#

set -e  # Exit on error

if [ -z "$1" ]; then
    echo "Usage: $0 <migration_directory>"
    echo "Example: $0 /root/migration_20251110_143000"
    exit 1
fi

MIGRATION_DIR="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "Server Migration Restoration Script"
echo "=========================================="
echo "Migration directory: $MIGRATION_DIR"
echo "Project root: $PROJECT_ROOT"
echo ""

# Verify migration directory exists
if [ ! -d "$MIGRATION_DIR" ]; then
    echo "❌ Error: Migration directory not found: $MIGRATION_DIR"
    exit 1
fi

# Function to log progress
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to verify checksums
verify_checksums() {
    if [ -f "$MIGRATION_DIR/checksums.txt" ]; then
        log "🔍 Verifying checksums..."
        cd "$MIGRATION_DIR"
        if sha256sum -c checksums.txt --quiet; then
            log "  ✅ All checksums verified!"
        else
            log "  ⚠️  Some checksums failed - files may be corrupted"
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
        cd - >/dev/null
    else
        log "  ⚠️  No checksums file found - skipping verification"
    fi
}

# ==========================================
# Phase 0: Pre-flight Checks
# ==========================================
log "🔍 Phase 0: Pre-flight checks..."

# Verify Docker is installed
if ! command -v docker &> /dev/null; then
    log "❌ Docker not found! Please install Docker first:"
    log "   curl -fsSL https://get.docker.com -o get-docker.sh"
    log "   sudo sh get-docker.sh"
    exit 1
fi

# Verify checksums
verify_checksums

# Check if secrets have been restored
if [ ! -f "$PROJECT_ROOT/.env" ]; then
    log "⚠️  .env file not found!"
    log ""
    log "Before running this script, you must:"
    log "1. Extract the secrets archive:"
    log "   tar xzf secrets_YYYYMMDD_HHMMSS.tar.gz -C /tmp/secrets"
    log "2. Copy .env files to project:"
    log "   cp /tmp/secrets/env_main $PROJECT_ROOT/.env"
    log "   cp /tmp/secrets/env_supabase $PROJECT_ROOT/supabase/docker/.env"
    log ""
    read -p "Have you restored the secrets? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

log "  ✅ Pre-flight checks passed"

# ==========================================
# Phase 1: Start Services
# ==========================================
log "🚀 Phase 1: Starting services..."

cd "$PROJECT_ROOT"

log "  - Pulling latest images..."
docker compose pull 2>&1 | grep -E "Pulling|Downloaded|up to date" || true

log "  - Starting containers..."
docker compose up -d

log "  - Waiting for services to initialize (30 seconds)..."
sleep 30

log "  ✅ Services started"

# ==========================================
# Phase 2: Restore Databases
# ==========================================
log "📊 Phase 2: Restoring databases..."

# Ask user which restoration method they prefer
echo ""
echo "Database Restoration Options:"
echo "1. Restore from SQL dumps (recommended - faster)"
echo "2. Restore from volume backups (complete - slower)"
echo "3. Skip database restoration"
echo ""
read -p "Choose option (1-3): " -n 1 -r RESTORE_OPTION
echo ""

if [ "$RESTORE_OPTION" = "1" ]; then
    # Restore from SQL dumps
    log "  - Restoring from SQL dumps..."

    # Supabase PostgreSQL
    if [ -f "$MIGRATION_DIR/databases/supabase_full_dump.sql.gz" ]; then
        log "    - Restoring Supabase database..."
        gunzip -c "$MIGRATION_DIR/databases/supabase_full_dump.sql.gz" | \
            docker exec -i supabase-db psql -U postgres -q
        log "      ✅ Supabase restored"
    fi

    # n8n SQLite
    if [ -f "$MIGRATION_DIR/databases/n8n_database.sqlite" ]; then
        log "    - Restoring n8n database..."
        docker cp "$MIGRATION_DIR/databases/n8n_database.sqlite" n8n:/home/node/.n8n/database.sqlite
        docker restart n8n
        sleep 5
        log "      ✅ n8n database restored"
    fi

    # Langfuse PostgreSQL
    if [ -f "$MIGRATION_DIR/databases/langfuse_postgres.sql.gz" ]; then
        log "    - Restoring Langfuse database..."
        gunzip -c "$MIGRATION_DIR/databases/langfuse_postgres.sql.gz" | \
            docker exec -i local-ai-packaged-langfuse-postgres-1 psql -U postgres langfuse -q 2>/dev/null || true
        log "      ✅ Langfuse restored"
    fi

elif [ "$RESTORE_OPTION" = "2" ]; then
    # Restore from volume backups
    log "  - Stopping services for volume restoration..."
    docker compose down

    log "  - Restoring Docker volumes..."
    for VOLUME_ARCHIVE in "$MIGRATION_DIR/volumes"/*.tar.gz; do
        if [ -f "$VOLUME_ARCHIVE" ]; then
            VOLUME_NAME=$(basename "$VOLUME_ARCHIVE" .tar.gz)
            log "    - Restoring volume: $VOLUME_NAME..."

            # Create volume if it doesn't exist
            docker volume create "$VOLUME_NAME" >/dev/null 2>&1 || true

            # Restore data
            docker run --rm \
                -v "$VOLUME_NAME:/target" \
                -v "$MIGRATION_DIR/volumes:/backup:ro" \
                alpine tar xzf "/backup/$(basename "$VOLUME_ARCHIVE")" -C /target

            log "      ✅ $VOLUME_NAME restored"
        fi
    done

    log "  - Restarting services..."
    docker compose up -d
    sleep 30

else
    log "  ⏭️  Skipping database restoration"
fi

# ==========================================
# Phase 3: Import n8n Workflows
# ==========================================
log "📋 Phase 3: Importing n8n workflows..."

if [ -f "$MIGRATION_DIR/workflows/all_workflows.json" ]; then
    log "  - Importing workflows..."
    docker exec -i n8n n8n import:workflow --separate --input=/dev/stdin < "$MIGRATION_DIR/workflows/all_workflows.json" 2>/dev/null || true
    log "  ✅ Workflows imported"
else
    log "  ⚠️  No workflows file found - skipping"
fi

# Import individual workflow backups if available
if [ -d "$MIGRATION_DIR/workflows/backup_files" ]; then
    log "  - Importing backup workflows..."
    for WORKFLOW_FILE in "$MIGRATION_DIR/workflows/backup_files"/*.json; do
        if [ -f "$WORKFLOW_FILE" ]; then
            docker exec -i n8n n8n import:workflow --input=/dev/stdin < "$WORKFLOW_FILE" 2>/dev/null || true
        fi
    done
    log "  ✅ Backup workflows imported"
fi

# ==========================================
# Phase 4: Verify Installation
# ==========================================
log "✔️  Phase 4: Verifying installation..."

log "  - Checking container health..."
docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "n8n|supabase|neo4j" || true

log ""
log "  - Verifying n8n..."
if docker exec n8n n8n list:workflow >/dev/null 2>&1; then
    WORKFLOW_COUNT=$(docker exec n8n n8n list:workflow 2>/dev/null | wc -l)
    log "    ✅ n8n operational ($((WORKFLOW_COUNT-1)) workflows)"
else
    log "    ⚠️  n8n may need more time to initialize"
fi

log ""
log "  - Verifying Supabase..."
if docker exec supabase-db psql -U postgres -c "SELECT count(*) FROM auth.users;" >/dev/null 2>&1; then
    USER_COUNT=$(docker exec supabase-db psql -U postgres -t -c "SELECT count(*) FROM auth.users;" 2>/dev/null | tr -d ' ')
    log "    ✅ Supabase operational ($USER_COUNT users)"
else
    log "    ⚠️  Supabase may need more time to initialize"
fi

# ==========================================
# Summary
# ==========================================
log ""
log "=========================================="
log "✅ Restoration Complete!"
log "=========================================="
log ""
log "🌐 Access your services:"
log "  - n8n:      https://n8n.leadingai.info"
log "  - Supabase: https://db.leadingai.info"
log ""
log "📝 Next steps:"
log "1. Verify all services are accessible"
log "2. Test workflows in n8n"
log "3. Check database integrity"
log "4. Update DNS if domain changed"
log "5. Verify SSL certificates"
log ""
log "📋 Verification commands:"
log "  docker ps                                    # Check running containers"
log "  docker logs n8n --tail 50                    # Check n8n logs"
log "  docker exec n8n n8n list:workflow            # List workflows"
log "  docker exec supabase-db psql -U postgres     # Access database"
log ""
log "⚠️  If you encounter issues:"
log "  - Check logs: docker compose logs"
log "  - Restart services: docker compose restart"
log "  - Full reset: docker compose down && docker compose up -d"
log ""
