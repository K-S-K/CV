# WissensNest Project — Context Handoff Document

## Purpose

This document captures the complete state, architecture decisions, and next steps
for the WissensNest project as of April 2026. Upload this to a new conversation to continue
development without re-explaining history.

---

## Project Overview

A locally-hosted AI assistant running on a MacBook Pro M3 with 36 GB RAM.
Goals: privacy (no cloud dependency), family use (embedded dev, German learning,
history/biology, cooking), persistent context, learning proper .NET architecture,
learning hou to create AI Assistants.

**Hardware:** MacBook Pro M3, 36 GB RAM
**Models in use:** phi4 (daily, fast, ~9 GB), qwen2.5:32b (available, slow on this HW)
**Runtime:** Ollama manages model loading. Models stored on local SSD.

---

## Solution Structure

```text
Src/
  Libraries/
    WissensNest.Contracts          — interfaces, DTOs, domain entities,BaseEntity, IRepository, zero dependencies
    WissensNest.Core               — business logic, ChatService, ConversationService, MarkdownResponseFormatter
    WissensNest.Client             — typed HTTP client wrapping API
    WissensNest.Ollama             — OllamaSharp wrapper implementing ILanguageModelClient
    WissensNest.Persistent.SQLite  — EF Core + SQLite, DBEntity classes, repositories, migrations, BaseRepository
    WissensNest.Tools.WebSearch          — IWebSearchTool stub (not yet implemented)
  Services/
    WissensNest.API                — Minimal API, composition root, DI wiring
    WissensNest.UI                 — Blazor Server, chat UI
  Tests/
    WissensNest.UnitTests          — MarkdownResponseFormatterTests
    WissensNest.IntegrationTests   — placeholder
```

**Target framework:** net10.0 throughout
**Key NuGet packages:** OllamaSharp, Microsoft.EntityFrameworkCore.Sqlite, Markdig

---

## Dependency Rules (strict — enforced by project references)

```text
WissensNest.Contracts         → (nothing)
WissensNest.Core              → WissensNest.Contracts
WissensNest.Client            → WissensNest.Contracts
WissensNest.Ollama            → WissensNest.Contracts
WissensNest.Tools.WebSearch         → WissensNest.Contracts
WissensNest.Persistent.SQLite → WissensNest.Contracts
WissensNest.API               → WissensNest.Core, WissensNest.Ollama, WissensNest.Persistent.SQLite,
                         WissensNest.Tools.WebSearch, WissensNest.Client
WissensNest.UI                → WissensNest.Client, WissensNest.Contracts
WissensNest.UnitTests         → WissensNest.Core, WissensNest.Contracts, WissensNest.Client
```

---

## Architecture Decisions

### Domain vs EF separation

EF entity classes (DBEntity) live exclusively in WissensNest.Persistent.SQLite/Entities.
Domain classes live in WissensNest.Contracts/Entities. Repositories map between them.
No EF types ever escape the SQLite assembly. Domain classes are plain C#.

**DBEntity classes:**

- BaseDBEntity (Id, CreatedAt, UpdatedAt, DeletedAt, IsDeleted)
- ProjectDBEntity
- ConversationDBEntity
- MessageDBEntity
- PromptCollectionDBEntity

**Domain classes in WissensNest.Contracts/Entities:**

- BaseEntity (same audit fields, no EF dependency)
- Project
- Conversation (has List<Message> Messages — plain list, not EF navigation)
- Message (has OriginalContent + NormalizedContent — raw and formatter-processed)
- PromptCollection (Content uses --- section separator for future composability)

### No global EF query filters

Soft-delete filtering is explicit in every repository query:
`.Where(e => !e.IsDeleted)` — visible, intentional, not magic.

### DatabaseInitializer owns migrations and seeding

WissensNest.Persistent.SQLite/DatabaseInitializer.cs runs MigrateAsync and seeds
default data. WissensNest.API calls only:
`await scope.ServiceProvider.GetRequiredService<DatabaseInitializer>().InitializeAsync()`

### Composition root

WissensNest.API/Program.cs is the only place where all implementations are wired.
Core never knows which model runner, database, or search provider is used.

---

## Key Interfaces (WissensNest.Contracts/Interfaces)

```csharp
ILanguageModelClient    — StreamChatAsync(history, userMessage, systemPrompt, ct)
IWissensNestClient             — StreamChatAsync, CreateConversationAsync,
                          GetConversationsAsync, GetMessagesAsync,
                          UpdateConversationTitleAsync
IResponseFormatter      — Format(rawResponse) → normalized string
IWebSearchTool          — SearchAsync(query, ct) → IReadOnlyList<SearchResult>
IRepository<T>          — GetByIdAsync, GetAllAsync, AddAsync, UpdateAsync,
                          SoftDeleteAsync, HardDeleteAsync, SaveChangesAsync
IProjectRepository      — + GetAllWithConversationsAsync
IConversationRepository — + GetByProjectAsync, GetWithMessagesAsync
IMessageRepository      — + GetByConversationAsync, ToggleIgnoreAsync
IPromptCollectionRepository — (base only for now)
```

---

## ChatRequest Flow

```text
UI (Chat.razor)
  → creates conversation on first message via IWissensNestClient.CreateConversationAsync
  → sends ChatRequest(ConversationId, History, UserMessage, UseWebSearch)
  → streams tokens, appends to buffer
  → on complete: Formatter.Format(buffer) → DisplayContent
  → stores ChatMessageViewModel(Role, RawContent, DisplayContent)

API (/chat/stream endpoint)
  → delegates to ChatService.StreamResponseAsync

ChatService
  → persists user message via IMessageRepository
  → optionally enriches history with web search context
  → calls ILanguageModelClient.StreamChatAsync with systemPrompt from ChatOptions
  → collects full response buffer while yielding tokens
  → persists assistant message (OriginalContent + NormalizedContent) after stream

OllamaLanguageModelClient
  → translates domain types to OllamaSharp types
  → prepends system prompt as system role message
  → streams response tokens
```

---

## ChatMessageViewModel (UI only, not persisted)

```csharp
public record ChatMessageViewModel
{
    string Role           // "user" or "assistant"
    string RawContent     // exactly what model returned
    string DisplayContent // after IResponseFormatter
    DateTimeOffset Timestamp

    static FromUser(content)
    static FromAssistant(rawContent, displayContent)
}
```

---

## MarkdownResponseFormatter (WissensNest.Client/Processing)

Normalizes model output before Markdig rendering. Steps in order:

1. NormalizeLineEndings — \r\n → \n, TrimEnd each line (removes trailing spaces → no <br>)
2. NormalizeTables — splits on || (model's row terminator), reconstructs valid MD table
3. NormalizeHeadings — inserts blank line before ### headings (with or without existing \n)
4. Collapse \n{3,} → \n\n
5. NormalizeLists — blank line before lists, collapse \n{2,} between list items

Unit tests in WissensNest.UnitTests/MarkdownResponseFormatterTests.cs cover:

- Plain text passthrough
- Table with double pipes
- Heading without blank line
- Numbered/bullet list without blank line
- Real model output table case
- Null/empty input
- Windows line endings

---

## MessageBubble Component

Each completed assistant message has a hover toolbar with:

- MD button — rendered Markdown (default)
- ~MD button — normalized text (DisplayContent, pre-render)
- RAW button — original model output (RawContent)
- Copy button — copies current view to clipboard, shows "OK" for 1.5s

Toolbar fades in on hover, hidden by default.
Copy uses JS interop: `window.copyToClipboard` in wwwroot/js/interop.js

---

## SQLite Schema

Table: Projects

- Id (Guid PK), Name, Description, DefaultPromptId (FK nullable)
- CreatedAt, UpdatedAt, DeletedAt (nullable), IsDeleted

Table: PromptCollections

- Id, Name, Description, Content (--- separated sections for future composability)
- Audit fields

Table: Conversations

- Id, ProjectId (FK), PromptCollectionId (FK nullable), Title
- PromptSnapshot (text snapshot of prompt at conversation start — for reproducibility)
- IsIgnored (exclude from context without deleting)
- Audit fields

Table: Messages

- Id, ConversationId (FK), Role (user/assistant/system/tool)
- OriginalContent, NormalizedContent
- IsIgnored (exclude from model context without deleting)
- Audit fields

Cascade: Conversation delete → Message delete (EF OnDelete.Cascade)
Soft delete: IsDeleted + DeletedAt on all tables
Hard delete: available via IRepository.HardDeleteAsync

**Migration:** 20260411170153_InitialSchema (single migration, applied)
**Default seed:** Project Id=00000000-0000-0000-0000-000000000001, Name="Default"

---

## Configuration (appsettings.json in WissensNest.API)

```json
{
  "ConnectionStrings": {
    "SQLite": "Data Source=myai.db"
  },
  "LanguageModel": {
    "BaseUrl": "http://localhost:11434",
    "ModelName": "phi4"
  },
  "Chat": {
    "SystemPrompt": "You are a helpful assistant. ..."
  }
}
```

ChatOptions.SystemPrompt injected into ChatService via IOptions<ChatOptions>.
LanguageModelOptions injected into OllamaLanguageModelClient via IOptions<LanguageModelOptions>.

---

## API Endpoints (WissensNest.API)

```text
POST   /chat/stream                          — stream chat response
POST   /conversations                        — create conversation
GET    /conversations/{projectId}            — list conversations for project
GET    /conversations/{id}/messages          — load conversation with messages
PATCH  /conversations/{id}/title             — update title
```

---

## What Is NOT Yet Implemented

- WissensNest.Tools.WebSearch — throws NotImplementedException (planned: SearXNG or DuckDuckGo)
- System prompt library UI — PromptCollection CRUD in Blazor
- Project/conversation selector UI — currently hardcoded to DefaultProjectId
- Persistent memory layer — per-user facts injected into every conversation
- Tool calling — GetCurrentTime, GetWeather, etc. (architecture discussed, not built)
- RAG / document chunking — for datasheets, source code, project docs
- Reminder service — BackgroundService + SignalR notifications
- Context curation UI — edit/delete individual messages from history
- User profiles — multiple family members with separate memory

---

## Next Steps (suggested order)

1. Project/conversation selector in sidebar UI
   — load project list on startup
   — show conversation list per project
   — new conversation button
   — load existing conversation history into Chat.razor
2. PromptCollection CRUD UI — list, create, edit, select per conversation
3. Implement WissensNest.Tools.WebSearch with SearXNG or DuckDuckGo
4. Tool calling infrastructure — ITool, ToolOrchestrator in Core
5. Persistent memory — UserMemory table, extraction after conversation, injection

---

## Context for Continuing

The developer has ~20 years MS SQL / T-SQL experience, 15 years .NET experience,
is learning embedded systems (STM32), is learning .NET architecture patterns
through this project deliberately. Prefers clean boundaries, no shortcuts, proper
testing. Not a frontend person — CSS help needed. Family members use the tool for history/
biology questions in Russian. Developer uses it for embedded dev advice and German.

The project is on GitHub: https://github.com/K-S-K/MyAI
