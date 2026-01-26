# AI-Study-Helper

<img width="1894" height="902" alt="Screenshot 2025-12-05 184232" src="https://github.com/user-attachments/assets/2b149fe1-02a9-40bd-8236-8c0bde59b591" />

AI Study Helper is a smart study companion built using Jac, walkers, and a modern React-style UI.

It transforms any text into structured study material using a system of specialized AI agents.

Instead of one big LLM responding to all queries, our system intelligently **classifies the user’s request** and routes it to the appropriate agent:

- **Quiz Agent** — generates MCQs and checks answers  
- **Summarizer Agent** — produces clean, concise summaries  
- **Explanation Agent** — gives step-by-step or simple explanations  
- **Flashcard Agent** — creates Q/A flashcards  
- **Task Manager** — identifies user intent and dispatches tasks  

The UI provides a dedicated **Study Workspace** and a **Homepage** with smooth navigation.

## Project Structure

```
AI_Study_Helper/
├── jac.toml              # Project configuration
├── main.jac              # Main entry point (combines server + client)
├── endpoints.sv.jac      # Server-side data models and walkers
├── frontend.cl.jac       # Client-side React UI
├── assets/               # Static assets (images, fonts, etc.)
│   ├── home_page_img.jpg  
└── components/           #components  
```

## Getting Started

### Prerequisites
- Python 3.10 or higher
- Node.js 18+ and npm

### 1. Clone the Jaseci Repository

First, clone the repository:

```bash
git clone https://github.com/Hushan-10/AI_Study_Helper.git
cd AI_Study_Helper

### 2. Create Virtual Environment

# Create a virtual environment
python -m venv venv

# Activate virtual environment
# On Linux/Mac:
source venv/bin/activate

# On Windows:
venv\Scripts\activate

### 3. Install Jac-Lang and Dependencies

```bash
# Install Jac-Lang
pip install jaclang

# Install Jac-Client for client-side functionality
pip install jac-client

# Install ByLLM for LLM integration
pip install byllm


## ▶️ How to Run

1. **Install dependencies**

```bash
pip install jac-client
pip install byllm
```
### 4. Export API Keys

```bash
export GEMINI_API_KEY = "your api key here"
export TAVILY_API_KEY = "your api key here"
```

### 5. Run the application

```bash
jac start
```

### 6.Open your browser

```bash
http://localhost:8000/page/app
```

## 🧠 System Architecture

![WhatsApp Image 2025-12-03 at 21 39 56_dfd1da09](https://github.com/user-attachments/assets/1e44ffb3-ce31-49b7-af5d-9d28320f51a2)

## ✨ Key Features

### 🔹 1. System
Your request is automatically categorized and routed to specialized AI agents.

### 🔹 2. Dedicated Study Workspace
Four separate panels:

- Quiz
- Summarize
- Explain
- Flashcards  

Everything clean, instant, and focused.

### 🔹 3. Interactive Quizzes
- Generate MCQs
- Enter your answer
- System checks it via `quiz_answer_walker`
- Immediate feedback

## 🧭 High-Level Architecture Overview
![WhatsApp Image 2025-12-03 at 21 40 10_f2f906b4](https://github.com/user-attachments/assets/5d556e79-2faa-4ad2-9fb6-29497b571985)


