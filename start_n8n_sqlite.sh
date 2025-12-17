#!/bin/bash
set -e

echo "=========================================="
echo "Starting n8n with SQLite (your existing data)"
echo "=========================================="
echo ""

# Stop n8n if running
echo "Stopping n8n container..."
docker stop n8n 2>/dev/null || echo "n8n not running"
docker rm n8n 2>/dev/null || echo "n8n container removed"

echo ""
echo "Starting n8n with SQLite database (your existing workflows)..."
cd /root/local-ai-packaged && docker compose -p localai -f docker-compose.yml up -d n8n --no-deps

echo ""
echo "Waiting for n8n to start..."
sleep 10

echo ""
echo "✅ n8n started! Checking logs..."
docker logs n8n --tail=50

echo ""
echo "=========================================="
echo "Access n8n at:"
echo "  - https://n8n.leadingai.info"
echo "  - http://localhost:5678"
echo "=========================================="
