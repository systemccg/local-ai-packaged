# Workflow Two-Flow Architecture

**Date**: 2025-11-07
**Workflow**: LeadingAI RAG AI Agent V5 - Multi-Tenant

---

## Overview

The workflow has **TWO SEPARATE FLOWS** with different tenant context nodes. Understanding this is critical for debugging expression errors.

---

## The Two Flows

### Flow 1: Upload Flow (Google Drive)

**Trigger**: File uploaded to Google Drive folder

```
File Created/Updated (Google Drive)
  ↓
Loop Over Items
  ↓
Map Folder to Tenant ⭐ (Extracts tenant from folder ID)
  ↓
Set Tenant Context (GDrive) ⭐⭐ IMPORTANT NODE
  ↓
Set File ID
  ↓
Soft Delete Old Documents
  ↓
Soft Delete Old Document Rows
  ↓
Insert Document Metadata ⭐ Uses $('Set Tenant Context (GDrive)')
  ↓
Download File
  ↓
Calculate Content Hash
  ↓
Check Existing Version
  ↓
Content Changed? → Create New Version
  ↓
Switch (by file type)
  ↓
Extract (PDF/Excel/CSV/Text)
  ↓
Insert Table Rows / Postgres PGVector Store
```

**Key Tenant Context Node**: `Set Tenant Context (GDrive)`

**Nodes that MUST reference this:**
- Insert Document Metadata
- Insert Table Rows
- Update Schema for Document Metadata
- Soft Delete Old Documents
- Soft Delete Old Document Rows

### Flow 2: Query Flow (Webhook/JWT)

**Trigger**: User sends query via webhook

```
Webhook
  ↓
JWT Validate & Extract Tenant ⭐ (Extracts from JWT token)
  ↓
Set Tenant Context ⭐⭐ DIFFERENT NODE
  ↓
Edit Fields
  ↓
RAG AI Agent
  ↓
Tools (query with tenant isolation):
    - List Documents ⭐ Uses $('Set Tenant Context')
    - Get File Contents ⭐ Uses $('Set Tenant Context')
    - Query Document Rows ⭐ Uses $('Set Tenant Context')
    - Postgres PGVector Store (retrieval) ⭐ Uses $('Set Tenant Context')
    - Graph Tool
```

**Key Tenant Context Node**: `Set Tenant Context`

**Nodes that MUST reference this:**
- List Documents
- Get File Contents
- Query Document Rows
- Postgres PGVector Store (retrieval mode)

---

## Common Error: "Invalid expression"

### Symptom
```
Problem in node 'Insert Document Metadata'
Invalid expression
```

### Cause
Node is in the **Upload Flow** but referencing the wrong tenant context node:
- ❌ Wrong: `$('Set Tenant Context')` (from webhook flow)
- ✅ Correct: `$('Set Tenant Context (GDrive)')` (from Google Drive flow)

### Fix
Check which flow the node belongs to:

**Upload Flow nodes** should reference:
```javascript
$('Set Tenant Context (GDrive)').item.json.tenant_id
$('Set Tenant Context (GDrive)').item.json.user_id
$('Set Tenant Context (GDrive)').item.json.created_by
```

**Query Flow nodes** should reference:
```javascript
$('Set Tenant Context').item.json.tenant_id
$('Set Tenant Context').item.json.user_id
$('Set Tenant Context').item.json.created_by
```

---

## Why Two Separate Nodes?

### Different Sources of Tenant Context

**Google Drive Uploads:**
- Tenant determined by **folder ID**
- No JWT token available
- Mapping: Folder ID → Tenant ID
- Set in: `Map Folder to Tenant` node
- Stored in: `Set Tenant Context (GDrive)` node

**Webhook Queries:**
- Tenant determined by **JWT token**
- Token validated in: `JWT Validate & Extract Tenant` node
- Payload decoded: `{ tenant_id, user_id, email, role }`
- Stored in: `Set Tenant Context` node

### Why Not Merge Them?

They execute in **completely different execution contexts**:
- Upload flow runs when Google Drive triggers
- Query flow runs when webhook receives request
- They never execute in the same workflow run
- Each needs its own context storage

---

## Debugging Checklist

When you see "Invalid expression" errors:

1. **Identify which flow the error is in**
   - Upload/processing? → Should use `Set Tenant Context (GDrive)`
   - Query/RAG? → Should use `Set Tenant Context`

2. **Check the execution path**
   - Follow the connections from trigger to the error node
   - Which tenant context node is in that path?

3. **Verify the reference**
   - Open the node in n8n UI
   - Check parameter expressions
   - Make sure they reference the correct node

4. **Test both flows separately**
   - Test upload: Upload file to Google Drive
   - Test query: Use test workflow with JWT token

---

## Node Reference Table

| Node Name | Flow | Tenant Context Reference |
|-----------|------|--------------------------|
| Insert Document Metadata | Upload | `Set Tenant Context (GDrive)` |
| Insert Table Rows | Upload | `Set Tenant Context (GDrive)` |
| Update Schema for Document Metadata | Upload | `Set Tenant Context (GDrive)` |
| Soft Delete Old Documents | Upload | `Set Tenant Context (GDrive)` |
| Soft Delete Old Document Rows | Upload | `Set Tenant Context (GDrive)` |
| List Documents | Query | `Set Tenant Context` |
| Get File Contents | Query | `Set Tenant Context` |
| Query Document Rows | Query | `Set Tenant Context` |
| Postgres PGVector Store (retrieve) | Query | `Set Tenant Context` |
| Postgres PGVector Store1 (insert) | Upload | Uses metadata from chunks |

---

## Recent Fixes (Nov 7, 2025)

### Issue 1: Query Parameter Format
**Error**: "Query Parameters must be a string of comma-separated values or an array of values"

**Fixed nodes:**
- Soft Delete Old Documents
- Soft Delete Old Document Rows

**Solution**: Changed from `$1` placeholder with `queryReplacement` to direct `{{ }}` expression substitution.

### Issue 2: Invalid Expression
**Error**: "Invalid expression" in Insert Document Metadata

**Fixed nodes:**
- Insert Document Metadata
- Insert Table Rows
- Update Schema for Document Metadata

**Solution**: Changed references from `$('Set Tenant Context')` to `$('Set Tenant Context (GDrive)')`.

---

## Testing Both Flows

### Test Upload Flow
```bash
# Upload file to Google Drive folder
# Folder: 18q2yQ-vWjk8I9Isd7Oz1F3h-FrNxkvtF
# Expected: File processes with tenant_id = 'mk3029839'

# Verify in database:
docker exec supabase-db psql -U postgres postgres -c "
  SELECT id, tenant_id, title, created_by
  FROM document_metadata
  WHERE tenant_id = 'mk3029839'
  ORDER BY created_at DESC
  LIMIT 5;"
```

### Test Query Flow
```bash
# Use test workflow at:
# https://n8n.leadingai.info/workflow/PsuX5LMowdnkkyZy

# Or send webhook request:
curl -X POST https://n8n.leadingai.info/webhook/bf4dd093-bb02-472c-9454-7ab9af97bd1d \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "chatInput": "What documents do we have?",
    "sessionId": "test-session-123"
  }'
```

---

## Visual Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Upload Flow (Left Side)                  │
│                                                              │
│  Google Drive Trigger                                        │
│         ↓                                                    │
│  Map Folder → Set Tenant Context (GDrive) ← Use This!      │
│         ↓                                                    │
│  [All upload/processing nodes]                              │
│                                                              │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    Query Flow (Right Side)                   │
│                                                              │
│  Webhook Trigger                                             │
│         ↓                                                    │
│  JWT Validate → Set Tenant Context ← Use This!             │
│         ↓                                                    │
│  RAG AI Agent → [Tool nodes]                                │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Future: Third Flow (Webhook Upload API)

When Approach 3 is implemented, there will be a third flow:

```
Webhook Upload API Trigger
  ↓
Validate API Key → Extract Tenant from Payload
  ↓
Set Tenant Context (API) ← New node
  ↓
[Same processing as Google Drive flow]
```

This will require another set of nodes or a unified approach.

---

**Last Updated**: 2025-11-07
**Status**: Active - workflow fully functional with both flows
