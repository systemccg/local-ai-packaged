# Multi-Tenant Document Upload Approaches

**Date**: 2025-11-07
**Workflow**: LeadingAI RAG AI Agent V5 - Multi-Tenant

This document outlines three approaches for uploading documents with proper tenant attribution in the RAG system.

---

## Summary Comparison

| Approach | Best For | Tenant Attribution | Duplicate Detection | Ease of Use | Security |
|----------|----------|-------------------|---------------------|-------------|----------|
| **Approach 1: Multiple Google Drive Folders** | Current teams using Google Drive | Automatic (folder-based) | Built-in (hash check) | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Approach 2: Web Interface (Future)** | External users, customers | Login-based (JWT) | Built-in (hash check) | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Approach 3: Webhook API** | Programmatic uploads, integrations | API key + payload | Built-in (hash check) | ⭐⭐⭐ | ⭐⭐⭐⭐ |

---

## Approach 1: Multiple Google Drive Folder Triggers

### Overview
Watch separate Google Drive folders, each mapped to a specific tenant. When files are uploaded, the workflow automatically extracts tenant context from the folder mapping.

### How It Works

```
Google Drive Folder 1 (Greg/CoCreators)
  ↓ File Created/Updated Trigger
  ↓ Loop Over Items
  ↓ Map Folder to Tenant → Extracts: tenant_id, user_id, email, role
  ↓ Set Tenant Context
  ↓ Set File ID
  ↓ Calculate Content Hash
  ↓ Check Existing Version → If hash changed, create new version
  ↓ Download & Process File
  ↓ Insert to document_metadata + documents_pg

Google Drive Folder 2 (Joanna/IOM)
  ↓ (same flow as above)
```

### Configuration

**Current Folder Mappings:**

| Folder Name | Folder ID | Tenant ID | User | Email |
|-------------|-----------|-----------|------|-------|
| Docs_for_RAG (CoCreators) | `18q2yQ-vWjk8I9Isd7Oz1F3h-FrNxkvtF` | `mk3029839` | Greg | gwasmuth@gmail.com |

**To Add More Folders:**

1. **Create Google Drive folder** for the tenant
2. **Copy the folder ID** from the folder URL:
   ```
   https://drive.google.com/drive/folders/FOLDER_ID_HERE
   ```
3. **Add folder trigger in n8n workflow**:
   - Duplicate the "File Created" and "File Updated" nodes
   - Change the `folderToWatch` to the new folder ID
   - Connect to the same "Loop Over Items" node

4. **Add mapping in "Map Folder to Tenant" node**:
   ```javascript
   const folderMap = {
     '18q2yQ-vWjk8I9Isd7Oz1F3h-FrNxkvtF': {
       tenant_id: 'mk3029839',
       user_id: 'b6015d8d-e018-46b2-a1ff-3598a13f10c1',
       email: 'gwasmuth@gmail.com',
       role: 'admin'
     },
     'NEW_FOLDER_ID_HERE': {
       tenant_id: 'test-tenant-001',
       user_id: 'another-user-uuid',
       email: 'jowasmuth@gmail.com',
       role: 'admin'
     }
     // Add more as needed
   };
   ```

### Duplicate Detection

The workflow includes **automatic duplicate and update detection**:

1. **Content Hash Calculation**: SHA-256 hash of file content
2. **Version Check**: Compares new hash with existing document hash
3. **Version Management**:
   - If file is new → Creates document
   - If file exists but hash unchanged → Skips processing
   - If file exists and hash changed → Creates new version

**Database Version Tracking:**
- `document_metadata` table stores:
  - `content_hash` - SHA-256 hash of file
  - `version_number` - Incremental version
  - `is_current` - Boolean flag for current version
  - `is_deleted` - Soft delete flag

### Pros
- ✅ Dead simple for users (just drag-drop to folder)
- ✅ Automatic tenant attribution
- ✅ Built-in duplicate detection
- ✅ File update handling
- ✅ Works for teams already using Google Drive

### Cons
- ❌ Requires Google account access
- ❌ All tenant files visible to folder admins
- ❌ Limited to Google Drive users
- ❌ Folder proliferation with many tenants

### Security Considerations
- 📁 Folder permissions control who can upload
- 🔒 Tenant isolation happens at processing time
- ⚠️ Anyone with folder access can upload for that tenant
- ⚠️ No authentication beyond Google Drive permissions

---

## Approach 2: Web Interface with Login (Future Implementation)

### Overview
Build a custom web interface where users log in with their credentials, then upload files. The system automatically attributes files to the logged-in user's tenant.

### Proposed Architecture

```
User visits upload.leadingai.info
  ↓ Login with Supabase Auth
  ↓ Receives JWT with tenant_id, user_id
  ↓ Uploads file through web form
  ↓ Frontend sends file + JWT to n8n webhook
  ↓ Webhook validates JWT → extracts tenant context
  ↓ Process file with tenant attribution
  ↓ Return upload confirmation
```

### Implementation Plan

**Frontend (upload.leadingai.info):**
- Technology: Next.js + Supabase Auth
- Features:
  - Login/logout
  - File upload form (drag-drop + browse)
  - Upload progress indicator
  - Upload history for user
  - File management (view, delete)

**Backend (n8n webhook):**
- Endpoint: `https://n8n.leadingai.info/webhook/file-upload`
- Authentication: JWT validation
- Processing: Same as Google Drive flow

**Database Integration:**
- Use existing `document_metadata` and `documents_pg` tables
- Add `upload_method` field: 'web_interface', 'google_drive', 'api'

### User Flow

1. User goes to `upload.leadingai.info`
2. Logs in with email/password (Supabase Auth)
3. System generates JWT containing:
   ```json
   {
     "sub": "user-uuid",
     "email": "user@example.com",
     "tenant_id": "mk3029839",
     "role": "admin"
   }
   ```
4. User selects file(s) to upload
5. Frontend sends:
   ```
   POST /webhook/file-upload
   Authorization: Bearer <JWT>
   Content-Type: multipart/form-data

   file: <binary data>
   filename: "document.pdf"
   ```
6. n8n workflow:
   - Validates JWT
   - Extracts tenant context
   - Calculates content hash
   - Checks for duplicates
   - Processes file
   - Returns confirmation

### Duplicate Detection

**Same as Approach 1** - uses content hash comparison:
- Before processing, calculate SHA-256 hash
- Query `document_metadata` for existing document with same hash and tenant
- If found:
  - Same hash → Skip (file unchanged)
  - Different hash → Create new version
- If not found → Create new document

### Pros
- ✅ Full authentication & authorization
- ✅ Per-user access control
- ✅ No Google Drive dependency
- ✅ Branded interface
- ✅ Usage tracking & analytics
- ✅ Can add file management features

### Cons
- ❌ Requires frontend development
- ❌ Additional hosting/maintenance
- ❌ Users must create accounts
- ❌ More complex than folder-drop

### Security Considerations
- 🔐 JWT-based authentication
- 🔐 Supabase RLS policies
- 🔐 Rate limiting on upload endpoint
- 🔐 File type validation
- 🔐 Size limits
- 🔐 Virus scanning (optional)

---

## Approach 3: Webhook API for Programmatic Uploads

### Overview
Provide a webhook endpoint for programmatic uploads. Clients authenticate with API keys and include tenant information in the request payload.

### How It Works

```
External System/Script
  ↓ POST /webhook/file-upload-api
  ↓ Headers: X-API-Key: <api-key>
  ↓ Body: { tenant_id, user_id, file_data, filename }
  ↓ n8n validates API key
  ↓ Extracts tenant from payload
  ↓ Calculate content hash
  ↓ Check for duplicates/updates
  ↓ Process file
  ↓ Return JSON response
```

### API Endpoint Specification

**Endpoint:**
```
POST https://n8n.leadingai.info/webhook/file-upload-api
```

**Headers:**
```
X-API-Key: your-api-key-here
Content-Type: application/json
```

**Request Body:**
```json
{
  "tenant_id": "mk3029839",
  "user_id": "b6015d8d-e018-46b2-a1ff-3598a13f10c1",
  "email": "gwasmuth@gmail.com",
  "filename": "document.pdf",
  "file_data": "base64-encoded-file-content",
  "file_url": "https://example.com/file.pdf",  // Alternative to file_data
  "metadata": {
    "title": "Document Title",
    "description": "Optional description",
    "tags": ["tag1", "tag2"]
  }
}
```

**Response (Success):**
```json
{
  "success": true,
  "file_id": "abc123",
  "status": "created",  // or "updated" or "unchanged"
  "version_number": 1,
  "message": "Document processed successfully",
  "document": {
    "id": "abc123",
    "title": "Document Title",
    "tenant_id": "mk3029839",
    "created_at": "2025-01-06T10:30:00Z"
  }
}
```

**Response (Duplicate - Unchanged):**
```json
{
  "success": true,
  "file_id": "abc123",
  "status": "unchanged",
  "version_number": 2,
  "message": "Document already exists with same content",
  "existing_document": {
    "id": "abc123",
    "content_hash": "sha256-hash",
    "last_updated": "2025-01-05T10:30:00Z"
  }
}
```

**Response (Error):**
```json
{
  "success": false,
  "error": "Invalid API key",
  "code": "UNAUTHORIZED"
}
```

### Duplicate Detection & Updates

**Same content hash-based system:**

1. **Client uploads file**
2. **Webhook calculates SHA-256 hash** of file content
3. **Checks database:**
   ```sql
   SELECT id, version_number, content_hash, is_current
   FROM document_metadata
   WHERE tenant_id = ? AND id = ?
   ORDER BY version_number DESC
   LIMIT 1
   ```
4. **Decision:**
   - **No existing document** → Create new document (version 1)
   - **Existing + same hash** → Return "unchanged" status, skip processing
   - **Existing + different hash** → Create new version (version N+1)

### API Key Management

**Approach:**
- Store API keys in n8n credentials
- Use n8n's header authentication
- Rotate keys per tenant

**Example Configuration in n8n:**
```javascript
// In "Validate API Key" node
const apiKeys = {
  'key-mk3029839-prod': {
    tenant_id: 'mk3029839',
    name: 'CoCreators Production Key'
  },
  'key-test-tenant-001-prod': {
    tenant_id: 'test-tenant-001',
    name: 'IOM Production Key'
  }
};

const providedKey = $('Webhook').item.json.headers['x-api-key'];
const keyConfig = apiKeys[providedKey];

if (!keyConfig) {
  throw new Error('Invalid API key');
}

return [keyConfig];
```

### Example Usage

**cURL:**
```bash
curl -X POST https://n8n.leadingai.info/webhook/file-upload-api \
  -H "X-API-Key: key-mk3029839-prod" \
  -H "Content-Type: application/json" \
  -d '{
    "tenant_id": "mk3029839",
    "user_id": "b6015d8d-e018-46b2-a1ff-3598a13f10c1",
    "email": "gwasmuth@gmail.com",
    "filename": "quarterly-report.pdf",
    "file_url": "https://example.com/reports/q4-2024.pdf",
    "metadata": {
      "title": "Q4 2024 Quarterly Report",
      "department": "Finance"
    }
  }'
```

**Python:**
```python
import requests
import base64

# Read file
with open('document.pdf', 'rb') as f:
    file_data = base64.b64encode(f.read()).decode('utf-8')

# Upload
response = requests.post(
    'https://n8n.leadingai.info/webhook/file-upload-api',
    headers={
        'X-API-Key': 'key-mk3029839-prod',
        'Content-Type': 'application/json'
    },
    json={
        'tenant_id': 'mk3029839',
        'user_id': 'b6015d8d-e018-46b2-a1ff-3598a13f10c1',
        'email': 'gwasmuth@gmail.com',
        'filename': 'document.pdf',
        'file_data': file_data,
        'metadata': {
            'title': 'Important Document',
            'tags': ['finance', 'quarterly']
        }
    }
)

print(response.json())
```

**JavaScript/Node.js:**
```javascript
const fs = require('fs');
const axios = require('axios');

const fileData = fs.readFileSync('document.pdf').toString('base64');

axios.post('https://n8n.leadingai.info/webhook/file-upload-api', {
  tenant_id: 'mk3029839',
  user_id: 'b6015d8d-e018-46b2-a1ff-3598a13f10c1',
  email: 'gwasmuth@gmail.com',
  filename: 'document.pdf',
  file_data: fileData,
  metadata: {
    title: 'Important Document'
  }
}, {
  headers: {
    'X-API-Key': 'key-mk3029839-prod'
  }
})
.then(response => console.log(response.data))
.catch(error => console.error(error.response.data));
```

### Pros
- ✅ Programmatic access
- ✅ Integration with existing systems
- ✅ Bulk uploads possible
- ✅ No UI needed
- ✅ Full control over metadata
- ✅ Built-in duplicate detection
- ✅ Version management

### Cons
- ❌ Requires development to use
- ❌ API key management overhead
- ❌ No visual interface
- ❌ Harder for non-technical users

### Security Considerations
- 🔑 API key authentication
- 🔑 Rate limiting per key
- 🔑 File size limits
- 🔑 File type validation
- 🔑 Tenant validation (key must match tenant_id)
- 🔑 Audit logging of all uploads

---

## Implementation Status

| Approach | Status | Workflow URL |
|----------|--------|--------------|
| **Approach 1: Google Drive Folders** | ✅ **IMPLEMENTED** | https://n8n.leadingai.info/workflow/aQnmDID5D90HKpH2 |
| **Approach 2: Web Interface** | 📋 **PLANNED** | TBD |
| **Approach 3: Webhook API** | 🏗️ **IN PROGRESS** | Will be added to same workflow |

---

## Recommendations

**For Current Use:**
- ✅ **Use Approach 1 (Google Drive Folders)**
- Already implemented and working
- Easy for your current team
- Supports multiple tenants via folder mapping

**For Future Scaling:**
- 🎯 **Implement Approach 2 (Web Interface)**
- Better for external users
- Professional branding
- Complete audit trail

**For Integrations:**
- 🔧 **Implement Approach 3 (Webhook API)**
- Allows automated uploads
- Integration with other systems
- Bulk processing capabilities

**Hybrid Approach:**
- Use **all three simultaneously**!
- Google Drive for internal teams
- Web interface for customers
- API for automated systems
- All share the same backend processing

---

## Next Steps

1. ✅ **Verify Google Drive folder approach** is working correctly
2. 🔧 **Add second Google Drive folder** for Joanna/IOM testing
3. 🏗️ **Implement Webhook API approach** (Approach 3)
4. 📋 **Plan Web Interface** (Approach 2) for future

## Testing Checklist

- [ ] Upload file to CoCreators folder → Verify tenant attribution
- [ ] Upload same file again → Verify duplicate detection (unchanged status)
- [ ] Modify file and re-upload → Verify version increment
- [ ] Add second folder for IOM tenant
- [ ] Upload file to IOM folder → Verify separate tenant isolation
- [ ] Test RAG retrieval for both tenants → Verify isolation
- [ ] Implement webhook API endpoint
- [ ] Test API upload with duplicate detection
- [ ] Test API with file URL vs base64 data
