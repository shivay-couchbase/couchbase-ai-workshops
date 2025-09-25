# Provider-agnostic embed helper
# Gemini
#  api: keys https://aistudio.google.com/u/0/api-keys
#  doc: https://ai.google.dev/gemini-api/docs/embeddings
#  command: embed --provider gemini "hello world"
#
# Voyage
#  api: https://dashboard.voyageai.com/api-keys
#  doc: https://docs.voyageai.com/docs/embeddings
#  run: embed --provider voyage --model "voyage-3-large" "hello world"
# Cohere
#  api: https://dashboard.cohere.com/api-keys
#  doc: https://dashboard.cohere.com/api-keys
#  run: embed --provider cohere --model "embed-english-v3.0" "hello world"
# Ollama
#  doc: https://ollama.com/blog/embedding-models
#   embed --provider ollama --model "nomic-embed-text" "hello world"
# OpenAI
#  api: https://platform.openai.com/api-keys
#  doc: https://platform.openai.com/docs/api-reference/embeddings
#   embed --provider openai --model "text-embedding-3-small" "hello world"

export def embed [
  content,                        # support string or list<string>
  --provider:string = "openai",   # gemini | voyage | cohere | ollama | openai 
  --model:string,                 # optional model override
  --dimensions:int            # optional dimension of the vector
  --task:string                   # optional task hint (cohere input_type, gemini taskType, etc.)
] {

  match $provider {
    "gemini" => {
      # Gemini: https://generativelanguage.googleapis.com
      if ($env.GEMINI_API_KEY | default "" | is-empty) { error make { msg: "Set GEMINI_API_KEY" } }
      let mdl = ($model | default "models/gemini-embedding-001")
      let dimensions = ($dimensions | default 1536)
      let content_type = $content | describe 
      let $content = match $content_type {
        "string" =>  [ (gemini_content_format $content $mdl $dimensions) ]
        "list<string>" => ( $content | each { |t|  gemini_content_format $t $mdl $dimensions}   )
        _ => { error make { msg: "Content was neither a string or list of string" }}
      }

      let body = { requests : $content}
      http post -H [
        "x-goog-api-key" $env.GEMINI_API_KEY,
        "Content-Type" "application/json"
      ] "https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:batchEmbedContents" ($body | to json)
      | get embeddings.values
    }

    "voyage" => {
      # Voyage: https://api.voyageai.com/v1/embeddings
      if ($env.VOYAGE_API_KEY | default "" | is-empty) { error make { msg: "Set VOYAGE_API_KEY" } }
      let dimensions = ($dimensions | default 1024)
      let mdl = ($model | default "voyage-3.5")
      let body = { output_dimension:$dimensions, model: $mdl, input: $content, "input_type": "document"  }
      http post -H [
        "Authorization" $"Bearer ($env.VOYAGE_API_KEY)",
        "Content-Type" "application/json"
      ] "https://api.voyageai.com/v1/embeddings" ($body | to json)
    | get data.embedding
    }

    "cohere" => {
      # Cohere: https://api.cohere.com/v1/embeddings
      if ($env.COHERE_API_KEY | default "" | is-empty) { error make { msg: "Set COHERE_API_KEY" } }
      let dimensions = ($dimensions | default 1536)
      let content_type = $content | describe 
      let $content = match $content_type {
        "string" => [ $content ]
        "list<string>" => $content
        _ => { error make { msg: "Content was neither a string or list of string" }}
      }
      let mdl = ($model | default "embed-english-v3.0")
      let itype = ($task | default "classification")
      let body = {output_dimension:$dimensions, model: $mdl, texts: $content , input_type: $itype, truncate: "NONE" }
      http post -H [
        "Authorization" $"Bearer ($env.COHERE_API_KEY)",
        "Content-Type" "application/json"
      ] "https://api.cohere.com/v1/embed" ($body | to json)
      | get embeddings
    }

    "ollama" => {
      # Ollama: POST $OLLAMA_HOST/api/embeddings
      let host = ($env.OLAMA_HOST? | default "http://127.0.0.1:11434")
      let mdl = ($model | default "nomic-embed-text")
      let body = { model: $mdl, input: $content }
      http post --headers [ "Content-Type" "application/json" ] $"($host)/api/embed" ($body | to json)
      | get embeddings
    }

    "openai" => {
      # OpenAI: https://api.openai.com/v1/embeddings
      if ($env.OPENAI_API_KEY | default "" | is-empty) { error make { msg: "Set OPENAI_API_KEY" } }
      let dimensions = ($dimensions | default 1536)
      let mdl = ($model | default "text-embedding-3-small")
      let body = { dimensions: $dimensions, input: $content, model: $mdl }
      http post -H [
        "Authorization" $"Bearer ($env.OPENAI_API_KEY)",
        "Content-Type" "application/json"
      ] "https://api.openai.com/v1/embeddings" ($body | to json)
      | get data.embedding
    }
    _ => {
      error make { msg: $"Unknown provider: ($provider)" }
    }
  }
}

def gemini_content_format [
  text
  model
  dimensions
] {
    {
      "model": $model,
      "content": {
        "parts":[{
          "text": $text
          }]
      },
      "output_dimensionality": $dimensions 
    }
}