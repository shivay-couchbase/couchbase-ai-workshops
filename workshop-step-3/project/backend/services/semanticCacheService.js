import { connect, SearchRequest, VectorSearch, VectorQuery } from 'couchbase'
import { getEmbedding } from './openaiService.js'
import { randomUUID } from 'crypto'
import dotenv from 'dotenv'
dotenv.config()

const {
  COUCHBASE_CONNECTION_STRING,
  COUCHBASE_USERNAME,
  COUCHBASE_PASSWORD,
  COUCHBASE_BUCKET_NAME
} = process.env

// Cache configuration - using a separate bucket/scope for cache
const CACHE_CONFIG = {
  bucket: 'semantic_cache', // Back to the actual bucket in your cluster
  scope: '_default',
  collection: 'semantic',
  searchIndex: 'semantic_cache_idx' // Back to the actual index name
}

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
 * Store a cache entry with prompt, LLM signature, response, and embedding
 * @param {string} prompt - The user prompt
 * @param {string} llmString - LLM configuration signature (model, temperature, etc.)
 * @param {string} response - The LLM response to cache
 * @param {number} ttlMinutes - TTL in minutes (default: 1440 = 24 hours)
 * @returns {Object} Cache entry metadata
 */
export async function cachePut(prompt, llmString, response, ttlMinutes = 1440) {
  try {
    const cluster = await initCouchbase()
    const collection = cluster.bucket(CACHE_CONFIG.bucket)
      .scope(CACHE_CONFIG.scope)
      .collection(CACHE_CONFIG.collection)

    // Generate unique ID and get embedding
    const id = randomUUID()
    console.log(`🔢 Generating embedding for cache storage...`)
    const embedding = await getEmbedding(prompt)
    const createdAt = Date.now()

    const doc = {
      type: 'semantic_cache',
      prompt: prompt,
      llm_string: llmString,
      response: response,
      embedding: embedding,
      created_at: createdAt,
      ttl_minutes: ttlMinutes
    }

    console.log(`💾 Storing cache entry:`)
    console.log(`   - ID: ${id}`)
    console.log(`   - Prompt: "${prompt.substring(0, 50)}..."`)
    console.log(`   - Response length: ${response.length} characters`)
    console.log(`   - LLM Signature: ${llmString}`)
    console.log(`   - TTL: ${ttlMinutes} minutes`)
    console.log(`   - Embedding dimensions: ${embedding.length}`)

    // Store with TTL
    await collection.upsert(id, doc, { expiry: ttlMinutes * 60 })

    console.log(`✅ Cache entry stored successfully`)

    return { id, created_at: createdAt }
  } catch (error) {
    console.error('❌ Error storing cache entry:', error)
    throw error
  }
}

/**
 * Retrieve cached response using vector similarity search
 * @param {string} prompt - The user prompt to search for
 * @param {string} llmString - LLM configuration signature
 * @param {number} similarityThreshold - Minimum similarity score (0-1, default: 0.85)
 * @param {number} k - Number of candidates to retrieve (default: 3)
 * @returns {Object|null} Cached document or null if no match
 */
export async function cacheGet(prompt, llmString, similarityThreshold = 0.85, k = 3) {
  try {
    console.log(`🔍 Searching cache for similar queries...`)
    console.log(`   - Query: "${prompt.substring(0, 50)}..."`)
    console.log(`   - LLM Signature: ${llmString}`)
    console.log(`   - Similarity threshold: ${similarityThreshold}`)
    console.log(`   - Candidates to check: ${k}`)

    const cluster = await initCouchbase()
    const collection = cluster.bucket(CACHE_CONFIG.bucket)
      .scope(CACHE_CONFIG.scope)
      .collection(CACHE_CONFIG.collection)

    // Get embedding for the prompt
    console.log(`🔢 Generating embedding for cache search...`)
    const embedding = await getEmbedding(prompt)

    // Create vector search query
    const request = SearchRequest.create(
      VectorSearch.fromVectorQuery(
        VectorQuery.create('embedding', embedding).numCandidates(k)
      )
    )

    // Execute search
    console.log(`🔎 Executing vector similarity search...`)
    const result = await cluster.bucket(CACHE_CONFIG.bucket)
      .scope(CACHE_CONFIG.scope)
      .search(CACHE_CONFIG.searchIndex, request)

    if (!result.rows || result.rows.length === 0) {
      console.log(`❌ No similar queries found in cache`)
      return null
    }

    console.log(`📊 Found ${result.rows.length} potential matches:`)
    result.rows.forEach((row, index) => {
      console.log(`   ${index + 1}. ID: ${row.id}, Score: ${row.score.toFixed(4)}`)
    })

    // Get the top result
    const topResult = result.rows[0]
    
    // Check similarity threshold
    if (topResult.score < similarityThreshold) {
      console.log(`❌ Top match score ${topResult.score.toFixed(4)} below threshold ${similarityThreshold}`)
      return null
    }

    console.log(`✅ Top match score ${topResult.score.toFixed(4)} meets threshold`)

    // Retrieve the full document
    console.log(`📄 Retrieving document ${topResult.id}...`)
    const docResult = await collection.get(topResult.id)
    const doc = docResult.content

    // Verify LLM string matches
    if (doc.llm_string !== llmString) {
      console.log(`❌ LLM signature mismatch:`)
      console.log(`   - Expected: ${llmString}`)
      console.log(`   - Found: ${doc.llm_string}`)
      return null
    }

    console.log(`✅ LLM signature matches`)
    console.log(`🎯 CACHE HIT! Returning cached response`)
    console.log(`   - Cache ID: ${topResult.id}`)
    console.log(`   - Similarity score: ${topResult.score.toFixed(4)}`)
    console.log(`   - Response length: ${doc.response.length} characters`)

    return doc
  } catch (error) {
    console.error('❌ Error retrieving from cache:', error)
    return null
  }
}

/**
 * High-level semantic cache API
 * @param {string} prompt - The user prompt
 * @param {string} llmString - LLM configuration signature
 * @param {Function} missHandler - Function to call when cache miss occurs
 * @param {Object} options - Cache options
 * @returns {Object} Result with source, id, and response
 */
export async function semanticCache(prompt, llmString, missHandler, options = {}) {
  const {
    similarityThreshold = 0.85,
    k = 3,
    ttlMinutes = 1440
  } = options

  console.log(`\n🔍 SEMANTIC CACHE CHECK`)
  console.log(`   - Query: "${prompt.substring(0, 50)}..."`)
  console.log(`   - LLM Signature: ${llmString}`)
  console.log(`   - Similarity Threshold: ${similarityThreshold}`)
  console.log(`   - TTL: ${ttlMinutes} minutes`)

  try {
    // Try to get from cache first
    const cached = await cacheGet(prompt, llmString, similarityThreshold, k)
    
    if (cached) {
      console.log(`\n🎯 CACHE HIT!`)
      console.log(`   - Cache ID: ${cached.id || 'unknown'}`)
      console.log(`   - Response length: ${cached.response.length} characters`)
      console.log(`   - Cost saved: No LLM API call needed`)
      return {
        source: 'cache',
        id: cached.id || 'unknown',
        response: cached.response
      }
    }

    // Cache miss - call miss handler
    console.log(`\n❌ CACHE MISS!`)
    console.log(`   - No similar queries found above threshold`)
    console.log(`   - Calling miss handler to generate fresh response...`)
    const freshResponse = await missHandler()
    
    console.log(`\n💾 STORING NEW CACHE ENTRY`)
    // Store in cache for future use
    const putResult = await cachePut(prompt, llmString, freshResponse, ttlMinutes)
    
    console.log(`✅ New cache entry created with ID: ${putResult.id}`)
    
    return {
      source: 'fresh',
      id: putResult.id,
      response: freshResponse
    }
  } catch (error) {
    console.error('❌ Error in semantic cache:', error)
    console.log(`🔄 Falling back to miss handler due to error...`)
    // Fallback to miss handler on error
    const freshResponse = await missHandler()
    return {
      source: 'fresh',
      id: 'error-fallback',
      response: freshResponse
    }
  }
}

/**
 * Create LLM signature string for consistent caching
 * @param {string} model - Model name
 * @param {number} temperature - Temperature setting
 * @param {number} maxTokens - Max tokens setting
 * @param {string} systemPrompt - System prompt (optional)
 * @returns {string} LLM signature string
 */
export function createLLMSignature(model, temperature, maxTokens, systemPrompt = '') {
  return `${model}:temp=${temperature}:max=${maxTokens}:system=${systemPrompt.slice(0, 50)}`
}

/**
 * Clear cache entries (useful for testing)
 * @param {string} llmString - Optional LLM string filter
 */
export async function clearCache(llmString = null) {
  try {
    const cluster = await initCouchbase()
    const collection = cluster.bucket(CACHE_CONFIG.bucket)
      .scope(CACHE_CONFIG.scope)
      .collection(CACHE_CONFIG.collection)

    // Get all cache entries (escape 'cache' as it's a reserved word)
    const query = llmString 
      ? `SELECT META().id FROM \`${CACHE_CONFIG.bucket}\`.\`${CACHE_CONFIG.scope}\`.\`${CACHE_CONFIG.collection}\` WHERE llm_string = $1`
      : `SELECT META().id FROM \`${CACHE_CONFIG.bucket}\`.\`${CACHE_CONFIG.scope}\`.\`${CACHE_CONFIG.collection}\``

    const result = await cluster.query(query, llmString ? [llmString] : [])
    
    // Delete each entry
    for (const row of result.rows) {
      await collection.remove(row.id)
    }

    console.log(`Cleared ${result.rows.length} cache entries`)
  } catch (error) {
    console.error('Error clearing cache:', error)
    throw error
  }
}
