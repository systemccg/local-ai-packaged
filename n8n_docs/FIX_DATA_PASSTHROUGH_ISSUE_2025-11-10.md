# Data Passthrough Issue Fix - November 10, 2025

## Problem Summary

The "Set File ID" node was outputting null values for all Google Drive file properties (file_id, file_type, file_title, file_url), even though the data was present earlier in the workflow.

## Root Cause

The "Set Tenant Context (GDrive)" **Set node** (n8n-nodes-base.set v3.4) was discarding all input data, despite having the `keepOnlySet: false` option specified in the workflow backup file.

### Investigation Results

Test workflow execution revealed:
- **Debug 2 Output** (after Map Folder to Tenant): ✅ All Google Drive fields present (id, name, mimeType, webViewLink) + tenant fields
- **Set Tenant Context Output** (Set node): ❌ Only tenant fields remained - all Google Drive data LOST
- **Set File ID Output**: ❌ All null values because source data was missing

### Why the Option Didn't Work

1. The backup workflow file `/root/local-ai-packaged/n8n/backup/workflows/V5_Multi_Tenant_RAG_Workflow_Debug.json` contained:
   ```json
   "options": {
     "keepOnlySet": false
   }
   ```

2. But after import, the live workflow in n8n showed:
   ```json
   "options": {}
   ```

3. The `keepOnlySet: false` option was either:
   - Not properly imported by n8n
   - Stripped during import
   - Not supported in Set node v3.4 format

## Solution

Replace the **Set node** with a **Code node** that explicitly preserves all input data while adding tenant context fields.

### Original Node (Set)
```json
{
  "name": "Set Tenant Context (GDrive)",
  "type": "n8n-nodes-base.set",
  "typeVersion": 3.4,
  "parameters": {
    "assignments": {
      "assignments": [
        {
          "name": "tenant_id",
          "value": "={{ $json.tenant_id }}",
          "type": "string"
        },
        {
          "name": "user_id",
          "value": "={{ $json.user_id }}",
          "type": "string"
        },
        {
          "name": "created_by",
          "value": "={{ $json.email }}",
          "type": "string"
        },
        {
          "name": "role",
          "value": "={{ $json.role }}",
          "type": "string"
        }
      ]
    },
    "options": {}  // keepOnlySet option missing/not applied
  }
}
```

### Fixed Node (Code)
```json
{
  "name": "Set Tenant Context (GDrive)",
  "type": "n8n-nodes-base.code",
  "typeVersion": 2,
  "parameters": {
    "jsCode": "// Set Tenant Context - Code version to preserve all data\nconst inputData = $input.item.json;\n\n// Add tenant context fields while preserving ALL existing fields\nreturn [{\n  ...inputData,\n  tenant_id: inputData.tenant_id,\n  user_id: inputData.user_id,\n  created_by: inputData.email,\n  role: inputData.role\n}];"
  },
  "notes": "Code version to preserve all Google Drive data"
}
```

## Verification

Test workflow execution after fix:
- **Set Tenant Context Output**: ✅ All fields preserved (id, name, mimeType, webViewLink, tenant_id, user_id, created_by, role)
- **Set File ID Output**: ✅ All values correctly populated:
  - `file_id`: "test-file-123"
  - `file_name`: "test-document.pdf"
  - `file_type`: "application/pdf"

## Files Modified

1. `/root/local-ai-packaged/n8n/backup/workflows/V5_Multi_Tenant_RAG_Workflow_Fixed_Data_Passthrough.json` - Fixed workflow with Code node
2. Workflow ID `aQnmDID5D90HKpH2` in n8n database - Updated and activated

## Key Learnings

1. **Set node `keepOnlySet` option behavior**:
   - May not import/export correctly in some n8n versions
   - When in doubt, use Code nodes for data transformation to ensure explicit control

2. **Data flow debugging**:
   - Insert Code nodes with `console.log()` at each step
   - Use `return $input.all();` to pass data through debug nodes
   - Check n8n logs with `docker logs n8n --tail 100` to see debug output

3. **n8n workflow testing**:
   - Create minimal test workflows with Manual Trigger
   - Use `docker exec n8n n8n execute --id=<workflow_id>` to run tests
   - Inspect execution output JSON to trace data transformations

## Next Steps

1. ✅ Fix has been applied and tested
2. 🔄 Workflow is active and ready for testing with real Google Drive files
3. 📋 Upload a test file to Google Drive folder `18q2yQ-vWjk8I9Isd7Oz1F3h-FrNxkvtF`
4. 📊 Verify complete end-to-end workflow execution
5. ✅ Confirm document appears in PostgreSQL with vector embeddings

## Related Documentation

- [WORKFLOW_TWO_FLOW_ARCHITECTURE.md](WORKFLOW_TWO_FLOW_ARCHITECTURE.md) - Explains two-flow system
- [WORKFLOW_ISSUES_AND_FIXES.md](WORKFLOW_ISSUES_AND_FIXES.md) - All previous fixes
- [SESSION_SUMMARY_2025-11-07.md](SESSION_SUMMARY_2025-11-07.md) - Previous session work
