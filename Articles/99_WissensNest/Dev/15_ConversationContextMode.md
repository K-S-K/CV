# My AI

## Conversation Context Mode

Some conversations don't benefit from history — translation, quick lookups, one-off Q&A. Sending the full conversation history for these wastes tokens and can confuse the model. This feature adds a per-project `ConversationContextMode` that controls whether history is sent to the model.

### Concept

Two modes, stored as an enum on `Project`:

| Mode | Value | Behavior |
|---|---|---|
| `MultiTurn` | 0 | Full conversation history sent to the model (default) |
| `SingleTurn` | 1 | Only the current user message sent — no prior turns |

The setting is project-level policy. All conversations under a project inherit its mode. The mode can be changed at any time; existing conversation history is preserved in the database and will be included again if the project is switched back to `MultiTurn`.

### New files

- [ConversationContextMode.cs](../../Src/Libraries/WissensNest.Contracts/Enums/ConversationContextMode.cs) — enum in `WissensNest.Contracts/Enums/`

### Modified files

**Contracts layer**

- [Project.cs](../../Src/Libraries/WissensNest.Contracts/Entities/Project.cs) — added `ContextMode` property (default `MultiTurn`)
- [ProjectInfo.cs](../../Src/Libraries/WissensNest.Contracts/Models/ProjectInfo.cs) — added `ContextMode` field to the DTO record
- [IMyAiClient.cs](../../Src/Libraries/WissensNest.Contracts/Interfaces/IMyAiClient.cs) — added `SetProjectContextModeAsync`

**Persistence layer**

- [ProjectDBEntity.cs](../../Src/Libraries/WissensNest.Persistent.SQLite/Entities/ProjectDBEntity.cs) — added `ContextMode` column (INTEGER)
- [ProjectRepository.cs](../../Src/Libraries/WissensNest.Persistent.SQLite/Repositories/ProjectRepository.cs) — mapped `ContextMode` in `ToDomain` / `ToEntity`

**API layer**

- [Program.cs](../../Src/Services/WissensNest.API/Program.cs) — new `PATCH /projects/{id}/context-mode` endpoint; `GET /projects` now returns `ContextMode`

**Client layer**

- [MyAiClient.cs](../../Src/Libraries/WissensNest.Client/MyAiClient.cs) — implemented `SetProjectContextModeAsync`

**UI layer**

- [ChatState.cs](../../Src/Services/WissensNest.UI/Models/ChatState.cs) — added `ActiveContextMode`; `SelectConversation` and `StartNewConversation` now accept and store the mode
- [ConversationSidebar.razor](../../Src/Services/WissensNest.UI/Components/Layout/ConversationSidebar.razor) — `⇄` / `→` toggle button per project header; amber highlight when `SingleTurn`; propagates mode to `ChatState` on conversation open/create
- [Chat.razor](../../Src/Services/WissensNest.UI/Components/Pages/Chat.razor) — `RebuildHistory` returns an empty list for `SingleTurn`; `SendMessage` clears history before each new turn in `SingleTurn` mode; `HandleRegenerate` looks up the last user message directly from `_messages` (not from `_history`) when in `SingleTurn`
- [app.css](../../Src/Services/WissensNest.UI/wwwroot/app.css) — `.sidebar-icon-btn.mode-single` amber colour for the active `SingleTurn` indicator

### Migration

[20260417130000_AddContextModeToProjects.cs](../../Src/Libraries/WissensNest.Persistent.SQLite/Migrations/20260417130000_AddContextModeToProjects.cs) + [snapshot](../../Src/Libraries/WissensNest.Persistent.SQLite/Migrations/WissensNestDbContextModelSnapshot.cs) updated — `ContextMode INTEGER DEFAULT 0` on the Projects table; applied automatically on next startup. Existing projects default to `MultiTurn` (0) — no data migration needed.

### Architecture notes

- `_history` in `Chat.razor` is always empty for `SingleTurn` projects. The `UserMessage` field of `ChatRequest` carries the current turn independently, so no server-side changes were needed.
- `IsIgnored` on messages retains its original meaning (manual per-message exclusion). `ContextMode` is orthogonal: it is a project-level policy, not a message attribute.
- Stored conversation history is never destroyed when switching modes — the DB record is preserved for display and potential future use.
