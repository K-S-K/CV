# WissensNest — Streaming

## The Problem

The original implementation ran the `await foreach` streaming loop directly inside `Chat.razor`.
When the user switched conversations mid-stream, the component cleared `_messages` and
`_history` — but the loop kept running and kept appending tokens into wiped state, causing
`InvalidOperationException`. There was also no way for a stream to continue silently while the
user browsed a different conversation.

---

## Solution: Circuit-Scoped `StreamingService`

The streaming loop moved out of `Chat.razor` into a dedicated circuit-scoped service:
`WissensNest.UI/Services/StreamingService`.

**Key principle:** the stream's lifetime is independent of any component's lifecycle.
Components subscribe to receive snapshots; the stream runs whether or not anything is subscribed.

---

## `StreamingService` API

```csharp
// Start a new stream; subscriber receives a snapshot on every chunk
void StartStream(Guid conversationId, ChatRequest request, Action<StreamSnapshot> subscriber)

// Swap the active subscriber when the user switches conversations
void Subscribe(Guid conversationId, Action<StreamSnapshot> onUpdate)
void Unsubscribe(Guid conversationId)

// Read the latest state when re-attaching (e.g. user navigates back)
StreamSnapshot? GetSnapshot(Guid conversationId)

// Called by Chat.razor after finalising the completed message; cleans up state
void AcknowledgeCompletion(Guid conversationId)
```

`StreamingService` implements `IDisposable`. `Dispose()` cancels all in-flight
`CancellationTokenSource` instances when the Blazor circuit disconnects.

---

## `StreamSnapshot`

```csharp
public record struct StreamSnapshot(
    string                          AccumulatedText,
    string                          ThinkingText,      // reasoning; empty when thinking not active
    IReadOnlyList<ToolActivityItem> LiveToolActivity,
    bool                            IsStreaming,
    bool                            IsComplete,
    long                            ElapsedMs);
```

An immutable value snapshot taken under lock before each subscriber call.
`Chat.razor` never reads from shared mutable state — it always works with a consistent
point-in-time copy.

---

## Chunk Types

| Type | Emitted by | Carried in snapshot |
| --- | --- | --- |
| `TextTokenChunk` | Model (streamed) | `AccumulatedText` |
| `ThinkingChunk` | Model (when `EnableThinking = true`) | `ThinkingText` |
| `ToolCallRequestChunk` | Model (non-streamed, tool mode) | `LiveToolActivity` |
| `ToolResultChunk` | `ToolOrchestrator` after executing the tool | `LiveToolActivity` |
| `DurationTickChunk` | `ChatService` timer every 200 ms | `ElapsedMs` |
| `CompletionChunk` | End of stream | triggers `IsComplete` |
| `ErrorChunk` | Any layer on failure | triggers `IsComplete` |

## Thread Safety

`ConversationStreamState` holds a `private readonly object _lock`. All mutations
(`AppendText`, `AppendThinking`, `AddToolCall`, `UpdateToolResult`, `Complete`) acquire the
lock and replace immutable values — strings and `IReadOnlyList<T>` references are swapped
atomically.
`TakeSnapshot()` acquires the lock and copies values in one step.

The subscriber field (`Action<StreamSnapshot>?`) is a reference. Reference reads/writes are
atomic on 64-bit .NET, so the worst case of a subscribe/unsubscribe race is a single missed
notification, which is harmless.

---

## `Chat.razor` Lifecycle

| Moment | Action |
| --- | --- |
| User sends a message | `StreamingService.StartStream(id, request, OnStreamUpdate)` |
| User switches away mid-stream | `StreamingService.Unsubscribe(id)` — stream keeps running silently |
| User returns to the streaming conversation | `StreamingService.Subscribe(id, OnStreamUpdate)` and read `GetSnapshot` |
| Stream completes | `OnStreamUpdate` detects `IsComplete`, calls `FinalizeStreamedMessage`, then `AcknowledgeCompletion` |
| Circuit disconnects | DI calls `StreamingService.Dispose()`, cancelling all in-flight streams |

`OnStreamUpdate` always marshals to the Blazor circuit synchronisation context via
`InvokeAsync` before calling `StateHasChanged`. A `_streamFinalized` bool guards
against double-finalisation.

---

## Registration

```csharp
// WissensNest.UI/Program.cs
builder.Services.AddScoped<StreamingService>();
```

`AddScoped` on a Blazor Server app gives one instance per circuit — the same lifetime as
`ChatState` and `ToolbarState`.
