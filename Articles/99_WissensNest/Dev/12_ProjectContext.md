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
learning how to create AI assistants.

**Name:** WissensNest — "Wissen" (knowledge) + "Nest" (nest); a cozy home knowledge base enriched by AI.
**Hardware:** MacBook Pro M3, 36 GB RAM
**Models in use:** phi4 (daily, fast, ~9 GB), qwen2.5:32b (available, slow on this HW)
**Runtime:** Ollama manages model loading. Models stored on local SSD.
**GitHub:** [K-S-K/MyAI](https://github.com/K-S-K/MyAI) *(repo will be renamed to WissensNest)*

---

## Solution Structure

```text
Src/
  Foundation/
    WissensNest.Contracts          — interfaces, DTOs, domain entities, BaseEntity, IRepository; zero dependencies
    WissensNest.Core               — business logic: ChatService, ConversationService, MarkdownResponseFormatter
    WissensNest.Client             — typed HTTP client wrapping API, MarkdownResponseFormatter
    WissensNest.Ollama             — OllamaSharp wrapper implementing ILanguageModelClient
    WissensNest.Persistent.SQLite  — EF Core + SQLite, DBEntity classes, repositories, migrations, BaseRepository
  Services/
    WissensNest.API                — Minimal API, composition root, DI wiring
    WissensNest.UI                 — Blazor Server, chat UI
  Tools/
    WissensNest.Tools.WebSearch    — IWebSearchTool stub (throws NotImplementedException)
  Tests/
    WissensNest.UnitTests          — MarkdownResponseFormatterTests
    WissensNest.IntegrationTests   — placeholder
```

**Solution file:** `Src/WissensNest.slnx`
**Target framework:** net10.0 throughout
**Key NuGet packages:** OllamaSharp, Microsoft.EntityFrameworkCore.Sqlite, Markdig

---

## Dependency Rules (enforced by project references)

```text
WissensNest.Contracts              → (nothing)
WissensNest.Core                   → WissensNest.Contracts, WissensNest.Client
WissensNest.Client                 → WissensNest.Contracts
WissensNest.Ollama                 → WissensNest.Contracts
WissensNest.Tools.WebSearch        → WissensNest.Contracts
WissensNest.Persistent.SQLite      → WissensNest.Contracts
WissensNest.API                    → WissensNest.Core, WissensNest.Ollama, WissensNest.Persistent.SQLite,
                                     WissensNest.Tools.WebSearch, WissensNest.Client
WissensNest.UI                     → WissensNest.Client, WissensNest.Core
WissensNest.UnitTests              → WissensNest.Core
```

---

## Architecture Decisions

### Domain vs EF separation

EF entity classes (DBEntity) live exclusively in `WissensNest.Persistent.SQLite/Entities`.
Domain classes live in `WissensNest.Contracts/Entities`. Repositories map between them.
No EF types ever escape the SQLite assembly. Domain classes are plain C#.

**DBEntity classes:** BaseDBEntity, ProjectDBEntity, ConversationDBEntity, MessageDBEntity, PromptCollectionDBEntity

**Domain classes:** BaseEntity, Project, Conversation, Message, PromptCollection

### Soft-delete and IsIgnored

No global EF query filters in repositories — soft-delete filtering is explicit:
`.Where(e => !e.IsDeleted)`

`IsIgnored` on Messages and Conversations is never filtered at query level — the caller
excludes ignored items from model context. Ignored items always appear in UI (greyed out)
so the user can restore them.

**Exception:** `WissensNestDbContext` does use global query filters (`HasQueryFilter`) — trust those.

### EF tracking fix in BaseRepository.UpdateAsync

`DbSet.Update()` on a freshly-mapped entity throws if EF is already tracking the same key.
Fix: check `ChangeTracker` first and call `SetValues` on the tracked entry.

### SQLite DateTimeOffset — CRITICAL

SQLite cannot translate `DateTimeOffset` comparisons in SQL (ORDER BY, WHERE, etc.).
**All filtering and sorting on DateTimeOffset columns is done in memory after `ToListAsync()`.**
Never put DateTimeOffset comparisons inside a LINQ-to-EF Where/OrderBy.

### Migration startup

`DatabaseInitializer.InitializeAsync()` (in `WissensNest.Persistent.SQLite`) is the single
entry point for both `MigrateAsync` and seeding. `WissensNest.API/Program.cs` calls only:

```csharp
await scope.ServiceProvider.GetRequiredService<DatabaseInitializer>().InitializeAsync();
```

Always generate migrations with:

```bash
dotnet ef migrations add <Name> --project Src/Foundation/WissensNest.Persistent.SQLite --startup-project Src/Services/WissensNest.API
```

### Prompt Composition (three layers)

**Layer 1 — Global config prompt:** `appsettings.json → Chat:SystemPrompt`. Always prepended.

**Layer 2 — Project-level prompt:** `Project.DefaultPromptId` (nullable FK → PromptCollections).
Set via `PATCH /projects/{id}/prompt`. UI: ⊞ button per project in sidebar.

**Layer 3 — Conversation-level prompt:** Selected at conversation creation via "Add context" dropdown.
Stored as `Conversation.PromptSnapshot` (snapshot of Layer 2 + Layer 3 joined with `\n---\n`).

`ChatService.BuildSystemPrompt(snapshot)` = Layer1 + `\n---\n` + snapshot (if both present).

### ChatState (circuit-scoped UI state)

`ChatState` is `AddScoped<ChatState>()` — one instance per Blazor circuit.
Holds `ActiveConversationId` and `ActiveProjectId`, fires `OnChange` so both
`ConversationSidebar` and `Chat.razor` react without tight coupling.

### Blazor rendermode

`ConversationSidebar` must use `@rendermode InteractiveServer` or `@onclick` is silently ignored.
CSS for child components goes in `app.css` (global), NOT in scoped `.razor.css` files.

### Environment variables

Services read URLs from env vars at startup via `UrlInfo.FromEnvironmentVariable(...)`:

- `WISSENSNEST_API_URL` (default `http://localhost:4000`)
- `WISSENSNEST_SITE_URL` (default `http://localhost:4001`)

---

## Key Interfaces (WissensNest.Contracts/Interfaces)

```csharp
ILanguageModelClient    — StreamChatAsync(history, userMessage, systemPrompt, ct)

IWissensNestClient      — StreamChatAsync, CreateConversationAsync,
                          GetConversationsAsync, GetMessagesAsync,
                          UpdateConversationTitleAsync,
                          GetProjectsAsync, CreateProjectAsync,
                          UpdateProjectNameAsync, DeleteProjectAsync,
                          DeleteConversationAsync, ToggleMessageIgnoredAsync,
                          UpdateMessageContentAsync, DeleteMessagesFromAsync

IResponseFormatter      — Format(rawResponse) → normalized string
IWebSearchTool          — SearchAsync(query, ct) → IReadOnlyList<SearchResult>

IRepository<T>          — GetByIdAsync, GetAllAsync, AddAsync, UpdateAsync,
                          SoftDeleteAsync, HardDeleteAsync, SaveChangesAsync
IProjectRepository      — + GetAllWithConversationsAsync
IConversationRepository — + GetByProjectAsync, GetWithMessagesAsync
IMessageRepository      — + GetByConversationAsync, ToggleIgnoreAsync,
                            UpdateContentAsync, MarkStaleAfterAsync, SoftDeleteFromAsync
IPromptCollectionRepository — (base IRepository<PromptCollection> only)
```

---

## Key DTOs (WissensNest.Contracts/Models)

```csharp
ProjectInfo(Guid Id, string Name, string? Description, Guid? DefaultPromptId, DateTimeOffset CreatedAt)
ConversationInfo(Guid Id, string Title, DateTimeOffset CreatedAt, DateTimeOffset UpdatedAt)
MessageInfo(Guid Id, string Role, string OriginalContent, string NormalizedContent,
            DateTimeOffset CreatedAt, bool IsIgnored, bool IsStale)
ChatRequest(Guid ConversationId, IList<ChatMessage> History,
            string UserMessage, bool UseWebSearch)
PromptCollectionInfo(Guid Id, string Name, string? Description, string Content, DateTimeOffset CreatedAt)
```

---

## ChatMessageViewModel (WissensNest.UI/Models)

```csharp
public record ChatMessageViewModel
{
    Guid?          Id             // null for in-flight messages
    string         Role           // "user" or "assistant"
    string         RawContent
    string         DisplayContent
    DateTimeOffset Timestamp
    bool           IsIgnored      // greyed out in UI, excluded from _history
    bool           IsStale        // amber border + Regenerate button

    static FromUser(content)
    static FromAssistant(rawContent, displayContent)
    static FromPersisted(id, role, rawContent, displayContent, isIgnored, isStale)
}
```

---

## Message Editing Flow

1. Hover toolbar → Edit button (user messages only, must have Id)
2. Bubble switches to resizable textarea (Ctrl+Enter save, Escape cancel)
3. On save: `PATCH /messages/{id}/content` — updates content + marks all later messages `IsStale=true`
4. UI: updates local content, marks tail stale, rebuilds `_history`

**Stale messages:** Amber left border + "outdated" badge. Stale assistant bubbles show Regenerate button.

**Regenerate:**

1. `DELETE /messages/{id}/from` — soft-deletes that message and all after
2. UI truncates `_messages` from that index, rebuilds `_history`
3. Re-streams from the last user message in history

---

## MarkdownResponseFormatter (WissensNest.Client/Processing)

1. NormalizeLineEndings
2. NormalizeTables
3. NormalizeHeadings
4. Collapse excess blank lines
5. NormalizeLists

---

## SQLite Schema

**Migrations applied:**

- `20260411170153_InitialSchema`
- `20260417120000_AddIsStaleToMessages`
- `20260417130000_AddContextModeToProjects`

**Projects:** Id, Name, Description (nullable), DefaultPromptId (nullable FK → PromptCollections),
ContextMode (INTEGER DEFAULT 0 — 0=MultiTurn, 1=SingleTurn), CreatedAt, UpdatedAt, DeletedAt, IsDeleted

**Conversations:** Id, ProjectId, Title, PromptCollectionId (nullable FK), PromptSnapshot (nullable text),
IsIgnored, CreatedAt, UpdatedAt, DeletedAt, IsDeleted

**Messages:** Id, ConversationId, Role, OriginalContent, NormalizedContent,
IsIgnored, IsStale (DEFAULT 0), CreatedAt, UpdatedAt, DeletedAt, IsDeleted

**PromptCollections:** Id, Name, Description (nullable), Content, CreatedAt, UpdatedAt, DeletedAt, IsDeleted

**Default seed:** Project Id=00000000-0000-0000-0000-000000000001, Name="Default"

---

## API Endpoints (WissensNest.API)

```text
POST   /chat/stream
POST   /conversations                        — body: { projectId, title, promptCollectionId? }
GET    /conversations/{projectId}
GET    /conversations/{id}/messages          — returns IsIgnored + IsStale per message
PATCH  /conversations/{id}/title
DELETE /conversations/{id}

GET    /projects                             — includes DefaultPromptId, ContextMode
POST   /projects
PATCH  /projects/{id}/name
PATCH  /projects/{id}/prompt                — set/clear project default prompt
PATCH  /projects/{id}/context-mode          — MultiTurn=0 / SingleTurn=1
DELETE /projects/{id}

PATCH  /messages/{id}/ignore                — toggle IsIgnored
PATCH  /messages/{id}/content               — edit content; marks later messages IsStale
DELETE /messages/{id}/from                  — soft-delete this message and all after (Regenerate)

GET    /prompt-collections
POST   /prompt-collections
PATCH  /prompt-collections/{id}
DELETE /prompt-collections/{id}
```

---

## Configuration

```json
{
  "ConnectionStrings": { "SQLite": "Data Source=/Users/ksk-work/Projects/AI/MyAI/Data/myai.db" },
  "LanguageModel": { "BaseUrl": "http://localhost:11434", "ModelName": "phi4" },
  "Chat": { "SystemPrompt": "..." }
}
```

Runtime URLs from env vars: `WISSENSNEST_API_URL` / `WISSENSNEST_SITE_URL`

---

## What Is NOT Yet Implemented

- Tool abstraction layer — ITool, ToolOrchestrator, model-driven invocation (Ollama function-calling)
- WissensNest.Tools.WebSearch — throws NotImplementedException (planned: SearXNG or DuckDuckGo)
- LocalFileAccess tool
- Persistent memory — UserMemory table, extract after conversation, inject into system prompt
- Viewing the effective prompt of an existing conversation (stored in DB, not shown in UI)
- RAG / document chunking
- Reminder service — BackgroundService + SignalR
- User profiles — multiple family members with separate memory

---

## Next Steps (priority order)

### Phase 1 — Tool abstraction (foundation)

- `ITool` interface in `WissensNest.Contracts` — Name, Description, ExecuteAsync(input, ct)
- `ToolOrchestrator` in `WissensNest.Core` — model decides which tools to call (Ollama function-calling)
- Wire into `ChatService.StreamResponseAsync`
- `ChatRequest.UseWebSearch` → `IList<string> EnabledTools` (generic)

### Phase 2 — Simple built-in tools (validate plumbing)

- `GetCurrentTime` — no external deps, smoke test
- `GetWeather` — simple HTTP call, tests async tool pattern

### Phase 3 — External access tools

- `WissensNest.Tools.WebSearch` — SearXNG or DuckDuckGo (replaces NotImplementedException)
- `LocalFileAccess` — read files from a configured allowed path

### Phase 4 — Persistent memory

- UserMemory table, extract after conversation, inject into system prompt

---

## Developer Context

~20 years MS SQL/T-SQL, ~15 years .NET. Learning .NET architecture patterns deliberately
through this project. Prefers clean boundaries, no shortcuts, proper testing. Not a frontend
person — CSS help often needed. Family uses the tool for history/biology questions in Russian.
Developer uses it for embedded dev advice and German.
