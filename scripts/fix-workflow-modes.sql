-- Fix Execute Workflow nodes to use "Run once for each item" mode
-- Run this after importing workflows to ensure proper batch processing

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
    FROM jsonb_array_elements(nodes) AS node
)
WHERE name = '01 - Main Orchestrator';

-- Verify the update
SELECT
    node->>'name' as node_name,
    node->'parameters'->'options'->>'mode' as mode
FROM workflow_entity,
     jsonb_array_elements(nodes) AS node
WHERE name = '01 - Main Orchestrator'
  AND node->>'type' = 'n8n-nodes-base.executeWorkflow';
