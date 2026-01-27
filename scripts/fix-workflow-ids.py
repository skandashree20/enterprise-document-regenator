#!/usr/bin/env python3
"""
Fix workflow IDs in Main Orchestrator after import.
This script looks up actual workflow IDs and updates the main orchestrator.
"""

import subprocess
import json
import sys

def run_sql(sql):
    """Execute SQL and return result"""
    result = subprocess.run(
        ['docker', 'exec', '-i', 'n8n-postgres-new', 'psql', '-U', 'n8n', '-d', 'n8n', '-t', '-A'],
        input=sql,
        capture_output=True,
        text=True
    )
    return result.stdout.strip(), result.returncode

def get_workflow_id(name):
    """Get workflow ID by name"""
    sql = f"SELECT id FROM workflow_entity WHERE name = '{name}';"
    result, _ = run_sql(sql)
    return result if result else None

def main():
    print("=== Fixing Workflow IDs in Main Orchestrator ===\n")

    # Get all workflow IDs by name
    workflow_map = {
        'Fetch Company Snippet': get_workflow_id('11 - Company Snippet Fetcher'),
        'Fetch Enrichment Data': get_workflow_id('10 - External Data Enricher'),
        'Scan Google Drive': get_workflow_id('02 - Google Drive Scanner'),
        'Analyze Document': get_workflow_id('08 - Document Analyzer OpenAI'),
        'Update Document': get_workflow_id('21 - Document Updater'),
        'Upload Updated Docs': get_workflow_id('18 - Google Drive Uploader'),
        'Generate Visuals': get_workflow_id('16 - Visual Asset Generator'),
        'Upload to Drive': get_workflow_id('18 - Google Drive Uploader'),
    }

    generator_map = {
        '12 - Corporate Overview Generator': get_workflow_id('12 - Corporate Overview Generator'),
        '13 - Product Datasheet Generator': get_workflow_id('13 - Product Datasheet Generator'),
        '14 - Higher Ed One-Pager Generator': get_workflow_id('14 - Higher Ed One-Pager Generator'),
    }

    print("Found workflow IDs:")
    for name, wf_id in workflow_map.items():
        print(f"  {name}: {wf_id or 'NOT FOUND'}")

    # Get main orchestrator
    sql = "SELECT nodes FROM workflow_entity WHERE name = '01 - Main Orchestrator';"
    nodes_json, _ = run_sql(sql)

    if not nodes_json:
        print("ERROR: Main Orchestrator not found!")
        sys.exit(1)

    nodes = json.loads(nodes_json)

    # Update Execute Workflow nodes
    for node in nodes:
        if node.get('type') == 'n8n-nodes-base.executeWorkflow':
            node_name = node.get('name')
            if node_name in workflow_map and workflow_map[node_name]:
                node['parameters']['workflowId']['value'] = workflow_map[node_name]
                print(f"  Updated {node_name} -> {workflow_map[node_name]}")

        # Update Route to Generators code
        if node.get('name') == 'Route to Generators' and node.get('type') == 'n8n-nodes-base.code':
            gen_ids = generator_map
            js_code = f"""const item = $input.first();
const analyzedDocs = item.json.analyzed_documents || [];
const context = item.json;
const combineContext = $('Combine Context').first().json;
const outputFolderId = combineContext.config?.output_folder_id || '';

const generationRequests = [
  {{ generator_id: '{gen_ids.get("12 - Corporate Overview Generator", "")}', generator_name: '12 - Corporate Overview Generator', document_type: 'corporate_overview', analyzed_documents: analyzedDocs, company_snippet: context.company_snippet, enrichment_data: context.enrichment_data, output_folder_id: outputFolderId }},
  {{ generator_id: '{gen_ids.get("13 - Product Datasheet Generator", "")}', generator_name: '13 - Product Datasheet Generator', document_type: 'product_datasheet', product_name: 'AIRR', analyzed_documents: analyzedDocs, company_snippet: context.company_snippet, enrichment_data: context.enrichment_data, output_folder_id: outputFolderId }},
  {{ generator_id: '{gen_ids.get("14 - Higher Ed One-Pager Generator", "")}', generator_name: '14 - Higher Ed One-Pager Generator', document_type: 'higher_ed_onepager', analyzed_documents: analyzedDocs, company_snippet: context.company_snippet, enrichment_data: context.enrichment_data, output_folder_id: outputFolderId }}
];

return generationRequests.map(req => ({{ json: req }}));"""
            node['parameters']['jsCode'] = js_code
            print("  Updated Route to Generators code")

    # Update database
    nodes_escaped = json.dumps(nodes).replace("'", "''")
    update_sql = f"""
UPDATE workflow_entity
SET nodes = '{nodes_escaped}'::jsonb,
    "updatedAt" = NOW()
WHERE name = '01 - Main Orchestrator';
"""

    _, returncode = run_sql(update_sql)

    if returncode == 0:
        print("\n✓ Main Orchestrator updated successfully!")
    else:
        print("\n✗ Failed to update Main Orchestrator")
        sys.exit(1)

if __name__ == '__main__':
    main()
