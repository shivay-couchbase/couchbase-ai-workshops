# Simple Chatbot with OpenAI API - Workshop Step 1

![OpenAI](https://img.shields.io/badge/OpenAI-API-412991)
[![License: MIT](https://cdn.prod.website-files.com/5e0f1144930a8bc8aace526c/65dd9eb5aaca434fac4f1c34_License-MIT-blue.svg)](/LICENSE)

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/your-username/workshop-step-1)

In this workshop, you'll build a simple yet powerful chatbot application that integrates with OpenAI's models. The application consists of a modern React frontend and a robust Node.js backend, demonstrating best practices for AI-powered web applications.

## Prerequisites

- **Node.js** (v18 or higher) - [Download here](https://nodejs.org/)
- **npm** or **yarn** package manager
- **OpenAI API key** - [Get yours here](https://platform.openai.com/api-keys)

## Quick Start


#### 1. Backend Setup

```bash
cd backend
npm install
cp env.example .env
```

Edit the `.env` file and add your OpenAI API key:
```env
# OpenAI API Configuration
OPENAI_API_KEY=your_openai_api_key_here

# Server Configuration
PORT=5002
```

#### 2. Frontend Setup

```bash
cd frontend
npm install
```

#### 3. Run the Application

**Terminal 1 - Backend:**
```bash
cd backend
npm run dev
```

**Terminal 2 - Frontend:**
```bash
cd frontend
npm run dev
```

#### 4. Open the Application

Open your browser and navigate to [http://localhost:3000](http://localhost:3000)


## API Endpoints

### POST /api/chat

Send a message to the chatbot and receive an AI-generated response.

**Request:**
```json
{
  "message": "Hello, how are you?"
}
```

**Response:**
```json
{
  "response": "Hello! I'm doing well, thank you for asking. How can I help you today?",
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

**Error Response:**
```json
{
  "error": "Failed to generate response",
  "message": "Invalid or missing OpenAI API key. Please check your .env file."
}
```

## Next Steps

Congratulations! You've successfully built a working AI chatbot.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
