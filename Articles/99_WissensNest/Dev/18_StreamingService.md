# WissensNest

## StreamingService — Background Streaming and Conversation Switch Safety

### Problem

The original streaming implementation ran the `await foreach` loop directly inside `Chat.razor`. When the user switched to a different conversation mid-stream, `OnChatStateChanged` called `LoadConversationAsync`, which cleared `_messages` and `_history`. The `await foreach` loop kept running and kept appending tokens — writing into state that had just been wiped. This caused `InvalidOperationException` and other exceptions.

The deeper issue: accumulation logic lived in the UI component, so any second UI (MAUI, CLI) would need to re-implement it. There was no way to have a response keep arriving while the user browsed a different conversation.

---

### Solution — Circuit-Scoped StreamingService

The streaming loop moved from `Chat.razor` into a dedicated circuit-scoped service: `WissensNest.UI/Services/StreamingService`.

**Key principle:** the stream's lifetime is independent of any component's lifecycle. Components subscribe to receive snapshots; the stream runs whether or not anything is subscribed.

---

### New Files

| File | Role |
| --- | --- |
| [StreamingService.cs](../../Src/Services/WissensNest.UI/Services/StreamingService.cs) | Circuit-scoped owner of in-flight streams |
| [ConversationStreamState.cs](../../Src/Services/WissensNest.UI/Services/ConversationStreamState.cs) | Per-conversation mutable state + `StreamSnapshot` record |

---

### StreamingService API

```csharp
// Start a stream; subscriber receives snapshots on every chunk
void StartStream(Guid conversationId, ChatRequest request, Action<StreamSnapshot> subscriber)

// Swap the subscriber when changing conversations (stream keeps running)
void Subscribe(Guid conversationId, Action<StreamSnapshot> onUpdate)
void Unsubscribe(Guid conversationId)

// Read current state when re-attaching (e.g. user navigates back)
StreamSnapshot? GetSnapshot(Guid conversationId)

// Called by Chat.razor after finalizing the completed message
void AcknowledgeCompletion(Guid conversationId)
```

`StreamingService` implements `IDisposable`. Its `Dispose()` cancels all in-flight `CancellationTokenSource` instances, which fires when the Blazor circuit disconnects.

---

### StreamSnapshot

```csharp
public record struct StreamSnapshot(
    string AccumulatedText,
    string ThinkingText,                        // accumulated reasoning; empty when thinking not active
    IReadOnlyList<ToolActivityItem> LiveToolActivity,
    bool IsStreaming,
    bool IsComplete,
    long ElapsedMs);
```

An immutable value snapshot taken under lock before each subscriber invocation. The component never reads from shared mutable state; it always works with a consistent point-in-time snapshot.

---

### Thread Safety

`ConversationStreamState` has a `private readonly object _lock`. All mutations (`AppendText`, `AppendThinking`, `AddToolCall`, `UpdateToolResult`, `Complete`) acquire the lock and replace immutable values: strings and `IReadOnlyList<T>` references are swapped atomically. `TakeSnapshot()` acquires the lock and copies in one step.

The subscriber field (`Action<StreamSnapshot>?`) is a reference — reads/writes are reference-atomic on 64-bit .NET. The worst case of a race on subscribe/unsubscribe is missing one notification, which is harmless.

---

### Chat.razor Changes

`Chat.razor` no longer contains a streaming loop. Instead:

**Sending a message:**

```csharp
StreamingService.StartStream(_conversationId.Value, request, OnStreamUpdate);
```

**The subscriber callback:**

```csharp
private void OnStreamUpdate(StreamSnapshot snapshot)
{
    _ = InvokeAsync(() =>
    {
        if (snapshot.IsComplete && !_streamFinalized)
        {
            _streamFinalized = true;
            FinalizeStreamedMessage(snapshot);
            StreamingService.AcknowledgeCompletion(_conversationId!.Value);
            _streamingBuffer = string.Empty;
            _liveToolActivity = [];
            _isStreaming = false;
        }
        else
        {
            _streamingBuffer = snapshot.AccumulatedText;
            _liveToolActivity = snapshot.LiveToolActivity.ToList();
            _isStreaming = snapshot.IsStreaming;
        }
        _scrollToBottom = true;
        StateHasChanged();
    });
}
```

`InvokeAsync` marshals the callback to the Blazor circuit's synchronization context so `StateHasChanged()` is always called on the correct thread.

**Switching away from a streaming conversation:**

```csharp
StreamingService.Unsubscribe(_conversationId.Value);  // stream keeps running
```

**Switching back:**

```csharp
var snapshot = StreamingService.GetSnapshot(conversationId);
if (snapshot.HasValue)
{
    if (snapshot.Value.IsComplete)
        StreamingService.AcknowledgeCompletion(conversationId); // DB already has the message
    else
    {
        StreamingService.Subscribe(conversationId, OnStreamUpdate);
        _streamingBuffer = snapshot.Value.AccumulatedText;
        _isStreaming = true;
    }
}
```

**Dispose (circuit/component teardown):**

```csharp
public void Dispose()
{
    ChatState.OnChange -= OnChatStateChanged;
    if (_conversationId.HasValue)
        StreamingService.Unsubscribe(_conversationId.Value);
    // StreamingService.Dispose() is called by DI when the circuit closes
}
```

---

### Registration

```csharp
// WissensNest.UI/Program.cs
builder.Services.AddScoped<StreamingService>();
```

One instance per Blazor circuit — same lifetime as `ChatState`.
