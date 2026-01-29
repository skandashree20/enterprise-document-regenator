#!/bin/bash

echo "🔧 Fixing Workflow ID References"
echo "================================="

# Get current IDs from database (active workflows only)
SCAN_ID=$(docker exec n8n-postgres-new psql -U n8n -d n8n -t -c "SELECT id FROM workflow_entity WHERE name = '02 - Google Drive Scanner' AND active = true;" | tr -d ' ')
ANALYZE_ID=$(docker exec n8n-postgres-new psql -U n8n -d n8n -t -c "SELECT id FROM workflow_entity WHERE name = '08 - Document Analyzer OpenAI' AND active = true;" | tr -d ' ')
SNIPPET_ID=$(docker exec n8n-postgres-new psql -U n8n -d n8n -t -c "SELECT id FROM workflow_entity WHERE name = '11 - Company Snippet Fetcher' AND active = true;" | tr -d ' ')
ENRICHMENT_ID=$(docker exec n8n-postgres-new psql -U n8n -d n8n -t -c "SELECT id FROM workflow_entity WHERE name = '10 - External Data Enricher' AND active = true;" | tr -d ' ')
UPLOAD_ID=$(docker exec n8n-postgres-new psql -U n8n -d n8n -t -c "SELECT id FROM workflow_entity WHERE name = '18 - Google Drive Uploader' AND active = true;" | tr -d ' ')
UPDATE_ID=$(docker exec n8n-postgres-new psql -U n8n -d n8n -t -c "SELECT id FROM workflow_entity WHERE name = '21 - Document Updater' AND active = true;" | tr -d ' ')
VISUALS_ID=$(docker exec n8n-postgres-new psql -U n8n -d n8n -t -c "SELECT id FROM workflow_entity WHERE name = '16 - Visual Asset Generator' AND active = true;" | tr -d ' ')
ERROR_ID=$(docker exec n8n-postgres-new psql -U n8n -d n8n -t -c "SELECT id FROM workflow_entity WHERE name = '19 - Error Orchestrator' AND active = true;" | tr -d ' ')

echo ""
echo "Current Active Workflow IDs:"
echo "  Scan: $SCAN_ID"
echo "  Analyze: $ANALYZE_ID"
echo "  Snippet: $SNIPPET_ID"
echo "  Enrichment: $ENRICHMENT_ID"
echo "  Upload: $UPLOAD_ID"
echo "  Update: $UPDATE_ID"
echo "  Visuals: $VISUALS_ID"
echo "  Error: $ERROR_ID"
echo ""

# Stop n8n to prevent caching issues
echo "Stopping n8n..."
cd /Users/megha/Downloads/enterprise-document-regenator/docker
docker compose stop n8n

# Update using text replacement (jsonb updates don't work due to n8n caching)
echo ""
echo "Updating workflow references..."
docker exec n8n-postgres-new psql -U n8n -d n8n << EOF
UPDATE workflow_entity 
SET nodes = replace(
  replace(
    replace(
      replace(
        replace(
          replace(
            replace(
              replace(nodes::text,
                'uCwI1pQ0arpZU6Yx', '$SCAN_ID'),
              'BvHmgECJ524epfsK', '$ANALYZE_ID'),
            '0SQrRxgwgIG0PBOn', '$SNIPPET_ID'),
          'Zc6mV1sKvl5W9Mfx', '$ENRICHMENT_ID'),
        '6irPjdjzFrh7yKL8', '$UPLOAD_ID'),
      'Bhey7Pf0xP0DH0Y6', '$UPDATE_ID'),
    'jNEJJdPLSGjWgFwS', '$VISUALS_ID'),
  'ERROR_WORKFLOW_ID', '$ERROR_ID')::jsonb
WHERE name = '01 - Main Orchestrator';
EOF

echo ""
echo "Starting n8n..."
docker compose up -d n8n
sleep 25

echo ""
echo "✅ Done! Verifying..."
docker exec n8n-postgres-new psql -U n8n -d n8n -c "
SELECT 
  elem->>'name' as node,
  elem->'parameters'->'workflowId'->>'value' as id,
  (SELECT name FROM workflow_entity WHERE id = elem->'parameters'->'workflowId'->>'value') as target
FROM workflow_entity,
     jsonb_array_elements(nodes::jsonb) arr(elem)
WHERE name = '01 - Main Orchestrator'
  AND elem->>'type' = 'n8n-nodes-base.executeWorkflow'
  AND elem->>'name' != 'Generate Document'
ORDER BY elem->>'name';
"
