# ArgumentBot

**AI Debate Simulator** - A real-time adversarial debate system where two Large Language Models argue opposing positions on any topic, scored by an impartial AI judge.

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![NestJS](https://img.shields.io/badge/NestJS-11.x-red.svg)](https://nestjs.com/)
[![Flutter](https://img.shields.io/badge/Flutter-3.10+-blue.svg)](https://flutter.dev/)
[![Ollama](https://img.shields.io/badge/Ollama-Local%20LLMs-purple.svg)](https://ollama.ai/)

---

## Overview

ArgumentBot pits two locally-hosted LLMs against each other in structured debates. Each model is constrained by strict rules that force adversarial reasoning: explicit claims, direct rebuttals, and pointed counter-questions. An AI judge scores each turn based on claim quality, directness, and attack strength.

### Key Differentiators

- **Local-first AI**: All models run via Ollama - no API costs, full privacy
- **Adversarial by design**: Prompts enforce falsifiable claims and penalize vague abstractions
- **RAG-enhanced**: Retrieval-augmented generation provides factual context
- **Dual scoring modes**: AI judge or algorithmic heuristics

---

## System Architecture

```
                                 +-------------------+
                                 |      Ollama       |
                                 |  +-----------+    |
                                 |  | Llama 3.2 |    |  (Proponent)
                                 |  +-----------+    |
                                 |  | Gemma 2:2b|    |  (Opponent)
                                 |  +-----------+    |
                                 |  |nomic-embed|    |  (RAG Embeddings)
                                 |  +-----------+    |
                                 +--------^----------+
                                          |
+------------------+              +-------v--------+              +-------------+
|                  |   REST API   |                |   Prisma    |             |
|  Flutter Mobile  +<------------>+  NestJS API    +<----------->+   SQLite    |
|     Client       |     JSON     |    Server      |     ORM     |  Database   |
|                  |              |                |             |             |
+------------------+              +----------------+              +-------------+
```

---

## Features

### Implemented

| Category | Feature | Description |
|:---------|:--------|:------------|
| **Debates** | Multi-Model Debates | Llama 3.2 (PRO) vs Gemma 2:2b (CON) |
| | Streaming Responses | Server-Sent Events for real-time generation |
| | RAG Context | Embedding-based fact retrieval |
| | Debate History | Persistent storage with replay |
| **Scoring** | AI Judge | LLM-based analysis with detailed metrics |
| | Algorithmic Judge | Heuristic scoring for instant results |
| | Power Bar | Visual cumulative score display |
| **Auth** | JWT Authentication | Stateless token-based auth |
| | User Registration | Email/password with Argon2 hashing |
| | Profile Management | Avatar selection, nickname/age |
| **Social** | Community Feed | Posts with like functionality |
| | Debate Sharing | Share results link generation |
| **UI** | Dark Theme | Black + neon green aesthetic |
| | How It Works | Interactive explainer with LaTeX formulas |

### Roadmap

| Priority | Feature | Status |
|:---------|:--------|:-------|
| High | User vs AI Mode | Planned |
| High | Topic Browser | Planned |
| Medium | Social Sharing | Planned |
| Medium | Debate Rematch | Planned |
| Medium | Leaderboard | Planned |
| Low | Voice Input | Planned |
| Low | Multi-language | Planned |

---

## Technology Stack

### Backend

| Component | Technology | Version | Purpose |
|:----------|:-----------|:--------|:--------|
| Runtime | Node.js | 20+ | JavaScript runtime |
| Framework | NestJS | 11.x | API framework |
| ORM | Prisma | 5.x | Database access |
| Database | SQLite | 3.x | Data persistence |
| Auth | Passport + JWT | - | Authentication |
| Caching | cache-manager | 7.x | Response caching |
| NLP | natural | 8.x | Algorithmic scoring |

### Frontend

| Component | Technology | Version | Purpose |
|:----------|:-----------|:--------|:--------|
| Framework | Flutter | 3.10+ | Cross-platform UI |
| HTTP | http | 1.6.x | API communication |
| Storage | flutter_secure_storage | 10.x | Token storage |
| Math | flutter_math_fork | 0.7.x | LaTeX rendering |
| Navigation | google_nav_bar | 5.x | Bottom navigation |

### AI Infrastructure

| Component | Technology | Purpose |
|:----------|:-----------|:--------|
| LLM Runtime | Ollama | Local model hosting |
| Proponent Model | Llama 3.2 | Fast, consistent reasoning |
| Opponent Model | Gemma 2:2b | Creative, divergent arguments |
| Embedding Model | nomic-embed-text | Vector embeddings for RAG |

---

## Scoring Algorithms

### AI Judge Scoring

The AI judge evaluates each turn on three dimensions with vagueness penalties:

```
Persuasiveness = (C_claim + C_answer + C_attack) / 3 - V_penalty
```

| Metric | Range | Criteria |
|:-------|:------|:---------|
| `C_claim` | 0-100 | Falsifiable claim with evidence |
| `C_answer` | 0-100 | Direct response to opponent's question |
| `C_attack` | 0-100 | Specific flaw identification in opponent's argument |
| `V_penalty` | -30 each | Penalty for undefined abstractions |

### Algorithmic Scoring

Instant heuristic-based scoring:

```
Score = w1 * L_arg + w2 * K_rel + w3 * C_struct
```

| Factor | Weight | Description |
|:-------|:-------|:------------|
| `L_arg` | 0.3 | Argument length (optimal: 50-150 words) |
| `K_rel` | 0.4 | Keyword relevance to topic |
| `C_struct` | 0.3 | Structural compliance (headers present) |

### Power Bar Calculation

Cumulative persuasiveness ratio:

```
R_pro = SUM(P_pro) / (SUM(P_pro) + SUM(P_con)) * 100%
```

### RAG Similarity

Cosine similarity for context retrieval:

```
similarity(q, d) = (q . d) / (||q|| * ||d||)
```

---

## Database Schema

### Core Tables

#### Users

| Column | Type | Constraints | Description |
|:-------|:-----|:------------|:------------|
| `id` | UUID | PRIMARY KEY | Unique identifier |
| `email` | VARCHAR | UNIQUE, NOT NULL | Login email |
| `password` | VARCHAR | NOT NULL | Argon2 hash |
| `avatarUrl` | VARCHAR | NULLABLE | Profile image URL |
| `nickname` | VARCHAR | NULLABLE | Display name |
| `age` | INTEGER | NULLABLE | User age |
| `createdAt` | TIMESTAMP | DEFAULT NOW | Registration time |

#### Debates

| Column | Type | Constraints | Description |
|:-------|:-----|:------------|:------------|
| `id` | UUID | PRIMARY KEY | Unique identifier |
| `topic` | VARCHAR | NOT NULL | Debate topic |
| `status` | ENUM | NOT NULL | ACTIVE, FINISHED |
| `userId` | UUID | FOREIGN KEY | Owner reference |
| `createdAt` | TIMESTAMP | DEFAULT NOW | Start time |

#### DebateTurns

| Column | Type | Constraints | Description |
|:-------|:-----|:------------|:------------|
| `id` | UUID | PRIMARY KEY | Unique identifier |
| `debateId` | UUID | FOREIGN KEY | Parent debate |
| `speaker` | ENUM | NOT NULL | MODEL_A, MODEL_B |
| `content` | TEXT | NOT NULL | Turn content |
| `modelName` | VARCHAR | NOT NULL | LLM model used |
| `analysis` | JSON | NULLABLE | Scoring data |
| `timestamp` | TIMESTAMP | DEFAULT NOW | Turn time |

---

## API Reference

### Authentication Endpoints

| Method | Endpoint | Body | Response |
|:-------|:---------|:-----|:---------|
| `POST` | `/auth/register` | `{email, password}` | `{token, user}` |
| `POST` | `/auth/login` | `{email, password}` | `{token, user}` |
| `GET` | `/auth/verify` | - | `{user}` |
| `POST` | `/auth/onboarding` | `{nickname, age}` | `{user}` |
| `PUT` | `/auth/profile` | `{avatarUrl}` | `{user}` |

### Debate Endpoints

| Method | Endpoint | Body | Response |
|:-------|:---------|:-----|:---------|
| `GET` | `/debate` | - | `[Debate]` |
| `GET` | `/debate/:id` | - | `Debate` |
| `POST` | `/debate/start` | `{topic}` | `Debate` |
| `POST` | `/debate/:id/turn` | `{scoringMode}` | `Debate` |
| `GET` | `/debate/:id/turn/stream` | - | SSE Stream |

### Feed Endpoints

| Method | Endpoint | Body | Response |
|:-------|:---------|:-----|:---------|
| `GET` | `/feed` | - | `[Post]` |
| `POST` | `/feed` | `{content, debateId?}` | `Post` |
| `POST` | `/feed/:id/like` | - | `{liked}` |

---

## Installation

### Prerequisites

| Requirement | Version | Purpose |
|:------------|:--------|:--------|
| Node.js | 20+ | Backend runtime |
| npm | 10+ | Package manager |
| Flutter | 3.10+ | Frontend framework |
| Ollama | Latest | LLM runtime |

### 1. Clone Repository

```bash
git clone https://github.com/TrendySloth1001/argumentbot.git
cd argumentbot
```

### 2. Backend Setup

```bash
cd backend

# Install dependencies
npm install

# Configure environment
cp .env.example .env
# Edit .env with your settings

# Initialize database
npx prisma generate
npx prisma migrate dev

# Start development server
npm run dev
```

### 3. Frontend Setup

```bash
cd frontend

# Install dependencies
flutter pub get

# Configure API URL
# Edit lib/core/config/api_config.dart

# Run application
flutter run
```

### 4. Ollama Setup

```bash
# Install Ollama from https://ollama.ai

# Pull required models
ollama pull llama3.2
ollama pull gemma2:2b
ollama pull nomic-embed-text

# Verify installation
ollama list
```

---

## Docker Deployment

### Build Backend Image

```bash
cd backend
docker build -t argumentbot-backend:latest .
```

### Run Container

```bash
docker run -d \
  --name argumentbot-api \
  -p 3000:3000 \
  -e DATABASE_URL="file:./dev.db" \
  -e JWT_SECRET="your-secret-key" \
  -e OLLAMA_API_URL="http://host.docker.internal:11434" \
  argumentbot-backend:latest
```

### Docker Compose

```bash
cd backend
docker-compose up -d
```

---

## Environment Variables

### Backend Configuration

| Variable | Required | Default | Description |
|:---------|:---------|:--------|:------------|
| `DATABASE_URL` | Yes | - | SQLite connection string |
| `JWT_SECRET` | Yes | - | JWT signing secret |
| `OLLAMA_API_URL` | No | `http://localhost:11434` | Ollama API endpoint |

---

## Project Structure

```
argumentbot/
+-- backend/
|   +-- src/
|   |   +-- auth/           # Authentication module
|   |   +-- debate/         # Debate logic and scoring
|   |   +-- feed/           # Social feed module
|   |   +-- llm/            # Ollama integration
|   |   +-- prisma/         # Database service
|   |   +-- rag/            # Retrieval-augmented generation
|   +-- prisma/
|   |   +-- schema.prisma   # Database schema
|   +-- Dockerfile
|   +-- docker-compose.yml
+-- frontend/
|   +-- lib/
|   |   +-- core/           # Config, theme, utilities
|   |   +-- features/       # Feature modules
|   |       +-- auth/       # Login, registration
|   |       +-- debate/     # Debate screens
|   |       +-- feed/       # Social feed
|   |       +-- home/       # Home screen
|   |       +-- profile/    # User profile
|   |       +-- settings/   # App settings
+-- README.md
```

---

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/new-feature`
3. Commit changes: `git commit -m 'Add new feature'`
4. Push to branch: `git push origin feature/new-feature`
5. Submit a Pull Request

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
