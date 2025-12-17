# Supabase Auth Integration for Multi-Tenant n8n RAG Workflow

**Project**: n8n RAG Workflow V5
**Created**: October 31, 2025
**Purpose**: Enable multi-tenant authentication using Supabase Auth with tenant_id in JWT claims

---

## Overview

This guide configures Supabase Auth to include `tenant_id` in JWT tokens, enabling the n8n workflow to enforce tenant isolation at the database level.

### Current Setup

**Supabase Auth Status**: ✅ Running (supabase-auth container healthy)
- **JWT Secret**: `0xhb7bIcKWuuigEd0rulU4xA6SZ6l93cllRBwB1Y`
- **JWT Audience**: `authenticated`
- **JWT Expiry**: 3600 seconds (1 hour)
- **API URL**: `http://localhost:8000` (via Kong gateway)
- **Existing Users**: 1 (system@cocreatorsgroup.com)
- **Existing Tenants**: 2 (Merkle: mk3029839, Default: default)

---

## Step 1: Link Auth Users to Tenants

### 1.1 Add tenant_id to auth.users metadata

We'll store tenant_id in the `raw_app_meta_data` field (server-controlled, not user-editable):

```sql
-- Add tenant_id to existing user (example for Merkle tenant)
UPDATE auth.users
SET raw_app_meta_data = jsonb_set(
    COALESCE(raw_app_meta_data, '{}'::jsonb),
    '{tenant_id}',
    '"mk3029839"'
)
WHERE email = 'system@cocreatorsgroup.com';
```

### 1.2 Create function to add tenant_id to JWT claims

```sql
-- Function to customize JWT claims
CREATE OR REPLACE FUNCTION public.custom_access_token_hook(event jsonb)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
    claims jsonb;
    user_tenant_id text;
BEGIN
    -- Get user's tenant_id from app_metadata
    user_tenant_id := event->'claims'->'app_metadata'->>'tenant_id';

    -- If tenant_id exists, add it to claims
    IF user_tenant_id IS NOT NULL THEN
        claims := event->'claims';
        claims := jsonb_set(claims, '{tenant_id}', to_jsonb(user_tenant_id));
        event := jsonb_set(event, '{claims}', claims);
    END IF;

    RETURN event;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.custom_access_token_hook TO supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.custom_access_token_hook TO postgres;
```

### 1.3 Configure Supabase Auth to use the hook

**Note**: This requires updating the Supabase Auth environment variable:

```bash
# Add to supabase/docker/.env or docker-compose.yml
GOTRUE_HOOK_CUSTOM_ACCESS_TOKEN_ENABLED=true
GOTRUE_HOOK_CUSTOM_ACCESS_TOKEN_URI=pg-functions://postgres/public/custom_access_token_hook
```

Then restart Supabase Auth:
```bash
cd /root/local-ai-packaged/supabase/docker
docker compose restart supabase-auth
```

---

## Step 2: Sync tenant_users table with auth.users

Create a trigger to automatically populate `tenant_users` when new auth users are created:

```sql
-- Function to sync auth.users to tenant_users
CREATE OR REPLACE FUNCTION public.sync_auth_to_tenant_users()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    user_tenant_id text;
BEGIN
    -- Extract tenant_id from metadata
    user_tenant_id := NEW.raw_app_meta_data->>'tenant_id';

    IF user_tenant_id IS NOT NULL THEN
        -- Insert or update tenant_users
        INSERT INTO public.tenant_users (
            tenant_id,
            user_id,
            email,
            role,
            is_active
        )
        VALUES (
            user_tenant_id,
            NEW.id::text,
            NEW.email,
            COALESCE(NEW.raw_app_meta_data->>'role', 'viewer'),
            true
        )
        ON CONFLICT (tenant_id, user_id) DO UPDATE
        SET email = EXCLUDED.email,
            role = EXCLUDED.role,
            last_login = NOW();
    END IF;

    RETURN NEW;
END;
$$;

-- Create trigger on auth.users
CREATE TRIGGER on_auth_user_created
    AFTER INSERT OR UPDATE ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.sync_auth_to_tenant_users();
```

---

## Step 3: JWT Token Structure

After configuration, JWT tokens will include:

```json
{
  "aud": "authenticated",
  "exp": 1698765432,
  "iat": 1698761832,
  "iss": "http://localhost:8000/auth/v1",
  "sub": "a91d22cf-1f2d-4621-82ea-cbfe584d1f9c",
  "email": "user@example.com",
  "phone": "",
  "app_metadata": {
    "tenant_id": "mk3029839",
    "role": "admin"
  },
  "user_metadata": {
    "name": "John Doe"
  },
  "role": "authenticated",
  "tenant_id": "mk3029839"  // ← Our custom claim
}
```

---

## Step 4: n8n Workflow Integration

### 4.1 Add JWT Authentication Node

At the start of your n8n workflow, add an HTTP Request node to validate JWT:

**Node Name**: `JWT Validate & Extract`
**Type**: Function
**Code**:
```javascript
// Get JWT from Authorization header
const authHeader = $input.item.headers.authorization;
if (!authHeader || !authHeader.startsWith('Bearer ')) {
  throw new Error('Missing or invalid Authorization header');
}

const token = authHeader.replace('Bearer ', '');

// Decode JWT (for development - use proper validation in production)
const base64Url = token.split('.')[1];
const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
const jsonPayload = decodeURIComponent(
  atob(base64)
    .split('')
    .map(c => '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2))
    .join('')
);

const payload = JSON.parse(jsonPayload);

// Extract tenant_id
const tenantId = payload.tenant_id || payload.app_metadata?.tenant_id;

if (!tenantId) {
  throw new Error('JWT does not contain tenant_id claim');
}

// Return tenant context
return {
  tenant_id: tenantId,
  user_id: payload.sub,
  email: payload.email,
  role: payload.app_metadata?.role || 'viewer',
  jwt_valid: true
};
```

**Alternative: Use Supabase Node**
- Add "Supabase" node
- Operation: "Get User"
- Authentication: Service Role Key
- This validates JWT and returns user metadata

### 4.2 Set Tenant Context Variable

Create a "Set" node after JWT validation:

**Node Name**: `Set Tenant Context`
**Type**: Set
**Values**:
- `tenant_id`: `{{ $json.tenant_id }}`
- `user_id`: `{{ $json.user_id }}`
- `created_by`: `{{ $json.email }}`

Now all subsequent nodes can reference:
- `{{ $('Set Tenant Context').item.json.tenant_id }}`
- `{{ $('Set Tenant Context').item.json.user_id }}`

---

## Step 5: Update Database Query Nodes

### 5.1 Postgres Vector Store Node

**Before:**
```javascript
// Retrieve documents query
SELECT * FROM documents_pg WHERE metadata->>'file_id' = '${fileId}'
```

**After:**
```javascript
// Add tenant_id filter
SELECT * FROM documents_pg
WHERE tenant_id = '{{ $('Set Tenant Context').item.json.tenant_id }}'
  AND metadata->>'file_id' = '${fileId}'
  AND is_current = TRUE
  AND is_deleted = FALSE
```

### 5.2 Postgres Execute Node (Insert Documents)

**Before:**
```sql
INSERT INTO document_metadata (id, title, created_at)
VALUES ($1, $2, NOW())
```

**After:**
```sql
INSERT INTO document_metadata (
  id,
  title,
  tenant_id,
  user_id,
  created_by,
  created_at,
  version_number,
  is_current
)
VALUES (
  $1,
  $2,
  '{{ $('Set Tenant Context').item.json.tenant_id }}',
  '{{ $('Set Tenant Context').item.json.user_id }}',
  '{{ $('Set Tenant Context').item.json.created_by }}',
  NOW(),
  1,
  TRUE
)
```

### 5.3 All Postgres Tool Nodes

Add to every SQL query:
```sql
WHERE tenant_id = '{{ $('Set Tenant Context').item.json.tenant_id }}'
  AND is_deleted = FALSE
```

---

## Step 6: Row Level Security (RLS) - Optional

For defense-in-depth, enable RLS policies (already created in migrations):

```sql
-- Enable RLS on tables
ALTER TABLE documents_pg ENABLE ROW LEVEL SECURITY;
ALTER TABLE document_metadata ENABLE ROW LEVEL SECURITY;
ALTER TABLE document_rows ENABLE ROW LEVEL SECURITY;

-- Uncomment policies in migrations/001_add_multi_tenancy_v2.sql
-- Then run:
-- psql -U supabase_admin -d postgres -f enable_rls_policies.sql
```

---

## Testing Multi-Tenant Auth

### Test 1: Create Test Tenant and User

```sql
-- Create test tenant
INSERT INTO tenants (tenant_id, name, slug, subscription_tier)
VALUES ('test-tenant-001', 'Test Company', 'test-company', 'free');

-- Create test user in Supabase Auth (via API or Supabase Studio)
-- Then link to tenant
UPDATE auth.users
SET raw_app_meta_data = jsonb_set(
    raw_app_meta_data,
    '{tenant_id}',
    '"test-tenant-001"'
)
WHERE email = 'testuser@example.com';
```

### Test 2: Generate JWT Token

Using Supabase Auth API:
```bash
curl -X POST 'http://localhost:8000/auth/v1/token?grant_type=password' \
  -H 'apikey: YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "email": "testuser@example.com",
    "password": "secure_password"
  }'
```

Response includes:
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "expires_in": 3600,
  "refresh_token": "...",
  "user": {
    "id": "...",
    "email": "testuser@example.com"
  }
}
```

### Test 3: Call n8n Workflow with JWT

```bash
curl -X POST 'https://n8n.leadingai.info/webhook/rag-chat' \
  -H 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...' \
  -H 'Content-Type: application/json' \
  -d '{
    "message": "What documents do I have?",
    "session_id": "test-session-123"
  }'
```

### Test 4: Verify Tenant Isolation

```sql
-- Upload document as tenant A
-- Upload same document as tenant B
-- Query as tenant A - should only see tenant A's document

SELECT
    dm.id,
    dm.title,
    dm.tenant_id,
    COUNT(dp.id) as embeddings,
    COUNT(dr.id) as rows
FROM document_metadata dm
LEFT JOIN documents_pg dp ON dp.tenant_id = dm.tenant_id AND dp.metadata->>'file_id' = dm.id
LEFT JOIN document_rows dr ON dr.tenant_id = dm.tenant_id AND dr.dataset_id = dm.id
WHERE dm.tenant_id = 'test-tenant-001'
  AND dm.is_deleted = FALSE
GROUP BY dm.id, dm.title, dm.tenant_id;
```

---

## Security Best Practices

### 1. JWT Validation
- **Always validate JWT signature** using Supabase client library or `jsonwebtoken` package
- Never trust client-provided tenant_id - always extract from validated JWT
- Set appropriate JWT expiry (default: 1 hour)

### 2. Service Role vs Anon Key
- **n8n workflows**: Use Service Role key (bypasses RLS for admin operations)
- **Frontend applications**: Use Anon key (enforces RLS)
- Store Service Role key in n8n credentials (encrypted)

### 3. Tenant Context Propagation
- Set tenant context once at workflow start
- Pass through all nodes via `$('Set Tenant Context')`
- Never allow user to override tenant_id

### 4. Audit Logging
- Log all document operations to `document_change_log`
- Include `tenant_id`, `user_id`, `ip_address`, `user_agent`
- Immutable audit trail (no updates/deletes)

---

## Troubleshooting

### Issue: JWT doesn't contain tenant_id

**Check 1**: Verify custom access token hook is configured
```sql
SELECT * FROM pg_proc WHERE proname = 'custom_access_token_hook';
```

**Check 2**: Verify user has tenant_id in metadata
```sql
SELECT email, raw_app_meta_data->'tenant_id' as tenant_id
FROM auth.users;
```

**Fix**: Update user metadata and restart Supabase Auth

### Issue: "Permission denied for table documents_pg"

**Cause**: RLS enabled but JWT not setting `app.current_tenant`

**Fix**: Either disable RLS or set session variable:
```sql
SET LOCAL app.current_tenant = 'tenant-id-from-jwt';
```

### Issue: Wrong tenant sees other tenant's data

**Critical Security Violation!**

**Check 1**: Verify tenant_id filter in ALL queries
```bash
grep -r "SELECT.*FROM document" /root/local-ai-packaged/n8n/backup/workflows/
# Should see: WHERE tenant_id = ...
```

**Check 2**: Test with SQL injection attempts
- Try injecting `' OR '1'='1` in tenant_id
- Should fail due to parameterized queries

---

## Next Steps

1. ✅ Decision made: Use Supabase Auth
2. ⏳ Run SQL scripts to configure JWT hooks
3. ⏳ Restart Supabase Auth container
4. ⏳ Export and modify n8n workflow
5. ⏳ Add JWT validation node
6. ⏳ Update all database queries
7. ⏳ Test multi-tenant isolation

---

## Files & Resources

- **Supabase Auth Docs**: https://supabase.com/docs/guides/auth
- **JWT Custom Claims**: https://supabase.com/docs/guides/auth/custom-claims-and-role-based-access-control-rbac
- **Database Functions**: `/root/local-ai-packaged/n8n/migrations/003_add_auth_hooks.sql` (to be created)
- **Workflow Template**: `/root/local-ai-packaged/n8n/docs/N8N_JWT_INTEGRATION_TEMPLATE.json` (to be created)

---

**Document Version**: 1.0
**Last Updated**: October 31, 2025
**Status**: Ready for Implementation
