import { GoogleGenerativeAI } from '@google/generative-ai'

// Initialize Gemini AI
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY)

// Get the generative model
const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" })

/**
 * Generate a response using Gemini AI
 * @param {string} userMessage - The user's input message
 * @returns {Promise<string>} - The AI generated response
 */
export async function generateResponse(userMessage) {
  try {
    // Check if API key is configured
    console.log('GEMINI_API_KEY check:', process.env.GEMINI_API_KEY ? 'Set' : 'Not set')
    if (!process.env.GEMINI_API_KEY) {
      throw new Error('GEMINI_API_KEY is not configured. Please set it in your .env file.')
    }

    // Create a prompt for the AI
    const prompt = `You are a helpful AI assistant. Please respond to the user's message in a friendly and helpful manner. Keep your responses concise but informative.

User message: ${userMessage}`

    // Generate content using Gemini
    const result = await model.generateContent(prompt)
    const response = await result.response
    const text = response.text()

    return text.trim()

  } catch (error) {
    console.error('Error generating response with Gemini:', error)
    
    // Handle specific Gemini API errors
    if (error.message.includes('API_KEY')) {
      throw new Error('Invalid or missing Gemini API key. Please check your .env file.')
    }
    
    if (error.message.includes('quota')) {
      throw new Error('Gemini API quota exceeded. Please try again later.')
    }
    
    if (error.message.includes('safety')) {
      throw new Error('Message was blocked by safety filters. Please try rephrasing your message.')
    }
    
    // Generic error fallback
    throw new Error(`Failed to generate response: ${error.message}`)
  }
}

/**
 * Test the Gemini API connection
 * @returns {Promise<boolean>} - True if connection is successful
 */
export async function testConnection() {
  try {
    if (!process.env.GEMINI_API_KEY) {
      return false
    }
    
    const testResult = await model.generateContent('Hello')
    return !!testResult.response
  } catch (error) {
    console.error('Gemini API connection test failed:', error)
    return false
  }
}
