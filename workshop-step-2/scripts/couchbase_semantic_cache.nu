use utils.nu *
use embedding.nu *

def cache_config [] {
    {
        bucket : "cache"
        scope : "_default"
        collection : "semantic"
        keyspace : "`cache`.`_default`.`semantic`"
    }
}

# Import the index manually for now
def ensure-index [] {
  let def = {
    "type": "fulltext-index",
    "name": "cache._default.semantic_cache_idx",
    "uuid": "785f8d8ac31f9bdb",
    "sourceType": "gocbcore",
    "sourceName": "cache",
    "sourceUUID": "88f2a56ac8673c4e174963f666dcc907",
    "planParams": {
      "maxPartitionsPerPIndex": 1024,
      "indexPartitions": 1
    },
    "params": {
      "doc_config": {
        "docid_prefix_delim": "",
        "docid_regexp": "",
        "mode": "scope.collection.type_field",
        "type_field": "type"
      },
      "mapping": {
        "analysis": {},
        "default_analyzer": "standard",
        "default_datetime_parser": "dateTimeOptional",
        "default_field": "_all",
        "default_mapping": {
          "dynamic": true,
          "enabled": false
        },
        "default_type": "_default",
        "docvalues_dynamic": false,
        "index_dynamic": true,
        "store_dynamic": false,
        "type_field": "_type",
        "types": {
          "_default.semantic": {
            "dynamic": true,
            "enabled": true,
            "properties": {
              "embedding": {
                "dynamic": false,
                "enabled": true,
                "fields": [
                  {
                    "dims": 1536,
                    "index": true,
                    "name": "embedding",
                    "similarity": "dot_product",
                    "type": "vector"
                  }
                ]
              },
              "llm_string": {
                "dynamic": false,
                "enabled": true,
                "fields": [
                  {
                    "index": true,
                    "name": "llm_string",
                    "store": true,
                    "type": "text"
                  }
                ]
              }
            }
          }
        }
      },
      "store": {
        "indexType": "scorch",
        "segmentVersion": 16
      }
    },
    "sourceParams": {}
  }
}


# Insert/Upsert a cache entry (stores prompt, embedding, llm signature, response)
def cache-put [
  prompt:string,
  llm_string:string,
  response:string,
  --ttl-minutes:int=1440
] {
  let config = cache_config
  let id = (random uuid)
  let created_at = epoch_now_nano
  let vec = (embed $prompt)

  let doc = {
    type: "semantic_cache",
    prompt: $prompt,
    llm_string: $llm_string,
    response: $response,
    embedding: $vec,
    created_at: $created_at,
    ttl_minutes: $ttl_minutes
  }

  doc upsert --bucket $config.bucket --scope $config.scope --collection $config.collection $id $doc
  { id: $id, created_at: $created_at }
}

# Lookup nearest cached prompt with Vector Search (FTS KNN)
def cache-get [
  prompt:string,
  llm_string:string,
  --similarity_threshold:float=0.85,
  --k:int=3
] {
  let config = cache_config
  let vec = (embed $prompt).0

  let query = {
    "knn": [ { "k": $k, "field": "embedding", "vector": $vec } ],
    "filter": { "term": $llm_string, "field": "llm_string" },
    "includeLocations": true
  }

 let query_options = {
    "index" : "cache._default.semantic_cache_idx"
  }

  let res = query $"SELECT SEARCH_META\(\) as hits, c.*  FROM ($config.keyspace) c where SEARCH\(c, ($query | to json),($query_options | to json)  \)"
  if ($res.hits? | flatten | is-empty) { return null }
  let top = ($res.hits | first)

  # NOTE: vector queries are scored by similarity; higher is better.
  # Tune similarity_threshold for your model/index.
  if ($top.score < $similarity_threshold) { return null }

  let docid = $top.id
  ($docid | doc get --bucket $config.bucket --scope $config.scope --collection $config.collection )
}

# High-level API: returns {source, id, response}
def semantic-cache [
  prompt:string,
  llm_string:string,
  --miss_handler:closure # closure that returns a string when there's a cache miss
] {
  let cached = (cache-get $prompt $llm_string)
  if $cached != null {
    { source: "cache", id: $cached.id, response: $cached.content }
  } else {
    if ($miss_handler | describe | str contains "closure") {
      let fresh = (do $miss_handler)
      let putres = (cache-put $prompt $llm_string $fresh)
      { source: "fresh", id: $putres.id, response: $fresh }
    } else {
      null
    }
  }
}