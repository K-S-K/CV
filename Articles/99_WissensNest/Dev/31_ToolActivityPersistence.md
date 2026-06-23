# WissensNest — Tool Communication Persistence

## Overview

When the model uses tools during a response, the live tool-activity panel appears in the chat UI.
Before this feature, that panel disappeared on page reload — the tool calls were executed and the
final answer was stored, but the intermediate tool communication was discarded.

This article documents how tool calls and results are now captured at the `ChatService` level,
serialised as JSON into the `Messages` table, and restored on every subsequent load of the
conversation — so the tool activity panel looks identical whether the response is streaming live
or was generated yesterday.

The implementation mirrors the pattern established for `ThinkingContent` persistence (see
[29_ThoughtStream.md](./29_ThoughtStream.md)).

---

## Architecture: 6-Layer Pipeline

```text
ChatService (accumulation)
  → Messages table (ToolActivityJson — JSON TEXT)
    → MessageRepository / ConversationRepository (serialize / deserialize)
      → MessageInfo DTO (IReadOnlyList<ToolActivityItem>?)
        → MyAiClient (HTTP deserialize)
          → Chat.razor (ChatMessageViewModel.FromPersisted → existing rendering block)
```

---

## Layer 1 — `ToolActivityItem` Relocation

`ToolActivityItem` was defined in `WissensNest.UI.Models`. `ChatService` lives in
`WissensNest.Core`, which does not reference the UI assembly. Moving the type to
`WissensNest.Contracts.Models` makes it accessible to all layers without introducing a
circular dependency.

```csharp
// WissensNest.Contracts/Models/ToolActivityItem.cs
namespace WissensNest.Contracts.Models;

public class ToolActivityItem
{
    public string  ToolName   { get; set; } = string.Empty;
    public string  InputJson  { get; set; } = "{}";
    public string? OutputText { get; set; }
    public long?   DurationMs { get; set; }
    public bool?   Success    { get; set; }

    public bool   IsPending        => OutputText is null;
    public int    InputSizeBytes   => Encoding.UTF8.GetByteCount(InputJson);
    public int?   OutputSizeBytes  => OutputText is null ? null : Encoding.UTF8.GetByteCount(OutputText);
}
```

`ConversationStreamState.cs` and `StreamingService.cs` update their `using` directive from
`WissensNest.UI.Models` to `WissensNest.Contracts.Models`. `ChatMessageViewModel.cs` adds the
same `using`.

---

## Layer 2 — DB Column and Migration

```sql
-- migration 20260513135639_AddToolActivityToMessages
ALTER TABLE Messages ADD COLUMN ToolActivityJson TEXT;   -- nullable
```

`MessageDBEntity` gains:

```csharp
public string? ToolActivityJson { get; set; }
```

---

## Layer 3 — ChatService Accumulation

Three parallel accumulators run inside the `llmTask` lambda:

```csharp
var responseBuffer   = new StringBuilder();
var thinkingBuffer   = new StringBuilder();
var toolActivityMap  = new Dictionary<string, ToolActivityItem>(); // keyed by CallId

// Inside the await foreach over OrchestrateAsync:
if (chunk is TextTokenChunk { Token: var token })
    responseBuffer.Append(token);
else if (chunk is ThinkingChunk { ThinkingContent: var thinking })
    thinkingBuffer.Append(thinking);
else if (chunk is ToolCallRequestChunk { CallId: var callId, ToolName: var tName, InputJson: var tInput })
    toolActivityMap[callId] = new ToolActivityItem { ToolName = tName, InputJson = tInput };
else if (chunk is ToolResultChunk { CallId: var rCallId, OutputText: var rOutput, Duration: var rDur, Success: var rOk }
         && toolActivityMap.TryGetValue(rCallId, out var activity))
{
    activity.OutputText = rOutput;
    activity.DurationMs = (long)rDur.TotalMilliseconds;
    activity.Success    = rOk;
}
```

After the stream ends, the map is materialised into a list (preserving insertion order) and
passed to `PersistMessageAsync`:

```csharp
var toolActivity = toolActivityMap.Count > 0
    ? (IReadOnlyList<ToolActivityItem>)toolActivityMap.Values.ToList()
    : null;

await PersistMessageAsync(..., toolActivity, ct);
```

`CallId` is used only during accumulation to correlate requests with results. It is not stored.

---

## Layer 4 — Domain Entity, DTO, and Repositories

### `Message` entity (`WissensNest.Contracts/Entities/Message.cs`)

```csharp
public IReadOnlyList<ToolActivityItem>? ToolActivity { get; set; }
```

### `MessageInfo` DTO (`WissensNest.Contracts/Models/MessageInfo.cs`)

```csharp
IReadOnlyList<ToolActivityItem>? ToolActivity = null
```

### `MessageRepository` — both directions

```csharp
// ToDomain
ToolActivity = e.ToolActivityJson is null
    ? null
    : JsonSerializer.Deserialize<List<ToolActivityItem>>(e.ToolActivityJson),

// ToEntity
ToolActivityJson = d.ToolActivity is null
    ? null
    : JsonSerializer.Serialize(d.ToolActivity),
```

### `ConversationRepository.ToDomainWithMessages`

The same deserialization line is applied in the inline mapping, keeping it in sync with
`MessageRepository`. **Critical:** this method has its own separate mapping that does not
delegate to `MessageRepository` — any new `Message` field must be added in both places.

---

## Layer 5 — API and Client

`GET /conversations/{id}/messages` adds `m.ToolActivity` to its anonymous object projection:

```csharp
var messages = conversation.Messages.Select(m => new
{
    m.Id, m.Role, m.OriginalContent, m.NormalizedContent,
    m.CreatedAt, m.IsIgnored, m.IsStale,
    DurationMs = (long)m.Duration.TotalMilliseconds,
    m.ModelName,
    m.ThinkingContent,
    m.Temperature,
    m.ToolActivity          // ← new
});
```

`MyAiClient.GetMessagesAsync` uses `GetFromJsonAsync<List<MessageInfo>>`. Because
`MessageInfo.ToolActivity` matches the JSON property name and `ToolActivityItem` is a
plain POCO, `System.Text.Json` deserializes the array automatically — no manual change needed.

---

## Layer 6 — UI

`ChatMessageViewModel.FromPersisted` gains one optional parameter:

```csharp
public static ChatMessageViewModel FromPersisted(
    ...,
    IReadOnlyList<ToolActivityItem>? toolActivity = null) =>
    new(...) { ..., ToolActivity = toolActivity };
```

`Chat.razor` passes it at the assistant call site:

```csharp
_messages.Add(ChatMessageViewModel.FromPersisted(
    m.Id, "assistant", m.OriginalContent, m.NormalizedContent, m.IsIgnored, m.IsStale,
    duration:        TimeSpan.FromMilliseconds(m.DurationMs),
    modelName:       m.ModelName,
    thinkingContent: m.ThinkingContent,
    temperature:     m.Temperature,
    toolActivity:    m.ToolActivity));   // ← new
```

No new rendering code is required. The existing block:

```razor
@if (ToolbarState.ShowToolActivity && message.Role == "assistant" && message.ToolActivity is { Count: > 0 })
{
    ...
}
```

already handles both live (in-flight) and persisted (historical) messages identically.

---

## What Is NOT Persisted

- `CallId` — a correlation key used only during the accumulation window; discarded after the stream ends.
- Pending (incomplete) tool calls — `IsPending` items are never written; all entries in `toolActivityMap` have their results filled before `PersistMessageAsync` is called (the orchestrator always completes a tool call before yielding `CompletionChunk`).

---

## Modified Files

| File | Change |
| --- | --- |
| [ToolActivityItem.cs](../../Src/Foundation/WissensNest.Contracts/Models/ToolActivityItem.cs) | Moved from UI.Models; namespace updated |
| [ConversationStreamState.cs](../../Src/Services/WissensNest.UI/Services/ConversationStreamState.cs) | `using` updated to Contracts.Models |
| [StreamingService.cs](../../Src/Services/WissensNest.UI/Services/StreamingService.cs) | `using` updated to Contracts.Models |
| [ChatMessageViewModel.cs](../../Src/Services/WissensNest.UI/Models/ChatMessageViewModel.cs) | Added `using`; `FromPersisted` gains `toolActivity` param |
| [MessageDBEntity.cs](../../Src/Foundation/WissensNest.Persistent.SQLite/Entities/MessageDBEntity.cs) | `ToolActivityJson` property |
| [20260513135639_AddToolActivityToMessages.cs](../../Src/Foundation/WissensNest.Persistent.SQLite/Migrations/20260513135639_AddToolActivityToMessages.cs) | Migration |
| [Message.cs](../../Src/Foundation/WissensNest.Contracts/Entities/Message.cs) | `ToolActivity` property |
| [MessageInfo.cs](../../Src/Foundation/WissensNest.Contracts/Models/MessageInfo.cs) | `ToolActivity` parameter |
| [MessageRepository.cs](../../Src/Foundation/WissensNest.Persistent.SQLite/Repositories/MessageRepository.cs) | JSON serialize/deserialize in both directions |
| [ConversationRepository.cs](../../Src/Foundation/WissensNest.Persistent.SQLite/Repositories/ConversationRepository.cs) | JSON deserialize in `ToDomainWithMessages` |
| [ChatService.cs](../../Src/Foundation/WissensNest.Core/Services/ChatService.cs) | `toolActivityMap` accumulation; `PersistMessageAsync` gains `toolActivity` param |
| [Program.cs](../../Src/Services/WissensNest.API/Program.cs) | `m.ToolActivity` added to messages projection |
| [Chat.razor](../../Src/Services/WissensNest.UI/Components/Pages/Chat.razor) | Passes `toolActivity: m.ToolActivity` to `FromPersisted` |
