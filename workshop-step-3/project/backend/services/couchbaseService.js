import { connect, SearchRequest, VectorSearch, VectorQuery } from 'couchbase'
import dotenv from 'dotenv'
dotenv.config()

const {
  COUCHBASE_CONNECTION_STRING,
  COUCHBASE_USERNAME,
  COUCHBASE_PASSWORD,
  COUCHBASE_BUCKET_NAME,
  COUCHBASE_SEARCH_INDEX_NAME
} = process.env

const COUCHBASE_SCOPE_NAME = 'public'
const full_idx_name = `${COUCHBASE_BUCKET_NAME}.${COUCHBASE_SCOPE_NAME}.${COUCHBASE_SEARCH_INDEX_NAME}`

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

export async function getRelevantDocumentIdsBySourceName(embedding, sourceName) {
  const cluster = await initCouchbase()
  const scope = cluster.bucket(COUCHBASE_BUCKET_NAME).scope(COUCHBASE_SCOPE_NAME);
  
   const query = `
    SELECT SEARCH_META(d.out) hits FROM \`documentation\` d
    JOIN \`documentation\` m ON d.metaId = META(m).id
    WHERE m.name=$SOURCE AND
      SEARCH(\`d\`, {
      "query": {
          "match_none": {}
      },
      "knn": [
        {
          "k": 4,
          "field": "vector",
          "vector": $VECTOR
        }
      ]
    },
    {
    "index" : "${full_idx_name}"
    }
   )
  `
  const options = { parameters: { SOURCE: sourceName, VECTOR: embedding, COUCHBASE_SEARCH_INDEX_NAME : full_idx_name } }

  const result = await scope.query(query, options)
  
  result.rows.slice(0, 3).forEach((row, index) => {
    console.log(`${index + 1}. ID: ${row.hits.id}`)
    console.log(`   Score: ${row.hits.score.toFixed(4)}`)
    console.log(`   ---`)
  })

  return result.rows.map(row => {
    return {
        id: row.hits.id,
        score: row.hits.score
    };
  });
}

export async function getRelevantDocumentIds(embedding) {
  const cluster = await initCouchbase()
  const scope = cluster.bucket(COUCHBASE_BUCKET_NAME).scope('public');
  
  let request = SearchRequest.create(
    VectorSearch.fromVectorQuery(
        VectorQuery.create('vector', embedding).numCandidates(4)
    )
  );

  const result = await scope.search(COUCHBASE_SEARCH_INDEX_NAME, request);
  
  result.rows.slice(0, 3).forEach((row, index) => {
    console.log(`${index + 1}. ID: ${row.id}`)
    console.log(`   Score: ${row.score.toFixed(4)}`)
    console.log(`   ---`)
  })

  return result.rows.map(row => {
    return {
        id: row.id,
        score: row.score
    };
  });
}

export async function getRelevantDocuments(embedding, name) {
  const cluster = await initCouchbase();
  const bucket = cluster.bucket(COUCHBASE_BUCKET_NAME);
  
  // Try different collection approaches
  let collection;
  try {
    collection = bucket.scope('public').collection('documentation');
  } catch (error) {
    console.log('📄 Falling back to default collection')
    collection = bucket.defaultCollection();
  }
let storedEmbeddings = []
  if (!name || name.trim() === '') {
    storedEmbeddings = await getRelevantDocumentIds(embedding);
  } else {
    storedEmbeddings = await getRelevantDocumentIdsBySourceName(embedding, name);
  }

  console.log(`\n📄 Retrieving ${storedEmbeddings.length} documents...`)

  const results = await Promise.all(
    storedEmbeddings.map(async ({ id, score }, index) => {
      try {
        const result = await collection.get(id);
        const content = result.content;
        
        // Remove embedding from content
        if (content && content.embedding) {
          delete content.embedding;
        }

        // Extract filepath for logging and response
        const filepath = content.filepath || 'No filepath available';
        
        console.log(`${index + 1}. Document ID: ${id}`)
        console.log(`   Filepath: ${filepath}`)
        console.log(`   Score: ${score.toFixed(4)}`)

        return {
          id: id,
          filepath: filepath,
          content: content,
          score: score 
        };
      } catch (err) {
        console.error(`Error fetching document with ID ${id}:`, err);
        return null;
      }
    })
  );

  return results.filter(doc => doc !== null); 
}