# Server Migration - Quick Start Guide

**Last Updated**: 2025-11-10

This guide provides the fastest path to migrate your server. Read this first!

---

## Overview

Your migration has 3 simple steps:
1. **Export** data from current server (1 command)
2. **Transfer** files to new server (scp or your method)
3. **Restore** on new server (1 command)

---

## Step 1: Export Everything (Current Server)

```bash
cd /root/local-ai-packaged
./scripts/export_for_migration.sh
```

**What this does:**
- ✅ Exports all n8n workflows
- ✅ Dumps all databases (Supabase, n8n, Langfuse)
- ✅ Backs up all Docker volumes
- ✅ Copies all config files
- ✅ Creates encrypted secrets archive
- ✅ Generates checksums for verification

**Time**: 15-30 minutes depending on data size

**Output location**: `/root/migration_YYYYMMDD_HHMMSS/`

---

## Step 2: Transfer to New Server

### Option A: Direct Transfer (Fastest)

```bash
# From current server, transfer to new server
NEW_SERVER="user@new-server-ip"

# Transfer migration directory
scp -r /root/migration_YYYYMMDD_HHMMSS $NEW_SERVER:/root/

# Transfer secrets archive
scp /root/secrets_YYYYMMDD_HHMMSS.tar.gz $NEW_SERVER:/root/
```

### Option B: Two-Step Transfer (via local machine)

```bash
# 1. Download from current server
scp -r current-server:/root/migration_YYYYMMDD_HHMMSS ./
scp current-server:/root/secrets_YYYYMMDD_HHMMSS.tar.gz ./

# 2. Upload to new server
scp -r ./migration_YYYYMMDD_HHMMSS new-server:/root/
scp ./secrets_YYYYMMDD_HHMMSS.tar.gz new-server:/root/
```

### Option C: Cloud Storage (if servers can't connect directly)

```bash
# Upload to cloud
aws s3 cp /root/migration_YYYYMMDD_HHMMSS s3://your-bucket/ --recursive
aws s3 cp /root/secrets_YYYYMMDD_HHMMSS.tar.gz s3://your-bucket/

# Download on new server
aws s3 cp s3://your-bucket/migration_YYYYMMDD_HHMMSS /root/ --recursive
aws s3 cp s3://your-bucket/secrets_YYYYMMDD_HHMMSS.tar.gz /root/
```

---

## Step 3: Restore on New Server

### 3.1 Prepare New Server

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install git
sudo apt install git -y
```

### 3.2 Clone Repository

```bash
cd /root
git clone https://github.com/coleam00/local-ai-packaged.git
cd local-ai-packaged
```

### 3.3 Restore Secrets

```bash
# Extract secrets
cd /root
tar xzf secrets_YYYYMMDD_HHMMSS.tar.gz -C /tmp/

# Copy to project
cp /tmp/env_main /root/local-ai-packaged/.env
cp /tmp/env_supabase /root/local-ai-packaged/supabase/docker/.env

# Verify
ls -la /root/local-ai-packaged/.env
```

### 3.4 Run Restoration Script

```bash
cd /root/local-ai-packaged
./scripts/restore_from_migration.sh /root/migration_YYYYMMDD_HHMMSS
```

**What this does:**
- ✅ Verifies checksums
- ✅ Starts all Docker containers
- ✅ Restores all databases
- ✅ Imports all workflows
- ✅ Verifies everything works

**Time**: 15-30 minutes

---

## Step 4: Verify Migration

### Check Services

```bash
# All containers running?
docker ps

# n8n working?
curl https://n8n.leadingai.info

# Check workflows
docker exec n8n n8n list:workflow

# Supabase working?
docker exec supabase-db psql -U postgres -c "SELECT count(*) FROM auth.users;"
```

### Access Web Interfaces

- **n8n**: https://n8n.leadingai.info
- **Supabase Studio**: https://db.leadingai.info

---

## Troubleshooting

### Services not starting?

```bash
# Check logs
docker-compose logs

# Restart specific service
docker-compose restart n8n

# Full restart
docker-compose down && docker-compose up -d
```

### Database restore failed?

```bash
# Check if databases are empty
docker exec supabase-db psql -U postgres -c "\l"

# Manual restore
gunzip -c /root/migration_*/databases/supabase_full_dump.sql.gz | \
    docker exec -i supabase-db psql -U postgres
```

### Workflows not showing?

```bash
# Check n8n database
docker exec n8n sqlite3 /home/node/.n8n/database.sqlite "SELECT count(*) FROM workflow_entity;"

# Re-import workflows
docker exec -i n8n n8n import:workflow --input=/dev/stdin < \
    /root/migration_*/workflows/all_workflows.json
```

---

## GitHub Setup (Optional but Recommended)

Keep your configs in sync:

```bash
cd /root/local-ai-packaged

# Check current status
git status

# Create .gitignore for secrets
cat > .gitignore << 'EOF'
.env
.env.*
!.env.example
secrets/
*.sql
*.sql.gz
*.sqlite
*.tar.gz
node_modules/
volumes/
EOF

# Stage files (configs only, no secrets!)
git add docker-compose.yml
git add Caddyfile
git add scripts/
git add CLAUDE.md
git add README.md
git add n8n/docs/
git add MIGRATION_*.md

# Commit
git commit -m "Migration preparation - configs and docs"

# Push to your fork
git remote set-url origin https://github.com/YOUR_USERNAME/local-ai-packaged.git
git push
```

---

## Complete Migration Checklist

### Pre-Migration
- [ ] Read this guide completely
- [ ] Verify current server is healthy
- [ ] Note all running services
- [ ] Have new server IP/access ready

### Export Phase (Current Server)
- [ ] Run export script: `./scripts/export_for_migration.sh`
- [ ] Verify export completed successfully
- [ ] Note migration directory location
- [ ] Verify secrets archive created

### Transfer Phase
- [ ] Transfer migration directory to new server
- [ ] Transfer secrets archive separately
- [ ] Verify file sizes match (checksums)

### Restore Phase (New Server)
- [ ] Install Docker
- [ ] Clone repository
- [ ] Extract and copy secrets
- [ ] Run restoration script
- [ ] Verify all services running

### Verification Phase
- [ ] Access n8n web interface
- [ ] Access Supabase Studio
- [ ] Test workflows
- [ ] Verify database data
- [ ] Check logs for errors

### Post-Migration
- [ ] Update DNS (if needed)
- [ ] Test all integrations
- [ ] Verify SSL certificates
- [ ] Keep old server running for 1 week (backup)
- [ ] Document any issues

---

## Time Estimates

| Task | Time |
|------|------|
| Export | 15-30 min |
| Transfer | 10-60 min (depends on bandwidth) |
| Restore | 15-30 min |
| Verification | 10-15 min |
| **Total** | **1-2 hours** |

---

## Support

If you encounter issues:

1. Check logs: `docker-compose logs -f`
2. Review `/root/SERVER_MIGRATION_PLAN.md` for detailed info
3. Verify checksums: `cd /root/migration_* && sha256sum -c checksums.txt`
4. Old server still has all data - you can retry

---

## Quick Reference Commands

```bash
# Export on current server
cd /root/local-ai-packaged && ./scripts/export_for_migration.sh

# Transfer to new server
scp -r /root/migration_* user@new-server:/root/

# Restore on new server
cd /root/local-ai-packaged && ./scripts/restore_from_migration.sh /root/migration_*

# Verify
docker ps
docker exec n8n n8n list:workflow
```

---

**That's it!** Three commands and your server is migrated. 🚀
