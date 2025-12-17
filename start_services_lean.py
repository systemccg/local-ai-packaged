#!/usr/bin/env python3
"""
start_services_lean.py - Enhanced with selective service startup

Usage examples:
  # Start everything (n8n + Supabase)
  python start_services_lean.py

  # Start only n8n (skip Supabase)
  python start_services_lean.py --skip-supabase

  # Start only specific services from main stack
  python start_services_lean.py --services n8n neo4j

  # Start only Neo4j (no n8n, no Supabase)
  python start_services_lean.py --skip-supabase --services neo4j

  # Start only Supabase stack
  python start_services_lean.py --only-supabase

  # List available services
  python start_services_lean.py --list
"""

import os
import subprocess
import shutil
import time
import argparse
from datetime import datetime

# Define absolute paths
PROJECT_DIR = '/root/local-ai-packaged'
SUPABASE_DOCKER_DIR = os.path.join(PROJECT_DIR, 'supabase', 'docker')
MAIN_COMPOSE_FILE = os.path.join(PROJECT_DIR, 'docker-compose.yml')
SUPABASE_COMPOSE_FILE = os.path.join(SUPABASE_DOCKER_DIR, 'docker-compose.yml')
ROOT_ENV_FILE = os.path.join(PROJECT_DIR, '.env')
SUPABASE_ENV_FILE = os.path.join(SUPABASE_DOCKER_DIR, '.env')

# Available services in main docker-compose.yml
AVAILABLE_SERVICES = {
    'n8n': 'Workflow automation platform',
    'neo4j': 'Graph database for knowledge graphs',
    'open-webui': 'Chat interface for AI models',
}

def run_command(cmd, cwd=None, check=True, show_output=True):
    """Run a shell command with better error handling."""
    print("Running:", " ".join(cmd))
    result = subprocess.run(cmd, cwd=cwd, check=False, capture_output=True, text=True)

    if result.returncode != 0:
        print(f"❌ Command failed with exit code {result.returncode}")
        if result.stdout and show_output:
            print(f"STDOUT: {result.stdout}")
        if result.stderr and show_output:
            print(f"STDERR: {result.stderr}")
        if check:
            raise subprocess.CalledProcessError(result.returncode, cmd, result.stdout, result.stderr)
    else:
        if result.stdout and show_output:
            print(result.stdout)

    return result

def clone_supabase_repo():
    """Clone the Supabase repository using sparse checkout if not already present."""
    supabase_dir = os.path.join(PROJECT_DIR, 'supabase')
    if not os.path.exists(supabase_dir):
        print("Cloning the Supabase repository...")
        run_command([
            "git", "clone", "--filter=blob:none", "--no-checkout",
            "https://github.com/supabase/supabase.git", supabase_dir
        ])
        run_command(["git", "sparse-checkout", "init", "--cone"], cwd=supabase_dir)
        run_command(["git", "sparse-checkout", "set", "docker"], cwd=supabase_dir)
        run_command(["git", "checkout", "master"], cwd=supabase_dir)
    else:
        print("Supabase repository already exists, assuming it is up to date.")

def prepare_supabase_env():
    """Copy .env to .env in supabase/docker."""
    if not os.path.exists(SUPABASE_ENV_FILE) or os.path.getmtime(ROOT_ENV_FILE) > os.path.getmtime(SUPABASE_ENV_FILE):
        print("Copying .env from root to supabase/docker/.env...")
        shutil.copyfile(ROOT_ENV_FILE, SUPABASE_ENV_FILE)
    else:
        print("Supabase .env file is already up to date.")

def patch_supabase_compose():
    """Patch the Supabase docker-compose.yml to add traefik network configuration."""
    print("Patching Supabase docker-compose.yml for Traefik integration...")

    with open(SUPABASE_COMPOSE_FILE, 'r') as f:
        content = f.read()

    # Check if already patched
    if 'networks:' in content and 'traefik:' in content and 'external: true' in content:
        print("Supabase docker-compose.yml already patched.")
        return

    # Add networks to kong service if not present
    kong_section_found = False
    lines = content.split('\n')
    new_lines = []
    i = 0

    while i < len(lines):
        line = lines[i]
        new_lines.append(line)

        # Find kong service and add networks after ports
        if '  kong:' in line:
            kong_section_found = True
        elif kong_section_found and '    ports:' in line:
            # Skip to end of ports section
            i += 1
            while i < len(lines) and lines[i].startswith('      -'):
                new_lines.append(lines[i])
                i += 1
            # Add networks section
            new_lines.append('    networks:')
            new_lines.append('      - default')
            new_lines.append('      - traefik')
            kong_section_found = False
            continue

        i += 1

    # Add networks definition at the end if not present
    if 'networks:' not in content or 'traefik:' not in content:
        # Find volumes section and add networks after it
        content = '\n'.join(new_lines)
        if 'volumes:\n  db-config:' in content:
            content = content.replace(
                'volumes:\n  db-config:',
                'volumes:\n  db-config:\n\nnetworks:\n  traefik:\n    external: true'
            )

    # Write patched content
    with open(SUPABASE_COMPOSE_FILE, 'w') as f:
        f.write(content)

    print("✅ Supabase docker-compose.yml patched successfully.")

def check_db_ready():
    """Check if the database is ready to accept connections."""
    result = run_command([
        "docker", "exec", "supabase-db",
        "pg_isready", "-U", "postgres"
    ], check=False, show_output=False)
    return result.returncode == 0

def stop_existing_containers(services=None):
    """
    Stop existing containers.

    Args:
        services: List of specific services to stop, or None to stop all
    """
    print("\n" + "="*60)
    if services:
        print(f"Stopping services: {', '.join(services)}...")
    else:
        print("Stopping existing containers...")
    print("="*60)

    # Stop specific services from main stack or all main services
    cmd = [
        "docker", "compose", "-p", "localai",
        "-f", MAIN_COMPOSE_FILE,
        "down", "--remove-orphans", "-t", "1"
    ]
    if services:
        # When specific services are provided, stop only those
        cmd = [
            "docker", "compose", "-p", "localai",
            "-f", MAIN_COMPOSE_FILE,
            "stop", "-t", "1"
        ] + services

    run_command(cmd, check=False)

    # Stop Supabase services if not selective mode
    if not services:
        run_command([
            "docker", "compose", "-p", "localai",
            "-f", SUPABASE_COMPOSE_FILE,
            "down", "--remove-orphans", "-t", "1"
        ], check=False)

def start_supabase():
    """Start the Supabase services."""
    print("\n" + "="*60)
    print("Starting Supabase services...")
    print("="*60)
    cmd = [
        "docker", "compose", "-p", "localai",
        "-f", SUPABASE_COMPOSE_FILE,
        "up", "-d", "--remove-orphans"
    ]
    run_command(cmd, cwd=PROJECT_DIR)

def start_services(services=None):
    """
    Start specific services or all services from main stack.

    Args:
        services: List of specific service names to start, or None for all
    """
    print("\n" + "="*60)
    if services:
        print(f"Starting services: {', '.join(services)}...")
    else:
        print("Starting all main services...")
    print("="*60)

    # Validate the compose file first
    print("Validating docker-compose.yml...")
    validate_result = run_command([
        "docker", "compose", "-p", "localai",
        "-f", MAIN_COMPOSE_FILE,
        "config"
    ], check=False, show_output=False)

    if validate_result.returncode != 0:
        print("❌ docker-compose.yml validation failed!")
        print(validate_result.stderr)
        return False

    print("✅ docker-compose.yml is valid")

    # Build the command
    cmd = [
        "docker", "compose", "-p", "localai",
        "-f", MAIN_COMPOSE_FILE,
        "up", "-d", "--remove-orphans"
    ]

    # Add specific services if provided
    if services:
        cmd.extend(services)

    result = run_command(cmd, cwd=PROJECT_DIR, check=False)

    if result.returncode != 0:
        print(f"\n❌ Failed to start services!")
        return False

    return True

def list_services():
    """List all available services."""
    print("\n" + "="*60)
    print("Available Services")
    print("="*60)
    print("\nMain Stack Services:")
    for service, description in AVAILABLE_SERVICES.items():
        print(f"  • {service:15} - {description}")

    print("\nSupabase Stack:")
    print("  • supabase        - Full Supabase stack (db, auth, storage, etc.)")

    print("\n" + "="*60)
    print("Usage Examples:")
    print("="*60)
    print("\n  # Start everything")
    print("  python start_services_lean.py")
    print("\n  # Start only n8n (skip Supabase)")
    print("  python start_services_lean.py --skip-supabase")
    print("\n  # Start only Neo4j")
    print("  python start_services_lean.py --skip-supabase --services neo4j")
    print("\n  # Start n8n and Neo4j (skip Supabase)")
    print("  python start_services_lean.py --skip-supabase --services n8n neo4j")
    print("\n  # Start only Supabase")
    print("  python start_services_lean.py --only-supabase")
    print()

def main():
    """Main execution function."""
    parser = argparse.ArgumentParser(
        description='Manage services with selective startup capabilities',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  Start everything:
    python start_services_lean.py

  Start only n8n (skip Supabase):
    python start_services_lean.py --skip-supabase

  Start only Neo4j:
    python start_services_lean.py --skip-supabase --services neo4j

  Start only Supabase:
    python start_services_lean.py --only-supabase

  List available services:
    python start_services_lean.py --list
        """
    )

    parser.add_argument('--skip-supabase', action='store_true',
                       help='Skip Supabase startup (only start main services)')
    parser.add_argument('--only-supabase', action='store_true',
                       help='Start only Supabase (skip main services)')
    parser.add_argument('--services', nargs='+', metavar='SERVICE',
                       choices=list(AVAILABLE_SERVICES.keys()),
                       help=f'Specific services to start: {", ".join(AVAILABLE_SERVICES.keys())}')
    parser.add_argument('--list', action='store_true',
                       help='List all available services and exit')
    parser.add_argument('--no-stop', action='store_true',
                       help='Skip stopping existing containers (useful for adding services)')

    args = parser.parse_args()

    # Handle --list
    if args.list:
        list_services()
        return

    # Validate argument combinations
    if args.skip_supabase and args.only_supabase:
        print("❌ Error: Cannot use --skip-supabase and --only-supabase together")
        return

    # Prepare Supabase if needed
    if not args.skip_supabase and not args.only_supabase:
        clone_supabase_repo()
        prepare_supabase_env()
        patch_supabase_compose()
    elif args.only_supabase:
        clone_supabase_repo()
        prepare_supabase_env()
        patch_supabase_compose()

    # Stop existing containers (unless --no-stop)
    if not args.no_stop:
        stop_existing_containers(services=args.services)

    # Start Supabase if needed
    if args.only_supabase or (not args.skip_supabase):
        start_supabase()

        print("\n⏳ Waiting for database to be ready...")
        max_wait = 60  # Maximum 60 seconds
        waited = 0
        while waited < max_wait:
            if check_db_ready():
                print(f"✅ Database is ready (waited {waited} seconds)")
                break
            time.sleep(2)
            waited += 2
            if waited % 10 == 0:
                print(f"   Still waiting... ({waited}/{max_wait} seconds)")

        if waited >= max_wait:
            print("⚠️  Database didn't become ready in time, but continuing anyway...")

        # Extra buffer to ensure all Supabase services are stable
        print("⏳ Waiting for Supabase services to stabilize (5 more seconds)...")
        time.sleep(5)

    # Start main services if needed
    if not args.only_supabase:
        if not start_services(services=args.services):
            print("\n⚠️  Services failed to start. Check the errors above.")
            print("\nManual troubleshooting:")
            print("  docker compose -p localai -f docker-compose.yml config")
            print("  docker compose -p localai -f docker-compose.yml up")
            if args.services:
                print(f"  docker logs {args.services[0]}")
            return

    print("\n" + "="*60)
    print("✅ Services started successfully!")
    print("="*60)

    # Show running containers
    print("\n📊 Running containers:")
    run_command([
        "docker", "ps",
        "--format", "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    ], check=False)

    # Show access URLs
    print("\n💡 Access URLs:")
    if not args.only_supabase:
        if not args.services or 'n8n' in args.services:
            print("  • n8n: https://n8n.leadingai.info")
        if not args.services or 'neo4j' in args.services:
            print("  • Neo4j: https://neo4j.leadingai.info")
        if not args.services or 'open-webui' in args.services:
            print("  • Open WebUI: https://webui.leadingai.info")

    if args.only_supabase or not args.skip_supabase:
        print("  • Supabase: https://db.leadingai.info")

if __name__ == "__main__":
    main()
