#!/bin/bash
# Fix Execute Workflow nodes to use "Run once for each item" mode
# Run this after importing workflows via n8n UI

echo "Fixing Execute Workflow node modes..."

docker exec -i n8n-postgres-new psql -U n8n -d n8n << 'EOF'
-- Update Main Orchestrator workflow
UPDATE workflow_entity
SET nodes = (
    SELECT jsonb_agg(
        CASE
            WHEN node->>'name' IN (
                'Analyze Document',
                'Generate Document',
                'Generate Visuals',
                'Upload to Drive',
                'Update Document',
                'Upload Updated Docs'
            ) AND node->>'type' = 'n8n-nodes-base.executeWorkflow'
            THEN jsonb_set(
                node,
                '{parameters,options}',
                '{"mode": "each"}'::jsonb
            )
            ELSE node
        END
    )
    FROM jsonb_array_elements(nodes::jsonb) AS node
),
"updatedAt" = NOW()
WHERE name = '01 - Main Orchestrator';
EOF

echo ""
echo "Done! Please refresh your n8n browser to see the changes."
echo ""
echo "The following nodes are now set to 'Run once for each item':"
echo "  - Analyze Document"
echo "  - Generate Document"
echo "  - Generate Visuals"
echo "  - Upload to Drive"
echo "  - Update Document"
echo "  - Upload Updated Docs"
