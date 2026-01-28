#!/bin/bash

echo "🔧 Fixing Workflow ID References"
echo "================================="
echo ""

# Get Main Orchestrator ID
MAIN_ID=$(docker exec n8n-postgres-new psql -U n8n -d n8n -t -c "SELECT id FROM workflow_entity WHERE name = '01 - Main Orchestrator';" | tr -d ' ')

echo "Main Orchestrator ID: $MAIN_ID"
echo ""

# Define the mapping of old IDs to new IDs
declare -A ID_MAP=(
  ["0SQrRxgwgIG0PBOn"]="oZtRdXneEmGX2I8H"  # Company Snippet Fetcher
  ["Zc6mV1sKvl5W9Mfx"]="VZWdJgwc1j6SlUQD"  # External Data Enricher
  ["uCwI1pQ0arpZU6Yx"]="uBxF2KxIPBH6Nb2b"  # Google Drive Scanner
  ["BvHmgECJ524epfsK"]="LzQRJuuz6T86h976"  # Document Analyzer OpenAI
  ["Bhey7Pf0xP0DH0Y6"]="qxzhnH9zmvxGJq0J"  # Document Updater
  ["6irPjdjzFrh7yKL8"]="ZQwCzBQ6yty0Bn1Y"  # Google Drive Uploader
  ["jNEJJdPLSGjWgFwS"]="HpkRzcQnRV6Tv84P"  # Visual Asset Generator
  ["Adlw6GFK6dfNNZ7X"]="y6ZcH9N8vfweDstk"  # Corporate Overview Generator
  ["ZhLZfoIafT5fDoq7"]="1TZkJmCEWYsyK3rq"  # Product Datasheet Generator
  ["DeeROqhJo4eQcfYk"]="HQaXPiDbhEmJNuzz"  # Higher Ed One-Pager Generator
)

echo "Updating workflow ID references..."
echo ""

# Update each workflow ID in the Main Orchestrator
for OLD_ID in "${!ID_MAP[@]}"; do
  NEW_ID="${ID_MAP[$OLD_ID]}"
  
  echo "Replacing $OLD_ID → $NEW_ID"
  
  docker exec n8n-postgres-new psql -U n8n -d n8n << EOF > /dev/null 2>&1
UPDATE workflow_entity 
SET nodes = nodes::text::jsonb 
WHERE id = '$MAIN_ID' 
AND nodes::text LIKE '%$OLD_ID%';

UPDATE workflow_entity 
SET nodes = replace(nodes::text, '$OLD_ID', '$NEW_ID')::jsonb
WHERE id = '$MAIN_ID';
EOF
done

echo ""
echo "✅ Workflow IDs updated!"
echo ""
echo "Restarting n8n to apply changes..."
docker restart n8n-doc-regenerator > /dev/null 2>&1
sleep 15

echo ""
echo "✅ Done! Workflow ID references are now correct."
echo ""
echo "Verify at: http://localhost:5680"
