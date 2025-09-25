import { Router } from 'express'
import { getEmbedding, getCompletionStream } from '../services/openaiService.js'
import { getRelevantDocuments } from '../services/couchbaseService.js'
import { semanticCache, createLLMSignature } from '../services/semanticCacheService.js'

const router = Router()

router.post('/', async (req, res) => {
  const { q } = req.body

  if (!q || q.trim() === '') {
    return res.status(400).json({ error: 'Query is required.' })
  }

  // Enhanced logging for request tracking
  const requestId = Math.random().toString(36).substr(2, 9)
  const timestamp = new Date().toISOString()
  
  console.log(`\n🚀 [${requestId}] NEW REQUEST at ${timestamp}`)
  console.log(`📝 [${requestId}] Query: "${q}"`)
  console.log(`🔍 [${requestId}] Query length: ${q.length} characters`)

  try {
    // Create LLM signature for consistent caching
    const llmSignature = createLLMSignature('gpt-4', 0.7, 1000, 'You are a Web MDN Documentation expert.')
    console.log(`🔑 [${requestId}] LLM Signature: ${llmSignature}`)

    // Use semantic cache with miss handler
    const result = await semanticCache(q, llmSignature, async () => {
      console.log(`\n🔄 [${requestId}] CACHE MISS - Generating fresh response`)
      console.log(`⏱️  [${requestId}] Starting RAG pipeline...`)
      
      const embedding = await getEmbedding(q)
      const documents = await getRelevantDocuments(embedding)

      console.log(`📚 [${requestId}] Found ${documents.length} relevant documents`)

      // Step 3: Construct the prompt with document info
      const documentList = documents.map((doc, index) => 
        `Document ${index + 1}:
         ID: ${doc.id}
         Filepath: ${doc.filepath}
         Score: ${doc.score}
         Content: ${JSON.stringify(doc.content)}`
      ).join('\n\n');

      const prompt = `You are a Web MDN Documentation expert.
Given the user query and the following relevant documents, provide a helpful and accurate answer.

${documentList}

User Query: ${q}

Please provide a helpful response based on these documentation pages. Include references to the document IDs and filepaths when relevant.`

      console.log(`🤖 [${requestId}] Calling OpenAI API for completion...`)
      // Get a streaming completion
      const stream = await getCompletionStream(prompt)
      
      // Collect the full response for caching
      let fullResponse = ''
      for await (const chunk of stream) {
        const token = chunk.choices[0]?.delta?.content
        if (token) {
          fullResponse += token
        }
      }
      
      console.log(`✅ [${requestId}] Fresh response generated (${fullResponse.length} characters)`)
      console.log(`💾 [${requestId}] Storing in semantic cache...`)
      
      return fullResponse
    }, {
      similarityThreshold: 0.85,
      k: 3,
      ttlMinutes: 1440 // 24 hours
    })

    // Enhanced cache status logging
    if (result.source === 'cache') {
      console.log(`\n🎯 [${requestId}] CACHE HIT!`)
      console.log(`📦 [${requestId}] Cache ID: ${result.id}`)
      console.log(`⚡ [${requestId}] Serving cached response (${result.response.length} characters)`)
      console.log(`💰 [${requestId}] Cost saved: No OpenAI API call needed`)
    } else {
      console.log(`\n🆕 [${requestId}] FRESH RESPONSE`)
      console.log(`🆔 [${requestId}] New cache entry ID: ${result.id}`)
      console.log(`📊 [${requestId}] Response length: ${result.response.length} characters`)
      console.log(`💾 [${requestId}] Stored in cache for future similar queries`)
    }

    // Set headers for streaming response
    res.setHeader('Content-Type', 'text/plain; charset=utf-8')
    res.setHeader('Transfer-Encoding', 'chunked')

    // Send the response (either cached or fresh)
    res.write(result.response)
    res.end()
    
    console.log(`✅ [${requestId}] Response sent successfully\n`)
  } catch (error) {
    console.error(`❌ [${requestId}] Error:`, error)
    if (!res.headersSent) {
      res.status(500).json({ error: 'An error occurred while processing your request.' })
    } else {
      res.end()
    }
  }
})

export default router
