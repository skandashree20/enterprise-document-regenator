# Credentials Configuration Guide

This guide explains how to set up all required credentials for the OneOrigin Document Regeneration System.

## Overview

The system requires the following credentials:

| Credential | Purpose | Free Tier |
|------------|---------|-----------|
| Google Drive | Document ingestion + upload | Yes (with Google account) |
| Google Docs | Company snippet | Yes (with Google account) |
| Google Chat | Error notifications | Yes (with Google Workspace) |
| OpenAI | GPT-4 analysis/generation | No (paid API) |
| Google Gemini | Gemini analysis | Yes (limited) |
| Serper | Web search | 2,500/month |
| Brave Search | Backup web search | 2,000/month |
| Tavily | AI-optimized search | 1,000/month |
| Nano Banana | AI image generation | Varies |
| Figma | Design automation | Yes (limited) |

---

## 1. Google Drive & Docs (OAuth2 / Service Account)

### Option A: OAuth2 (For Personal Drives)

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing
3. Navigate to **APIs & Services > Library**
4. Enable:
   - Google Drive API
   - Google Docs API
5. Go to **APIs & Services > Credentials**
6. Click **Create Credentials > OAuth 2.0 Client ID**
7. Configure consent screen if prompted
8. Select **Desktop App** or **Web Application**
9. Download the JSON credentials

**In n8n:**
1. Go to **Settings > Credentials**
2. Add new **Google Drive OAuth2 API** credential
3. Enter Client ID and Client Secret from downloaded JSON
4. Authorize and grant permissions

### Option B: Service Account (For Ex-Employee Drives)

For accessing shared drives and ex-employee drives, use a service account with domain-wide delegation:

1. In Google Cloud Console, go to **IAM & Admin > Service Accounts**
2. Create a new service account
3. Grant roles: **Viewer** (or custom with Drive access)
4. Click on the service account > **Keys > Add Key > Create New Key**
5. Download JSON key file

**Enable Domain-Wide Delegation:**
1. In service account details, enable **Domain-wide Delegation**
2. Copy the **Client ID**
3. In **Google Workspace Admin Console**:
   - Go to **Security > API Controls > Domain-wide Delegation**
   - Add new delegation with the Client ID
   - Add scopes:
     ```
     https://www.googleapis.com/auth/drive.readonly
     https://www.googleapis.com/auth/drive.file
     https://www.googleapis.com/auth/documents.readonly
     ```

**In n8n:**
1. Add new **Google Drive API** credential
2. Select **Service Account**
3. Paste the entire JSON key content
4. Enter the email of a user to impersonate (optional, for domain-wide access)

---

## 2. Google Chat Webhook

1. Open the Google Chat space where you want notifications
2. Click the space name at the top
3. Select **Apps & integrations**
4. Click **Add webhooks**
5. Enter a name (e.g., "Document Regeneration Alerts")
6. Click **Save**
7. Copy the webhook URL

**In n8n:**
- Use the webhook URL directly in HTTP Request nodes
- No credential setup needed, just use the URL

---

## 3. OpenAI API

1. Go to [OpenAI Platform](https://platform.openai.com/)
2. Sign up or log in
3. Navigate to **API Keys**
4. Click **Create new secret key**
5. Copy the key (you won't see it again)

**In n8n:**
1. Add new **OpenAI** credential
2. Paste the API key

**Recommended Model:** `gpt-4o` (best balance of quality and cost)

**Cost Considerations:**
- GPT-4o: ~$5 per 1M input tokens, ~$15 per 1M output tokens
- For large documents, consider chunking or using `gpt-4o-mini` for initial analysis

---

## 4. Google Gemini API

1. Go to [Google AI Studio](https://aistudio.google.com/)
2. Sign in with Google account
3. Click **Get API Key** in the left sidebar
4. Create a new API key

**In n8n:**
1. Add new **Google Gemini Chat Model** credential
2. Paste the API key

**Free Tier Limits:**
- 60 requests per minute
- 1 million tokens per minute
- 1,500 requests per day

---

## 5. Serper API (Web Search)

1. Go to [Serper.dev](https://serper.dev/)
2. Sign up for free account
3. Go to **Dashboard > API Key**
4. Copy your API key

**In n8n:**
- Use in HTTP Request nodes with header: `X-API-KEY: your-key`

**Free Tier:** 2,500 searches/month

**Example Request:**
```json
POST https://google.serper.dev/search
Headers: X-API-KEY: your-key
Body: {"q": "EdTech trends 2024", "num": 10}
```

---

## 6. Brave Search API

1. Go to [Brave Search API](https://brave.com/search/api/)
2. Click **Get Started**
3. Create account and subscription (Free tier available)
4. Generate API key from dashboard

**In n8n:**
- Use in HTTP Request nodes with header: `X-Subscription-Token: your-key`

**Free Tier:** 2,000 queries/month

**Example Request:**
```
GET https://api.search.brave.com/res/v1/web/search?q=FERPA+compliance&count=10
Headers: X-Subscription-Token: your-key
```

---

## 7. Tavily API (AI-Optimized Search)

1. Go to [Tavily](https://tavily.com/)
2. Sign up for free account
3. Get API key from dashboard

**In n8n:**
- Use in HTTP Request nodes

**Free Tier:** 1,000 API credits/month

**Example Request:**
```json
POST https://api.tavily.com/search
Body: {
  "api_key": "your-key",
  "query": "higher education technology trends",
  "max_results": 10
}
```

---

## 8. Nano Banana API (AI Image Generation)

1. Go to [Nano Banana](https://www.nanobanana.com/) or equivalent service
2. Sign up and get API access
3. Generate API key

**In n8n:**
- Configure as HTTP Request with appropriate headers
- Or use dedicated n8n node if available

**Note:** Check current pricing and limits on their website.

---

## 9. Figma API

1. Go to [Figma](https://www.figma.com/)
2. Log in to your account
3. Go to **Settings > Personal Access Tokens**
4. Generate a new token with description

**In n8n:**
1. Add new **Figma** credential (if native node exists)
2. Or use HTTP Request with header: `X-Figma-Token: your-token`

**API Endpoints:**
- Files: `GET https://api.figma.com/v1/files/{file_key}`
- Components: `GET https://api.figma.com/v1/files/{file_key}/components`

---

## Credential Storage Best Practices

1. **Never commit credentials to Git**
   - Use `.env` files (added to `.gitignore`)
   - Store sensitive values in n8n's credential system

2. **Use n8n's built-in credential encryption**
   - Set `N8N_ENCRYPTION_KEY` in your environment
   - Back up this key securely

3. **Rotate credentials regularly**
   - Set reminders to rotate API keys quarterly
   - Update in n8n immediately after rotation

4. **Limit credential scope**
   - Use read-only credentials where possible
   - Create separate credentials for different environments

---

## Testing Credentials

After setting up each credential, test it in n8n:

1. **Google Drive:**
   - Create a simple workflow with Google Drive node
   - Try listing files in a test folder

2. **OpenAI/Gemini:**
   - Create a workflow with a Chat Model node
   - Send a simple test prompt

3. **Search APIs:**
   - Create HTTP Request nodes for each API
   - Execute a test search query

4. **Google Chat:**
   - Send a test message via HTTP Request to webhook URL

---

## Troubleshooting

### "Invalid Credentials" Error
- Verify API key is correct (no extra spaces)
- Check if key has expired
- Ensure required scopes are enabled

### "Rate Limit Exceeded"
- Add delays between requests in workflow
- Use multiple API providers for load balancing
- Upgrade to paid tier if needed

### "Permission Denied" for Google Drive
- Verify OAuth scopes are correct
- For service account: ensure domain-wide delegation is configured
- Check folder sharing permissions

### "Model Not Found" for LLMs
- Verify you have access to the model (some require special access)
- Check model name spelling
- Try fallback model (e.g., `gpt-3.5-turbo` instead of `gpt-4`)
