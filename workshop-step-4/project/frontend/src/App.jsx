import React, { useState, useEffect } from 'react'
import ChatWindow from './components/ChatWindow'
import Header from './components/Header'
import './App.css'

// Generate a unique session ID for this browser session
const getOrCreateSessionId = () => {
  let sessionId = sessionStorage.getItem('chat-session-id')
  if (!sessionId) {
    sessionId = `session-${Date.now()}-${Math.random().toString(36).substring(7)}`
    sessionStorage.setItem('chat-session-id', sessionId)
  }
  return sessionId
}

function App() {
  const [messages, setMessages] = useState([
    {
      id: 1,
      text: "Hello! I'm your AI assistant. Ask me about Web MDN Documentation! I can remember our conversation, so feel free to ask follow-up questions.",
      sender: 'bot',
      timestamp: new Date()
    }
  ])
  
  const [isLoading, setIsLoading] = useState(false)
  const [sessionId] = useState(getOrCreateSessionId())

  const sendMessage = async (messageText) => {
    const userMessage = {
      id: Date.now(),
      text: messageText,
      sender: 'user',
      timestamp: new Date()
    }

    setMessages(prev => [...prev, userMessage])
    setIsLoading(true)

    try {
      const response = await fetch('/api/query', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ 
          q: messageText,
          sessionId: sessionId 
        }),
      })

      if (!response.ok) {
        throw new Error('Failed to send message')
      }

      // Handle streaming response
      const reader = response.body.getReader()
      const decoder = new TextDecoder()
      let botResponseText = ''

      const botMessage = {
        id: Date.now() + 1,
        text: '',
        sender: 'bot',
        timestamp: new Date()
      }
      
      setMessages(prev => [...prev, botMessage])

      while (true) {
        const { value, done } = await reader.read()
        if (done) break
        
        const chunk = decoder.decode(value, { stream: true })
        botResponseText += chunk
        
        setMessages(prev => 
          prev.map(msg => 
            msg.id === botMessage.id 
              ? { ...msg, text: botResponseText }
              : msg
          )
        )
      }
    } catch (error) {
      console.error('Error sending message:', error)
      const errorMessage = {
        id: Date.now() + 1,
        text: 'Sorry, I encountered an error. Please try again.',
        sender: 'bot',
        timestamp: new Date()
      }
      setMessages(prev => [...prev, errorMessage])
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <div className="app">
      <Header />
      <ChatWindow 
        messages={messages} 
        onSendMessage={sendMessage}
        isLoading={isLoading}
      />
    </div>
  )
}

export default App

