import { Router } from 'express'
import { 
  getConversationHistory, 
  clearConversationHistory 
} from '../services/conversationService.js'

const router = Router()

/**
 * GET /api/conversation/history
 * Retrieve conversation history for a session
 */
router.get('/history', async (req, res) => {
  const { sessionId, limit } = req.query

  if (!sessionId) {
    return res.status(400).json({ error: 'sessionId is required' })
  }

  try {
    const messages = await getConversationHistory(sessionId, parseInt(limit) || 10)
    res.json({
      sessionId,
      messages,
      count: messages.length
    })
  } catch (error) {
    console.error('Error retrieving conversation history:', error)
    res.status(500).json({ error: 'Failed to retrieve conversation history' })
  }
})

/**
 * DELETE /api/conversation/clear
 * Clear conversation history for a session
 */
router.delete('/clear', async (req, res) => {
  const { sessionId } = req.body

  if (!sessionId) {
    return res.status(400).json({ error: 'sessionId is required' })
  }

  try {
    await clearConversationHistory(sessionId)
    res.json({ 
      success: true, 
      message: `Conversation history cleared for session ${sessionId}` 
    })
  } catch (error) {
    console.error('Error clearing conversation history:', error)
    res.status(500).json({ error: 'Failed to clear conversation history' })
  }
})

export default router
