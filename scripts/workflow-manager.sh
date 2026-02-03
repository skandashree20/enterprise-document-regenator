#!/bin/bash
# Unified n8n workflow management script

set -e
source "$(dirname "$0")/workflow-functions.sh"

show_help() {
    echo -e "${BLUE}n8n Workflow Management Tool${NC}"
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  import     Import all workflows from workflows/ directory"
    echo "  fix-ids    Fix workflow ID references in Main Orchestrator"
    echo "  fix-modes  Fix Execute Workflow node modes"
    echo "  enhance    Apply enhancements to existing workflows"
    echo "  status     Show workflow status and IDs"
    echo "  reset      Reset database (WARNING: deletes all data)"
    echo "  help       Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 import          # Full import with fixes"
    echo "  $0 fix-ids         # Fix workflow references only"
    echo "  $0 status          # Show current workflow status"
}

import_workflows() {
    echo -e "${BLUE}=== Importing Workflows ===${NC}"
    check_containers
    
    cd "$PROJECT_DIR"
    skip_files=('21-document-updater-import.json')
    success=0
    failed=0

    for wf_file in "$WORKFLOWS_DIR"/*.json; do
        [[ ! -f "$wf_file" ]] && continue
        
        filename=$(basename "$wf_file")
        if [[ " ${skip_files[@]} " =~ " ${filename} " ]]; then
            continue
        fi
        
        if import_workflow "$wf_file"; then
            ((success++))
        else
            ((failed++))
        fi
    done

    echo ""
    echo -e "${GREEN}Imported: $success${NC} | ${RED}Failed: $failed${NC}"
    
    share_workflows
    fix_workflow_ids
    fix_workflow_modes
    
    echo -e "${GREEN}=== Import Complete ===${NC}"
}

fix_workflow_ids() {
    echo -e "${BLUE}=== Fixing Workflow IDs ===${NC}"
    check_containers
    
    local SCAN_ID=$(get_workflow_id '02 - Google Drive Scanner')
    local ANALYZE_ID=$(get_workflow_id '08 - Document Analyzer OpenAI')
    local SNIPPET_ID=$(get_workflow_id '11 - Company Snippet Fetcher')
    local ENRICHMENT_ID=$(get_workflow_id '10 - External Data Enricher')
    local UPLOAD_ID=$(get_workflow_id '18 - Google Drive Uploader')
    local UPDATE_ID=$(get_workflow_id '21 - Document Updater')
    local VISUALS_ID=$(get_workflow_id '16 - Visual Asset Generator')
    local ERROR_ID=$(get_workflow_id '19 - Error Orchestrator')

    restart_n8n

    exec_sql "
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
    "
    
    echo -e "${GREEN}✅ Workflow IDs fixed${NC}"
}

fix_workflow_modes() {
    echo -e "${BLUE}=== Fixing Workflow Modes ===${NC}"
    check_containers
    
    exec_sql "
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
                    '{\"mode\": \"each\"}'::jsonb
                )
                ELSE node
            END
        )
        FROM jsonb_array_elements(nodes::jsonb) AS node
    ),
    \"updatedAt\" = NOW()
    WHERE name = '01 - Main Orchestrator';
    "
    
    echo -e "${GREEN}✅ Workflow modes fixed${NC}"
}

show_status() {
    echo -e "${BLUE}=== Workflow Status ===${NC}"
    check_containers
    print_workflow_ids
    
    echo ""
    echo -e "${BLUE}Workflow Count:${NC}"
    exec_sql "SELECT COUNT(*) as total_workflows FROM workflow_entity;"
    
    echo ""
    echo -e "${BLUE}Active Workflows:${NC}"
    exec_sql "SELECT name FROM workflow_entity WHERE active = true ORDER BY name;"
}

reset_database() {
    echo -e "${RED}⚠️  WARNING: This will delete ALL workflow data!${NC}"
    read -p "Are you sure? (type 'yes' to confirm): " confirm
    
    if [[ "$confirm" == "yes" ]]; then
        cd "$DOCKER_DIR"
        docker compose down -v
        docker compose up -d
        echo -e "${GREEN}Database reset complete${NC}"
    else
        echo "Reset cancelled"
    fi
}

case "${1:-help}" in
    import)
        import_workflows
        ;;
    fix-ids)
        fix_workflow_ids
        ;;
    fix-modes)
        fix_workflow_modes
        ;;
    enhance)
        source "$SCRIPT_DIR/enhance-existing-workflows.sh"
        ;;
    status)
        show_status
        ;;
    reset)
        reset_database
        ;;
    help|*)
        show_help
        ;;
esac
