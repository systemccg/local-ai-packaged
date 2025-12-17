#!/bin/bash

# Add Test Document for RAG Testing
# Usage: ./add_test_document.sh <tenant_id> <user_email> <title> <content>

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

# Insert document into documents_pg table (the table used by n8n RAG workflows)
# Use psql variables to properly escape special characters
DOC_ID=$(docker exec supabase-db psql -U postgres postgres -v content="$CONTENT" -v title="$TITLE" -v user_email="$USER_EMAIL" -v tenant_id="$TENANT_ID" -v user_id="$USER_ID" -t -A <<'EOF'
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
  :'content',
  :'content',
  jsonb_build_object(
    'title', :'title',
    'user_email', :'user_email',
    'source', 'test_script',
    'created_at', NOW()
  ),
  :'tenant_id',
  :'user_id',
  :'user_email',
  true,
  false
) RETURNING id;
EOF
)

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
echo "      2. Find a workflow that processes documents and generates embeddings"
echo "      3. The workflow should use OpenAI/Ollama to create vector embeddings"
echo ""
echo "   Option 2 - Generate embeddings manually (Advanced):"
echo "      Use OpenAI or Ollama API to generate embeddings and update documents_pg.embedding column"
echo ""
echo "To verify the document exists (but note: it won't be searchable yet):"
echo "   docker exec supabase-db psql -U postgres postgres -c \"SELECT id, tenant_id, metadata->>'title' as title, LEFT(content, 80) as preview FROM documents_pg WHERE id=$DOC_ID;\""
