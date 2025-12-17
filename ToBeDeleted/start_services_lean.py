#!/usr/bin/env python3
"""
start_services_lean.py

This script starts the Supabase stack first, waits for it to initialize, and then starts
the n8n stack. Both stacks use the same Docker Compose project name ("localai")
so they appear together in Docker.
"""

import os
import subprocess
import shutil
import time

# Define absolute paths
PROJECT_DIR = '/root/local-ai-packaged'
SUPABASE_DOCKER_DIR = os.path.join(PROJECT_DIR, 'supabase', 'docker')
MAIN_COMPOSE_FILE = os.path.join(PROJECT_DIR, 'docker-compose.yml')
SUPABASE_COMPOSE_FILE = os.path.join(SUPABASE_DOCKER_DIR, 'docker-compose.yml')
ROOT_ENV_FILE = os.path.join(PROJECT_DIR, '.env')
SUPABASE_ENV_FILE = os.path.join(SUPABASE_DOCKER_DIR, '.env')


def run_command(cmd, cwd=None):
    """Run a shell command and print it."""
    print("Running:", " ".join(cmd))
    subprocess.run(cmd, cwd=cwd, check=True)

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

def stop_existing_containers():
    print("Stopping and removing all containers for the unified project 'localai'...")
    try:
        # Stop main services first
        cmd_main = ["docker", "compose", "-p", "localai", "-f", MAIN_COMPOSE_FILE, "down", "--remove-orphans", "-t", "1"]
        run_command(cmd_main)
    except subprocess.CalledProcessError as e:
        print(f"Could not stop main services (this may be expected if they weren't running): {e}")
    try:
        # Then stop supabase services
        cmd_supabase = ["docker", "compose", "-p", "localai", "-f", SUPABASE_COMPOSE_FILE, "down", "--remove-orphans", "-t", "1"]
        run_command(cmd_supabase)
    except subprocess.CalledProcessError as e:
        print(f"Could not stop supabase services (this may be expected if they weren't running): {e}")


def start_supabase():
    """Start the Supabase services."""
    print("Starting Supabase services under project 'localai'...")
    cmd = [
        "docker", "compose", "-p", "localai",
        "-f", SUPABASE_COMPOSE_FILE,
        "up", "-d", "--remove-orphans"
    ]
    run_command(cmd, cwd=PROJECT_DIR)

def start_n8n():
    """Start the n8n service."""
    print("Starting n8n service under project 'localai'...")
    cmd = [
        "docker", "compose", "-p", "localai",
        "-f", MAIN_COMPOSE_FILE,
        "up", "-d", "--remove-orphans"
    ]
    run_command(cmd, cwd=PROJECT_DIR)


def main():
    """Main execution function."""
    clone_supabase_repo()
    prepare_supabase_env()
    stop_existing_containers()

    print("Starting Supabase...")
    start_supabase()

    print("Waiting for Supabase to initialize (15 seconds)...")
    time.sleep(15)

    print("Starting n8n...")
    start_n8n()

    print("All services have been started successfully.")

if __name__ == "__main__":
    main()
