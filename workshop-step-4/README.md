# Workshop 4 - RAG with Couchbase and Node.js (with Conversation History)

![Couchbase Capella](https://img.shields.io/badge/Couchbase_Capella-Enabled-red)
[![License: MIT](https://cdn.prod.website-files.com/5e0f1144930a8bc8aace526c/65dd9eb5aaca434fac4f1c34_License-MIT-blue.svg)](/LICENSE)

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)]()

In this 4th part of the workshop, we will build upon the data and vector embeddings generated in Part 3 and integrate them into a Retrieval Augmented Generation (RAG) application with **conversation history**. We'll use a React frontend and a Node.js backend that leverages OpenAI for embeddings, Couchbase Capella for vector similarity searches, and **Couchbase for storing conversation history** to enable personalized, context-aware responses.

> 🚀 **Quick Start**: Want to get conversation history running in 5 minutes? See [QUICK_START.md](./QUICK_START.md)

## Prerequisites

- Completion of Part 3 of this workshop where you have:
- A Couchbase Capella cluster with a bucket containing documents and their vector embeddings.
- A functioning vector search index in Capella.
- An OpenAI API key.
- A working Node.js environment.

## Workshop Outline

1. [Set Up the Frontend (React)](#set-up-the-frontend-react)
2. [Set Up the Backend (Node.js)](#set-up-the-backend-nodejs)
3. [Integrate Capella Vector Search](#integrate-capella-vector-search)
4. [Integrate OpenAI for RAG](#integrate-openai-for-rag)
5. [Conversation History with Couchbase](#conversation-history-with-couchbase)
6. [Run and Test the Application](#run-and-test-the-application)

## Set Up the Frontend (React)

In this step, you’ll have a pre-configured React frontend that provides a UI for users to query your RAG application. The frontend will send user queries to your backend’s `/api/query` endpoint.

### Steps

1. Navigate to the `frontend` directory.
2. Install dependencies:  
   ```bash
   npm install
   ```
3. Start the development server:
    ```bash
    npm run dev
    ```
4. Open your browser and navigate to `http://localhost:3000`. You should see the RAG application UI.

## Set Up the Backend (Node.js)

Your backend will:

* Accept user queries from the frontend.
* Transform the queries into vector embeddings using OpenAI.
* Search for similar vectors in your Capella cluster.
* Augment the user query with the retrieved documents and request a response from OpenAI.
* Return the response to the frontend.

### Steps

1. Navigate to the `backend` directory.
2. Install dependencies:  
   ```bash
   npm install
   ```
3. Start the backend:
    ```bash
    node server.js
    ```

## Integrate Capella Vector Search

Your backend will use the Couchbase Node.js SDK to connect to Capella and execute vector similarity queries against the index created in Part 2.

Verify you have your Couchbase Capella connection config defined in `.env` file in the `backend` directory:

```env
COUCHBASE_CONNECTION_STRING=your-connection-string
COUCHBASE_USERNAME=your-username
COUCHBASE_PASSWORD=your-password
COUCHBASE_SEARCH_INDEX_NAME=your-index-name
COUCHBASE_BUCKET_NAME=your-bucket-name

# Optional: Conversation history settings (defaults shown)
COUCHBASE_CONVERSATION_SCOPE=_default
COUCHBASE_CONVERSATION_COLLECTION=conversations
```

## Integrate OpenAI for RAG

To transform user queries into embeddings and generate responses using retrieved context from Capella, you'll integrate OpenAI's API.

Verify you have your OpenAI API key defined in `.env` file in the `backend` directory:

```env
OPENAI_API_KEY=your-api-key
```

## Conversation History with Couchbase

This workshop now includes **conversation history** functionality that stores all user messages and AI responses in Couchbase. This enables:

- **Contextual conversations**: The AI remembers previous questions and answers
- **Personalized responses**: Ask questions like "What was my last question?" or "Tell me more about that"
- **Session management**: Each browser session maintains its own conversation history

### How It Works

1. **Message Storage**: Every user message and AI response is stored in a Couchbase collection
2. **Context Retrieval**: Before answering, the system retrieves recent conversation history
3. **Enhanced Prompts**: The conversation history is included in the prompt to provide context
4. **Session Tracking**: Sessions are tracked using unique IDs stored in browser sessionStorage

### Setting Up Conversation History

#### Create the Collection

In your Couchbase Capella cluster:

1. Navigate to your bucket
2. Go to the **Scopes & Collections** tab
3. Create a new collection called `conversations` in the `_default` scope (or customize using environment variables)

Alternatively, create it programmatically using N1QL:

```sql
CREATE COLLECTION `your-bucket-name`.`_default`.`conversations`;
```

#### Create an Index (Optional but Recommended)

For better query performance, create an index on the conversation collection:

```sql
CREATE INDEX idx_conversation_session 
ON `your-bucket-name`.`_default`.`conversations`(sessionId, timestamp)
WHERE type = 'chat_message';
```

### Conversation Service Features

The `conversationService.js` provides the following functions:

- `addMessage(sessionId, message, role)`: Store a user or assistant message
- `getConversationHistory(sessionId, limit)`: Retrieve recent messages for a session
- `formatConversationHistory(messages)`: Format messages for inclusion in prompts
- `clearConversationHistory(sessionId)`: Clear all messages for a session

### Testing Conversation History

Try these example queries to test the conversation memory:

1. Ask: "What is the JavaScript Array.map() method?"
2. Then ask: "What was my previous question?"
3. Or ask: "Can you explain that in simpler terms?"

The AI will use the conversation history to provide contextual responses!

### Additional Resources

For detailed technical documentation about the conversation history implementation, see [CONVERSATION_HISTORY_GUIDE.md](./CONVERSATION_HISTORY_GUIDE.md).

## Run and Test the Application

Once everything is connected, you can run both the frontend and backend together:

1. Ensure the backend (node server.js in backend) and frontend (npm run dev in frontend) servers are running.
2. Visit the frontend URL in your browser.
3. Enter a query and submit it.
4. Frontend displays the response.
