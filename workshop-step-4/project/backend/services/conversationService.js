import { connect } from 'couchbase'
import dotenv from 'dotenv'
dotenv.config()

const {
  COUCHBASE_CONNECTION_STRING,
  COUCHBASE_USERNAME,
  COUCHBASE_PASSWORD,
  COUCHBASE_BUCKET_NAME,
  COUCHBASE_CONVERSATION_SCOPE,
  COUCHBASE_CONVERSATION_COLLECTION
} = process.env

let cluster

async function initCouchbase() {
  if (!cluster) {
    cluster = await connect(COUCHBASE_CONNECTION_STRING, {
      username: COUCHBASE_USERNAME,
      password: COUCHBASE_PASSWORD,
      configProfile: 'wanDevelopment',
    })
  }
  return cluster
}

/**
 * Store a message in the conversation history
 * @param {string} sessionId - Unique identifier for the conversation session
 * @param {string} message - The message content
 * @param {string} role - Either 'user' or 'assistant'
 */
export async function addMessage(sessionId, message, role) {
  const cluster = await initCouchbase()
  const bucket = cluster.bucket(COUCHBASE_BUCKET_NAME)
  
  const scope = COUCHBASE_CONVERSATION_SCOPE || '_default'
  const collectionName = COUCHBASE_CONVERSATION_COLLECTION || 'conversations'
  
  const collection = bucket.scope(scope).collection(collectionName)

  const messageDoc = {
    sessionId,
    role, // 'user' or 'assistant'
    content: message,
    timestamp: new Date().toISOString(),
    type: 'chat_message'
  }

  // Generate a unique ID for the message
  const messageId = `${sessionId}_${Date.now()}_${role}`

  try {
    await collection.insert(messageId, messageDoc)
    console.log(`💾 Stored ${role} message for session ${sessionId}`)
  } catch (error) {
    console.error('Error storing message:', error)
    throw error
  }
}

/**
 * Retrieve conversation history for a session
 * @param {string} sessionId - Unique identifier for the conversation session
 * @param {number} limit - Maximum number of messages to retrieve (default: 10)
 * @returns {Array} Array of message objects ordered by timestamp
 */
export async function getConversationHistory(sessionId, limit = 10) {
  const cluster = await initCouchbase()
  const bucket = cluster.bucket(COUCHBASE_BUCKET_NAME)
  
  const scope = COUCHBASE_CONVERSATION_SCOPE || '_default'
  
  try {
    // Query to get conversation history for this session
    // Note: 'role' is a reserved word in N1QL, so it must be escaped with backticks
    const query = `
      SELECT content, \`role\`, timestamp
      FROM \`${COUCHBASE_BUCKET_NAME}\`.\`${scope}\`.\`${COUCHBASE_CONVERSATION_COLLECTION || 'conversations'}\`
      WHERE sessionId = $sessionId AND type = 'chat_message'
      ORDER BY timestamp DESC
      LIMIT $limit
    `

    const result = await cluster.query(query, {
      parameters: { sessionId, limit }
    })

    const messages = result.rows.map(row => ({
      role: row.role,
      content: row.content,
      timestamp: row.timestamp
    }))

    // Reverse to get chronological order (oldest first)
    messages.reverse()

    console.log(`📖 Retrieved ${messages.length} messages for session ${sessionId}`)
    return messages
  } catch (error) {
    console.error('Error retrieving conversation history:', error)
    // Return empty array if there's an error (e.g., collection doesn't exist yet)
    return []
  }
}

/**
 * Format conversation history for inclusion in prompt
 * @param {Array} messages - Array of message objects
 * @returns {string} Formatted conversation history
 */
export function formatConversationHistory(messages) {
  if (!messages || messages.length === 0) {
    return 'No previous conversation history.'
  }

  return messages
    .map((msg) => {
      const role = msg.role === 'user' ? 'User' : 'Assistant'
      return `${role}: ${msg.content}`
    })
    .join('\n')
}

/**
 * Clear conversation history for a session
 * @param {string} sessionId - Unique identifier for the conversation session
 */
export async function clearConversationHistory(sessionId) {
  const cluster = await initCouchbase()
  const bucket = cluster.bucket(COUCHBASE_BUCKET_NAME)
  
  const scope = COUCHBASE_CONVERSATION_SCOPE || '_default'
  
  try {
    const query = `
      DELETE FROM \`${COUCHBASE_BUCKET_NAME}\`.\`${scope}\`.\`${COUCHBASE_CONVERSATION_COLLECTION || 'conversations'}\`
      WHERE sessionId = $sessionId AND type = 'chat_message'
    `

    await cluster.query(query, {
      parameters: { sessionId }
    })

    console.log(`🗑️  Cleared conversation history for session ${sessionId}`)
  } catch (error) {
    console.error('Error clearing conversation history:', error)
    throw error
  }
}
