# Start Services Guide - Selective Startup

## Overview

The enhanced `start_services_lean.py` script provides flexible, selective service startup capabilities for your Traefik-based environment. Start exactly what you need, when you need it.

## Quick Reference

### List Available Services
```bash
python3 start_services_lean.py --list
```

### Common Usage Patterns

#### Start Everything (Default)
```bash
python3 start_services_lean.py
```
Starts: n8n, neo4j, open-webui, Supabase stack

#### Start Only n8n (No Supabase)
```bash
python3 start_services_lean.py --skip-supabase
```
Starts: n8n, neo4j, open-webui (no Supabase)

#### Start Only Neo4j
```bash
python3 start_services_lean.py --skip-supabase --services neo4j
```
Starts: Only Neo4j container

#### Start Only Supabase
```bash
python3 start_services_lean.py --only-supabase
```
Starts: Full Supabase stack (db, auth, storage, kong, etc.)

#### Start Multiple Specific Services
```bash
python3 start_services_lean.py --skip-supabase --services n8n neo4j
```
Starts: n8n and Neo4j (no open-webui, no Supabase)

#### Add Service Without Stopping Others
```bash
python3 start_services_lean.py --skip-supabase --services open-webui --no-stop
```
Starts: open-webui without stopping running containers

## Available Services

### Main Stack
- **n8n**: Workflow automation platform (https://n8n.leadingai.info)
- **neo4j**: Graph database for knowledge graphs (https://neo4j.leadingai.info)
- **open-webui**: Chat interface for AI models (https://webui.leadingai.info)

### Supabase Stack
- Full backend-as-a-service (https://db.leadingai.info)
  - PostgreSQL database
  - Authentication
  - Storage
  - Realtime
  - Kong API Gateway

## Command-Line Options

| Option | Description |
|--------|-------------|
| `--skip-supabase` | Skip Supabase startup (only start main services) |
| `--only-supabase` | Start only Supabase (skip main services) |
| `--services SERVICE [SERVICE ...]` | Start specific services: n8n, neo4j, open-webui |
| `--list` | List all available services and exit |
| `--no-stop` | Skip stopping existing containers (useful for adding services) |
| `--help` | Show help message |

## Examples by Use Case

### Development Workflow

**Morning startup - everything:**
```bash
python3 start_services_lean.py
```

**Just need Neo4j for graph work:**
```bash
python3 start_services_lean.py --skip-supabase --services neo4j
```

**Testing n8n workflows without DB:**
```bash
python3 start_services_lean.py --skip-supabase --services n8n
```

### Resource Management

**Minimal footprint - just one service:**
```bash
python3 start_services_lean.py --skip-supabase --services neo4j
```

**Database work only:**
```bash
python3 start_services_lean.py --only-supabase
```

### Troubleshooting

**Restart single service:**
```bash
# First stop it
docker stop neo4j

# Start it back up
python3 start_services_lean.py --skip-supabase --services neo4j --no-stop
```

**Check what's running:**
```bash
docker ps --format "table {{.Names}}\t{{.Status}}"
```

## Technical Details

### Architecture
- Uses Docker Compose with project name: `localai`
- Two separate compose files:
  - Main: `/root/local-ai-packaged/docker-compose.yml`
  - Supabase: `/root/local-ai-packaged/supabase/docker/docker-compose.yml`
- All services share the Traefik network for routing

### Environment Configuration
- Environment variables from: `/root/local-ai-packaged/.env`
- Auto-copied to Supabase: `/root/local-ai-packaged/supabase/docker/.env`

### Database Readiness
When starting Supabase, the script:
1. Waits up to 60 seconds for PostgreSQL to be ready
2. Uses `pg_isready` to verify connection
3. Adds 5-second buffer for other Supabase services to stabilize

## Comparison with start_services.py

| Feature | start_services.py | start_services_lean.py |
|---------|------------------|------------------------|
| GPU profiles | ✅ Yes (nvidia, amd, cpu) | ❌ No |
| SearXNG setup | ✅ Yes | ❌ No |
| Ollama management | ✅ Yes | ❌ No |
| Public/private env | ✅ Yes | ❌ No |
| Selective services | ❌ No | ✅ Yes |
| Service-by-service | ❌ No | ✅ Yes |
| Error handling | Basic | ✅ Enhanced |
| Validation | Basic | ✅ Pre-flight checks |

**Use `start_services_lean.py` when:**
- You want selective service startup
- You're working with Traefik (not Caddy)
- You need fine-grained control
- You want faster, targeted restarts

**Use `start_services.py` when:**
- You need GPU support (nvidia/amd)
- You need SearXNG
- You need Ollama auto-pull
- You're deploying to production with Caddy

## Troubleshooting

### Service won't start
```bash
# Check validation
docker compose -p localai -f /root/local-ai-packaged/docker-compose.yml config

# Check logs
docker logs <service-name>
```

### Database connection issues
```bash
# Verify database is ready
docker exec supabase-db pg_isready -U postgres

# Check Supabase logs
docker logs supabase-db
docker logs supabase-kong
```

### Traefik routing issues
```bash
# Check Traefik dashboard
https://traefik.leadingai.info

# Verify container labels
docker inspect <service-name> | grep traefik
```

## Notes

- The script uses `python3` (not `python`)
- All URLs use HTTPS via Traefik with Let's Encrypt
- Services auto-restart unless stopped with `docker stop`
- Use `--no-stop` to add services without disrupting running ones

## Quick Copy-Paste Commands

```bash
# List services
python3 /root/local-ai-packaged/start_services_lean.py --list

# Start just Neo4j
python3 /root/local-ai-packaged/start_services_lean.py --skip-supabase --services neo4j

# Start just n8n
python3 /root/local-ai-packaged/start_services_lean.py --skip-supabase --services n8n

# Start everything
python3 /root/local-ai-packaged/start_services_lean.py

# Start only Supabase
python3 /root/local-ai-packaged/start_services_lean.py --only-supabase
```
