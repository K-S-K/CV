# WissensNest — Data Model

## Entity Hierarchy

Two parallel trees live in the database:

```text
Project
  ├── Conversation  (chat sessions)
  │     └── Message
  └── Section       (thematic grouping)
        ├── Conversation  (a conversation can belong to a section)
        └── Article
              └── Block   (atomic Markdown chunk)
```

`PromptCollection` is a standalone entity referenced by Projects and Conversations.

---

## Domain vs EF Separation

EF entity classes (`BaseDBEntity`, `ProjectDBEntity`, etc.) live exclusively in
`WissensNest.Persistent.SQLite/Entities`. Domain classes (`BaseEntity`, `Project`, `Conversation`,
etc.) live in `WissensNest.Contracts/Entities`. Repositories map between them.

**No EF type ever escapes the SQLite assembly.** Core and Contracts never reference
`Microsoft.EntityFrameworkCore`. This keeps the business logic testable without a database.

---

## Soft-Delete, IsIgnored, and IsStale

Every entity has `IsDeleted`, `DeletedAt`, and `IsIgnored` columns. Messages additionally carry `IsStale`.

**Soft-delete** (`IsDeleted = true`) hides entities from all normal queries without destroying data.
Repositories filter explicitly: `.Where(e => !e.IsDeleted)` — there are no global query filters
in repository methods so the intent is always visible at the call site.

**IsIgnored** is separate from soft-delete. An ignored Message or Conversation is still fully
visible in the UI (greyed out) so it can be restored, but it is excluded from the history sent
to the model. This lets the user prune noisy context without deleting anything.

**IsStale** applies to Messages only and is set to `true` on every message that follows an edited
user message. A stale message is stored, visible in the UI (amber left border + "outdated" badge),
and is excluded from the history sent to the model — the model only sees up to and including the
edited message on the next request. The user can click **Regenerate** on a stale assistant bubble
to soft-delete that message and everything after it, then re-stream a fresh response.

The three flags are independent and form a clear hierarchy of intent:

| Flag | Scope | UI appearance | Sent to model |
| --- | --- | --- | --- |
| `IsDeleted` | All entities | Hidden entirely | No |
| `IsIgnored` | Messages, Conversations | Greyed out; restorable | No |
| `IsStale` | Messages only | Amber border + badge; restorable via Regenerate | No |

---

## Prompt Snapshot — Three Layers Captured at Creation

When a conversation is created, `HandleCreateConversations` in the API assembles the effective
system prompt from up to three sources and stores it as `Conversation.PromptSnapshot`:

| Layer | Source |
| --- | --- |
| Layer 2 | `Project.DefaultPromptId` → `PromptCollection.Content` |
| Layer 3 | Request `PromptCollectionId` → `PromptCollection.Content` |

The two layers are joined with `\n---\n` and written once. After that, the conversation's prompt
never changes — editing the project's default prompt does not affect existing conversations.

`ChatService.BuildSystemPrompt(snapshot)` prepends the global Layer 1
(from `appsettings.json → Chat:SystemPrompt`) at request time before sending to the model.

---

## SQLite DateTimeOffset Limitation

SQLite cannot translate `DateTimeOffset` comparisons in SQL. Attempting an `ORDER BY` or `WHERE`
on a `DateTimeOffset` column inside a LINQ-to-EF expression throws at runtime.

**Rule:** all sorting and filtering on `DateTimeOffset` columns (`CreatedAt`, `UpdatedAt`) is
performed in memory after `ToListAsync()`. Never put `DateTimeOffset` comparisons inside a
LINQ `Where` or `OrderBy` that would be translated to SQL.

---

## EF Tracking Fix in BaseRepository

`DbSet.Update()` on a freshly mapped entity throws `InvalidOperationException` if EF is
already tracking an entity with the same primary key. `BaseRepository.UpdateAsync` checks
`ChangeTracker` first and calls `entry.SetValues(entity)` on the tracked entry instead of
calling `Update`.

---

## Migration Process

Migrations are generated with the EF CLI, not written manually:

```bash
dotnet ef migrations add <Name> \
  --project Src/Foundation/WissensNest.Persistent.SQLite \
  --startup-project Src/Services/WissensNest.API
```

A migration file created without the accompanying `.Designer.cs` file is silently ignored
by EF Core at runtime — always use the CLI to ensure both files are generated.

`DatabaseInitializer.InitializeAsync()` (in `WissensNest.Persistent.SQLite`) is the single
entry point for `MigrateAsync` and seeding. `Program.cs` calls only this method — no direct
`DbContext` usage at startup.

### Applied migrations

| Migration | What it added |
| --- | --- |
| `20260411170153_InitialSchema` | Projects, Conversations, Messages, PromptCollections |
| `20260417120000_AddIsStaleToMessages` | `IsStale` on Messages |
| `20260417130000_AddContextModeToProjects` | `ContextMode` on Projects |
| `20260429084822_AddKnowledgeWorkbench` | Sections, Articles, Blocks; `SectionId` on Conversations |
| `20260503045447_AddPromptsAndProfiles` | PromptCategories, Profiles; profile FK on Conversations |
| `20260512014612_AddThinkingContentToMessages` | `ThinkingContent` (nullable TEXT) on Messages |
| `20260513113546_AddTemperatureToMessages` | `Temperature` (nullable REAL) on Messages |
| `20260513135639_AddToolActivityToMessages` | `ToolActivityJson` (nullable TEXT — JSON array of tool call+result pairs) on Messages |
