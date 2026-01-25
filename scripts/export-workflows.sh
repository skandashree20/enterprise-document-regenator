#!/bin/bash

# Export Workflows Script for OneOrigin Document Regeneration System
# This script exports all workflows from n8n to JSON files

set -e

# Configuration
N8N_URL="${N8N_URL:-http://localhost:5678}"
N8N_API_KEY="${N8N_API_KEY:-}"
OUTPUT_DIR="${OUTPUT_DIR:-../workflows-backup}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}OneOrigin Document Regeneration System${NC}"
echo -e "${GREEN}Workflow Export Script${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if API key is provided
if [ -z "$N8N_API_KEY" ]; then
    echo -e "${RED}Error: N8N_API_KEY environment variable is required${NC}"
    echo "Set it with: export N8N_API_KEY=your-api-key"
    exit 1
fi

# Check if n8n is accessible
echo -e "${YELLOW}Checking n8n connection...${NC}"
if ! curl -s -o /dev/null -w "%{http_code}" "$N8N_URL/healthz" | grep -q "200"; then
    echo -e "${RED}Error: Cannot connect to n8n at $N8N_URL${NC}"
    exit 1
fi
echo -e "${GREEN}n8n is accessible${NC}"
echo ""

# Create output directory
EXPORT_DIR="$OUTPUT_DIR/$TIMESTAMP"
mkdir -p "$EXPORT_DIR"
echo -e "${YELLOW}Exporting to: $EXPORT_DIR${NC}"
echo ""

# Get list of workflows
echo -e "${YELLOW}Fetching workflow list...${NC}"
workflows=$(curl -s -X GET "$N8N_URL/api/v1/workflows" \
    -H "X-N8N-API-KEY: $N8N_API_KEY")

if [ -z "$workflows" ]; then
    echo -e "${RED}Error: Could not fetch workflows${NC}"
    exit 1
fi

# Parse and export each workflow
echo "$workflows" | jq -r '.data[] | @base64' | while read -r workflow; do
    _jq() {
        echo "$workflow" | base64 --decode | jq -r "${1}"
    }

    id=$(_jq '.id')
    name=$(_jq '.name')

    # Sanitize filename
    filename=$(echo "$name" | sed 's/[^a-zA-Z0-9_-]/_/g')

    echo -e "${YELLOW}Exporting: $name${NC}"

    # Get full workflow details
    curl -s -X GET "$N8N_URL/api/v1/workflows/$id" \
        -H "X-N8N-API-KEY: $N8N_API_KEY" \
        > "$EXPORT_DIR/${filename}.json"

    if [ -f "$EXPORT_DIR/${filename}.json" ]; then
        echo -e "${GREEN}  ✓ Exported to ${filename}.json${NC}"
    else
        echo -e "${RED}  ✗ Export failed${NC}"
    fi
done

# Count exported files
count=$(ls -1 "$EXPORT_DIR"/*.json 2>/dev/null | wc -l)

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Export complete!${NC}"
echo -e "${GREEN}Exported $count workflows to $EXPORT_DIR${NC}"
echo -e "${GREEN}========================================${NC}"
