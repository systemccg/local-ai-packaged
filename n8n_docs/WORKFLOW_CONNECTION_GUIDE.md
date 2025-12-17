# n8n Workflow V5 - Manual Connection Guide

**Workflow ID**: zwRjhxpdTGh10WGE
**Workflow Name**: LeadingAI RAG AI Agent V5 - Multi-Tenant
**Task**: Connect version detection nodes
**Time Required**: 15-20 minutes

---

## 🎯 What Needs to Be Connected

The upgrade script added 6 new nodes but couldn't automatically connect them. You need to wire up the **version detection flow** and verify the **JWT authentication flow**.

---

## 📍 Step-by-Step Instructions

### Step 1: Open the Workflow

1. Navigate to: **https://n8n.leadingai.info**
2. Log in to n8n
3. Go to **Workflows** in the left sidebar
4. Find and open: **"LeadingAI RAG AI Agent V5 - Multi-Tenant"**
   - Workflow ID: `zwRjhxpdTGh10WGE`

---

### Step 2: Locate the New Nodes

You should see these **6 new nodes** (they may not be connected yet):

#### JWT Authentication Nodes (Left side of canvas)
1. **JWT Validate & Extract Tenant** (Code node)
   - Position: Right after Webhook/Chat Trigger
   - Icon: JavaScript/Code icon

2. **Set Tenant Context** (Set node)
   - Position: After JWT Validate
   - Icon: Set/Edit fields icon

#### Version Detection Nodes (Middle of canvas, near Download File)
3. **Calculate Content Hash** (Code node)
   - Position: After "Download File"
   - Icon: JavaScript/Code icon

4. **Check Existing Version** (Postgres node)
   - Position: After "Calculate Content Hash"
   - Icon: Postgres/Database icon

5. **Content Changed?** (IF node)
   - Position: After "Check Existing Version"
   - Icon: Diamond/Decision icon

6. **Create New Version** (Postgres node)
   - Position: After "Content Changed?" (TRUE branch)
   - Icon: Postgres/Database icon

---

### Step 3: Connect JWT Authentication Flow

**Goal**: Ensure all chat/webhook requests go through JWT validation first.

#### Connection 1: Webhook → JWT Validate
1. Find the **Webhook** node (or **When chat message received** node)
2. Click the **small circle** on the right side of the node
3. Drag the connection line to **JWT Validate & Extract Tenant**
4. Release to connect

#### Connection 2: JWT Validate → Set Tenant Context
1. Find **JWT Validate & Extract Tenant** node
2. Click the output circle on the right
3. Drag to **Set Tenant Context**
4. Release to connect

#### Connection 3: Set Tenant Context → Edit Fields
1. Find **Set Tenant Context** node
2. Click the output circle
3. Drag to **Edit Fields** node
4. Release to connect

**Verify**: The flow should now be:
```
Webhook → JWT Validate & Extract Tenant → Set Tenant Context → Edit Fields → RAG AI Agent
```

---

### Step 4: Connect Version Detection Flow

**Goal**: Insert version detection between Download File and Switch (file type routing).

#### Find the Starting Point
1. Locate the **Download File** node (Google Drive node)
2. Currently it connects directly to **Switch** node
3. We need to insert version detection in between

#### Disconnect Download File from Switch (if connected)
1. Click on the **Switch** node
2. Look at the input connections (left side)
3. If there's a connection from **Download File**, hover over it
4. Click the **X** to disconnect (or we'll reconnect later)

#### Connection 4: Download File → Calculate Content Hash
1. Find **Download File** node
2. Click the output circle (right side)
3. Drag to **Calculate Content Hash**
4. Release to connect

#### Connection 5: Calculate Content Hash → Check Existing Version
1. Find **Calculate Content Hash** node
2. Click the output circle
3. Drag to **Check Existing Version**
4. Release to connect

#### Connection 6: Check Existing Version → Content Changed?
1. Find **Check Existing Version** node
2. Click the output circle
3. Drag to **Content Changed?** (IF node)
4. Release to connect

#### Connection 7A: Content Changed? (TRUE) → Create New Version
1. Find **Content Changed?** IF node
2. It has **two output circles**:
   - Top one: **TRUE** (content has changed)
   - Bottom one: **FALSE** (content unchanged)
3. Click the **top circle** (TRUE branch)
4. Drag to **Create New Version**
5. Release to connect

#### Connection 7B: Create New Version → Switch
1. Find **Create New Version** node
2. Click the output circle
3. Drag to **Switch** node
4. Release to connect

#### Connection 8: Content Changed? (FALSE) → Switch
1. Go back to **Content Changed?** IF node
2. Click the **bottom circle** (FALSE branch)
3. Drag directly to **Switch** node
4. Release to connect

**Verify**: The flow should now be:
```
Download File
  → Calculate Content Hash
    → Check Existing Version
      → Content Changed?
        ├─ TRUE → Create New Version → Switch
        └─ FALSE → Switch (skip version creation)
```

---

### Step 5: Verify Connections

#### Check JWT Flow
Starting from **Webhook**:
```
Webhook
  → JWT Validate & Extract Tenant
    → Set Tenant Context
      → Edit Fields
        → RAG AI Agent
          → Respond to Webhook
```

#### Check File Processing Flow
Starting from **File Created** or **File Updated** triggers:
```
Google Drive Trigger
  → Loop Over Items
    → Set File ID
      → Soft Delete Old Documents
        → Soft Delete Old Document Rows
          → Insert Document Metadata
            → Download File
              → Calculate Content Hash
                → Check Existing Version
                  → Content Changed?
                    ├─ TRUE → Create New Version → Switch
                    └─ FALSE → Switch
                      → [Extract PDF/Excel/CSV/Document Text]
                        → [Processing continues...]
```

---

### Step 6: Adjust Node Positions (Optional)

For better visibility, you can rearrange nodes:

1. **Drag nodes** to adjust their positions
2. Suggested layout:
   - JWT flow: Top-left area (horizontal)
   - File upload flow: Left-to-right across canvas
   - Version detection: Between Download File and Switch
   - Agent tools: Bottom area

3. Use **minimap** (bottom-right) to navigate large canvas

---

### Step 7: Save the Workflow

1. Click **Save** button (top-right)
2. You should see: "Workflow saved" confirmation
3. If there are any errors, n8n will highlight problematic nodes in red

---

## ✅ Verification Checklist

After connecting, verify:

- [ ] JWT Validate node is connected to Webhook/Chat trigger
- [ ] Set Tenant Context follows JWT Validate
- [ ] Edit Fields comes after Set Tenant Context
- [ ] Calculate Content Hash is after Download File
- [ ] Check Existing Version follows Calculate Content Hash
- [ ] Content Changed? IF node has TWO outputs
- [ ] TRUE branch goes to Create New Version then Switch
- [ ] FALSE branch goes directly to Switch
- [ ] No red error indicators on any nodes
- [ ] Workflow saved successfully

---

## 🔍 Troubleshooting

### Issue: Can't find a specific node

**Solution**:
- Use **Ctrl+F** (or Cmd+F on Mac) to search for node names
- Use the **minimap** in bottom-right to navigate
- Zoom out to see more of the canvas (mouse wheel or pinch)

### Issue: Connection won't create

**Solution**:
- Make sure you're dragging FROM output circle (right side) TO input circle (left side)
- Some nodes only accept certain connection types
- Check that the line turns green before releasing

### Issue: Node shows red error

**Solution**:
- Click the node to see error details
- Common issues:
  - Missing credentials (Postgres, Google Drive)
  - Invalid expressions in parameters
  - Missing required fields

### Issue: Can't tell which output is TRUE vs FALSE on IF node

**Solution**:
- Hover over the output circles
- Top output = TRUE condition met
- Bottom output = FALSE condition not met
- Labels appear on hover

---

## 📸 Visual Reference

### JWT Flow Connection Pattern
```
[Webhook]---->[JWT Validate]---->[ Set Tenant ]---->[ Edit Fields]
                  (Code)           Context (Set)         (Set)
```

### Version Detection Pattern
```
                                    [ Content Changed? ]
                                           (IF)
                                          /    \
                                       TRUE    FALSE
                                        /        \
                        [Create New Version]      \
                              (Postgres)           \
                                    \               \
                                     \               \
                                      ----[Switch]----
                                           (Route by file type)
```

### Full Download → Switch Flow
```
[Download File]
      ↓
[Calculate Content Hash]
      ↓
[Check Existing Version]
      ↓
[Content Changed?]
     / \
    /   \
 TRUE   FALSE
  ↓       \
[Create    \
Version]    \
  ↓         ↓
  [Switch]
```

---

## 🎉 What Happens After Connection

Once connected, the workflow will:

1. **On document upload**:
   - Calculate SHA-256 hash of file content
   - Check if document already exists with that hash
   - If hash is **different** → Create new version (v2, v3, etc.)
   - If hash is **same** → Skip reprocessing (saves time!)

2. **On chat/webhook request**:
   - Validate JWT token
   - Extract tenant_id from JWT
   - Set tenant context for all database queries
   - Ensure user only sees their own documents

3. **On document delete** (via Google Drive trash):
   - Soft-delete (mark as deleted, preserve data)
   - Log deletion to audit trail
   - Hide from queries but keep for recovery

---

## 📝 After Connecting

Once all connections are made:

1. **Activate the workflow** (toggle in top-right)
2. **Run a test**:
   - Upload a document to the Google Drive folder
   - Watch it process in the execution log
   - Check document_metadata table for version_number = 1
3. **Update the document**:
   - Modify and re-upload the same file
   - Verify version_number = 2 created
4. **Test tenant isolation**:
   - Make a chat request with JWT token
   - Verify only that tenant's documents are visible

---

## 🎯 Success Criteria

Connections are complete when:
- ✅ All nodes are connected (no isolated nodes)
- ✅ No red error indicators
- ✅ Workflow saves successfully
- ✅ Test execution completes without errors
- ✅ Version detection creates v2 on document update
- ✅ Tenant isolation verified with JWT tokens

---

**Need Help?** If you encounter issues:
1. Take a screenshot of the workflow canvas
2. Check the execution logs for specific errors
3. Verify all node credentials are configured
4. Review the error messages in each node

---

**Last Updated**: October 31, 2025 02:25 UTC
**Status**: Ready for manual connections
