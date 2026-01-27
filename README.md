# Enterprise Document Regenerator

An n8n-based system for automatically regenerating and updating company documents using AI.

## Overview

This system:
1. Scans Google Drive for source documents
2. Extracts text using Apache Tika
3. Analyzes documents with OpenAI/Gemini
4. Generates new documents (Corporate Overview, Product Datasheet, Higher Ed One-Pager)
5. Creates visuals for documents
6. Checks for document updates using external research (Serper API)
7. Uploads generated documents to Google Drive

## Prerequisites

- Docker and Docker Compose
- Google Cloud credentials (for Google Drive OAuth)
- OpenAI API key
- Serper API key (for document update research)

---

## Setup Instructions

### Step 1: Clone the Repository

```bash
git clone <repository-url>
cd enterprise-document-regenator
```

### Step 2: Start Docker Services

```bash
cd docker
docker compose up -d
```

This starts:
- **n8n** (workflow automation) - http://localhost:5680
- **PostgreSQL** (database)
- **Apache Tika** (text extraction)

Verify all containers are running:
```bash
docker ps
```

You should see:
- `n8n-app-new`
- `n8n-postgres-new`
- `n8n-tika`

### Step 3: Create n8n Account

1. Open http://localhost:5680 in your browser
2. Create a new account (first time only)
3. Complete the setup wizard

### Step 4: Import Workflows

Run the import script from the project root:

```bash
./scripts/import-workflows.sh
```

This script automatically:
1. Imports all workflow JSON files to the database
2. Shares workflows with your user account
3. Fixes workflow ID references in Main Orchestrator
4. Sets correct execution modes (`Run once for each item`)

**Important**: The import script handles workflow ID mismatches automatically. When workflows are imported, they get new database IDs. The `fix-workflow-ids.sh` script (called by the import) looks up the actual IDs by workflow name and updates the Main Orchestrator accordingly.

### Step 5: Configure Credentials in n8n

Open n8n at http://localhost:5680 and add the following credentials:

#### 5.1 Google Drive OAuth2
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing
3. Enable Google Drive API
4. Create OAuth 2.0 credentials (Web application)
5. Add authorized redirect URI: `http://localhost:5680/rest/oauth2-credential/callback`
6. In n8n: **Settings** → **Credentials** → **Add Credential** → **Google Drive OAuth2**
7. Enter Client ID and Client Secret
8. Click **Connect** and authorize

#### 5.2 OpenAI API
1. Get API key from [OpenAI Platform](https://platform.openai.com/api-keys)
2. In n8n: **Settings** → **Credentials** → **Add Credential** → **OpenAI API**
3. Enter your API key

#### 5.3 Serper API (for document update research)
1. Get API key from [serper.dev](https://serper.dev/)
2. In n8n: **Settings** → **Credentials** → **Add Credential** → **Header Auth**
3. Configure:
   - **Name**: `Serper API`
   - **Header Name**: `X-API-KEY`
   - **Header Value**: Your Serper API key

### Step 6: Link Credentials to Workflows

After adding credentials, link them to the workflows:

1. Open **01 - Main Orchestrator**
2. For each node showing a credential error (red icon):
   - Click the node
   - Select the correct credential from the dropdown
   - Save

Repeat for these workflows:
- 02 - Google Drive Scanner (Google Drive)
- 08 - Document Analyzer OpenAI (OpenAI)
- 11 - Company Snippet Fetcher (Google Drive)
- 18 - Google Drive Uploader (Google Drive)
- 21 - Document Updater (Serper API, OpenAI)

### Step 7: Configure Google Drive Folders

1. Open **01 - Main Orchestrator** workflow
2. Find the **Set Config** node (near the start)
3. Update these values:
   - `source_folder_ids`: Array of Google Drive folder IDs containing source documents
   - `output_folder_id`: Google Drive folder ID where generated documents will be saved

To get a folder ID from Google Drive:
1. Open the folder in Google Drive
2. Copy the ID from the URL: `https://drive.google.com/drive/folders/THIS_IS_THE_FOLDER_ID`

### Step 8: Run the Workflow

**Option A: Via Webhook**
```bash
curl -X POST http://localhost:5680/webhook/run-regeneration
```

**Option B: Via n8n UI**
1. Open **01 - Main Orchestrator**
2. Click **Execute Workflow** button

---

## Scripts Reference

| Script | Purpose |
|--------|---------|
| `scripts/import-workflows.sh` | Complete workflow import with all fixes |
| `scripts/fix-workflow-ids.sh` | Fix workflow ID references after import |
| `scripts/fix-workflow-modes.sh` | Fix Execute Workflow node modes |

### When to Use Each Script

**After cloning the repo:**
```bash
./scripts/import-workflows.sh
```

**After manually importing workflows via n8n UI:**
```bash
./scripts/fix-workflow-ids.sh
./scripts/fix-workflow-modes.sh
```

---

## Workflow Architecture

```
Main Orchestrator
├── Fetch Company Snippet (11)
├── Fetch Enrichment Data (10)
├── Scan Google Drive (02)
├── Download & Extract (Tika)
├── Analyze Document (08/09) ──┬── Aggregate → Generate Documents (12,13,14)
│                              │                    ↓
│                              │              Generate Visuals (16)
│                              │                    ↓
│                              │              Upload to Drive (18)
│                              │
│                              └── Document Updater (21) → Upload Updated Docs
└── Notify Completion
```

## Workflows

| ID | Name | Description |
|----|------|-------------|
| 01 | Main Orchestrator | Main workflow that coordinates all sub-workflows |
| 02 | Google Drive Scanner | Scans folders for documents |
| 08 | Document Analyzer OpenAI | Analyzes documents with GPT-4 |
| 09 | Document Analyzer Gemini | Analyzes documents with Gemini |
| 10 | External Data Enricher | Fetches external enrichment data |
| 11 | Company Snippet Fetcher | Fetches company information |
| 12 | Corporate Overview Generator | Generates corporate overview docs |
| 13 | Product Datasheet Generator | Generates product datasheets |
| 14 | Higher Ed One-Pager Generator | Generates higher ed one-pagers |
| 16 | Visual Asset Generator | Generates visuals for documents |
| 18 | Google Drive Uploader | Uploads documents to Drive |
| 19 | Error Orchestrator | Handles workflow errors |
| 20 | Error Notifier | Sends error notifications |
| 21 | Document Updater | Checks for and applies document updates |

---

## Troubleshooting

### Workflow not found error
If you see "The workflow with ID X does not exist" after import:
```bash
./scripts/fix-workflow-ids.sh
```

### Execute Workflow mode reset
If Execute Workflow nodes are set to "Run once with all items" instead of "Run once for each item":
```bash
./scripts/fix-workflow-modes.sh
```

### Tika connection error
If you see "ENOTFOUND host.docker.internal":
- The Tika URL should be `http://n8n-tika:9998/tika` (not `host.docker.internal`)
- This is already configured correctly in the workflow JSON files

### Credentials not found
After importing workflows, credentials need to be re-linked:
1. Open each workflow with credential errors
2. Click on nodes with red credential icons
3. Select the correct credential from the dropdown

### Workflows not visible
If workflows are imported but not visible in the UI:
```bash
docker exec -i n8n-postgres-new psql -U n8n -d n8n -c "
INSERT INTO shared_workflow (\"workflowId\", \"projectId\", \"role\", \"createdAt\", \"updatedAt\")
SELECT id, (SELECT id FROM project LIMIT 1), 'workflow:owner', NOW(), NOW()
FROM workflow_entity
ON CONFLICT DO NOTHING;
"
```

### Docker containers not starting
```bash
cd docker
docker compose down
docker compose up -d
```

### Database reset (start fresh)
```bash
cd docker
docker compose down -v  # This deletes all data!
docker compose up -d
# Then re-import workflows
./scripts/import-workflows.sh
```

---

## License

Proprietary - OneOrigin
