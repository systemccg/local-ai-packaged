# Multi-Tenant RAG Agent - Testing Guide

**Date**: November 3, 2025
**Status**: Ready for Testing
**Workflow**: LeadingAI RAG AI Agent V5 - Multi-Tenant (ID: zwRjhxpdTGh10WGE)

---

## Test Users Created

### 👤 Greg Wasmuth (CoCreators Tenant)

- **Email**: gwasmuth@gmail.com
- **Password**: Gr3at-Thing5
- **User ID**: `b6015d8d-e018-46b2-a1ff-3598a13f10c1`
- **Tenant ID**: `mk3029839`
- **Tenant Name**: CoCreators
- **Role**: admin

**JWT Token** (valid for 24 hours):
```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJiNjAxNWQ4ZC1lMDE4LTQ2YjItYTFmZi0zNTk4YTEzZjEwYzEiLCJlbWFpbCI6Imd3YXNtdXRoQGdtYWlsLmNvbSIsInRlbmFudF9pZCI6Im1rMzAyOTgzOSIsInJvbGUiOiJhZG1pbiIsImlhdCI6MTc2MjIwOTQ1OSwiZXhwIjoxNzYyMjk1ODU5fQ.z1Zw0EB64Iox-hCsn7_k2yXKGmwgsa9dk-43QaWpyKM
```

---

### 👤 Joanna Wasmuth (IOM Tenant)

- **Email**: jowasmuth@gmail.com
- **Password**: Gr3at-Thing5
- **User ID**: `9578aa8f-886a-46ea-86ff-e4ccc3d983a1`
- **Tenant ID**: `test-tenant-001`
- **Tenant Name**: IOM
- **Role**: admin

**JWT Token** (valid for 24 hours):
```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI5NTc4YWE4Zi04ODZhLTQ2ZWEtODZmZi1lNGNjYzNkOTgzYTEiLCJlbWFpbCI6Impvd2FzbXV0aEBnbWFpbC5jb20iLCJ0ZW5hbnRfaWQiOiJ0ZXN0LXRlbmFudC0wMDEiLCJyb2xlIjoiYWRtaW4iLCJpYXQiOjE3NjIyMDk0NTksImV4cCI6MTc2MjI5NTg1OX0.eQVlBcSpNhwzzyQ9Ody_EMAeJ9SEBRAOwmnBNUWY3A0
```

---

## Testing Methods

### Method 1: Using the n8n Test Workflow

1. **Import the test workflow**:
   ```bash
   # File location
   /root/local-ai-packaged/n8n/backup/workflows/Test_RAG_Agent_Multi_Tenant.json
   ```

2. **Set environment variables** in n8n (Settings → Environment Variables):
   ```bash
   GREG_JWT_TOKEN=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJiNjAxNWQ4ZC1lMDE4LTQ2YjItYTFmZi0zNTk4YTEzZjEwYzEiLCJlbWFpbCI6Imd3YXNtdXRoQGdtYWlsLmNvbSIsInRlbmFudF9pZCI6Im1rMzAyOTgzOSIsInJvbGUiOiJhZG1pbiIsImlhdCI6MTc2MjIwOTQ1OSwiZXhwIjoxNzYyMjk1ODU5fQ.z1Zw0EB64Iox-hCsn7_k2yXKGmwgsa9dk-43QaWpyKM

   JOANNA_JWT_TOKEN=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI5NTc4YWE4Zi04ODZhLTQ2ZWEtODZmZi1lNGNjYzNkOTgzYTEiLCJlbWFpbCI6Impvd2FzbXV0aEBnbWFpbC5jb20iLCJ0ZW5hbnRfaWQiOiJ0ZXN0LXRlbmFudC0wMDEiLCJyb2xlIjoiYWRtaW4iLCJpYXQiOjE3NjIyMDk0NTksImV4cCI6MTc2MjI5NTg1OX0.eQVlBcSpNhwzzyQ9Ody_EMAeJ9SEBRAOwmnBNUWY3A0
   ```

3. **Run the workflow**:
   - Click "Test as Greg (CoCreators)" to test Greg's access
   - Click "Test as Joanna (IOM)" to test Joanna's access

4. **Verify tenant isolation**:
   - Greg should only see documents from tenant `mk3029839`
   - Joanna should only see documents from tenant `test-tenant-001`

---

### Method 2: Using curl

#### Test as Greg (CoCreators)

```bash
curl -X POST https://n8n.leadingai.info/webhook/rag-chat \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJiNjAxNWQ4ZC1lMDE4LTQ2YjItYTFmZi0zNTk4YTEzZjEwYzEiLCJlbWFpbCI6Imd3YXNtdXRoQGdtYWlsLmNvbSIsInRlbmFudF9pZCI6Im1rMzAyOTgzOSIsInJvbGUiOiJhZG1pbiIsImlhdCI6MTc2MjIwOTQ1OSwiZXhwIjoxNzYyMjk1ODU5fQ.z1Zw0EB64Iox-hCsn7_k2yXKGmwgsa9dk-43QaWpyKM" \
  -H "Content-Type: application/json" \
  -d '{"chatInput": "What documents do I have access to?", "sessionId": "greg-test-1"}'
```

#### Test as Joanna (IOM)

```bash
curl -X POST https://n8n.leadingai.info/webhook/rag-chat \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI5NTc4YWE4Zi04ODZhLTQ2ZWEtODZmZi1lNGNjYzNkOTgzYTEiLCJlbWFpbCI6Impvd2FzbXV0aEBnbWFpbC5jb20iLCJ0ZW5hbnRfaWQiOiJ0ZXN0LXRlbmFudC0wMDEiLCJyb2xlIjoiYWRtaW4iLCJpYXQiOjE3NjIyMDk0NTksImV4cCI6MTc2MjI5NTg1OX0.eQVlBcSpNhwzzyQ9Ody_EMAeJ9SEBRAOwmnBNUWY3A0" \
  -H "Content-Type: application/json" \
  -d '{"chatInput": "What documents do I have access to?", "sessionId": "joanna-test-1"}'
```

---

### Method 3: Using Postman/Thunder Client

**Endpoint**: `https://n8n.leadingai.info/webhook/rag-chat`
**Method**: POST

**Headers**:
```
Authorization: Bearer <JWT_TOKEN>
Content-Type: application/json
```

**Body** (JSON):
```json
{
  "chatInput": "What documents do I have access to?",
  "sessionId": "test-session-1"
}
```

Replace `<JWT_TOKEN>` with either Greg's or Joanna's token from above.

---

## Test Scenarios

### Scenario 1: Basic Document Query

**Greg's Query**:
```json
{
  "chatInput": "List all the documents I have access to",
  "sessionId": "greg-scenario-1"
}
```

**Expected Result**: Only documents from CoCreators tenant (mk3029839)

**Joanna's Query**:
```json
{
  "chatInput": "List all the documents I have access to",
  "sessionId": "joanna-scenario-1"
}
```

**Expected Result**: Only documents from IOM tenant (test-tenant-001)

---

### Scenario 2: Upload Document (Greg)

1. **Upload a test document** to Greg's tenant:
   - Use the RAG workflow's file upload endpoint
   - Include Greg's JWT token
   - Document should be tagged with `tenant_id=mk3029839`

2. **Verify** Greg can see the new document
3. **Verify** Joanna CANNOT see Greg's document

---

### Scenario 3: Cross-Tenant Isolation Test

1. Upload document as Greg → Document ID: `doc-greg-1`
2. Upload document as Joanna → Document ID: `doc-joanna-1`
3. Query as Greg: Should see `doc-greg-1`, NOT `doc-joanna-1`
4. Query as Joanna: Should see `doc-joanna-1`, NOT `doc-greg-1`

---

## Regenerating JWT Tokens

If tokens expire (after 24 hours), regenerate them:

```bash
python3 /root/local-ai-packaged/n8n/scripts/generate_jwt_tokens.py
```

This will generate fresh tokens with the current timestamp.

---

## Verifying Multi-Tenancy in Database

### Check Document Metadata

```sql
-- See all documents by tenant
SELECT tenant_id, id, title, created_by, is_current, is_deleted
FROM document_metadata
ORDER BY tenant_id, created_at DESC;
```

### Check Tenant Users

```sql
-- Verify user-tenant mappings
SELECT tu.tenant_id, t.name as tenant_name, tu.email, tu.role
FROM tenant_users tu
JOIN tenants t ON t.tenant_id = tu.tenant_id
WHERE tu.email IN ('gwasmuth@gmail.com', 'jowasmuth@gmail.com')
ORDER BY tu.tenant_id;
```

### Check Audit Log

```sql
-- View recent document changes by tenant
SELECT tenant_id, document_id, change_type, changed_by, changed_at
FROM document_change_log
ORDER BY changed_at DESC
LIMIT 10;
```

---

## Troubleshooting

### Issue: "Unauthorized" Error

**Cause**: JWT token is invalid or expired
**Solution**: Regenerate tokens using the Python script

### Issue: "No documents found"

**Cause**: Tenant has no documents uploaded yet
**Solution**: Upload a test document to that tenant first

### Issue: Seeing wrong tenant's documents

**Cause**: Workflow connections may not be set up correctly
**Solution**: Verify the "Set Tenant Context" node is receiving the correct `tenant_id` from JWT

### Issue: JWT validation fails

**Cause**: JWT_SECRET mismatch
**Solution**: Ensure JWT_SECRET in generate script matches Supabase: `0xhb7bIcKWuuigEd0rulU4xA6SZ6l93cllRBwB1Y`

---

## Expected JWT Token Structure

The workflow expects JWT tokens with this structure:

```json
{
  "sub": "<user_id>",
  "email": "<user_email>",
  "tenant_id": "<tenant_id>",
  "role": "<user_role>",
  "iat": <issued_at_timestamp>,
  "exp": <expiration_timestamp>
}
```

**Critical Field**: `tenant_id` - This is used to filter all database queries

---

## Files Reference

- **Test Workflow**: `/root/local-ai-packaged/n8n/backup/workflows/Test_RAG_Agent_Multi_Tenant.json`
- **Token Generator**: `/root/local-ai-packaged/n8n/scripts/generate_jwt_tokens.py`
- **User Creation Script**: `/root/local-ai-packaged/n8n/scripts/create_test_users.sql`
- **Testing Report**: `/root/local-ai-packaged/n8n/docs/TESTING_REPORT.md`
- **Progress Summary**: `/root/local-ai-packaged/n8n/PROGRESS_SUMMARY.md`

---

## Next Steps

1. ✅ Test basic queries for both users
2. ✅ Upload test documents to each tenant
3. ✅ Verify tenant isolation
4. ⏳ Test document versioning (upload same doc twice)
5. ⏳ Test soft-delete and restore
6. ⏳ Test knowledge graph integration (Phase 2)
7. ⏳ Test OCR and field extraction (Phase 3)

---

**Status**: ✅ Multi-tenant authentication and authorization ready for testing!
**Database**: All migrations applied successfully
**Workflow**: Version detection nodes connected
**Users**: Greg (CoCreators) and Joanna (IOM) ready to test

Happy testing! 🚀
