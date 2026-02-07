# MrArgue - AI Debate Simulator

**MrArgue** is an advanced AI-powered debate simulator where users can engage in real-time voice debates with AI personas. The system features a Flutter frontend, a NestJS backend, and a custom Python microservice for high-quality, low-latency text-to-speech (TTS) synthesis using Piper.

## 🏗️ Architecture

The system follows a microservices-inspired architecture:

```mermaid
graph TD
    Client[Flutter Mobile App]
    
    subgraph "Backend Services (Dockerized)"
        API[NestJS Backend API]
        DB[(PostgreSQL)]
        MinIO[(MinIO Object Storage)]
        TTS[TTS Microservice (Python/FastAPI)]
    end

    Client -- HTTP/WebSockets --> API
    API -- ORM --> DB
    API -- S3 Protocol --> MinIO
    API -- HTTP --> TTS
    
    TTS -- Generates Audio --> PIPER[Piper TTS Engine]
    TTS -- Returns Stream --> API
    API -- Streams Audio --> Client
```

## 🚀 Key Features

- **Real-time Voice Debate**: Low-latency voice interaction with AI opponents.
- **Dynamic Personas**: Choose between Proponent (For) and Opponent (Against) voices.
- **Karaoke Mode**: Real-time text highlighting synchronized with audio playback.
- **AI Judge**: Automated scoring and analysis of debate performance.
- **Persistent Auth**: "Remember Me" functionality to keep users logged in.
- **Offline Support**: Caching of debate history and audio files.

## 🛠️ Tech Stack

### Frontend (Mobile)
- **Framework**: Flutter (Dart)
- **State Management**: `setState` & Services pattern
- **Audio**: `just_audio` with stream caching
- **Storage**: `flutter_secure_storage`, `shared_preferences`

### Backend (API)
- **Framework**: NestJS (TypeScript)
- **Database**: PostgreSQL (via Prisma ORM)
- **Storage**: MinIO (S3-compatible object storage)
- **Authentication**: JWT (Passport.js)

### TTS Service
- **Framework**: FastAPI (Python)
- **Engine**: Piper TTS (Neural network-based synthesis)
- **Deployment**: Dockerized with pre-downloaded voice models

## 📂 Directory Structure

```graphql
argumentbot/
├── backend/                # NestJS Backend API
│   ├── src/
│   │   ├── auth/           # Authentication (JWT, Guards)
│   │   ├── debate/         # Debate logic & scoring
│   │   ├── tts/            # TTS Proxy & caching logic
│   │   └── ...
│   └── prisma/             # Database schema
│
├── frontend/               # Flutter Mobile Application
│   ├── lib/
│   │   ├── core/           # Shared services, config, theme
│   │   ├── features/       # Feature-based modules (Auth, Debate, Settings)
│   │   └── main.dart       # Entry point
│   └── pubspec.yaml        # Dependencies
│
├── tts-service/            # Python Microservice
│   ├── main.py             # FastAPI application
│   └── Dockerfile          # Builds Piper & downloads models
│
└── docker-compose.yml      # Orchestration for DB, Redis, MinIO, TTS
```

## ⚡ Setup & Installation

### Prerequisites
- Docker & Docker Compose
- Node.js (v18+)
- Flutter SDK (v3.10+)

### 1. Start Backend Services
```bash
# Start PostgreSQL, MinIO, and TTS Service
docker-compose up -d --build
```
*Note: The TTS service may take a moment to initialize as it loads voice models.*

### 2. Run Backend API
```bash
cd backend
npm install
npx prisma generate
npx prisma db push  # Update database schema
npm run start:dev
```

### 3. Run Mobile App
```bash
cd frontend
flutter pub get
flutter run
```

## ⚠️ Known Issues

- **Karaoke Sync**: The text highlighting in Karaoke mode involves estimating word duration based on character count. This may occasionally drift slightly from the actual audio playback, especially with faster voice models.
- **Emulator Audio**: Audio playback latency can be higher on Android Emulators/iOS Simulators compared to physical devices.
- **First-Time Load**: The first synthesis request for a specific phrase may have slight latency as the backend initializes the stream; subsequent requests are cached.

## 🗺️ Roadmap

- [ ] WebSocket-based real-time debate streaming.
- [ ] Multi-user debate rooms.
- [ ] Improved phoneme-based karaoke synchronization.
- [ ] Custom voice cloning support.
