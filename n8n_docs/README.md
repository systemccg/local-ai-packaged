# n8n RAG Workflow Documentation Hub

**Last Updated**: 2025-11-07
**Project**: Multi-Tenant RAG AI Agent with n8n

---

## 📚 Quick Navigation

### 🚨 Critical - Start Here

| Document | Purpose | When to Use |
|----------|---------|-------------|
| **[RECOVERY_GUIDE.md](./RECOVERY_GUIDE.md)** | Resume after session loss/crash | **Always read this first when resuming** |
| **[WORKFLOW_ISSUES_AND_FIXES.md](./WORKFLOW_ISSUES_AND_FIXES.md)** | Known issues & solutions | When debugging workflow problems |
| **[MULTI_TENANT_UPLOAD_APPROACHES.md](./MULTI_TENANT_UPLOAD_APPROACHES.md)** | Upload strategies & duplicate detection | When setting up document uploads |

### 📖 Implementation Guides

| Document | Purpose | Covers |
|----------|---------|--------|
| **[MULTI_TENANT_TESTING_GUIDE.md](./MULTI_TENANT_TESTING_GUIDE.md)** | Testing procedures | JWT tokens, tenant isolation, RAG queries |
| **[PHASE1_SCHEMA_DESIGN.md](./PHASE1_SCHEMA_DESIGN.md)** | Database architecture | Multi-tenancy, versioning, audit logs |
| **[SUPABASE_AUTH_INTEGRATION.md](./SUPABASE_AUTH_INTEGRATION.md)** | Authentication setup | JWT validation, Supabase RLS |
| **[WORKFLOW_V5_CHANGES.md](./WORKFLOW_V5_CHANGES.md)** | V5 upgrade details | Technical changes from V4 to V5 |
| **[WORKFLOW_CONNECTION_GUIDE.md](./WORKFLOW_CONNECTION_GUIDE.md)** | Manual workflow connections | n8n UI connection instructions |

### 📊 Status Reports

| Document | Purpose | Date |
|----------|---------|------|
| **[PROGRESS_SUMMARY.md](./PROGRESS_SUMMARY.md)** | Overall project status | Oct 31, 2025 |
| **[TESTING_REPORT.md](./TESTING_REPORT.md)** | Test results & validation | Oct 31, 2025 |
| **[TEST_EXECUTION_SUMMARY_2025-11-05.md](./TEST_EXECUTION_SUMMARY_2025-11-05.md)** | Latest test execution | Nov 5, 2025 |

---

## 🎯 Quick Start by Scenario

### Scenario 1: "I just lost my session - what was I working on?"
1. Read **[RECOVERY_GUIDE.md](./RECOVERY_GUIDE.md)**
2. Check **[PROGRESS_SUMMARY.md](./PROGRESS_SUMMARY.md)** for current status
3. Review **[WORKFLOW_ISSUES_AND_FIXES.md](./WORKFLOW_ISSUES_AND_FIXES.md)** for pending issues

### Scenario 2: "I need to set up document uploads"
1. Read **[MULTI_TENANT_UPLOAD_APPROACHES.md](./MULTI_TENANT_UPLOAD_APPROACHES.md)**
2. Choose your approach:
   - **Approach 1**: Google Drive folders (easiest, currently implemented)
   - **Approach 2**: Web interface (future, for external users)
   - **Approach 3**: Webhook API (for integrations)
3. Follow the implementation guide for your chosen approach

### Scenario 3: "I need to test tenant isolation"
1. Read **[MULTI_TENANT_TESTING_GUIDE.md](./MULTI_TENANT_TESTING_GUIDE.md)**
2. Generate JWT tokens using the provided script
3. Run test workflows with different tenant contexts
4. Verify documents are properly isolated

### Scenario 4: "The workflow isn't working correctly"
1. Check **[WORKFLOW_ISSUES_AND_FIXES.md](./WORKFLOW_ISSUES_AND_FIXES.md)** for known issues
2. Verify workflow connections in **[WORKFLOW_CONNECTION_GUIDE.md](./WORKFLOW_CONNECTION_GUIDE.md)**
3. Review **[TESTING_REPORT.md](./TESTING_REPORT.md)** for test results

### Scenario 5: "I need to understand the database structure"
1. Read **[PHASE1_SCHEMA_DESIGN.md](./PHASE1_SCHEMA_DESIGN.md)**
2. Understand the two-table architecture:
   - `document_metadata` - Source document tracking
   - `documents_pg` - Vector chunks for RAG
3. Review multi-tenancy columns and soft-delete strategy

---

## 🔑 Key Concepts

### Multi-Tenancy
- All tables have `tenant_id` and `user_id` columns
- Tenant isolation enforced at database and workflow level
- JWT tokens contain tenant context
- RLS policies in Supabase for data isolation

### Document Upload Strategies

**Approach 1: Google Drive Folders** ✅ **IMPLEMENTED**
- Each tenant gets a dedicated Google Drive folder
- Folder ID → Tenant mapping in workflow
- Automatic tenant attribution
- Built-in duplicate detection via content hashing

**Approach 2: Web Interface** 📋 **PLANNED**
- Custom upload.leadingai.info with login
- JWT-based authentication
- Professional UI for external users

**Approach 3: Webhook API** 🏗️ **READY TO IMPLEMENT**
- POST endpoint with API key auth
- Programmatic uploads
- Bulk processing support

### Duplicate Detection & Versioning
- **SHA-256 content hashing** detects file changes
- Same hash → Skip (no change)
- Different hash → Create new version
- Version tracking in `document_metadata` table
- Preserves history with `version_number` and `is_current` flags

### Two-Table Architecture
1. **`document_metadata`** (Table OID: 19838)
   - Purpose: Source document tracking
   - View at: https://db.leadingai.info/project/default/editor/19838
   - Used by: n8n tools to list documents

2. **`documents_pg`** (Table OID: 74889)
   - Purpose: Vector chunks for RAG
   - View at: https://db.leadingai.info/project/default/editor/74889
   - Contains: content, embeddings (vector(1536)), metadata (JSONB)

---

## 🔧 Common Commands

### View All Documentation
```bash
ls -lah /root/local-ai-packaged/n8n/docs/
```

### Check Workflow Status
```bash
# List all workflows
docker exec n8n n8n list:workflow

# Export specific workflow
docker exec n8n n8n export:workflow --id=aQnmDID5D90HKpH2 --output=/tmp/workflow.json
```

### Check Database Tables
```bash
# Connect to Supabase database
docker exec -it supabase-db psql -U postgres postgres

# Check document_metadata
SELECT tenant_id, COUNT(*) as doc_count
FROM document_metadata
WHERE is_deleted = FALSE
GROUP BY tenant_id;

# Check documents_pg (vector chunks)
SELECT tenant_id, COUNT(*) as chunk_count
FROM documents_pg
WHERE is_deleted = FALSE
GROUP BY tenant_id;
```

### Generate Test JWT Tokens
```bash
python3 /root/local-ai-packaged/n8n/scripts/generate_jwt_tokens.py
```

### Add Test Documents
```bash
# Use v3 script (adds to both tables)
/root/local-ai-packaged/n8n/scripts/add_test_document_v3.sh \
  "<tenant_id>" \
  "<user_email>" \
  "<document_title>" \
  "<document_content>"
```

---

## 📍 Important Locations

### Documentation
```
/root/local-ai-packaged/n8n/docs/          # All docs (THIS LOCATION)
/root/local-ai-packaged/CLAUDE.md          # Main guidance file
/root/local-ai-packaged/WORKFLOW_ISSUES_AND_FIXES.md  # (Deprecated - now in docs/)
```

### Workflows
```
/root/local-ai-packaged/n8n/backup/workflows/
├── V5_Multi_Tenant_RAG_Workflow_Connected.json  # Latest with folder mapping
├── Test_RAG_Agent_Multi_Tenant_Fixed.json       # Test workflow (fixed webhook URL)
└── (other versions)
```

### Scripts
```
/root/local-ai-packaged/n8n/scripts/
├── add_test_document_v3.sh        # Add documents for testing
├── generate_jwt_tokens.py         # Generate test JWT tokens
├── create_test_users.sql          # Create test users in database
└── upgrade_workflow_to_v5.py      # V5 upgrade script (already run)
```

### Database Migrations
```
/root/local-ai-packaged/n8n/migrations/
├── 001_add_multi_tenancy_v2.sql   # ✅ Executed
├── 002_add_versioning.sql         # ✅ Executed
└── 003_supabase_auth_hook.sql     # ✅ Executed
```

---

## 🚦 Current Project Status

**As of Nov 7, 2025:**

### ✅ Completed
- Multi-tenancy database schema
- Workflow V5 upgrade with tenant isolation
- Google Drive folder-based uploads (Approach 1)
- Duplicate detection via content hashing
- Test workflow with corrected webhook URL
- Comprehensive documentation

### 🏗️ In Progress
- Fixing workflow connections (Set File ID node)
- Webhook API upload approach (Approach 3)

### 📋 Planned
- Web interface for uploads (Approach 2)
- Additional Google Drive folder for IOM tenant
- End-to-end testing with multiple tenants

---

## 🆘 Troubleshooting

### Issue: "Documents don't show up in Supabase"
- **Check both tables**: `document_metadata` AND `documents_pg`
- **Verify tenant_id**: Make sure you're filtering by the correct tenant
- **Check is_deleted flag**: Filter for `is_deleted = FALSE`
- **See**: [WORKFLOW_ISSUES_AND_FIXES.md](./WORKFLOW_ISSUES_AND_FIXES.md)

### Issue: "RAG queries don't return results"
- **Check embeddings**: Documents in `documents_pg` must have embeddings
- **Verify tenant isolation**: Query includes tenant_id filter
- **Check workflow**: Postgres PGVector Store node configuration
- **See**: [MULTI_TENANT_TESTING_GUIDE.md](./MULTI_TENANT_TESTING_GUIDE.md)

### Issue: "Google Drive uploads not attributed to tenant"
- **Check folder mapping**: "Map Folder to Tenant" node configuration
- **Verify connections**: Loop Over Items → Map Folder to Tenant → Set Tenant Context → Set File ID
- **See**: [WORKFLOW_ISSUES_AND_FIXES.md](./WORKFLOW_ISSUES_AND_FIXES.md) - Issue #1

### Issue: "Test workflow can't call main workflow"
- **Check webhook URL**: Should be `/webhook/` not `/webhook-test/`
- **Status**: ✅ Fixed in `Test_RAG_Agent_Multi_Tenant_Fixed.json`
- **See**: [WORKFLOW_ISSUES_AND_FIXES.md](./WORKFLOW_ISSUES_AND_FIXES.md) - Issue #2

---

## 📝 Document Naming Convention

When creating new documentation:
- Use `SCREAMING_SNAKE_CASE.md` for file names
- Always add to `/root/local-ai-packaged/n8n/docs/`
- Update this README.md with the new file
- Include date in header: `**Last Updated**: YYYY-MM-DD`

**Examples:**
- `FEATURE_IMPLEMENTATION_GUIDE.md`
- `DEPLOYMENT_PROCEDURES.md`
- `API_INTEGRATION_GUIDE.md`

---

## 🔗 External Resources

- **n8n Workflow (Live)**: https://n8n.leadingai.info/workflow/aQnmDID5D90HKpH2
- **Test Workflow (Live)**: https://n8n.leadingai.info/workflow/PsuX5LMowdnkkyZy
- **Supabase UI**: https://db.leadingai.info
- **document_metadata Table**: https://db.leadingai.info/project/default/editor/19838
- **documents_pg Table**: https://db.leadingai.info/project/default/editor/74889

---

## 📞 Quick Recovery Prompt for Claude

If you start a new session and need to recover context, use this prompt:

```
Read /root/local-ai-packaged/n8n/docs/README.md and RECOVERY_GUIDE.md.
Give me a complete status summary of the multi-tenant RAG workflow project.
What's completed, what's in progress, and what's next?
```

---

**This documentation hub is your source of truth for the n8n RAG workflow project.**

**All future docs MUST go to `/root/local-ai-packaged/n8n/docs/`**
