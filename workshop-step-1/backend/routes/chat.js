import express from 'express'
import { generateResponse } from '../services/openaiService.js'

const router = express.Router()

// POST /api/chat - Send message to OpenAI and get response
router.post('/chat', async (req, res) => {
  try {
    const { message, systemPrompt } = req.body

    if (!message || typeof message !== 'string') {
      return res.status(400).json({ 
        error: 'Message is required and must be a string' 
      })
    }

    if (message.trim().length === 0) {
      return res.status(400).json({ 
        error: 'Message cannot be empty' 
      })
    }

    console.log(`📨 Received message: ${message}`)
    console.log(`⚙️ System prompt: ${systemPrompt ? systemPrompt.substring(0, 50) + '...' : 'Default'}`)
    
    // Generate response using OpenAI with system prompt
    const response = await generateResponse(message, systemPrompt)
    
    console.log(`🤖 Generated response: ${response.substring(0, 100)}...`)
    
    res.json({ 
      response,
      timestamp: new Date().toISOString()
    })

  } catch (error) {
    console.error('❌ Error in chat route:', error)
    
    res.status(500).json({ 
      error: 'Failed to generate response',
      message: error.message 
    })
  }
})

export default router
