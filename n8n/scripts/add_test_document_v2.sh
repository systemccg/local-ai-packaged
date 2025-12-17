#!/bin/bash

# Add Test Document for RAG Testing (Version 2 - Better escaping)
# Usage: ./add_test_document_v2.sh <tenant_id> <user_email> <title> <content>

set -e

TENANT_ID="${1:-mk3029839}"
USER_EMAIL="${2:-gwasmuth@gmail.com}"
TITLE="${3:-Test Document}"
CONTENT="${4:-This is a test document for $USER_EMAIL in tenant $TENANT_ID. It contains information about the CoCreators project and AI workflows.}"

echo "Adding test document for user $USER_EMAIL in tenant $TENANT_ID..."

# Get user_id from email
USER_ID=$(docker exec supabase-db psql -U postgres postgres -t -A -c \
  "SELECT id FROM auth.users WHERE email = '$USER_EMAIL';")

if [ -z "$USER_ID" ]; then
  echo "Warning: User $USER_EMAIL not found in auth.users"
  echo "Creating document without user_id verification..."
  USER_ID="unknown"
fi

echo "User ID: $USER_ID"

# Create a temporary SQL file with proper escaping using dollar quoting
TEMP_SQL=$(mktemp)
cat > "$TEMP_SQL" <<EOSQL
INSERT INTO documents_pg (
  content,
  text,
  metadata,
  tenant_id,
  user_id,
  created_by,
  is_current,
  is_deleted
) VALUES (
  \$\$${CONTENT}\$\$,
  \$\$${CONTENT}\$\$,
  jsonb_build_object(
    'title', \$\$${TITLE}\$\$,
    'user_email', \$\$${USER_EMAIL}\$\$,
    'source', 'test_script',
    'created_at', NOW()
  ),
  '${TENANT_ID}',
  '${USER_ID}',
  '${USER_EMAIL}',
  true,
  false
) RETURNING id;
EOSQL

# Execute the SQL and capture the ID
DOC_ID=$(docker exec -i supabase-db psql -U postgres postgres -t -A < "$TEMP_SQL")

# Clean up temp file
rm "$TEMP_SQL"

if [ -z "$DOC_ID" ]; then
  echo "❌ Error: Document was not created!"
  exit 1
fi

echo ""
echo "✅ Document added successfully!"
echo "   Document ID: $DOC_ID"
echo "   Tenant: $TENANT_ID"
echo "   User: $USER_EMAIL ($USER_ID)"
echo "   Title: $TITLE"
echo ""
echo "⚠️  CRITICAL: The document does NOT have embeddings yet!"
echo ""
echo "   The RAG system CANNOT find this document until embeddings are generated."
echo "   You have two options:"
echo ""
echo "   Option 1 - Use n8n workflow (RECOMMENDED):"
echo "      1. Go to https://n8n.leadingai.info"
echo "      2. Find the 'LeadingAI RAG AI Agent V5 - Multi-Tenant' workflow"
echo "      3. Use the document upload tool to generate embeddings"
echo ""
echo "   Option 2 - Generate embeddings manually (Advanced):"
echo "      Use OpenAI or Ollama API to generate embeddings and UPDATE documents_pg SET embedding=... WHERE id=$DOC_ID"
echo ""
echo "To verify the document exists:"
echo "   docker exec supabase-db psql -U postgres postgres -c \"SELECT id, tenant_id, metadata->>'title' as title, LEFT(content, 80) as preview FROM documents_pg WHERE id=$DOC_ID;\""
