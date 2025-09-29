# Quick Start: Conversation History Feature

A quick reference guide to get conversation history working in 5 minutes.

## Prerequisites

Completed Workshop Step 2 (vector embeddings in Couchbase)  
Couchbase Capella cluster with a bucket  
OpenAI API key  
Node.js installed

## Setup Steps

### 1. Create Couchbase Collection (30 seconds)

In Couchbase Capella Query Workbench, run:

```sql
CREATE COLLECTION `your-bucket-name`.`_default`.`conversations`;

CREATE INDEX idx_conversation_session 
ON `your-bucket-name`.`_default`.`conversations`(sessionId, timestamp)
WHERE type = 'chat_message';
```

Replace `your-bucket-name` with your actual bucket name.

### 2. Update Environment Variables (30 seconds)

Add to `project/backend/.env`:

```env
# Add these two lines (optional, uses defaults if omitted)
COUCHBASE_CONVERSATION_SCOPE=_default
COUCHBASE_CONVERSATION_COLLECTION=conversations
```

Your existing environment variables remain unchanged.

### 3. Install Dependencies & Start (2 minutes)

```bash
# Backend
cd project/backend
npm install
node server.js

# Frontend (in a new terminal)
cd project/frontend
npm install
npm run dev
```

### 4. Test It! (2 minutes)

Open your browser to the frontend URL and try:

1. **Ask**: "What is JavaScript Array.map()?"
2. **Then ask**: "What was my previous question?"
3. **Watch**: The AI remembers and responds based on history! 🎉

## What Just Happened?

| Before | After |
|--------|-------|
| Each query was independent | Queries have context from history |
| "What did I just ask?" → ❌ Can't answer | "What did I just ask?" → ✅ Answers correctly |
| No memory between questions | Remembers the entire conversation |

## New Features Available

### For Users
- Ask follow-up questions naturally
- Request clarification on previous answers
- Build on previous topics in conversation

### For Developers
- `POST /api/query` - Now accepts `sessionId` parameter
- `GET /api/conversation/history?sessionId=xxx` - Retrieve history
- `DELETE /api/conversation/clear` - Clear conversation (body: `{sessionId}`)

## Architecture at a Glance

```
User Query → Store in Couchbase → Retrieve History → 
Vector Search → Enhanced Prompt (with history) → 
Stream Response → Store Response in Couchbase
```

## Example Queries to Try

**Basic Memory**
- "Explain JavaScript closures"
- "What was my last question?"

**Follow-up Questions**
- "How does Promise.all work?"
- "Can you give me an example of that?"

**Context Building**
- "What are React hooks?"
- "How do they compare to class components?"
- "Which approach did you just recommend?"

**Meta Questions**
- "What topics have we discussed so far?"
- "Can you summarize our conversation?"

---

**Tip**: Clear your browser's sessionStorage (`sessionStorage.clear()` in DevTools Console) to start a fresh conversation without restarting the server.
