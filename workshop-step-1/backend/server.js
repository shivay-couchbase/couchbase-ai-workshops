import express from 'express'
import cors from 'cors'
import dotenv from 'dotenv'
import { fetch, Headers, Request, Response } from 'undici'
import chatRoutes from './routes/chat.js'

// Load environment variables
dotenv.config()

// Polyfill fetch and related APIs for Node.js
global.fetch = fetch
global.Headers = Headers
global.Request = Request
global.Response = Response

// Debug environment variables
console.log('Environment check:')
console.log('OPENAI_API_KEY:', process.env.OPENAI_API_KEY ? 'Set' : 'Not set')
console.log('PORT:', process.env.PORT)

const app = express()
const PORT = process.env.PORT || 5000

// Middleware
app.use(cors())
app.use(express.json())

// Routes
app.use('/api', chatRoutes)

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'OK', message: 'Server is running' })
})

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack)
  res.status(500).json({ 
    error: 'Something went wrong!',
    message: err.message 
  })
})

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({ error: 'Route not found' })
})

app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`)
  console.log(`📱 Frontend should be running on http://localhost:3000`)
  console.log(`🔗 Backend API available at http://localhost:${PORT}`)
})
