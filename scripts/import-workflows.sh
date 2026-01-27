#!/bin/bash
# Import all workflows into n8n database
# This script imports workflows directly to PostgreSQL, preserving all settings

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
WORKFLOWS_DIR="$PROJECT_DIR/workflows"

echo "=== Enterprise Document Regenerator - Workflow Import ==="
echo ""

# Check if containers are running
if ! docker ps | grep -q n8n-postgres-new; then
    echo "Error: n8n-postgres-new container is not running"
    echo "Start it with: cd docker && docker compose up -d"
    exit 1
fi

echo "Importing workflows from $WORKFLOWS_DIR..."
echo ""

cd "$PROJECT_DIR"

# Import all workflow JSON files
python3 << 'PYEOF'
import json
import subprocess
from pathlib import Path
import uuid

WORKFLOWS_DIR = "workflows"
workflow_files = sorted(Path(WORKFLOWS_DIR).rglob("*.json"))

skip_files = ['21-document-updater-import.json']

success = 0
failed = 0

for wf_file in workflow_files:
    if wf_file.name in skip_files:
        continue

    try:
        with open(wf_file, 'r') as f:
            workflow = json.load(f)

        name = workflow.get('name', wf_file.stem)
        wf_id = workflow.get('id', str(uuid.uuid4())[:16])
        nodes = json.dumps(workflow.get('nodes', []))
        connections = json.dumps(workflow.get('connections', {}))
        settings = json.dumps(workflow.get('settings', {}))
        static_data = json.dumps(workflow.get('staticData')) if workflow.get('staticData') else 'null'
        version_id = str(uuid.uuid4())

        sql = f"""
INSERT INTO workflow_entity (id, name, active, nodes, connections, settings, "staticData", "createdAt", "updatedAt", "versionId")
VALUES (
    $WF_ID${wf_id}$WF_ID$,
    $WF_NAME${name}$WF_NAME$,
    false,
    $NODES${nodes}$NODES$::jsonb,
    $CONN${connections}$CONN$::jsonb,
    $SETTINGS${settings}$SETTINGS$::jsonb,
    $STATIC${static_data}$STATIC$::jsonb,
    NOW(),
    NOW(),
    $VERSION${version_id}$VERSION$
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    nodes = EXCLUDED.nodes,
    connections = EXCLUDED.connections,
    settings = EXCLUDED.settings,
    "updatedAt" = NOW();
"""

        with open('/tmp/import_wf.sql', 'w') as f:
            f.write(sql)

        result = subprocess.run(
            ['docker', 'exec', '-i', 'n8n-postgres-new', 'psql', '-U', 'n8n', '-d', 'n8n'],
            stdin=open('/tmp/import_wf.sql'),
            capture_output=True,
            text=True
        )

        if result.returncode == 0:
            print(f"✓ {name}")
            success += 1
        else:
            print(f"✗ {name}: {result.stderr[:50]}")
            failed += 1

    except Exception as e:
        print(f"✗ Error: {wf_file.name} - {e}")
        failed += 1

print(f"\nImported: {success} | Failed: {failed}")
PYEOF

echo ""
echo "Sharing workflows with default user..."

docker exec -i n8n-postgres-new psql -U n8n -d n8n << 'EOSQL'
INSERT INTO shared_workflow ("workflowId", "projectId", "role", "createdAt", "updatedAt")
SELECT w.id, p.id, 'workflow:owner', NOW(), NOW()
FROM workflow_entity w
CROSS JOIN (SELECT id FROM project LIMIT 1) p
ON CONFLICT DO NOTHING;
EOSQL

echo ""
echo "Fixing workflow IDs in Main Orchestrator..."
"$SCRIPT_DIR/fix-workflow-ids.sh"

echo ""
echo "Fixing Execute Workflow mode settings..."
"$SCRIPT_DIR/fix-workflow-modes.sh"

echo ""
echo "=== Import Complete ==="
echo ""
echo "Next steps:"
echo "1. Open n8n at http://localhost:5680"
echo "2. Configure credentials (Google Drive, OpenAI, Serper API)"
echo "3. Update source_folder_ids and output_folder_id in Main Orchestrator"
echo "4. Run the workflow!"
