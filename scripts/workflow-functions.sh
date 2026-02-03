#!/bin/bash
# Common functions for n8n workflow management

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Common variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
WORKFLOWS_DIR="$PROJECT_DIR/workflows"
DOCKER_DIR="$PROJECT_DIR/docker"

# Check if containers are running
check_containers() {
    if ! docker ps | grep -q n8n-postgres-new; then
        echo -e "${RED}Error: n8n-postgres-new container is not running${NC}"
        echo "Start it with: cd docker && docker compose up -d"
        exit 1
    fi
}

# Execute SQL command
exec_sql() {
    docker exec -i n8n-postgres-new psql -U n8n -d n8n -c "$1"
}

# Execute SQL from file
exec_sql_file() {
    docker exec -i n8n-postgres-new psql -U n8n -d n8n < "$1"
}

# Get workflow ID by name
get_workflow_id() {
    local name="$1"
    exec_sql "SELECT id FROM workflow_entity WHERE name = '$name' AND active = true;" | tr -d ' ' | head -n1
}

# Stop/start n8n service
restart_n8n() {
    echo -e "${YELLOW}Restarting n8n...${NC}"
    cd "$DOCKER_DIR"
    docker compose stop n8n
    docker compose up -d n8n
    sleep 25
}

# Share workflows with default user
share_workflows() {
    echo -e "${BLUE}Sharing workflows with default user...${NC}"
    exec_sql "
    INSERT INTO shared_workflow (\"workflowId\", \"projectId\", \"role\", \"createdAt\", \"updatedAt\")
    SELECT w.id, p.id, 'workflow:owner', NOW(), NOW()
    FROM workflow_entity w
    CROSS JOIN (SELECT id FROM project LIMIT 1) p
    ON CONFLICT DO NOTHING;
    "
}

# Print workflow IDs
print_workflow_ids() {
    echo -e "${BLUE}Current Active Workflow IDs:${NC}"
    echo "  Scan: $(get_workflow_id '02 - Google Drive Scanner')"
    echo "  Analyze: $(get_workflow_id '08 - Document Analyzer OpenAI')"
    echo "  Snippet: $(get_workflow_id '11 - Company Snippet Fetcher')"
    echo "  Enrichment: $(get_workflow_id '10 - External Data Enricher')"
    echo "  Upload: $(get_workflow_id '18 - Google Drive Uploader')"
    echo "  Update: $(get_workflow_id '21 - Document Updater')"
    echo "  Visuals: $(get_workflow_id '16 - Visual Asset Generator')"
    echo "  Error: $(get_workflow_id '19 - Error Orchestrator')"
}

# Import single workflow
import_workflow() {
    local file="$1"
    python3 << PYEOF
import json
import subprocess
import uuid

try:
    with open('$file', 'r') as f:
        workflow = json.load(f)

    name = workflow.get('name', '$file')
    wf_id = workflow.get('id', str(uuid.uuid4())[:16])
    nodes = json.dumps(workflow.get('nodes', []))
    connections = json.dumps(workflow.get('connections', {}))
    settings = json.dumps(workflow.get('settings', {}))
    static_data = json.dumps(workflow.get('staticData')) if workflow.get('staticData') else 'null'
    version_id = str(uuid.uuid4())

    sql = f"""
INSERT INTO workflow_entity (id, name, active, nodes, connections, settings, "staticData", "createdAt", "updatedAt", "versionId")
VALUES (
    \$WF_ID\${wf_id}\$WF_ID\$,
    \$WF_NAME\${name}\$WF_NAME\$,
    false,
    \$NODES\${nodes}\$NODES\$::jsonb,
    \$CONN\${connections}\$CONN\$::jsonb,
    \$SETTINGS\${settings}\$SETTINGS\$::jsonb,
    \$STATIC\${static_data}\$STATIC\$::jsonb,
    NOW(),
    NOW(),
    \$VERSION\${version_id}\$VERSION\$
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
        exit(0)
    else:
        print(f"✗ {name}: {result.stderr[:50]}")
        exit(1)

except Exception as e:
    print(f"✗ Error: $file - {e}")
    exit(1)
PYEOF
}
