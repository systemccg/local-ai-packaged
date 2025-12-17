# Phase 1: Multi-Tenancy & Versioning Database Schema Design

**Project**: n8n RAG Workflow V5 Improvement
**Phase**: 1 - Multi-Tenancy & Versioning Foundation
**Date**: October 30, 2025
**Status**: Design Complete, Ready for Implementation

---

## Executive Summary

This document defines the database schema changes required to add multi-tenant support and document versioning to the n8n RAG AI Agent workflow. The design ensures:

- **Complete tenant data isolation** via tenant_id filtering and Row Level Security (RLS)
- **Full version history** for all documents with soft-delete preservation
- **Backward compatibility** with existing V3 workflow during migration
- **Performance optimization** through strategic indexing

---

## Current Schema Analysis

###Current Tables (Inferred from V3 Workflow):

**1. documents_pg** (PGVector table)
```sql
-- Current structure (inferred):
id SERIAL PRIMARY KEY,
text TEXT,
metadata JSONB,  -- Contains: {file_id, file_title}
embedding VECTOR(1536),  -- nomic-embed-text dimensions
created_at TIMESTAMP DEFAULT NOW()
```

**2. document_metadata**
```sql
CREATE TABLE document_metadata (
    id TEXT PRIMARY KEY,           -- File path (e.g., "/data/shared/document.pdf")
    title TEXT,                    -- File name without extension
    created_at TIMESTAMP DEFAULT NOW(),
    schema TEXT                    -- JSON array of column names (for CSV/Excel)
);
```

**3. document_rows**
```sql
CREATE TABLE document_rows (
    id SERIAL PRIMARY KEY,
    dataset_id TEXT REFERENCES document_metadata(id),  -- File path
    row_data JSONB                 -- Entire row as JSON object
);
```

---

## New Schema Design

### 1. Multi-Tenancy Fields

**Required columns to add to ALL tables:**

```sql
tenant_id TEXT NOT NULL,           -- Organization/customer identifier
user_id TEXT,                      -- Individual user within tenant (optional)
created_by TEXT,                   -- User who created the record
updated_by TEXT,                   -- User who last updated the record
```

**Rationale**:
- `tenant_id`: Primary isolation boundary. All queries MUST filter by this.
- `user_id`: Enables user-level tracking within a tenant for audit purposes.
- `created_by/updated_by`: Audit trail for compliance requirements.

### 2. Versioning Fields

**Required columns for document_metadata and documents_pg:**

```sql
version_number INTEGER DEFAULT 1,
is_current BOOLEAN DEFAULT TRUE,
is_deleted BOOLEAN DEFAULT FALSE,
content_hash TEXT,                 -- SHA-256 of document content
superseded_by TEXT,                -- Reference to newer version file_id
superseded_at TIMESTAMP,
deleted_at TIMESTAMP,
deleted_by TEXT
```

**Rationale**:
- `version_number`: Sequential version tracking (1, 2, 3...)
- `is_current`: Fast filtering for latest version without complex queries
- `is_deleted`: Soft-delete flag (never physically delete)
- `content_hash`: Detect unchanged files to skip reprocessing
- `superseded_by`: Link to replacement document for version chains
- Deletion timestamps: Complete audit trail

---

## Updated Table Schemas

### 1. documents_pg (Vector Embeddings)

```sql
-- UPDATED SCHEMA
ALTER TABLE documents_pg ADD COLUMN tenant_id TEXT NOT NULL DEFAULT 'default';
ALTER TABLE documents_pg ADD COLUMN user_id TEXT;
ALTER TABLE documents_pg ADD COLUMN version_number INTEGER DEFAULT 1;
ALTER TABLE documents_pg ADD COLUMN is_current BOOLEAN DEFAULT TRUE;
ALTER TABLE documents_pg ADD COLUMN is_deleted BOOLEAN DEFAULT FALSE;
ALTER TABLE documents_pg ADD COLUMN created_by TEXT;
ALTER TABLE documents_pg ADD COLUMN updated_at TIMESTAMP;
ALTER TABLE documents_pg ADD COLUMN updated_by TEXT;
ALTER TABLE documents_pg ADD COLUMN deleted_at TIMESTAMP;
ALTER TABLE documents_pg ADD COLUMN deleted_by TEXT;

-- Indexes for performance
CREATE INDEX idx_documents_pg_tenant ON documents_pg(tenant_id);
CREATE INDEX idx_documents_pg_tenant_current ON documents_pg(tenant_id, is_current) WHERE is_current = TRUE;
CREATE INDEX idx_documents_pg_deleted ON documents_pg(is_deleted) WHERE is_deleted = FALSE;

-- Composite index for common query pattern
CREATE INDEX idx_documents_pg_tenant_file ON documents_pg(tenant_id, (metadata->>'file_id'));
```

### 2. document_metadata

```sql
-- UPDATED SCHEMA
ALTER TABLE document_metadata ADD COLUMN tenant_id TEXT NOT NULL DEFAULT 'default';
ALTER TABLE document_metadata ADD COLUMN user_id TEXT;
ALTER TABLE document_metadata ADD COLUMN version_number INTEGER DEFAULT 1;
ALTER TABLE document_metadata ADD COLUMN is_current BOOLEAN DEFAULT TRUE;
ALTER TABLE document_metadata ADD COLUMN is_deleted BOOLEAN DEFAULT FALSE;
ALTER TABLE document_metadata ADD COLUMN content_hash TEXT;
ALTER TABLE document_metadata ADD COLUMN superseded_by TEXT;
ALTER TABLE document_metadata ADD COLUMN superseded_at TIMESTAMP;
ALTER TABLE document_metadata ADD COLUMN created_by TEXT;
ALTER TABLE document_metadata ADD COLUMN updated_at TIMESTAMP;
ALTER TABLE document_metadata ADD COLUMN updated_by TEXT;
ALTER TABLE document_metadata ADD COLUMN deleted_at TIMESTAMP;
ALTER TABLE document_metadata ADD COLUMN deleted_by TEXT;

-- Additional metadata fields for Phase 4
ALTER TABLE document_metadata ADD COLUMN file_size BIGINT;
ALTER TABLE document_metadata ADD COLUMN mime_type TEXT;
ALTER TABLE document_metadata ADD COLUMN page_count INTEGER;
ALTER TABLE document_metadata ADD COLUMN source TEXT;              -- 'upload', 'email', 'api', etc.
ALTER TABLE document_metadata ADD COLUMN language TEXT DEFAULT 'en';
ALTER TABLE document_metadata ADD COLUMN processing_status TEXT;    -- 'pending', 'processing', 'completed', 'failed'
ALTER TABLE document_metadata ADD COLUMN processing_duration_ms INTEGER;
ALTER TABLE document_metadata ADD COLUMN document_type TEXT;        -- 'insurance', 'contract', 'financial', 'general'
ALTER TABLE document_metadata ADD COLUMN custom_tags TEXT[];
ALTER TABLE document_metadata ADD COLUMN confidence_score DECIMAL;  -- Document classification confidence

-- Indexes
CREATE INDEX idx_metadata_tenant ON document_metadata(tenant_id);
CREATE INDEX idx_metadata_tenant_current ON document_metadata(tenant_id, is_current) WHERE is_current = TRUE;
CREATE INDEX idx_metadata_hash ON document_metadata(content_hash);
CREATE INDEX idx_metadata_type ON document_metadata(tenant_id, document_type);
CREATE INDEX idx_metadata_status ON document_metadata(processing_status) WHERE processing_status != 'completed';
```

### 3. document_rows

```sql
-- UPDATED SCHEMA
ALTER TABLE document_rows ADD COLUMN tenant_id TEXT NOT NULL DEFAULT 'default';
ALTER TABLE document_rows ADD COLUMN user_id TEXT;
ALTER TABLE document_rows ADD COLUMN is_deleted BOOLEAN DEFAULT FALSE;
ALTER TABLE document_rows ADD COLUMN created_by TEXT;
ALTER TABLE document_rows ADD COLUMN deleted_at TIMESTAMP;
ALTER TABLE document_rows ADD COLUMN deleted_by TEXT;

-- Indexes
CREATE INDEX idx_rows_tenant ON document_rows(tenant_id);
CREATE INDEX idx_rows_tenant_dataset ON document_rows(tenant_id, dataset_id);
```

---

## New Tables

### 4. document_versions (Version History Tracking)

```sql
CREATE TABLE document_versions (
    id SERIAL PRIMARY KEY,
    tenant_id TEXT NOT NULL,
    original_file_id TEXT NOT NULL,    -- Base file_id without version suffix
    version_number INTEGER NOT NULL,
    file_id TEXT NOT NULL,              -- Full versioned file_id
    content_hash TEXT NOT NULL,
    file_size BIGINT,
    created_at TIMESTAMP DEFAULT NOW(),
    created_by TEXT,
    change_summary TEXT,                -- Optional description of changes
    metadata JSONB,                     -- Snapshot of document_metadata at version creation
    UNIQUE(tenant_id, original_file_id, version_number)
);

CREATE INDEX idx_versions_tenant ON document_versions(tenant_id);
CREATE INDEX idx_versions_file ON document_versions(tenant_id, original_file_id);
CREATE INDEX idx_versions_hash ON document_versions(content_hash);
```

### 5. extracted_fields (Structured Data - Phase 3)

```sql
CREATE TABLE extracted_fields (
    id SERIAL PRIMARY KEY,
    tenant_id TEXT NOT NULL,
    document_id TEXT NOT NULL,          -- References document_metadata.id
    field_name TEXT NOT NULL,
    field_value TEXT,
    field_type TEXT,                    -- 'string', 'number', 'date', 'boolean', 'array'
    confidence DECIMAL,                 -- 0.0 to 1.0
    extraction_method TEXT,             -- 'llm', 'ocr', 'regex', 'manual'
    extracted_at TIMESTAMP DEFAULT NOW(),
    extracted_by TEXT,
    is_valid BOOLEAN DEFAULT TRUE,
    validation_errors JSONB,
    UNIQUE(tenant_id, document_id, field_name)
);

CREATE INDEX idx_fields_tenant ON extracted_fields(tenant_id);
CREATE INDEX idx_fields_document ON extracted_fields(tenant_id, document_id);
CREATE INDEX idx_fields_name ON extracted_fields(tenant_id, field_name);
CREATE INDEX idx_fields_value ON extracted_fields(tenant_id, field_name, field_value);
```

### 6. document_change_log (Audit Trail)

```sql
CREATE TABLE document_change_log (
    id SERIAL PRIMARY KEY,
    tenant_id TEXT NOT NULL,
    document_id TEXT NOT NULL,
    version_from INTEGER,
    version_to INTEGER,
    change_type TEXT NOT NULL,          -- 'created', 'updated', 'deleted', 'restored', 'accessed'
    changed_by TEXT,
    changed_at TIMESTAMP DEFAULT NOW(),
    change_details JSONB,               -- Detailed change information
    ip_address INET,
    user_agent TEXT
);

CREATE INDEX idx_changelog_tenant ON document_change_log(tenant_id);
CREATE INDEX idx_changelog_document ON document_change_log(tenant_id, document_id);
CREATE INDEX idx_changelog_type ON document_change_log(change_type);
CREATE INDEX idx_changelog_time ON document_change_log(changed_at DESC);
```

### 7. tenants (Tenant Management - Optional)

```sql
CREATE TABLE tenants (
    tenant_id TEXT PRIMARY KEY,
    tenant_name TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    is_active BOOLEAN DEFAULT TRUE,
    subscription_tier TEXT,             -- 'free', 'pro', 'enterprise'
    max_documents INTEGER,
    max_storage_gb INTEGER,
    settings JSONB,
    metadata JSONB
);

CREATE INDEX idx_tenants_active ON tenants(is_active) WHERE is_active = TRUE;
```

### 8. tenant_users (User Management - Optional)

```sql
CREATE TABLE tenant_users (
    id SERIAL PRIMARY KEY,
    tenant_id TEXT NOT NULL REFERENCES tenants(tenant_id),
    user_id TEXT NOT NULL,
    email TEXT,
    role TEXT,                          -- 'admin', 'editor', 'viewer'
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW(),
    last_login TIMESTAMP,
    UNIQUE(tenant_id, user_id)
);

CREATE INDEX idx_users_tenant ON tenant_users(tenant_id);
CREATE INDEX idx_users_email ON tenant_users(email);
```

---

## Row Level Security (RLS) Policies

**Enable RLS on Supabase:**

```sql
-- Enable RLS on all tables
ALTER TABLE documents_pg ENABLE ROW LEVEL SECURITY;
ALTER TABLE document_metadata ENABLE ROW LEVEL SECURITY;
ALTER TABLE document_rows ENABLE ROW LEVEL SECURITY;
ALTER TABLE extracted_fields ENABLE ROW LEVEL SECURITY;
ALTER TABLE document_change_log ENABLE ROW LEVEL SECURITY;

-- Create policies for tenant isolation
CREATE POLICY tenant_isolation_documents_pg ON documents_pg
    USING (tenant_id = current_setting('app.current_tenant', TRUE));

CREATE POLICY tenant_isolation_metadata ON document_metadata
    USING (tenant_id = current_setting('app.current_tenant', TRUE));

CREATE POLICY tenant_isolation_rows ON document_rows
    USING (tenant_id = current_setting('app.current_tenant', TRUE));

CREATE POLICY tenant_isolation_fields ON extracted_fields
    USING (tenant_id = current_setting('app.current_tenant', TRUE));

CREATE POLICY tenant_isolation_changelog ON document_change_log
    USING (tenant_id = current_setting('app.current_tenant', TRUE));

-- Service role bypass (for n8n operations)
CREATE POLICY service_role_bypass_documents ON documents_pg
    TO service_role
    USING (TRUE)
    WITH CHECK (TRUE);

CREATE POLICY service_role_bypass_metadata ON document_metadata
    TO service_role
    USING (TRUE)
    WITH CHECK (TRUE);

-- Repeat for other tables...
```

---

## Migration Strategy

### Phase 1: Preparation
1. Backup database (DONE)
2. Test RLS policies in development environment
3. Create rollback plan

### Phase 2: Schema Migration
1. Add columns with DEFAULT values to avoid breaking existing workflows
2. Set DEFAULT tenant_id = 'default' for backward compatibility
3. Backfill existing records with tenant_id = 'default'
4. Gradually migrate specific tenants

### Phase 3: Application Updates
1. Update n8n workflow to extract tenant_id from JWT
2. Modify all Postgres nodes to include tenant_id in WHERE clauses
3. Update vector search to filter by tenant_id
4. Test multi-tenant isolation

### Phase 4: Cleanup
1. Remove DEFAULT 'default' constraints after migration
2. Add NOT NULL constraints
3. Enable RLS policies
4. Monitor performance

---

## Query Pattern Updates

### Before (V3):
```sql
SELECT * FROM document_metadata WHERE id = 'file.pdf';
```

### After (V5):
```sql
SELECT * FROM document_metadata
WHERE tenant_id = {{ $('Tenant Context').json.tenant_id }}
  AND id = 'file.pdf'
  AND is_current = TRUE
  AND is_deleted = FALSE;
```

### Version History Query:
```sql
SELECT * FROM document_metadata
WHERE tenant_id = {{ $('Tenant Context').json.tenant_id }}
  AND id LIKE 'file.pdf%'
  ORDER BY version_number DESC;
```

---

## Performance Considerations

**Expected Impact**:
- Tenant filtering: Minimal overhead with proper indexing (~5-10ms per query)
- Version queries: Slightly slower for historical lookups, optimized for current version
- RLS policies: ~10-20% overhead, acceptable for security benefit

**Optimization Strategies**:
1. **Composite indexes** for common query patterns (tenant_id + is_current)
2. **Partial indexes** for frequently filtered boolean columns
3. **JSONB GIN indexes** for metadata queries
4. **Connection pooling** to handle increased query load
5. **Query result caching** for frequently accessed documents

---

## Security Considerations

**Tenant Isolation**:
- All API endpoints MUST validate tenant_id from JWT
- n8n workflow MUST extract and pass tenant_id to every database operation
- RLS provides defense-in-depth even if application logic fails

**Audit Trail**:
- All changes logged in document_change_log
- IP address and user_agent captured for forensics
- Immutable log (no updates/deletes allowed)

**Data Retention**:
- Soft-delete only (never hard delete)
- Historical versions retained indefinitely (or per tenant policy)
- GDPR compliance: Add tenant-specific data purge workflow if needed

---

## Testing Requirements

**Test Cases**:
1. **Tenant Isolation**: User A cannot access User B's documents
2. **Version History**: Can retrieve all versions of a document
3. **Soft Delete**: Deleted documents not visible but recoverable
4. **Performance**: Query time with tenant filtering < 100ms for 95th percentile
5. **RLS Bypass**: Service role can access all tenants
6. **Concurrent Updates**: Version numbers increment correctly
7. **Hash Detection**: Unchanged files skip reprocessing

---

## Next Steps

1. Review and approve this schema design
2. Create SQL migration scripts (001_add_multi_tenancy.sql, 002_add_versioning.sql)
3. Test migrations in development environment
4. Update n8n workflow nodes with new schema
5. Implement JWT tenant extraction logic
6. Deploy to staging for integration testing

---

## Appendix: Sample Data

**Example document_metadata row:**
```json
{
  "id": "insurance/policy-12345-v2.pdf",
  "title": "Homeowners Insurance Policy",
  "tenant_id": "tenant-abc-123",
  "user_id": "user-456",
  "version_number": 2,
  "is_current": true,
  "is_deleted": false,
  "content_hash": "sha256:a1b2c3d4...",
  "superseded_by": null,
  "created_at": "2025-10-30T12:00:00Z",
  "created_by": "user-456",
  "file_size": 2048576,
  "mime_type": "application/pdf",
  "page_count": 12,
  "document_type": "insurance",
  "confidence_score": 0.95,
  "custom_tags": ["homeowners", "2025", "renewal"]
}
```

**Example extracted_fields row:**
```json
{
  "tenant_id": "tenant-abc-123",
  "document_id": "insurance/policy-12345-v2.pdf",
  "field_name": "named_insured",
  "field_value": "John Smith",
  "field_type": "string",
  "confidence": 0.98,
  "extraction_method": "llm",
  "is_valid": true
}
```

---

**Document Version**: 1.0
**Last Updated**: October 30, 2025
**Author**: System Implementation Team
**Status**: ✅ Ready for Implementation
