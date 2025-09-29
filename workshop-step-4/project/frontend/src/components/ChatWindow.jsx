import React, { useState, useRef, useEffect } from 'react'
import MessageBubble from './MessageBubble'
import './ChatWindow.css'

const ChatWindow = ({ messages, onSendMessage, isLoading }) => {
  const [inputMessage, setInputMessage] = useState('')
  const messagesEndRef = useRef(null)

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" })
  }

  useEffect(() => {
    scrollToBottom()
  }, [messages])

  const handleSubmit = (e) => {
    e.preventDefault()
    if (inputMessage.trim() && !isLoading) {
      onSendMessage(inputMessage.trim())
      setInputMessage('')
    }
  }

  return (
    <div className="chat-window">
      <div className="messages-container">
        {messages.map((message) => (
          <MessageBubble key={message.id} message={message} />
        ))}
        {isLoading && (
          <div className="message bot-message">
            <div className="message-content">
              <div className="typing-indicator">
                <span></span>
                <span></span>
                <span></span>
              </div>
            </div>
          </div>
        )}
        <div ref={messagesEndRef} />
      </div>
      
      <form className="input-form" onSubmit={handleSubmit}>
        <div className="input-container">
          <input
            type="text"
            value={inputMessage}
            onChange={(e) => setInputMessage(e.target.value)}
            placeholder="Ask about the docs..."
            disabled={isLoading}
            className="message-input"
          />
          <button 
            type="submit" 
            disabled={!inputMessage.trim() || isLoading}
            className="send-button"
          >
            Send
          </button>
        </div>
      </form>
    </div>
  )
}

export default ChatWindow
