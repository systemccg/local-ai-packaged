#!/bin/bash
# Service Management Aliases for start_services_lean.py
# Add to ~/.bashrc or source this file directly

# Base directory
export LAI_DIR="/root/local-ai-packaged"

# Quick aliases for common operations
alias lai-list="python3 $LAI_DIR/start_services_lean.py --list"
alias lai-help="python3 $LAI_DIR/start_services_lean.py --help"

# Start everything
alias lai-all="python3 $LAI_DIR/start_services_lean.py"

# Start only Supabase
alias lai-supabase="python3 $LAI_DIR/start_services_lean.py --only-supabase"

# Start main stack without Supabase
alias lai-main="python3 $LAI_DIR/start_services_lean.py --skip-supabase"

# Individual services (without Supabase)
alias lai-n8n="python3 $LAI_DIR/start_services_lean.py --skip-supabase --services n8n"
alias lai-neo4j="python3 $LAI_DIR/start_services_lean.py --skip-supabase --services neo4j"
alias lai-webui="python3 $LAI_DIR/start_services_lean.py --skip-supabase --services open-webui"

# Common combinations
alias lai-n8n-neo4j="python3 $LAI_DIR/start_services_lean.py --skip-supabase --services n8n neo4j"

# Status and logs
alias lai-status="docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | grep -E 'NAMES|n8n|neo4j|supabase|open-webui'"
alias lai-logs="docker compose -p localai logs -f"

# Stop all services
alias lai-stop="docker compose -p localai -f $LAI_DIR/docker-compose.yml down && docker compose -p localai -f $LAI_DIR/supabase/docker/docker-compose.yml down"

# Quick restart individual services
alias lai-restart-n8n="docker restart n8n"
alias lai-restart-neo4j="docker restart local-ai-packaged-neo4j-1"
alias lai-restart-supabase="docker compose -p localai -f $LAI_DIR/supabase/docker/docker-compose.yml restart"

echo "Local AI Package aliases loaded!"
echo "Usage:"
echo "  lai-list          - List available services"
echo "  lai-all           - Start everything"
echo "  lai-n8n           - Start only n8n"
echo "  lai-neo4j         - Start only Neo4j"
echo "  lai-supabase      - Start only Supabase"
echo "  lai-status        - Show running services"
echo "  lai-stop          - Stop all services"
echo ""
echo "For more: lai-help"
