#!/bin/bash

# Add Test Document for RAG Testing (Version 3 - BOTH tables)
# This matches what the n8n workflow expects
# Usage: ./add_test_document_v3.sh <tenant_id> <user_email> <title> <content>

set -e

TENANT_ID="${1:-mk3029839}"
USER_EMAIL="${2:-gwasmuth@gmail.com}"
TITLE="${3:-Test Document}"
CONTENT="${4:-This is a test document for $USER_EMAIL in tenant $TENANT_ID.}"

echo "Adding test document for user $USER_EMAIL in tenant $TENANT_ID..."

# Get user_id from email
USER_ID=$(docker exec supabase-db psql -U postgres postgres -t -A -c \
  "SELECT id FROM auth.users WHERE email = '$USER_EMAIL';")

if [ -z "$USER_ID" ]; then
  echo "Warning: User $USER_EMAIL not found in auth.users"
  echo "Using email as user_id..."
  USER_ID="$USER_EMAIL"
fi

echo "User ID: $USER_ID"

# Generate unique document ID
DOC_ID="doc-$(date +%s)-$(uuidgen | cut -d'-' -f1)"

echo "Document ID: $DOC_ID"

# Create a temporary SQL file with proper escaping
TEMP_SQL=$(mktemp)
cat > "$TEMP_SQL" <<EOSQL
BEGIN;

-- Insert into document_metadata (for tracking and UI visibility)
INSERT INTO document_metadata (
  id,
  title,
  tenant_id,
  user_id,
  created_by,
  processing_status,
  document_type,
  source,
  is_current,
  is_deleted,
  version_number
) VALUES (
  '${DOC_ID}',
  \$\$${TITLE}\$\$,
  '${TENANT_ID}',
  '${USER_ID}',
  '${USER_EMAIL}',
  'completed',
  'text',
  'manual_test_script',
  true,
  false,
  1
);

-- Insert into documents_pg (for RAG vector storage)
INSERT INTO documents_pg (
  content,
  text,
  metadata,
  tenant_id,
  user_id,
  created_by,
  is_current,
  is_deleted,
  version_number
) VALUES (
  \$\$${CONTENT}\$\$,
  \$\$${CONTENT}\$\$,
  jsonb_build_object(
    'title', \$\$${TITLE}\$\$,
    'user_email', '${USER_EMAIL}',
    'source', 'test_script',
    'file_id', '${DOC_ID}',
    'created_at', NOW()
  ),
  '${TENANT_ID}',
  '${USER_ID}',
  '${USER_EMAIL}',
  true,
  false,
  1
);

COMMIT;

SELECT 'Document added to BOTH tables successfully!' as status;
EOSQL

# Execute the SQL
docker exec -i supabase-db psql -U postgres postgres < "$TEMP_SQL"

# Clean up temp file
rm "$TEMP_SQL"

echo ""
echo "✅ Document added successfully to BOTH tables!"
echo "   Document ID: $DOC_ID"
echo "   Tenant: $TENANT_ID"
echo "   User: $USER_EMAIL ($USER_ID)"
echo "   Title: $TITLE"
echo ""
echo "📋 Document added to:"
echo "   1. document_metadata (visible in Supabase UI)"
echo "   2. documents_pg (used for RAG)"
echo ""
echo "⚠️  CRITICAL: The document still needs embeddings!"
echo ""
echo "   Without embeddings in documents_pg.embedding column,"
echo "   the RAG system CANNOT retrieve this document."
echo ""
echo "To verify documents were added:"
echo "   # Check document_metadata"
echo "   docker exec supabase-db psql -U postgres postgres -c \"SELECT id, tenant_id, title FROM document_metadata WHERE id='$DOC_ID';\""
echo ""
echo "   # Check documents_pg"
echo "   docker exec supabase-db psql -U postgres postgres -c \"SELECT id, tenant_id, metadata->>'title' as title, embedding IS NULL as needs_embedding FROM documents_pg WHERE metadata->>'file_id'='$DOC_ID';\""
