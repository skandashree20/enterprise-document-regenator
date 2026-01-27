# OneOrigin Enterprise Document Regeneration System

An AI-powered n8n workflow system that automatically ingests, analyzes, enriches, and regenerates corporate documents for OneOrigin.

## Overview

This system:

- **Ingests** documents from Google Drive (including subfolders)
- **Enriches** with real-time industry context (EdTech news, FERPA updates, higher ed trends, AI news)
- **Fetches** company identity from a dedicated Google Doc for brand consistency
- **Analyzes** content using OpenAI GPT-4 to extract themes, entities, and relevance scores
- **Updates** existing documents with fresh research and industry context
- **Generates** new corporate documents aligned with company identity and latest trends
- **Creates** visual assets (presentation slides) with industry-informed content
- **Uploads** all outputs back to Google Drive

---

## Complete Workflow Architecture

```
                          ┌─────────────────────────────────┐
                          │       TRIGGER                   │
                          │   (Schedule: 2 AM daily)        │
                          │   (Webhook: /run-regeneration)  │
                          └───────────────┬─────────────────┘
                                          │
                                          ▼
                          ┌─────────────────────────────────┐
                          │    Initialize Variables         │
                          │  - source_folder_ids            │
                          │  - output_folder_id             │
                          │  - batch_size: 5                │
                          └───────────────┬─────────────────┘
                                          │
                    ┌─────────────────────┼─────────────────────┐
                    │                     │                     │
                    ▼                     ▼                     ▼
     ┌──────────────────────┐  ┌──────────────────┐  ┌───────────────────┐
     │  11 - Company        │  │  10 - External   │  │   Pass-through    │
     │  Snippet Fetcher     │  │  Data Enricher   │  │   (config data)   │
     │                      │  │                  │  │                   │
     │  Fetches brand       │  │  4 Parallel      │  │                   │
     │  identity from       │  │  Serper searches │  │                   │
     │  Google Doc          │  │                  │  │                   │
     └──────────┬───────────┘  └────────┬─────────┘  └─────────┬─────────┘
                │                       │                      │
                └───────────────────────┼──────────────────────┘
                                        │
                                        ▼
                          ┌─────────────────────────────────┐
                          │       Merge & Combine Context   │
                          │  - company_snippet              │
                          │  - enrichment_data              │
                          │    (edtech_news, ferpa_updates, │
                          │     higher_ed_trends,           │
                          │     ai_tech_news)               │
                          └───────────────┬─────────────────┘
                                          │
                                          ▼
                          ┌─────────────────────────────────┐
                          │    02 - Google Drive Scanner    │
                          │                                 │
                          │  Scans root + subfolders        │
                          │  Filters by supported types     │
                          │  Returns document list          │
                          └───────────────┬─────────────────┘
                                          │
                                          ▼
                          ┌─────────────────────────────────┐
                          │     Split Into Batches (5)      │
                          └───────────────┬─────────────────┘
                                          │
        ┌─────────────────────────────────┼─────────────────────────────────┐
        │ (Loop output)                   │                                 │
        │                                 ▼                                 │
        │              ┌─────────────────────────────────┐                  │
        │              │    Download from Google Drive   │                  │
        │              └───────────────┬─────────────────┘                  │
        │                              │                                    │
        │                              ▼                                    │
        │              ┌─────────────────────────────────┐                  │
        │              │      Tika Extract Text          │                  │
        │              │  (PDF, DOCX, PPTX, etc.)        │                  │
        │              └───────────────┬─────────────────┘                  │
        │                              │                                    │
        │                              ▼                                    │
        │              ┌─────────────────────────────────┐                  │
        │              │  08 - Document Analyzer OpenAI  │                  │
        │              │                                 │                  │
        │              │  Extracts:                      │                  │
        │              │  - themes, key_points, quotes   │                  │
        │              │  - entities (products, clients) │                  │
        │              │  - compliance_mentions          │                  │
        │              │  - recommended_output scores    │                  │
        │              └───────────────┬─────────────────┘                  │
        │                              │                                    │
        │                              ▼                                    │
        │              ┌─────────────────────────────────┐                  │
        │              │      Accumulate Results         │                  │
        │              │  (stores in static data)        │                  │
        │              └───────────────┬─────────────────┘                  │
        │                              │                                    │
        │                              ▼                                    │
        │              ┌─────────────────────────────────┐                  │
        │              │     21 - Document Updater       │                  │
        │              │                                 │                  │
        │              │  For EACH analyzed document:    │                  │
        │              │  1. Extract keywords from       │                  │
        │              │     analysis themes/entities    │                  │
        │              │  2. Run targeted web searches   │                  │
        │              │  3. Combine with enrichment     │                  │
        │              │  4. LLM decides if update needed│                  │
        │              │  5. Generates updated content   │                  │
        │              └───────────────┬─────────────────┘                  │
        │                              │                                    │
        │           ┌──────────────────┴──────────────────┐                 │
        │           │                                     │                 │
        │           ▼                                     ▼                 │
        │  ┌────────────────────┐            ┌─────────────────────┐        │
        │  │ needs_update=true  │            │ needs_update=false  │        │
        │  │ Upload Updated Doc │            │ Log Skipped         │        │
        │  └────────┬───────────┘            └─────────────────────┘        │
        │           │                                                       │
        │           └────────────────────────┬──────────────────────────────┘
        │                                    │
        │                                    ▼
        └────────────────────────────► Loop back to next batch
                                             │
                                             │ (Done output - all batches complete)
                                             ▼
                          ┌─────────────────────────────────┐
                          │     Retrieve All Results        │
                          │  (gets accumulated docs)        │
                          └───────────────┬─────────────────┘
                                          │
                                          ▼
                          ┌─────────────────────────────────┐
                          │      Route to Generators        │
                          │                                 │
                          │  Creates 3 generation requests: │
                          │  - Corporate Overview           │
                          │  - Product Datasheet            │
                          │  - Higher Ed One-Pager          │
                          │                                 │
                          │  Each receives:                 │
                          │  - analyzed_documents           │
                          │  - company_snippet              │
                          │  - enrichment_data              │
                          └───────────────┬─────────────────┘
                                          │
            ┌─────────────────────────────┼─────────────────────────────┐
            │                             │                             │
            ▼                             ▼                             ▼
┌───────────────────────┐   ┌───────────────────────┐   ┌───────────────────────┐
│ 12 - Corporate        │   │ 13 - Product          │   │ 14 - Higher Ed        │
│ Overview Generator    │   │ Datasheet Generator   │   │ One-Pager Generator   │
│                       │   │                       │   │                       │
│ Uses:                 │   │ Uses:                 │   │ Uses:                 │
│ - company_snippet     │   │ - company_snippet     │   │ - company_snippet     │
│ - edtech_news         │   │ - ai_tech_news        │   │ - ferpa_updates       │
│ - ferpa_updates       │   │ - edtech_news         │   │ - higher_ed_trends    │
│ - higher_ed_trends    │   │ - ferpa_updates       │   │ - edtech_news         │
│ - ai_tech_news        │   │ - higher_ed_trends    │   │ - ai_tech_news        │
└───────────┬───────────┘   └───────────┬───────────┘   └───────────┬───────────┘
            │                           │                           │
            └───────────────────────────┼───────────────────────────┘
                                        │
                                        ▼
                          ┌─────────────────────────────────┐
                          │  16 - Visual Asset Generator    │
                          │                                 │
                          │  For EACH generated document:   │
                          │  - Creates presentation slides  │
                          │  - Uses company_snippet         │
                          │  - Incorporates industry        │
                          │    highlights from enrichment   │
                          └───────────────┬─────────────────┘
                                          │
                                          ▼
                          ┌─────────────────────────────────┐
                          │   18 - Google Drive Uploader    │
                          │                                 │
                          │  Uploads:                       │
                          │  - Generated markdown docs      │
                          │  - HTML presentation previews   │
                          └───────────────┬─────────────────┘
                                          │
                                          ▼
                          ┌─────────────────────────────────┐
                          │       Generate Summary          │
                          │  - Documents generated count    │
                          │  - Upload success/failure       │
                          └───────────────┬─────────────────┘
                                          │
                                          ▼
                          ┌─────────────────────────────────┐
                          │    Notify via Google Chat       │
                          └─────────────────────────────────┘
```

---

## Detailed Workflow Descriptions

### Phase 1: Initialization & Context Gathering

#### Triggers
The Main Orchestrator can be triggered two ways:
- **Schedule Trigger**: Runs daily at 2 AM (`0 2 * * *`)
- **Manual Webhook**: POST to `/run-regeneration`

#### Initialize Variables
Sets up the execution context:
- `source_folder_ids`: Google Drive folders to scan (JSON array)
- `output_folder_id`: Where to save generated documents
- `batch_size`: Number of documents to process per batch (default: 5)

---

### Phase 2: Enrichment Data Fetching

#### 11 - Company Snippet Fetcher

**Purpose**: Fetches OneOrigin's brand identity from a dedicated Google Doc to ensure all generated content maintains consistent messaging.

**Process**:
1. Reads the configured Google Doc ID
2. Extracts text content from the document
3. Parses sections (mission, vision, values, products, services, differentiators, target market)
4. Returns structured `company_snippet` object

**Output Structure**:
```json
{
  "company_snippet": {
    "raw_content": "Full text of the company identity document",
    "title": "OneOrigin Company Identity",
    "sections": {
      "mission": "...",
      "vision": "...",
      "products": "...",
      "services": "...",
      "differentiators": "...",
      "target_market": "..."
    }
  }
}
```

**Fallback**: If the Google Doc is unavailable, returns a default company snippet with standard OneOrigin messaging.

---

#### 10 - External Data Enricher

**Purpose**: Gathers real-time industry context via Serper API to ensure generated content reflects current trends and developments.

**Four Parallel Searches**:

| Search | Query | API Endpoint | Purpose |
|--------|-------|--------------|---------|
| EdTech News | "EdTech trends higher education 2025 digital transformation learning" | `/search` | Latest EdTech industry developments |
| FERPA Updates | "FERPA compliance updates 2025 student data privacy regulations education" | `/news` | Compliance and regulatory changes |
| Higher Ed Trends | "higher education technology trends 2025 accreditation automation universities" | `/search` | Educational technology trends |
| AI Tech News | "AI artificial intelligence education technology 2025 machine learning EdTech" | `/news` | AI developments relevant to EdTech |

**Process**:
1. Defines 4 search queries
2. Executes all 4 Serper API calls in parallel
3. Tags each response with `_source` identifier (edtech, ferpa, higher_ed, ai_tech)
4. Merges all results using append mode with 4 inputs
5. Structures results into categorized arrays

**Output Structure**:
```json
{
  "edtech_news": [
    { "title": "...", "snippet": "...", "link": "...", "source": "serper" }
  ],
  "ferpa_updates": [
    { "title": "...", "snippet": "...", "link": "...", "date": "...", "source": "serper" }
  ],
  "higher_ed_trends": [
    { "title": "...", "snippet": "...", "link": "...", "source": "serper" }
  ],
  "ai_tech_news": [
    { "title": "...", "snippet": "...", "link": "...", "date": "...", "source": "serper" }
  ],
  "fetch_timestamp": "2025-01-27T...",
  "sources_queried": 4,
  "total_results": 20
}
```

---

### Phase 3: Document Ingestion

#### 02 - Google Drive Scanner

**Purpose**: Scans configured Google Drive folders (including subfolders) and returns a list of supported documents.

**Process**:
1. Receives folder IDs from Main Orchestrator config
2. Lists root folder contents via Google Drive API
3. Identifies subfolders and files separately
4. For each subfolder, lists its contents
5. Filters files by supported extensions
6. Returns combined document list

**Supported File Types**:
- Documents: `pdf`, `docx`, `doc`, `txt`, `md`
- Presentations: `pptx`, `ppt`
- Spreadsheets: `xlsx`, `xls`, `csv`
- Data: `json`

**Output**: Array of document objects with `file_id`, `file_name`, `mime_type`, `extension`, `modified_time`, `size`, `web_link`

---

### Phase 4: Document Processing & Analysis

#### Text Extraction (Tika)

**Purpose**: Extracts text content from various document formats using Apache Tika.

**Process**:
1. Downloads document binary from Google Drive
2. Sends to Tika service (`http://n8n-tika:9998/tika`)
3. Receives plain text extraction
4. Cleans and normalizes text (removes excessive newlines, trims)

**Supports**: PDF, DOCX, PPTX, TXT, MD, and most common document formats

---

#### 08 - Document Analyzer OpenAI

**Purpose**: Analyzes extracted text using GPT-4 to extract structured information for document generation.

**Analysis Extracts**:
- `summary`: 2-3 sentence document summary
- `document_type`: sales, technical, proposal, marketing, internal, legal, other
- `themes`: Main topics and themes
- `entities`: Products, clients, technologies mentioned
- `edtech_relevance`: Higher ed context, compliance mentions, transcript processing relevance
- `key_points`: Important facts and statements
- `quotes`: Notable quotes
- `recommended_output`: Relevance scores (0-1) for each document type
- `confidence`: Overall analysis confidence

**Sample Output**:
```json
{
  "analysis": {
    "summary": "This document describes AIRR's transcript processing capabilities...",
    "document_type": "technical",
    "themes": ["transcript automation", "higher education", "compliance"],
    "entities": {
      "products": ["AIRR", "Transcript Processing System"],
      "clients": ["Arizona State University", "MIT"],
      "technologies": ["OCR", "Machine Learning", "NLP"]
    },
    "edtech_relevance": {
      "higher_ed_context": "Focuses on university registrar operations",
      "compliance_mentions": ["FERPA", "AAMVA", "SOC 2"],
      "transcript_processing": "Core focus on automated transcript evaluation"
    },
    "key_points": ["Reduces processing time by 90%", "Handles 500+ institutions"],
    "recommended_output": {
      "corporate_overview": 0.7,
      "product_datasheet": 0.95,
      "higher_ed_onepager": 0.8,
      "client_document": 0.6
    }
  }
}
```

---

### Phase 5: Document Updating

#### 21 - Document Updater

**Purpose**: Determines if existing documents need updates based on new research and industry context, and generates updated versions.

**Keyword Extraction Process**:

The workflow extracts search keywords from the document analysis:

1. **From Themes** (up to 3):
   - Example: `["transcript automation", "compliance", "higher education"]`

2. **From Product Entities** (up to 2):
   - Example: `["AIRR", "Transcript Processing System"]`

3. **From Technology Entities** (up to 2):
   - Example: `["OCR", "Machine Learning"]`

4. **From Compliance Mentions** (all):
   - Example: `["FERPA", "SOC 2", "AAMVA"]`

5. **Query Transformation**:
   - FERPA mention → `"FERPA compliance updates 2024 2025"`
   - SOC mention → `"SOC 2 compliance requirements updates"`
   - Transcript mention → `"academic transcript processing technology updates"`
   - AIRR mention → `"AIRR transcript automation higher education"`
   - Generic topic → `"{topic} higher education EdTech updates 2024 2025"`

**Research & Update Flow**:

```
┌─────────────────────────────────────────────────────────────────┐
│                   Document Updater Workflow                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  INPUT: analyzed document + enrichment_data + company_snippet   │
│                                                                  │
│  1. EXTRACT RESEARCH TOPICS                                     │
│     ├─ analysis.themes → ["transcript automation", "compliance"]│
│     ├─ analysis.entities.products → ["AIRR"]                    │
│     ├─ analysis.entities.technologies → ["OCR", "ML"]           │
│     └─ analysis.edtech_relevance.compliance_mentions → ["FERPA"]│
│                                                                  │
│  2. GENERATE SEARCH QUERIES                                     │
│     ├─ "FERPA compliance updates 2024 2025"                     │
│     ├─ "AIRR transcript automation higher education"            │
│     └─ "transcript automation higher education EdTech updates"  │
│                                                                  │
│  3. EXECUTE TARGETED SEARCHES (Serper API)                      │
│     └─ Gets document-specific recent developments               │
│                                                                  │
│  4. COMPILE ALL RESEARCH                                        │
│     ├─ Document-specific search results                         │
│     ├─ Pre-fetched edtech_news                                  │
│     ├─ Pre-fetched ferpa_updates                                │
│     ├─ Pre-fetched higher_ed_trends                             │
│     └─ Pre-fetched ai_tech_news                                 │
│                                                                  │
│  5. LLM ANALYSIS (GPT-4)                                        │
│     INPUT:                                                       │
│     ├─ Company Identity (company_snippet)                       │
│     ├─ Original Document Text                                   │
│     ├─ Document-Specific Research Findings                      │
│     └─ Pre-Fetched Industry Context (all 4 categories)          │
│                                                                  │
│     DECIDES:                                                    │
│     ├─ needs_update: true/false                                 │
│     ├─ update_summary: "Added FERPA 2025 updates..."            │
│     ├─ updated_sections: [{section, original, updated, reason}] │
│     └─ updated_document: Full updated text with [UPDATED] tags  │
│                                                                  │
│  OUTPUT: Updated document (if needed) ready for upload          │
└─────────────────────────────────────────────────────────────────┘
```

**How Enrichment Data is Used in Document Updater**:

The LLM receives a comprehensive context including:

```markdown
## COMPANY IDENTITY
[Company snippet content for brand consistency]

## ORIGINAL DOCUMENT
[Full document text]

## DOCUMENT-SPECIFIC RESEARCH
### Research: FERPA compliance updates 2024 2025
- **New FERPA Guidance Released**: The Department of Education issued...
- **Student Privacy Trends**: Institutions are adopting...

### Research: AIRR transcript automation higher education
- **Transcript Automation Growth**: Market sees 40% increase...

## PRE-FETCHED INDUSTRY CONTEXT

### EdTech Industry News
- **AI in Education Report 2025**: Major findings show...
- **Learning Management Evolution**: New trends in LMS...

### FERPA & Compliance Updates
- **FERPA Amendment Proposal**: New privacy requirements...
- **State-Level Data Privacy**: California introduces...

### Higher Education Trends
- **Digital Transformation Acceleration**: Universities invest...
- **Credential Innovation**: Micro-credentials gain traction...

### AI & Technology News
- **GPT-5 Education Applications**: New capabilities for...
- **Automated Assessment Tools**: AI grading systems...
```

---

### Phase 6: New Document Generation

All generators receive the same enrichment context to ensure consistency across all generated content.

#### 12 - Corporate Overview Generator

**Purpose**: Generates a comprehensive company overview document.

**Input Context**:
- `company_snippet`: Full brand identity
- `aggregated_themes`: Combined themes from all analyzed documents
- `aggregated_key_points`: Key facts from all documents
- All 4 enrichment categories

**Generated Sections**:
1. Executive Summary
2. About OneOrigin
3. Our Mission & Vision
4. Products & Solutions
5. Services
6. Market Opportunity
7. Why OneOrigin
8. Contact Information

**Enrichment Usage in Prompt**:
```
### EdTech Industry News
{{ $json.enrichment_data.edtech_news }}

### FERPA & Compliance Updates
{{ $json.enrichment_data.ferpa_updates }}

### Higher Education Trends
{{ $json.enrichment_data.higher_ed_trends }}

### AI & Technology News
{{ $json.enrichment_data.ai_tech_news }}
```

---

#### 13 - Product Datasheet Generator

**Purpose**: Creates technical product datasheets for OneOrigin products (primarily AIRR).

**Input Context**:
- `company_snippet`: Brand identity
- `product_info`: Extracted features, benefits, integrations
- All 4 enrichment categories

**Generated Sections**:
1. Product Overview
2. Key Features
3. Benefits
4. Technical Specifications
5. Use Cases
6. Integration Capabilities
7. Compliance & Security (uses FERPA context)
8. Getting Started / Contact

**Enrichment Usage**:
- AI Tech News → Highlights relevant AI capabilities
- EdTech Trends → Positions product in market context
- FERPA Updates → Ensures compliance messaging is current
- Higher Ed Trends → Aligns with industry direction

---

#### 14 - Higher Ed One-Pager Generator

**Purpose**: Creates concise one-page documents for higher education decision-makers.

**Input Context**:
- `company_snippet`: Brand identity
- `higher_ed_info`: Compliance mentions, client references
- All 4 enrichment categories

**Generated Sections**:
1. Headline (attention-grabbing, references current trends)
2. The Challenge (2-3 pain points with industry context)
3. The Solution (OneOrigin's approach)
4. Key Benefits (3-4 bullet points)
5. Compliance Assurance (incorporates FERPA updates)
6. Success Indicators / Social Proof
7. Call to Action

**Enrichment Usage**:
- Higher Ed Trends → Frames challenges and solutions
- FERPA Updates → Current compliance requirements
- EdTech News → Industry positioning
- AI Tech News → Technology differentiation

---

### Phase 7: Visual Asset Generation

#### 16 - Visual Asset Generator

**Purpose**: Creates presentation slide decks from generated documents.

**Process**:
1. Receives generated document content
2. Extracts industry highlights from enrichment data
3. Creates 5-8 slide presentation structure
4. Generates HTML preview of slides

**Industry Highlights Extraction**:
```javascript
let industryHighlights = '';
if (enrichmentData.edtech_news?.length > 0) {
  industryHighlights += 'EdTech: ' + enrichmentData.edtech_news[0].title + '. ';
}
if (enrichmentData.ai_tech_news?.length > 0) {
  industryHighlights += 'AI: ' + enrichmentData.ai_tech_news[0].title + '. ';
}
if (enrichmentData.higher_ed_trends?.length > 0) {
  industryHighlights += 'Higher Ed: ' + enrichmentData.higher_ed_trends[0].title + '.';
}
```

**Slide Generation Prompt Context**:
- `company_snippet`: For brand consistency
- `industry_highlights`: Condensed enrichment for visual context
- `document_content`: Source content for slides

**Output Structure**:
```json
{
  "presentation_title": "OneOrigin: Transforming Higher Education",
  "subtitle": "AI-Powered Transcript Solutions",
  "slides": [
    {
      "slide_number": 1,
      "slide_type": "title",
      "title": "...",
      "bullets": [],
      "speaker_notes": "...",
      "visual_suggestion": "..."
    }
  ],
  "color_scheme": {
    "primary": "#003366",
    "secondary": "#00A86B",
    "accent": "#FFB800"
  },
  "html_preview": "<!DOCTYPE html>..."
}
```

---

### Phase 8: Output & Upload

#### 18 - Google Drive Uploader

**Purpose**: Saves generated documents and visual assets to Google Drive.

**Process**:
1. Receives document content and metadata
2. Creates binary data from markdown/HTML content
3. Uploads to configured output folder
4. Returns upload status with file ID and web link

**Uploaded Files**:
- `OneOrigin_Corporate_Overview_YYYY-MM-DD.md`
- `AIRR_Datasheet_YYYY-MM-DD.md`
- `OneOrigin_HigherEd_OnePager_YYYY-MM-DD.md`
- `{original_file}_updated_YYYY-MM-DD.md` (if updates were needed)

---

## Output Documents

| Document Type | Description | Key Enrichment Sources |
|--------------|-------------|------------------------|
| **Corporate Overview** | Company positioning and identity | All 4 enrichment categories |
| **Product Datasheets** | Technical product documentation | AI Tech News, FERPA Updates |
| **Higher Ed One-Pagers** | Quick reference for education | FERPA Updates, Higher Ed Trends |
| **Updated Documents** | Refreshed existing documents | Document-specific + all enrichment |
| **Visual Assets** | Presentation slides | Industry highlights summary |

---

## Quick Start

```bash
# 1. Clone and configure
cd docker
cp .env.example .env
# Edit .env with your settings

# 2. Start n8n
docker compose up -d

# 3. Access n8n UI
open http://localhost:5680

# 4. Import workflows
for f in workflows/**/*.json; do
  docker cp "$f" n8n-doc-regenerator:/tmp/workflow.json
  docker exec n8n-doc-regenerator n8n import:workflow --input=/tmp/workflow.json
done

# 5. Configure credentials in n8n UI (Settings → Credentials)
```

---

## Required Credentials

| Credential | Purpose | Used By |
|------------|---------|---------|
| Google Drive OAuth2 | Document ingestion + upload | Scanner, Uploader |
| Google Docs OAuth2 | Company snippet | Snippet Fetcher |
| OpenAI API | Document analysis + generation | Analyzer, Generators, Updater |
| Serper API (Header Auth) | Web search | Enricher, Updater |
| Google Chat Webhook | Notifications | Main Orchestrator |

---

## Configuration

### Environment Variables

See [docker/.env.example](../docker/.env.example) for all configuration options.

### Workflow Settings

Key settings in Main Orchestrator's "Initialize Variables" node:
- `source_folder_ids`: JSON array of Google Drive folder IDs to scan
- `output_folder_id`: Destination folder for generated documents
- `batch_size`: Documents per batch (default: 5)

---

## Workflow Files

| # | Workflow | File | Purpose |
|---|----------|------|---------|
| 01 | Main Orchestrator | `workflows/main/01-main-orchestrator.json` | Central coordinator |
| 02 | Google Drive Scanner | `workflows/ingestion/02-gdrive-scanner.json` | Scans source folders |
| 08 | Document Analyzer OpenAI | `workflows/analysis/08-document-analyzer-openai.json` | AI document analysis |
| 10 | External Data Enricher | `workflows/enrichment/10-external-data-enricher.json` | Industry context |
| 11 | Company Snippet Fetcher | `workflows/enrichment/11-company-snippet-fetcher.json` | Brand identity |
| 12 | Corporate Overview Generator | `workflows/generation/12-corporate-overview-generator.json` | Company docs |
| 13 | Product Datasheet Generator | `workflows/generation/13-product-datasheet-generator.json` | Product docs |
| 14 | Higher Ed One-Pager Generator | `workflows/generation/14-higher-ed-onepager-generator.json` | Higher ed docs |
| 16 | Visual Asset Generator | `workflows/visuals/16-visual-asset-generator.json` | Presentations |
| 18 | Google Drive Uploader | `workflows/output/18-gdrive-uploader.json` | Saves output |
| 21 | Document Updater | `workflows/processing/21-document-updater.json` | Updates existing docs |

---

## Documentation

- [SETUP.md](./SETUP.md) - Full deployment guide
- [CREDENTIALS.md](./CREDENTIALS.md) - API credentials setup
- [WORKFLOWS.md](./WORKFLOWS.md) - Detailed workflow documentation

---

## License

Proprietary - OneOrigin
