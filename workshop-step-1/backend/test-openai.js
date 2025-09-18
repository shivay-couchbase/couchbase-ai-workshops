import { generateResponse } from './services/openaiService.js'
import dotenv from 'dotenv'

// Load environment variables
dotenv.config()

async function testOpenAI() {
  try {
    console.log('Testing OpenAI API...')
    console.log('API Key:', process.env.OPENAI_API_KEY ? 'Set' : 'Not set')
    
    const response = await generateResponse('Hello, how are you?')
    console.log('Success! Response:', response)
  } catch (error) {
    console.log('Error:', error.message)
  }
}

testOpenAI()
