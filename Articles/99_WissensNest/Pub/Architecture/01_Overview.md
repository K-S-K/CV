# WissensNest — System Overview

## Goals

WissensNest is a privately-hosted AI assistant designed for a single household running on a
MacBook Pro M3 (36 GB RAM). Three principles drive every architectural choice:

- **Privacy** — no data leaves the local network; models run locally via Ollama.
- **Family use** — multiple people with different languages (Russian, German, English) and topics (embedded dev, history, biology, cooking, language learning).
- **Learning** — deliberately applying clean .NET architecture patterns: dependency inversion, separated concerns, proper testing boundaries.

---

## Assembly Map

![System architecture diagram](../../Images/01_01_WissensNest_System_Architecture.svg)

```text
Src/
  Foundation/
    Contracts     — interfaces, DTOs, domain entities; zero dependencies
    Core          — business logic: ChatService, ConversationService, ToolOrchestrator
    Client        — typed HTTP client wrapping the API
    Ollama        — OllamaSharp adapter implementing ILanguageModelClient
    Persistent.SQLite — EF Core + SQLite; repositories; migrations
  Services/
    API           — Minimal API; composition root; DI wiring
    UI            — Blazor Server; chat and article editor
  Tools/
    WebSearch     — DuckDuckGo HTML scraping
    GetCurrentTime
    Weather       — open-meteo.com
    Geocoding     — open-meteo geocoding API
    FetchPage     — HTML + PDF fetching with byte cache
    Library       — local document library (search / read / describe)
  Tests/
    UnitTests
    IntegrationTests
```

### Dependency rules

The key principle: **Core never knows what model it is talking to, what database stores the data, or how the UI is built.**

```text
Contracts          → (nothing)
Core               → Contracts, Client
Client             → Contracts
Ollama             → Contracts
Tools.*            → Contracts
Persistent.SQLite  → Contracts
API                → Core, Ollama, Persistent.SQLite, Tools.*, Client
UI                 → Client, Core
```

All concrete infrastructure (Ollama, SQLite, tool HTTP calls) lives below the dependency line.
Core and Contracts are infrastructure-agnostic and testable in isolation.

---

## Runtime

| Component | Technology | Notes |
| --- | --- | --- |
| Language models | Ollama (local) | Default: `qwen2.5:14b`; fast alternative: `phi4` |
| Database | SQLite via EF Core | Stored at `/Users/ksk-work/Projects/AI/WissensNest/Data/myai.db` |
| UI | Blazor Server | Interactive Server render mode throughout |
| API | ASP.NET Core Minimal API | HTTP + Server-Sent Events for streaming |

---

## Request Flow

![Chat sequence diagram](../../Images/01_02_WissensNest_Sequence_Diagram.svg)

A single chat message follows this path:

1. **UI** — user types a message; `Chat.razor` builds a `ChatRequest` and calls `IWissensNestClient.StreamChatAsync`.
2. **Client** — `MyAiClient` posts to `POST /chat/stream` and reads the NDJSON response line by line.
3. **API** — `HandleChatStream` loads the conversation's `PromptSnapshot` from the database, resolves the enabled tools, and calls `ChatService.StreamResponseAsync`.
4. **Core** — `ChatService` builds the system prompt and delegates to `ToolOrchestrator.OrchestrateAsync`.
5. **ToolOrchestrator** — calls `ILanguageModelClient.StreamChatAsync`; if the model requests tool calls, executes them and loops; yields `StreamChunk` events upstream.
6. **Ollama** — `OllamaLanguageModelClient` translates chunks to OllamaSharp calls and maps responses back to `StreamChunk`.
7. **StreamingService** (UI, circuit-scoped) — receives chunks, updates `ConversationStreamState`, and notifies `Chat.razor` via subscriber callback.

---

## Key Interfaces

| Interface | Assembly | Role |
| --- | --- | --- |
| `ILanguageModelClient` | Contracts | Abstracts Ollama (or any future model backend) |
| `ITool` | Contracts | Implemented by each tool assembly |
| `IWissensNestClient` | Contracts | HTTP client abstraction used by the UI |
| `IRepository<T>` | Contracts | Generic repository; specialized per entity type |
| `IResponseFormatter` | Contracts | Normalizes raw model output before Markdig rendering |
