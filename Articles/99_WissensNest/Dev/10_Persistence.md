# My AI

## Persistence - Reading to UI

### What we need to build

1. A ConversationSidebar component — renders inside NavMenu.razor or MainLayout.razor, shows projects and their conversations
2. An event/state mechanism to tell Chat.razor which conversation is active (a shared AppState service or a cascading parameter)
3. Chat.razor changes: react to conversation selection, load history, reset state on new conversation
4. A "New conversation" button per project
5. The API already has all the endpoints we need (GET /conversations/{projectId}, GET /conversations/{id}/messages)

**Approach** — _AppState_ cascading service:

- Register a singleton _ChatState_ (scoped to the Blazor circuit) that holds _ActiveConversationId_ and fires _OnChange_
- Both sidebar and chat page subscribe — clean, no tight coupling, fits your architecture

### ...the feature is complete

The flow will be:

```text
App starts          → sidebar loads, calls GetConversationsAsync, lists them
User clicks conv    → ChatState.SelectConversation → Chat loads history + _history
User clicks "＋"    → ChatState.StartNewConversation → Chat resets to blank
User sends first msg → conversation created → ChatState.ConversationCreated → sidebar refreshes + highlights new entry
```

### Debug

**I started the project and get the first error:**  
SQLite does not support expressions of type 'DateTimeOffset' in ORDER BY clauses.  
Convert the values to a supported type, or use LINQ to Objects to order the results on the client side.'

**The reason:** Classic SQLite/EF Core limitation — DateTimeOffset isn't natively supported in SQLite ORDER BY. Let me see the repository code to give you the exact fix.

GetByProjectAsync — sort after fetch:

```csharp
public async Task<IReadOnlyList<Conversation>> GetByProjectAsync(
    Guid projectId, CancellationToken ct = default)
{
    var entities = await DbSet
        .Where(c => c.ProjectId == projectId && !c.IsDeleted)
        .ToListAsync(ct);

    return entities
        .OrderByDescending(c => c.UpdatedAt)
        .Select(ToDomain)
        .ToList();
}
```

**Why this works:** SQLite stores DateTimeOffset as text (ISO 8601). EF Core can filter on it fine, but can't translate ORDER BY on it to SQL. Sorting on the already-materialized C# objects costs nothing at the scale of conversations/messages in a personal assistant — and keeps the clean boundary you already have between EF and domain layers.

If you later see the same error from MessageRepository or ProjectRepository, the same pattern applies: remove OrderBy/OrderByDescending from the EF query, add it after ToListAsync.
