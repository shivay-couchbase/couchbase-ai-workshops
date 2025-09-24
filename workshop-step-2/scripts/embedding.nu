# Provider-agnostic embed helper using `match`.
#   embed --provider gemini "hello world"
#   embed --provider voyage --model "voyage-3-large" "hello world"
#   embed --provider cohere --model "embed-english-v3.0" "hello world"
#   embed --provider ollama --model "nomic-embed-text" "hello world"
#   embed --provider openai --model "text-embedding-3-small" "hello world"

def embed [
  text:string,
  --provider:string = "openai",          # gemini | voyage | cohere | ollama | openai | anthropic/claude | openrouter
  --model:string,             # optional model override
  --task:string               # optional task hint (cohere input_type, gemini taskType, etc.)
] {

  match $provider {
    "gemini" => {
      # Gemini: https://generativelanguage.googleapis.com
      if ($env.GEMINI_API_KEY | default "" | is-empty) { error make { msg: "Set GEMINI_API_KEY" } }
      let mdl = ($model | default "models/gemini-embedding-001")
      let body = {
        model: $mdl,
        content: { parts: [ { text: $text } ] },
        taskType: ($task | default null)
      }
      http post -H [
        "x-goog-api-key" $"($env.GEMINI_API_KEY)",
        "Content-Type" "application/json"
      ] "https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent" ($body | to json)
      | get embedding.values
    }

    "voyage" => {
      # Voyage: https://api.voyageai.com/v1/embeddings
      if ($env.VOYAGE_API_KEY | default "" | is-empty) { error make { msg: "Set VOYAGE_API_KEY" } }
      let mdl = ($model | default "voyage-3-large")
      let body = { model: $mdl, input: [ $text ] }
      http post -H [
        "Authorization" $"Bearer ($env.VOYAGE_API_KEY)",
        "Content-Type" "application/json"
      ] "https://api.voyageai.com/v1/embeddings" ($body | to json)
      | get data.0.embedding
    }

    "cohere" => {
      # Cohere: https://api.cohere.com/v1/embeddings
      if ($env.COHERE_API_KEY | default "" | is-empty) { error make { msg: "Set COHERE_API_KEY" } }
      let mdl = ($model | default "embed-english-v3.0")
      let itype = ($task | default "search_document")
      let body = { model: $mdl, texts: [ $text ], input_type: $itype }
      http post -H [
        "Authorization" $"Bearer ($env.COHERE_API_KEY)",
        "Content-Type" "application/json"
      ] "https://api.cohere.com/v1/embeddings" ($body | to json)
      | get embeddings.0
    }

    "ollama" => {
      # Ollama: POST $OLLAMA_HOST/api/embeddings
      let host = ($env.OLAMA_HOST? | default "http://127.0.0.1:11434")
      let mdl = ($model | default "nomic-embed-text")
      let body = { model: $mdl, input: $text }
      http post --headers [ "Content-Type" "application/json" ] $"($host)/api/embed" ($body | to json)
      | get embeddings
    }

    "openai" => {
      # OpenAI: https://api.openai.com/v1/embeddings
      if ($env.OPENAI_API_KEY | default "" | is-empty) { error make { msg: "Set OPENAI_API_KEY" } }
      let mdl = ($model | default "text-embedding-3-small")
      let body = { input: $text, model: $mdl }
      http post -H [
        "Authorization" $"Bearer ($env.OPENAI_API_KEY)",
        "Content-Type" "application/json"
      ] "https://api.openai.com/v1/embeddings" ($body | to json)
      | get data.0.embedding
    }
    _ => {
      error make { msg: $"Unknown provider: ($provider)" }
    }
  }
}