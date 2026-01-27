#!/bin/bash
# Fix workflow IDs in Main Orchestrator after import
# This script looks up actual workflow IDs and updates the main orchestrator

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if containers are running
if ! docker ps | grep -q n8n-postgres-new; then
    echo "Error: n8n-postgres-new container is not running"
    exit 1
fi

python3 "$SCRIPT_DIR/fix-workflow-ids.py"
