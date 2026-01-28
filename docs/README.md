# Enterprise Document Regenerator - Complete Guide

## Table of Contents
1. [Overview](#overview)
2. [Setup](#setup)
3. [Credentials Configuration](#credentials)
4. [Workflows](#workflows)
5. [Troubleshooting](#troubleshooting)

---

## Overview

An n8n-based system for automatically regenerating company documents using AI.

**Key Features:**
- Scans Google Drive for source documents
- Extracts text using Apache Tika
- Analyzes with OpenAI/Gemini AI
- Generates corporate documents (Overview, Datasheet, One-Pagers)
- Automated error notifications via Google Chat
- Multi-model consensus for better analysis

---

## Setup

### Prerequisites
- Docker and Docker Compose
- Google Cloud credentials (OAuth for Drive)
- OpenAI API key
- Serper API key (optional, for document updates)

### Quick Start

1. **Start Services**
```bash
cd docker
docker compose up -d
```

Services running:
- n8n: http://localhost:5680
- PostgreSQL: Internal database
- Apache Tika: Text extraction service

2. **Create n8n Account**
- Open http://localhost:5680
- Create account (first time only)

3. **Import Workflows**
```bash
./scripts/import-workflows.sh
```

This automatically:
- Imports all 21 workflows
- Fixes workflow ID references
- Sets correct execution modes
- Shares workflows with your account

---

## Credentials

### Google Drive OAuth2

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create project → Enable Google Drive API
3. Create OAuth 2.0 credentials (Web application)
4. Add redirect URI: `http://localhost:5680/rest/oauth2-credential/callback`
5. In n8n: Settings → Credentials → Add → Google Drive OAuth2
6. Enter Client ID/Secret → Connect

### OpenAI API

1. Get key from [OpenAI Platform](https://platform.openai.com/api-keys)
2. In n8n: Settings → Credentials → Add → OpenAI API
3. Enter API key

### Google Gemini API

1. Get key from [Google AI Studio](https://makersuite.google.com/app/apikey)
2. In n8n: Settings → Credentials → Add → Google PaLM API
3. Enter API key

### Serper API (Optional)

1. Get key from [serper.dev](https://serper.dev/)
2. In n8n: Settings → Credentials → Add → Header Auth
3. Name: `Serper API`
4. Header Name: `X-API-KEY`
5. Header Value: Your API key

### Google Chat Webhook (Optional)

For error notifications:
1. Create Google Chat space
2. Add webhook: Space menu → Apps & integrations → Webhooks
3. Copy webhook URL
4. Update in workflow: 20 - Error Notifier → HTTP Request node

---

## Workflows

### Main Workflow
**01 - Main Orchestrator** - Coordinates all sub-workflows

### Ingestion
- **02 - Google Drive Scanner** - Scans folders for documents
- **03 - Document Fetcher** - Downloads documents

### Processing
- **04 - Batch Router** - Routes documents by type
- **05 - PDF Processor** - Processes PDFs
- **06 - DOCX Processor** - Processes Word docs
- **07 - Generic Processor** - Handles other formats
- **21 - Document Updater** - Checks for updates

### Analysis
- **08 - Document Analyzer OpenAI** - GPT-4 analysis
- **09 - Document Analyzer Gemini** - Gemini analysis
- **23 - Two-Model Consensus** - Combines both analyses

### Enrichment
- **10 - External Data Enricher** - Fetches industry news
- **11 - Company Snippet Fetcher** - Gets company context

### Generation
- **12 - Corporate Overview Generator**
- **13 - Product Datasheet Generator**
- **14 - Higher Ed One-Pager Generator**
- **15 - Client Document Generator**

### Visuals
- **16 - Visual Asset Generator** - Creates document visuals

### Output
- **18 - Google Drive Uploader** - Uploads generated docs

### Error Handling
- **19 - Error Orchestrator** - Handles errors
- **20 - Error Notifier** - Sends Google Chat alerts

---

## Configuration

### Set Google Drive Folders

In **01 - Main Orchestrator** → **Set Config** node:

```javascript
{
  "source_folder_ids": ["FOLDER_ID_1", "FOLDER_ID_2"],
  "output_folder_id": "OUTPUT_FOLDER_ID"
}
```

Get folder IDs from Drive URLs:
`https://drive.google.com/drive/folders/THIS_IS_THE_FOLDER_ID`

### Set Company Context

In **11 - Company Snippet Fetcher**:
- Update Google Doc ID containing company information
- Or use default OneOrigin context

---

## Running the System

### Via Webhook
```bash
curl -X POST http://localhost:5680/webhook/run-regeneration
```

### Via n8n UI
1. Open **01 - Main Orchestrator**
2. Click **Execute Workflow**

---

## Troubleshooting

### Workflow Not Found Error
```bash
./scripts/fix-workflow-ids.sh
```

### Execution Mode Issues
```bash
./scripts/fix-workflow-modes.sh
```

### Credentials Not Linked
After import, manually link credentials:
1. Open each workflow with red credential icons
2. Select correct credential from dropdown
3. Save

### Tika Connection Error
Ensure Tika URL is: `http://n8n-tika:9998/tika`
(Not `host.docker.internal`)

### Workflows Not Visible
```bash
docker exec -i n8n-postgres-new psql -U n8n -d n8n -c "
INSERT INTO shared_workflow (\"workflowId\", \"projectId\", \"role\", \"createdAt\", \"updatedAt\")
SELECT id, (SELECT id FROM project LIMIT 1), 'workflow:owner', NOW(), NOW()
FROM workflow_entity
ON CONFLICT DO NOTHING;
"
```

### Reset Database
```bash
cd docker
docker compose down -v  # Deletes all data!
docker compose up -d
./scripts/import-workflows.sh
```

### Check Logs
```bash
docker logs n8n-doc-regenerator --tail 100
docker logs n8n-postgres-new --tail 50
docker logs n8n-tika --tail 50
```

---

## Architecture

```
Main Orchestrator
├── Fetch Company Snippet (11)
├── Fetch Enrichment Data (10)
├── Scan Google Drive (02)
├── Download & Extract (Tika)
├── Analyze Document (08/09/23)
│   ├── OpenAI Analyzer
│   ├── Gemini Analyzer
│   └── Build Consensus
├── Generate Documents (12,13,14,15)
├── Generate Visuals (16)
├── Upload to Drive (18)
└── Error Handling (19,20)
```

---

## Maintenance

### Export Workflows
```bash
./scripts/export-workflows.sh
```

### Backup Database
```bash
docker exec n8n-postgres-new pg_dump -U n8n n8n > backup.sql
```

### Update n8n
```bash
cd docker
docker compose pull
docker compose up -d
```

---

## Support

For issues:
1. Check logs: `docker logs n8n-doc-regenerator`
2. Verify credentials are linked
3. Run fix scripts if needed
4. Check Google Chat for error notifications

---

## License

Proprietary - OneOrigin
