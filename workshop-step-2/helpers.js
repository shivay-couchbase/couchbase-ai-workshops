const openai = require('openai');
const couchbase = require('couchbase');
require('dotenv').config();

// Initialize OpenAI client
const openaiclient = new openai.OpenAI({ apiKey: process.env.OPENAI_API_KEY });

/**
 * Generate embeddings for a query using OpenAI's text-embedding-ada-002 model.
 * 
 * @param {string} query - The text to generate embeddings for.
 * @returns {Array} The embedding vector.
 */
async function generateQueryEmbedding(query) {
  const response = await openaiclient.embeddings.create({
    model: 'text-embedding-ada-002',
    input: query,
  });
  return response.data[0].embedding;
}

let cluster;
async function init() {
  if (!cluster) {
    cluster = await couchbase.connect(process.env.COUCHBASE_URL, {
      username: process.env.COUCHBASE_USERNAME,
      password: process.env.COUCHBASE_PASSWORD,
      configProfile: "wanDevelopment",
    });
  }
  return cluster;
}

/**
 * Store JSON document with its embedding in Couchbase.
 * 
 * @param {string} content - The JSON content to store.
 * @param {string} id - The document identifier.
 * @returns {Object} The stored document information.
 */
async function storeEmbedding(content, id) {
  try {
    console.log(`Processing document: ${id}...`);

    // Parse the JSON content
    let parsedContent;
    try {
      parsedContent = JSON.parse(content);
    } catch (parseErr) {
      console.error(`Invalid JSON in file ${id}:`, parseErr);
      throw new Error(`Invalid JSON in file ${id}: ${parseErr.message}`);
    }

    // Generate embedding for the content
    // For JSON documents, we'll embed the string representation
    console.log(`Generating embedding for ${id}...`);
    const embedding = await generateQueryEmbedding(JSON.stringify(parsedContent));
    console.log(`Embedding generated for ${id}.`);

    // Connect to Couchbase
    console.log(`Connecting to Couchbase for ${id}...`);
    const cluster = await init();
    const bucket = cluster.bucket(process.env.COUCHBASE_BUCKET);
    const collection = bucket.defaultCollection();

    // Store document with embedding
    const document = { ...parsedContent, embedding };
    const docId = `embedding::${id}`;
    
    console.log(`Storing document ${docId}...`);
    await collection.upsert(docId, document);
    console.log(`Document stored successfully: ${docId}`);

    return { docId, success: true };
  } catch (err) {
    console.error(`Error storing document ${id}:`, err);
    throw err;
  }
}

module.exports = { generateQueryEmbedding, storeEmbedding };
