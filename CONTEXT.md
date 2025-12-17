# Local AI Package - Project Context

This file provides context for AI assistants (Claude Code, Gemini, Copilot, etc.) when working with this project.

## System Documentation

**For system-wide documentation, see:**
- **Master Context:** `/root/flourisha/00_AI_Brain/context/MASTER_CONTEXT.md`
- **Documentation Hub:** `/root/flourisha/00_AI_Brain/docs/README.md`
- **Skills:** `/root/flourisha/00_AI_Brain/skills/`
- **Scripts:** `/root/flourisha/00_AI_Brain/scripts/`

---

## 📚 Documentation Hub

**LATEST FIX (2025-11-10):** Data passthrough issue in "Set Tenant Context (GDrive)" node resolved. See `FIX_DATA_PASSTHROUGH_ISSUE_2025-11-10.md` for details. Working workflow: `V5_Multi_Tenant_RAG_Workflow_WORKING.json`

**IMPORTANT: All n8n workflow documentation is located at:**
```
/root/local-ai-packaged/n8n/docs/
```

**Quick Recovery Commands:**
```bash
# View all available docs
ls -lah /root/local-ai-packaged/n8n/docs/

# Read the index
cat /root/local-ai-packaged/n8n/docs/README.md

# Quick recovery guide
cat /root/local-ai-packaged/n8n/docs/RECOVERY_GUIDE.md
```

**Key Documentation Files:**
- `README.md` - Documentation index and navigation guide
- `RECOVERY_GUIDE.md` - How to resume this project after session loss
- `MULTI_TENANT_UPLOAD_APPROACHES.md` - Document upload strategies (Google Drive, Web UI, Webhook API)
- `WORKFLOW_ISSUES_AND_FIXES.md` - Known issues and solutions
- `MULTI_TENANT_TESTING_GUIDE.md` - Testing procedures for tenant isolation
- `WORKFLOW_V5_CHANGES.md` - Technical details of V5 upgrade

**ALL future documentation MUST go to `/root/local-ai-packaged/n8n/docs/`**

## Project Overview

This is a self-hosted Local AI Package - a Docker Compose-based system that combines n8n (workflow automation), Supabase (database/auth), Ollama (local LLMs), Open WebUI, and supporting services (Neo4j, Qdrant, SearXNG, Langfuse, Flowise, Caddy) for building local AI workflows.

## CRITICAL: Public URLs

**ALWAYS use these public URLs when referencing services, NOT localhost:**

- **n8n**: https://n8n.leadingai.info
- **Supabase**: https://db.leadingai.info
- **Open WebUI**: https://webui.leadingai.info (if configured)
- **Langfuse**: https://langfuse.leadingai.info (if configured)
- **Flowise**: https://flowise.leadingai.info (if configured)
- **Neo4j**: https://neo4j.leadingai.info (if configured)

## CRITICAL: Accessing n8n Workflows

**n8n workflows are NOT in backup files!**

Live workflows are stored in SQLite database inside n8n container:
- Location: `/home/node/.n8n/database.sqlite` inside n8n container
- Table: `workflow_entity`
- Backup files at `/root/local-ai-packaged/n8n/backup/workflows/` may be outdated

**To access live workflow data:**
```bash
# Copy database from container
docker cp n8n:/home/node/.n8n/database.sqlite /tmp/n8n.db

# List all workflows
sqlite3 /tmp/n8n.db "SELECT id, name, active FROM workflow_entity;"

# Export specific workflow nodes
sqlite3 /tmp/n8n.db "SELECT nodes FROM workflow_entity WHERE id='WORKFLOW_ID';" > /tmp/workflow.json

# Parse with jq
cat /tmp/workflow.json | jq -r '.[] | {name: .name, type: .type}'
```

**Key Workflows:**
- Main RAG: `zwRjhxpdTGh10WGE` - "LeadingAI RAG AI Agent V5 - Multi-Tenant"
- Test RAG: `2kfCsaB87v58j9zE` - "Test RAG Agent - Multi-Tenant"

## CRITICAL: n8n Database Backup & Modification Rules

**⚠️ NEVER modify the n8n SQLite database directly!**

**Mandatory rules before ANY database operation:**

1. **DO NOT copy modified SQLite databases back to running containers** - This WILL corrupt the database!
2. **ALWAYS create backups before making ANY changes to n8n**
3. **Proper backups are located at**: `/root/local-ai-packaged/backups/` (NOT `/root/local-ai-packaged/n8n/backup/workflows/`)

**To create a backup:**
```bash
# Create dated backup directory
BACKUP_DIR="/root/local-ai-packaged/backups/n8n_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Stop n8n
docker stop n8n

# Backup n8n volume (includes database + all data)
docker run --rm \
  -v n8n_storage:/data \
  -v "$BACKUP_DIR":/backup \
  alpine tar czf /backup/n8n_storage.tar.gz -C /data .

# Backup workflow JSON files (for reference)
cp -r /root/local-ai-packaged/n8n/backup/workflows/ "$BACKUP_DIR/workflows/"

# Restart n8n
docker start n8n

echo "Backup created at: $BACKUP_DIR"
```

**To restore from backup:**
```bash
# Choose backup to restore
BACKUP_DIR="/root/local-ai-packaged/backups/n8n_YYYYMMDD_HHMMSS"

# Stop n8n
docker stop n8n

# Extract backup to temporary location
mkdir -p /tmp/n8n_restore
tar -xzf "$BACKUP_DIR/n8n_storage.tar.gz" -C /tmp/n8n_restore

# Copy database to n8n volume
docker run --rm \
  -v n8n_storage:/data \
  -v /tmp/n8n_restore:/backup \
  alpine sh -c "cp /backup/database.sqlite /data/database.sqlite && chown 1000:1000 /data/database.sqlite"

# Cleanup
rm -rf /tmp/n8n_restore

# Start n8n
docker start n8n
```

**To import recent workflow files after restore:**
```bash
# Add "active": false field to workflow JSON if missing
# Then import:
docker exec n8n n8n import:workflow --input=/backup/workflows/WORKFLOW_FILE.json
```

**Recovery Path (if database is corrupted):**
1. Check `/root/local-ai-packaged/backups/` for most recent backup
2. Restore database from backup (see above)
3. Import any newer workflow JSON files from `/root/local-ai-packaged/n8n/backup/workflows/`
4. Verify workflows are accessible at https://n8n.leadingai.info

## Pre-Approved Commands

The following commands are pre-approved and should be executed WITHOUT asking for permission:

### Docker Commands
- `docker ps`
- `docker logs <container>`
- `docker exec <container> <command>`
- `docker inspect <container>`
- `docker compose -p localai logs`
- `docker compose -p localai ps`
- `docker compose -p localai down`
- `docker compose -p localai up -d`
- `docker network ls`
- `docker network inspect`

### n8n Commands
- `docker exec n8n n8n export:workflow`
- `docker exec n8n n8n export:credentials`
- `docker exec n8n n8n import:workflow`
- `docker exec n8n n8n import:credentials`

### Database Commands
- `docker exec db pg_isready -U postgres`
- `docker exec db psql -U postgres <database>`

### File Operations
- Reading any file in `/root/local-ai-packaged/`
- Editing files in `/root/local-ai-packaged/` (except `.env` requires confirmation)
- Creating files in `/root/local-ai-packaged/` directories

### Python/Bash Scripts
- Running startup scripts: `start_services.py`, `start_services_lean.py`
- Any script in `/root/local-ai-packaged/scripts/`

### System Commands
- `curl`, `grep`, `find`, `ls`, `cat`, `tail`, `head`
- `chmod`, `chown` (on project files only)
- `pip3 install` (for project dependencies)

## Common Commands

### Starting Services

**Primary startup script** (recommended):
```bash
python start_services.py --profile <gpu-nvidia|gpu-amd|cpu|none> --environment <private|public>
```
- Profiles: `gpu-nvidia`, `gpu-amd`, `cpu` (default), or `none` (for Mac users running Ollama locally)
- Environments: `private` (default, all ports accessible) or `public` (only ports 80/443 exposed)

**Lean startup script** (n8n + Supabase only):
```bash
python start_services_lean.py [--skip-supabase]
```
- Located at `/root/local-ai-packaged/start_services_lean.py`
- Includes better error handling and validation
- Use `--skip-supabase` to only restart n8n

**SQLite-based n8n** (minimal setup):
```bash
./start_n8n_sqlite.sh
```

### Docker Management

**Stop all services**:
```bash
docker compose -p localai -f docker-compose.yml --profile <profile> down
```

**Pull latest container versions**:
```bash
docker compose -p localai -f docker-compose.yml --profile <profile> pull
```

**View logs**:
```bash
docker logs n8n          # n8n logs
docker logs db           # Supabase Postgres logs
docker compose -p localai logs -f  # All services
```

**Check running containers**:
```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

### Supabase Management

The Supabase stack is managed separately but uses the same Docker project name (`localai`):

```bash
# Located in supabase/docker/
cd supabase/docker

# Reset Supabase (WARNING: deletes all data)
./reset.sh
```

## Architecture

### Service Stack

The system uses **two Docker Compose files** managed under a single project name (`localai`):

1. **Main stack** (`docker-compose.yml`): n8n, Neo4j
2. **Supabase stack** (`supabase/docker/docker-compose.yml`): Database, Auth, Storage, Realtime, etc.

Both stacks share the `localai_default` Docker network for inter-service communication.

### Key Services & Internal Networking

Services communicate via Docker internal hostnames:

- **n8n**: `http://localhost:5678` (external), `n8n:5678` (internal)
- **Supabase Postgres**: Host is `db` (NOT `localhost`), port `5432`
- **Supabase Kong (API Gateway)**: `kong:8000`
- **Ollama**: `http://ollama:11434` (or `http://host.docker.internal:11434` on Mac running locally)
- **Qdrant**: `http://qdrant:6333`
- **Neo4j**: `neo4j:7687` (bolt), `neo4j:7474` (browser)
- **SearXNG**: `http://searxng:8080`

### Startup Sequence

The `start_services.py` script orchestrates startup in this order:

1. **Clone/update Supabase repo** (sparse checkout of `/docker` directory only)
2. **Generate SearXNG secret key** (if first run)
3. **Stop existing containers** (both stacks)
4. **Start Supabase** (docker-compose up on supabase stack)
5. **Wait 10 seconds** for Supabase initialization
6. **Start main services** (docker-compose up on main stack)

### Environment Configuration

All secrets are managed in a **single `.env` file** at project root:

- **Required**: N8N keys, Supabase secrets, Neo4j auth, Langfuse credentials
- **Production only**: Caddy hostname variables for TLS/SSL

The startup scripts copy `.env` to `supabase/docker/.env` automatically.

### Volume Persistence

- **n8n data**: External volume `n8n_storage` (must be created before first run)
- **Shared files**: `./shared` directory mounted to `/data/shared` in n8n
- **Backups**: `./n8n/backup` for credentials/workflows
- **Workflows**: `./workflow-registry` (read-only) for template workflows
- **Neo4j data**: `./neo4j/data`, `./neo4j/logs`
- **Supabase data**: `./supabase/docker/volumes/`

## Important Notes

### Supabase Connection from n8n

When configuring Postgres credentials in n8n:
- **Host**: Must be `db` (the Docker service name), NOT `localhost` or `supabase`
- **Port**: `5432`
- **Database**: From `.env` (usually `postgres`)
- **Username/Password**: From `.env` (`POSTGRES_PASSWORD`)

### SearXNG First Run

SearXNG requires special handling on first run:
- The `start_services.py` script automatically handles the `cap_drop: - ALL` directive
- Temporarily removes it for first run (to allow uwsgi.ini creation)
- Re-enables it after successful initialization

If SearXNG keeps restarting: `chmod 755 searxng`

### Mac/Apple Silicon Specifics

If running Ollama locally on Mac (not in Docker):
1. Use `--profile none` when starting
2. Update n8n environment to use `OLLAMA_HOST=host.docker.internal:11434`
3. In n8n credentials, set Ollama base URL to `http://host.docker.internal:11434/`

### Special Characters in Postgres Password

Avoid `@` symbol and other special characters in `POSTGRES_PASSWORD` as they can cause connection issues with the Kong API gateway.

## Development Workflows

### Testing n8n Workflows

1. Access n8n at https://n8n.leadingai.info
2. Shared folder accessible at `/data/shared` within n8n container

### RAG Document Management & Testing

**Quick Start - Add Test Documents:**

Use the v3 script (adds to BOTH required tables):

```bash
# Add document for Greg (CoCreators tenant)
/root/local-ai-packaged/n8n/scripts/add_test_document_v3.sh \
  "mk3029839" \
  "gwasmuth@gmail.com" \
  "CoCreators AI Strategy" \
  "This document contains information about CoCreators AI implementation strategy and best practices."

# Add document for Joanna (IOM tenant)
/root/local-ai-packaged/n8n/scripts/add_test_document_v3.sh \
  "test-tenant-001" \
  "jowasmuth@gmail.com" \
  "IOM Project Plan" \
  "This document outlines the IOM project roadmap and deliverables for Q4 2025."
```

**CRITICAL - Database Location:**

The RAG system uses the LOCAL Supabase Postgres database (`supabase-db` container):
- db.leadingai.info is just the public URL that routes through Kong API gateway
- The actual database container is `supabase-db`
- n8n connects directly to `supabase-db` container via Docker network

**CRITICAL - Database Architecture:**

The n8n RAG workflow uses **TWO TABLES**:

1. **`document_metadata`** - Source document tracking
   - View at: https://db.leadingai.info/project/default/editor/19838
   - Purpose: Tracks original documents, titles, URLs, processing status
   - One row per document/file
   - Used by: n8n tools to list available documents

2. **`documents_pg`** - Vector chunks for RAG
   - View at: https://db.leadingai.info/project/default/editor/74889
   - Purpose: Stores CHUNKS of documents with embeddings for RAG search
   - Multiple rows per document (one per chunk)
   - Schema:
     - `id` - Auto-increment integer (chunk ID)
     - `content`/`text` - Chunk text
     - `embedding` - vector(1536) for similarity search
     - `metadata` - JSONB with title, file_id linking back to document_metadata
     - `tenant_id` - Multi-tenant isolation
     - `user_id` - Document owner

**The Workflow Handles Both Tables Automatically:**
- When you upload via Google Drive, the workflow:
  1. Adds source document to `document_metadata`
  2. Chunks the document
  3. Generates embeddings for each chunk
  4. Stores chunks in `documents_pg`

**DO NOT manually add to these tables - let the workflow handle it!**

**CRITICAL**: Chunks WITHOUT embeddings in `documents_pg` CANNOT be retrieved by RAG queries!

**Adding Documents for User-Specific Testing:**

**RECOMMENDED: Upload via Google Drive**

The workflow is NOW FIXED to automatically handle tenant isolation for Google Drive uploads!

1. **Upload file to the Docs_for_RAG folder** in Google Drive
   - Folder ID: `18q2yQ-vWjk8I9Isd7Oz1F3h-FrNxkvtF`
   - Folder is mapped to: tenant `mk3029839`, user `gwasmuth@gmail.com`
   - The workflow will automatically:
     - Extract tenant context from folder mapping
     - Process the document
     - Create chunks
     - Generate embeddings
     - Store in both `document_metadata` and `documents_pg`

2. **Add more folder→tenant mappings**:
   - Go to https://n8n.leadingai.info/workflow/zwRjhxpdTGh10WGE
   - Find the "Map Folder to Tenant" node
   - Edit the `folderMap` to add more folder mappings:
   ```javascript
   const folderMap = {
     'FOLDER_ID_1': {
       tenant_id: 'mk3029839',
       user_id: 'user-uuid',
       email: 'user@example.com',
       role: 'admin'
     },
     'FOLDER_ID_2': {
       tenant_id: 'another-tenant',
       user_id: 'other-user-uuid',
       email: 'other@example.com',
       role: 'viewer'
     }
   };
   ```

**ALTERNATIVE: Manual Script** (for testing only, doesn't generate embeddings):
```bash
# This adds raw text but workflow won't process it automatically
/root/local-ai-packaged/n8n/scripts/add_test_document_v3.sh <tenant_id> <user_email> <title> <content>
```
⚠️ This script adds to both tables but does NOT generate embeddings, so documents won't be searchable!

**Testing Tenant Isolation:**

1. **Create test users** (if not already exists):
   ```bash
   docker exec supabase-db psql -U postgres postgres < /root/local-ai-packaged/n8n/scripts/create_test_users.sql
   ```

2. **Add tenant-specific documents** using the script above

3. **Generate JWT tokens**:
   ```bash
   python3 /root/local-ai-packaged/n8n/scripts/generate_jwt_tokens.py
   ```

4. **Set tokens in n8n** at https://n8n.leadingai.info:
   - Go to Settings → Variables
   - Add: `GREG_JWT_TOKEN` (CoCreators tenant: mk3029839)
   - Add: `JOANNA_JWT_TOKEN` (IOM tenant: test-tenant-001)

5. **Run the test workflow**: "Test RAG Agent - Multi-Tenant" at https://n8n.leadingai.info
   - Each user should only retrieve documents from their own tenant
   - Greg should see only CoCreators documents
   - Joanna should see only IOM documents

**Document Storage Locations:**
- **`document_metadata` table**: Document tracking, titles, metadata
  - View at: https://db.leadingai.info/project/default/editor/19838
  - Used by n8n tools for listing documents
- **`documents_pg` table**: RAG content + embeddings
  - View at: https://db.leadingai.info/project/default/editor/74889
  - Contains: content, embeddings (vector), metadata (JSONB), tenant_id, user_id
  - Uses pgvector extension for similarity search
  - Indexed on tenant_id for multi-tenant isolation
- **Files**: Supabase Storage buckets (for file uploads)
- **Shared Files**: `/root/local-ai-packaged/shared/` (accessible at `/data/shared` in n8n)

**Verify Documents in BOTH Tables:**
```bash
# Check document_metadata
docker exec supabase-db psql -U postgres postgres -c "
  SELECT id, tenant_id, title, processing_status
  FROM document_metadata
  WHERE tenant_id IN ('mk3029839', 'test-tenant-001')
  ORDER BY created_at DESC;"

# Check documents_pg (for RAG)
docker exec supabase-db psql -U postgres postgres -c "
  SELECT id, tenant_id, metadata->>'title' as title,
         LEFT(content, 60) as preview,
         embedding IS NULL as needs_embedding
  FROM documents_pg
  WHERE tenant_id IN ('mk3029839', 'test-tenant-001')
  ORDER BY id DESC;"
```

**Known Issues:**
See `/root/local-ai-packaged/WORKFLOW_ISSUES_AND_FIXES.md` for detailed workflow issues including:
- Google Drive trigger missing tenant context extraction
- Test workflow webhook URL mismatch
- Comparison of V5 vs V5 Fixed workflows

### Importing/Exporting Workflows

**Export**:
```bash
docker exec n8n n8n export:workflow --output=/backup/workflows --separate
docker exec n8n n8n export:credentials --output=/backup/credentials --separate
```

**Import** (uses special profile):
```bash
docker compose -p localai --profile import -f docker-compose.yml run n8n-import
```

### Cloud Deployment

For public/production deployment:

1. **Firewall setup**:
   ```bash
   ufw enable
   ufw allow 80 && ufw allow 443
   ufw reload
   ```
   ⚠️ **Note**: UFW does not block Docker-published ports. All traffic should route through Caddy on 443.

2. **Use public environment**:
   ```bash
   python start_services.py --profile gpu-nvidia --environment public
   ```

3. **Configure DNS**: Set A records for subdomains in `.env` to point to server IP

4. **Set Caddy environment variables** in `.env`:
   - `N8N_HOSTNAME`, `WEBUI_HOSTNAME`, etc.
   - `LETSENCRYPT_EMAIL`

## Troubleshooting

### Database Connection Issues

1. **Check if DB is ready**:
   ```bash
   docker exec db pg_isready -U postgres
   ```

2. **Check Kong API logs** (if Supabase unavailable):
   ```bash
   docker logs supabase-kong
   ```

3. **Common fixes**:
   - Ensure no `@` in `POSTGRES_PASSWORD`
   - Verify host is `db`, not `localhost`
   - Wait 10+ seconds after Supabase starts

### Supabase Pooler Restarting

See: https://github.com/supabase/supabase/issues/30210#issuecomment-2456955578

### Supabase Analytics Failure After Password Change

Delete folder: `supabase/docker/volumes/db/data`

### Docker Compose Not Found (Cloud Instances)

Some cloud Ubuntu images lack docker compose:
```bash
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo mkdir -p /usr/local/lib/docker/cli-plugins
sudo ln -s /usr/local/bin/docker-compose /usr/local/lib/docker/cli-plugins/docker-compose
```

## File Locations

- **Project root**: `/root/local-ai-packaged`
- **Main compose file**: `docker-compose.yml`
- **Supabase compose**: `supabase/docker/docker-compose.yml`
- **Environment file**: `.env` (copy from `.env.example`)
- **n8n workflows**: `n8n/backup/workflows/`
- **Tool workflows**: `n8n-tool-workflows/`
- **Registry workflows**: `workflow-registry/`
- **Startup scripts**: `start_services.py`, `start_services_lean.py`
