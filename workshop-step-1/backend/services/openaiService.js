import OpenAI from 'openai'

// Initialize OpenAI client (will be created when needed)
let openai = null

/**
 * Generate a response using OpenAI GPT
 * @param {string} userMessage - The user's input message
 * @returns {Promise<string>} - The AI generated response
 */
export async function generateResponse(userMessage) {
  try {
    // Check if API key is configured
    console.log('OPENAI_API_KEY check:', process.env.OPENAI_API_KEY ? 'Set' : 'Not set')
    if (!process.env.OPENAI_API_KEY) {
      throw new Error('OPENAI_API_KEY is not configured. Please set it in your .env file.')
    }

    // Initialize OpenAI client if not already done
    if (!openai) {
      openai = new OpenAI({
        apiKey: process.env.OPENAI_API_KEY,
      })
    }

    // Create a prompt for the AI
    const prompt = `You are a helpful AI assistant. Please respond to the user's message in a friendly and helpful manner. Keep your responses concise but informative.

User message: ${userMessage}`

    // Generate content using OpenAI
    const completion = await openai.chat.completions.create({
      model: "gpt-4o",
      messages: [
        {
          role: "system",
          content: "You are a helpful AI assistant. Please respond to the user's message in a friendly and helpful manner. Keep your responses concise but informative."
        },
        {
          role: "user",
          content: userMessage
        }
      ],
      max_tokens: 1000,
      temperature: 0.7,
    })

    const response = completion.choices[0]?.message?.content

    if (!response) {
      throw new Error('No response generated from OpenAI')
    }

    return response.trim()

  } catch (error) {
    console.error('Error generating response with OpenAI:', error)
    
    // Handle specific OpenAI API errors
    if (error.message.includes('API key')) {
      throw new Error('Invalid or missing OpenAI API key. Please check your .env file.')
    }
    
    if (error.message.includes('quota')) {
      throw new Error('OpenAI API quota exceeded. Please try again later.')
    }
    
    if (error.message.includes('rate limit')) {
      throw new Error('OpenAI API rate limit exceeded. Please try again later.')
    }
    
    // Generic error fallback
    throw new Error(`Failed to generate response: ${error.message}`)
  }
}

/**
 * Test the OpenAI API connection
 * @returns {Promise<boolean>} - True if connection is successful
 */
export async function testConnection() {
  try {
    if (!process.env.OPENAI_API_KEY) {
      return false
    }
    
    // Initialize OpenAI client if not already done
    if (!openai) {
      openai = new OpenAI({
        apiKey: process.env.OPENAI_API_KEY,
      })
    }
    
    const completion = await openai.chat.completions.create({
      model: "gpt-3.5-turbo",
      messages: [{ role: "user", content: "Hello" }],
      max_tokens: 10,
    })
    
    return !!completion.choices[0]?.message?.content
  } catch (error) {
    console.error('OpenAI API connection test failed:', error)
    return false
  }
}
