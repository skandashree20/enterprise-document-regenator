# OneOrigin Enterprise Document Regeneration System

An AI-powered n8n workflow system that automatically ingests, analyzes, and regenerates corporate documents for OneOrigin.

## Overview

This system:

- **Ingests** documents from Google Drive (including ex-employee drives)
- **Analyzes** content using OpenAI GPT-4 and Google Gemini
- **Enriches** with external EdTech/Higher Ed news and trends
- **Generates** updated corporate documents aligned with company identity
- **Creates** visual assets using Nano Banana/Figma
- **Handles errors** with auto-fix attempts and Google Chat notifications

## Output Documents

1. **Corporate Overview** - Company positioning and identity
2. **Product Datasheets** - For any OneOrigin product (AIRR, etc.)
3. **Higher Ed One-Pagers** - Quick reference docs for education services
4. **Client-Specific Documents** - Custom docs for clients
5. **Visual Assets** - Slides, infographics, brochures

## Quick Start

```bash
# 1. Clone and configure
cd docker
cp .env.example .env
# Edit .env with your settings (change port if 5678 is in use)

# 2. Start n8n
docker compose up -d

# 3. Access n8n UI
open http://localhost:5680  # or your configured port

# 4. Import all 20 workflows via CLI (recommended)
cd ..  # back to project root
for f in workflows/**/*.json; do
  docker cp "$f" n8n-doc-regenerator:/tmp/workflow.json
  docker exec n8n-doc-regenerator n8n import:workflow --input=/tmp/workflow.json
done

# 5. Configure credentials in n8n UI (Settings → Credentials)
```

**One-liner to import all workflows:**
```bash
for f in workflows/**/*.json; do docker cp "$f" n8n-doc-regenerator:/tmp/workflow.json && docker exec n8n-doc-regenerator n8n import:workflow --input=/tmp/workflow.json; done
```

## Documentation

- [SETUP.md](./SETUP.md) - Full deployment guide
- [CREDENTIALS.md](./CREDENTIALS.md) - API credentials setup
- [WORKFLOWS.md](./WORKFLOWS.md) - Workflow documentation

## Architecture

```
[Schedule/Manual Trigger]
        │
        ▼
┌─────────────────────────────────────────┐
│         MAIN ORCHESTRATOR               │
└─────────────────────────────────────────┘
        │
        ├──► Company Snippet (Google Doc)
        ├──► External Enrichment (Serper/Brave/Tavily)
        │
        ▼
┌─────────────────────────────────────────┐
│         DOCUMENT INGESTION              │
│  Google Drive Scanner → Batch Router    │
└─────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────┐
│         PROCESSING & ANALYSIS           │
│  PDF/DOCX Processors → LLM Analyzers    │
└─────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────┐
│         DOCUMENT GENERATION             │
│  Corporate Overview, Product Datasheets │
│  Higher Ed One-Pagers, Client Docs      │
└─────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────┐
│         VISUAL GENERATION               │
│  Nano Banana / Figma Integration        │
└─────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────┐
│         OUTPUT                          │
│  Upload to Google Drive                 │
└─────────────────────────────────────────┘
```

## Workflows

| #     | Workflow             | Purpose                 |
| ----- | -------------------- | ----------------------- |
| 01    | Main Orchestrator    | Central coordinator     |
| 02    | Google Drive Scanner | Scans source folders    |
| 03    | Document Fetcher     | Downloads documents     |
| 04    | Batch Router         | Routes by file type     |
| 05-07 | Processors           | PDF, DOCX, Generic      |
| 08-09 | Analyzers            | OpenAI, Gemini          |
| 10    | External Enricher    | Web search for context  |
| 11    | Snippet Fetcher      | Company identity        |
| 12-15 | Generators           | Document types          |
| 16-17 | Visual Gen           | Images and designs      |
| 18    | GDrive Uploader      | Saves output            |
| 19-20 | Error Handling       | Orchestrator + Notifier |

## Configuration

### Required Credentials

- Google Drive (OAuth2 or Service Account)
- OpenAI API
- Google Gemini API
- Serper API (2,500 free/month)
- Brave Search API (2,000 free/month)
- Nano Banana API
- Figma API
- Google Chat Webhook

### Environment Variables

See [docker/.env.example](../docker/.env.example) for all configuration options.

## License

Proprietary - OneOrigin
