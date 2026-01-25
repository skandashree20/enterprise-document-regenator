# Setup Guide

This guide will help you deploy the OneOrigin Document Regeneration System.

## Prerequisites

- **Docker** (version 20.10+)
- **Docker Compose** (version 2.0+)
- **Git**
- **8GB+ RAM** recommended for n8n with LLM workflows

### Check Prerequisites

```bash
docker --version
docker compose version
git --version
```

---

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/your-org/enterprise-document-regenator.git
cd enterprise-document-regenator
```

### 2. Configure Environment

```bash
cd docker
cp .env.example .env
```

Edit `.env` with your settings:

```bash
# Generate a secure encryption key
openssl rand -hex 16
# Use this output for N8N_ENCRYPTION_KEY

# Generate secure passwords
openssl rand -base64 24
# Use for POSTGRES_PASSWORD and N8N_BASIC_AUTH_PASSWORD
```

**Minimum required settings:**
```env
POSTGRES_PASSWORD=your-secure-db-password
N8N_ENCRYPTION_KEY=your-32-char-key
N8N_BASIC_AUTH_PASSWORD=your-ui-password
```

### 3. Start the System

```bash
docker compose up -d
```

### 4. Verify Deployment

```bash
# Check container status
docker compose ps

# View logs
docker compose logs -f n8n

# Check health
curl http://localhost:5678/healthz
```

### 5. Access n8n UI

Open http://localhost:5678 in your browser.

Login with:
- Username: `admin` (or your `N8N_BASIC_AUTH_USER`)
- Password: Your `N8N_BASIC_AUTH_PASSWORD`

---

## Import Workflows

After n8n is running, import the 20 workflows using one of these methods:

### Option 1: Docker CLI Import (Recommended)

This is the fastest method - imports all 20 workflows automatically:

```bash
# Navigate to project root
cd /path/to/enterprise-document-regenator

# Import all workflows via n8n CLI
for f in workflows/**/*.json; do
  echo "Importing: $(basename $f)"
  docker cp "$f" n8n-doc-regenerator:/tmp/workflow.json
  docker exec n8n-doc-regenerator n8n import:workflow --input=/tmp/workflow.json
done
```

**One-liner version:**

```bash
for f in workflows/**/*.json; do docker cp "$f" n8n-doc-regenerator:/tmp/workflow.json && docker exec n8n-doc-regenerator n8n import:workflow --input=/tmp/workflow.json; done
```

**Expected output:**
```
Importing: 08-document-analyzer-openai.json
Successfully imported 1 workflow.
Importing: 09-document-analyzer-gemini.json
Successfully imported 1 workflow.
... (20 workflows total)
```

### Option 2: n8n API Import

Requires an API key from n8n:

1. Open n8n UI and go to **Settings → API**
2. Create a new API key
3. Run:

```bash
export N8N_API_KEY="your-api-key"
export N8N_URL="http://localhost:5680"  # or your n8n URL

for f in workflows/**/*.json; do
  echo "Importing: $(basename $f)"
  curl -s -X POST "$N8N_URL/api/v1/workflows" \
    -H "Content-Type: application/json" \
    -H "X-N8N-API-KEY: $N8N_API_KEY" \
    -d @"$f"
done
```

### Option 3: Using Import Script

```bash
cd scripts
chmod +x import-workflows.sh
./import-workflows.sh
```

### Option 4: Manual Import via UI

1. Open n8n UI at http://localhost:5680
2. Go to **Workflows**
3. Click **Import from File**
4. Select each workflow JSON from `workflows/` directory
5. Repeat for all 20 workflow files

**Import Order (if importing manually):**
1. Error handling workflows (19, 20)
2. Output workflows (18)
3. Visual workflows (16, 17)
4. Generation workflows (12-15)
5. Enrichment workflows (10, 11)
6. Analysis workflows (08, 09)
7. Processing workflows (05-07)
8. Ingestion workflows (02-04)
9. Main orchestrator (01)

### Verify Import

After importing, refresh the n8n UI. You should see 20 workflows:

| # | Workflow Name |
|---|---------------|
| 01 | Main Orchestrator |
| 02 | Google Drive Scanner |
| 03 | Document Fetcher |
| 04 | Batch Router |
| 05 | PDF Processor |
| 06 | DOCX Processor |
| 07 | Generic Processor |
| 08 | Document Analyzer OpenAI |
| 09 | Document Analyzer Gemini |
| 10 | External Data Enricher |
| 11 | Company Snippet Fetcher |
| 12 | Corporate Overview Generator |
| 13 | Product Datasheet Generator |
| 14 | Higher Ed One-Pager Generator |
| 15 | Client Document Generator |
| 16 | Visual Asset Generator |
| 17 | Figma Integration |
| 18 | Google Drive Uploader |
| 19 | Error Orchestrator |
| 20 | Error Notifier |

---

## Configure Credentials

After importing workflows, set up credentials in n8n:

1. Go to **Settings > Credentials**
2. Add each required credential (see [CREDENTIALS.md](./CREDENTIALS.md))

**Required credentials:**
- [ ] Google Drive OAuth2 or Service Account
- [ ] Google Docs (can share with Drive credential)
- [ ] OpenAI API
- [ ] Google Gemini API
- [ ] Serper API
- [ ] Brave Search API (optional backup)
- [ ] Tavily API (optional)
- [ ] Nano Banana API
- [ ] Figma API

---

## Configure Workflows

### Set Up Google Drive Folders

1. Open **02-gdrive-scanner.json** workflow
2. In the Set node, configure:
   - `source_folder_ids`: Array of Google Drive folder IDs to scan
   - `output_folder_id`: Where to save generated documents
   - `include_shared_drives`: Set to `true` for ex-employee drives

**How to get folder ID:**
1. Open Google Drive folder in browser
2. URL format: `https://drive.google.com/drive/folders/{FOLDER_ID}`
3. Copy the `FOLDER_ID`

### Set Up Company Snippet

1. Create a Google Doc with your company identity/positioning
2. Copy the document ID from URL
3. Open **11-company-snippet-fetcher.json** workflow
4. Update the Google Docs node with your document ID

### Configure Error Notifications

1. Create a Google Chat webhook (see [CREDENTIALS.md](./CREDENTIALS.md))
2. Open **20-error-notifier.json** workflow
3. Update the HTTP Request node with your webhook URL

---

## Test the System

### 1. Test Individual Workflows

Start with sub-workflows before the orchestrator:

```
1. Test 02-gdrive-scanner with a small folder
2. Test 08-document-analyzer-openai with a single document
3. Test 12-corporate-overview-generator with sample data
4. Test 20-error-notifier manually
```

### 2. Run End-to-End Test

1. Prepare a test folder with 5-10 sample documents
2. Set the folder ID in the main orchestrator
3. Execute the main orchestrator workflow manually
4. Check:
   - Documents are scanned
   - Analysis runs without errors
   - Generated documents appear in output folder
   - Error notifications work (trigger a deliberate error)

---

## Production Deployment

### Secure the Installation

1. **Use HTTPS:**

   Add a reverse proxy (Traefik, Nginx) for SSL:

   ```yaml
   # Add to docker-compose.yml
   services:
     traefik:
       image: traefik:v2.10
       command:
         - "--api.insecure=true"
         - "--providers.docker=true"
         - "--entrypoints.websecure.address=:443"
       ports:
         - "443:443"
       volumes:
         - /var/run/docker.sock:/var/run/docker.sock
   ```

2. **Firewall:**
   - Block direct access to port 5678
   - Only allow through reverse proxy

3. **Backup Strategy:**
   ```bash
   # Backup database
   docker exec n8n-postgres pg_dump -U n8n n8n > backup.sql

   # Backup n8n data
   docker cp n8n-doc-regenerator:/home/node/.n8n ./n8n-backup
   ```

### Set Up Scheduled Runs

1. Open **01-main-orchestrator.json**
2. Configure the Schedule Trigger node:
   - Recommended: Daily at off-peak hours (e.g., 2:00 AM)
   - Or weekly for lower volume

### Monitoring

1. **n8n Metrics:**
   - Access at `http://localhost:5678/metrics`
   - Configure Prometheus/Grafana for dashboards

2. **Container Logs:**
   ```bash
   # Follow logs
   docker compose logs -f

   # Save logs
   docker compose logs > logs.txt
   ```

---

## Scaling Considerations

### High Volume (1000+ documents)

1. **Enable Queue Mode:**
   ```env
   EXECUTIONS_MODE=queue
   QUEUE_BULL_REDIS_HOST=redis
   ```

   Add Redis to docker-compose.yml:
   ```yaml
   redis:
     image: redis:7-alpine
     networks:
       - n8n-network
   ```

2. **Increase Memory:**
   ```env
   NODE_OPTIONS=--max-old-space-size=8192
   ```

3. **Use Worker Nodes:**
   - Deploy multiple n8n instances
   - Share the same database
   - Use queue mode for distribution

---

## Troubleshooting

### n8n Won't Start

```bash
# Check logs
docker compose logs n8n

# Common issues:
# - Port already in use: Change N8N_PORT
# - Database connection: Wait for postgres to be ready
# - Memory: Increase Docker memory limit
```

### Workflows Not Found

```bash
# Ensure workflows are imported
# Check if n8n can read the files
docker exec n8n-doc-regenerator ls -la /workflows
```

### Database Issues

```bash
# Reset database (WARNING: loses all data)
docker compose down -v
docker compose up -d
```

### Permission Errors

```bash
# Fix volume permissions
sudo chown -R 1000:1000 ./docker/local-files
```

---

## Updating

### Update n8n Version

```bash
# Pull latest image
docker compose pull

# Restart with new version
docker compose up -d

# Check logs for migration issues
docker compose logs -f n8n
```

### Update Workflows

1. Export modified workflows from development
2. Copy to `workflows/` directory
3. Re-import in production n8n

---

## Getting Help

- **n8n Documentation:** https://docs.n8n.io/
- **n8n Community:** https://community.n8n.io/
- **Project Issues:** [Your issue tracker URL]
