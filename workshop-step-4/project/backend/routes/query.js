import { Router } from 'express'
import { getEmbedding, getCompletionStream } from '../services/openaiService.js'
import { getRelevantDocuments } from '../services/couchbaseService.js'
import { 
  addMessage, 
  getConversationHistory, 
  formatConversationHistory 
} from '../services/conversationService.js'

const router = Router()

router.post('/', async (req, res) => {
  const { q, sessionId } = req.body

  if (!q || q.trim() === '') {
    return res.status(400).json({ error: 'Query is required.' })
  }

  // Generate a session ID if not provided (for demo purposes)
  const session = sessionId || 'default-session'

  try {
    // Step 1: Store the user's message in conversation history
    await addMessage(session, q, 'user')

    // Step 2: Retrieve conversation history for context
    const conversationHistory = await getConversationHistory(session, 10)
    const formattedHistory = formatConversationHistory(conversationHistory)

    // Step 3: Generate embedding for the query
    const embedding = await getEmbedding(q)

    // Step 4: Get relevant documents from vector search
    const documents = await getRelevantDocuments(embedding)

    // Step 5: Construct the prompt with document info and conversation history
    const documentList = documents.map((doc, index) => 
      `Document ${index + 1}:
       ID: ${doc.id}
       Filepath: ${doc.filepath}
       Score: ${doc.score}
       Content: ${JSON.stringify(doc.content)}`
    ).join('\n\n');

    const prompt = `You are a Web MDN Documentation expert with access to the conversation history.
Given the user query, conversation history, and the following relevant documents, provide a helpful and accurate answer.

CONVERSATION HISTORY:
${formattedHistory}

RELEVANT DOCUMENTS:
${documentList}

CURRENT USER QUERY: ${q}

Please provide a helpful response based on the documentation pages and conversation context. 
If the user asks about previous questions or the conversation history, use the conversation history above.
Include references to the document IDs and filepaths when relevant.`

    // Set headers for streaming response
    res.setHeader('Content-Type', 'text/plain; charset=utf-8')
    res.setHeader('Transfer-Encoding', 'chunked')

    // Step 6: Get a streaming completion
    const stream = await getCompletionStream(prompt)

    let fullResponse = ''

    // Iterate over the streamed chunks and send them to the client as they arrive
    for await (const chunk of stream) {
      const token = chunk.choices[0]?.delta?.content
      if (token) {
        fullResponse += token
        res.write(token)
      }
    }

    // Step 7: Store the assistant's response in conversation history
    await addMessage(session, fullResponse, 'assistant')

    // When the stream ends, end the response
    res.end()
  } catch (error) {
    console.error(error)
    if (!res.headersSent) {
      res.status(500).json({ error: 'An error occurred while processing your request.' })
    } else {
      res.end()
    }
  }
})

export default router
