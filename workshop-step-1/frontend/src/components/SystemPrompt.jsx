import React, { useState, useEffect } from 'react'
import './SystemPrompt.css'

function SystemPrompt({ systemPrompt, onSystemPromptChange, isVisible, onToggleVisibility, defaultSystemPrompt }) {
  const [tempPrompt, setTempPrompt] = useState(systemPrompt)

  // System prompt presets for easy configuration
  const systemPromptPresets = [
    {
      name: "Default Assistant",
      prompt: defaultSystemPrompt
    },
    {
      name: "Code Helper",
      prompt: "You are an expert programmer and coding assistant. Help users with coding questions, debug issues, explain concepts, and provide code examples. Always format code properly with syntax highlighting when possible."
    },
    {
      name: "Creative Writer",
      prompt: "You are a creative writing assistant. Help users with storytelling, creative writing, brainstorming ideas, character development, and plot creation. Be imaginative and inspiring while providing constructive feedback."
    },
    {
      name: "Business Advisor",
      prompt: "You are a knowledgeable business consultant. Provide strategic advice, help with business planning, market analysis, and professional communication. Keep responses practical and actionable."
    },
    {
      name: "Educational Tutor",
      prompt: "You are a patient and knowledgeable tutor. Break down complex topics into simple explanations, provide examples, and encourage learning. Adapt your teaching style to help students understand concepts clearly."
    },
    {
      name: "Technical Documentarian",
      prompt: "You are a technical documentation specialist. Help create clear, comprehensive documentation, API guides, user manuals, and technical specifications. Focus on clarity, accuracy, and usability."
    }
  ]

  // Update tempPrompt when systemPrompt changes (useful when loading from localStorage)
  useEffect(() => {
    setTempPrompt(systemPrompt)
  }, [systemPrompt])

  const handleSave = () => {
    onSystemPromptChange(tempPrompt)
    onToggleVisibility()
  }

  const handleCancel = () => {
    setTempPrompt(systemPrompt)
    onToggleVisibility()
  }

  const handleReset = () => {
    setTempPrompt(defaultSystemPrompt)
  }

  const handlePresetSelect = (preset) => {
    setTempPrompt(preset.prompt)
  }

  if (!isVisible) {
    return (
      <div className="system-prompt-toggle">
        <button 
          className="toggle-button"
          onClick={onToggleVisibility}
          title="Configure System Prompt"
        >
          ⚙️ System Prompt
        </button>
      </div>
    )
  }

  return (
    <div className="system-prompt-overlay">
      <div className="system-prompt-modal">
        <div className="system-prompt-header">
          <h3>Configure System Prompt</h3>
          <button 
            className="close-button"
            onClick={handleCancel}
            title="Close"
          >
            ✕
          </button>
        </div>
        
        <div className="system-prompt-content">
          <p className="system-prompt-description">
            The system prompt defines how the AI assistant should behave and respond. 
            This will be sent with every user message to provide context to the AI.
          </p>

          <div className="presets-section">
            <label className="presets-label">Quick Start Templates:</label>
            <div className="presets-grid">
              {systemPromptPresets.map((preset, index) => (
                <button
                  key={index}
                  className="preset-button"
                  onClick={() => handlePresetSelect(preset)}
                  title={`Use ${preset.name} template`}
                >
                  {preset.name}
                </button>
              ))}
            </div>
          </div>
          
          <div className="textarea-container">
            <label htmlFor="system-prompt-textarea">System Prompt:</label>
            <textarea
              id="system-prompt-textarea"
              value={tempPrompt}
              onChange={(e) => setTempPrompt(e.target.value)}
              placeholder="Enter your system prompt here..."
              rows={8}
              className="system-prompt-textarea"
            />
          </div>
          
          <div className="character-count">
            {tempPrompt.length} characters
          </div>
        </div>
        
        <div className="system-prompt-actions">
          <button 
            className="reset-button"
            onClick={handleReset}
            title="Reset to default prompt"
          >
            Reset to Default
          </button>
          
          <div className="action-buttons">
            <button 
              className="cancel-button"
              onClick={handleCancel}
            >
              Cancel
            </button>
            <button 
              className="save-button"
              onClick={handleSave}
            >
              Save
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}

export default SystemPrompt
