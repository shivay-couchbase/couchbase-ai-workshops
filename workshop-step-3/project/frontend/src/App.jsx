import React, { useState, useEffect } from 'react'
import ChatWindow from './components/ChatWindow'
import Header from './components/Header'
import './App.css'

function App() {
  const [messages, setMessages] = useState([
    {
      id: 1,
      text: "Hello! I'm your AI assistant. Ask me about Web MDN Documentation!",
      sender: 'bot',
      timestamp: new Date()
    }
  ])
  
  const [isLoading, setIsLoading] = useState(false)

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
        body: JSON.stringify({ q: messageText }),
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

