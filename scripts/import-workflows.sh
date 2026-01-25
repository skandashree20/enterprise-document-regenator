#!/bin/bash

# Import Workflows Script for OneOrigin Document Regeneration System
# This script imports all workflow JSON files into n8n

set -e

# Configuration
N8N_URL="${N8N_URL:-http://localhost:5678}"
N8N_API_KEY="${N8N_API_KEY:-}"
WORKFLOWS_DIR="${WORKFLOWS_DIR:-../workflows}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}OneOrigin Document Regeneration System${NC}"
echo -e "${GREEN}Workflow Import Script${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if n8n is accessible
echo -e "${YELLOW}Checking n8n connection...${NC}"
if ! curl -s -o /dev/null -w "%{http_code}" "$N8N_URL/healthz" | grep -q "200"; then
    echo -e "${RED}Error: Cannot connect to n8n at $N8N_URL${NC}"
    echo "Make sure n8n is running and accessible."
    exit 1
fi
echo -e "${GREEN}n8n is accessible at $N8N_URL${NC}"
echo ""

# Function to import a workflow
import_workflow() {
    local file=$1
    local name=$(basename "$file" .json)

    echo -e "${YELLOW}Importing: $name${NC}"

    if [ -n "$N8N_API_KEY" ]; then
        # Use API if key is provided
        response=$(curl -s -X POST "$N8N_URL/api/v1/workflows" \
            -H "Content-Type: application/json" \
            -H "X-N8N-API-KEY: $N8N_API_KEY" \
            -d @"$file")

        if echo "$response" | grep -q '"id"'; then
            echo -e "${GREEN}  ✓ Imported successfully${NC}"
        else
            echo -e "${RED}  ✗ Import failed: $response${NC}"
        fi
    else
        echo -e "${YELLOW}  → Manual import required (no API key)${NC}"
        echo -e "     File: $file"
    fi
}

# Import order matters for sub-workflows
echo -e "${YELLOW}Importing workflows in recommended order...${NC}"
echo ""

# Error handling workflows first
echo -e "${GREEN}--- Error Handling Workflows ---${NC}"
for file in "$WORKFLOWS_DIR"/error-handling/*.json; do
    [ -f "$file" ] && import_workflow "$file"
done

# Output workflows
echo ""
echo -e "${GREEN}--- Output Workflows ---${NC}"
for file in "$WORKFLOWS_DIR"/output/*.json; do
    [ -f "$file" ] && import_workflow "$file"
done

# Visual workflows
echo ""
echo -e "${GREEN}--- Visual Generation Workflows ---${NC}"
for file in "$WORKFLOWS_DIR"/visuals/*.json; do
    [ -f "$file" ] && import_workflow "$file"
done

# Generation workflows
echo ""
echo -e "${GREEN}--- Document Generation Workflows ---${NC}"
for file in "$WORKFLOWS_DIR"/generation/*.json; do
    [ -f "$file" ] && import_workflow "$file"
done

# Enrichment workflows
echo ""
echo -e "${GREEN}--- Enrichment Workflows ---${NC}"
for file in "$WORKFLOWS_DIR"/enrichment/*.json; do
    [ -f "$file" ] && import_workflow "$file"
done

# Analysis workflows
echo ""
echo -e "${GREEN}--- Analysis Workflows ---${NC}"
for file in "$WORKFLOWS_DIR"/analysis/*.json; do
    [ -f "$file" ] && import_workflow "$file"
done

# Processing workflows
echo ""
echo -e "${GREEN}--- Processing Workflows ---${NC}"
for file in "$WORKFLOWS_DIR"/processing/*.json; do
    [ -f "$file" ] && import_workflow "$file"
done

# Ingestion workflows
echo ""
echo -e "${GREEN}--- Ingestion Workflows ---${NC}"
for file in "$WORKFLOWS_DIR"/ingestion/*.json; do
    [ -f "$file" ] && import_workflow "$file"
done

# Main orchestrator last
echo ""
echo -e "${GREEN}--- Main Orchestrator ---${NC}"
for file in "$WORKFLOWS_DIR"/main/*.json; do
    [ -f "$file" ] && import_workflow "$file"
done

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Import process complete!${NC}"
echo -e "${GREEN}========================================${NC}"

if [ -z "$N8N_API_KEY" ]; then
    echo ""
    echo -e "${YELLOW}Note: No API key was provided.${NC}"
    echo "To enable automatic import, set the N8N_API_KEY environment variable."
    echo ""
    echo "For manual import:"
    echo "1. Open n8n at $N8N_URL"
    echo "2. Go to Workflows"
    echo "3. Click Import from File"
    echo "4. Select each JSON file from the workflows directory"
fi
