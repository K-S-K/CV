# WissensNest — Thought Stream Visualization

## Overview

Some Ollama models expose a separate *thinking* token stream that represents the model's
internal reasoning before it starts generating the answer. This article documents how
WissensNest captures, transports, persists, and visualizes that stream end-to-end.

Supported models: `qwen3`, `deepseek-r1`, `phi4-reasoning`, `openthinker`, `gemma4:e4b`.

---

## Architecture: 8-Layer Pipeline

```text
OllamaLanguageModelClient
  → ToolOrchestrator
    → ChatService
      → HandleChatStream (NDJSON)
        → MyAiClient (HTTP)
          → StreamingService
            → ConversationStreamState / StreamSnapshot
              → Chat.razor (UI panels)
                → Messages table (DB persistence)
```

Each layer adds or passes `ThinkingChunk` — a new member of the `StreamChunk` discriminated
union — without changing the existing contract for other chunk types.

---

## New Types

### `ThinkingChunk` (`WissensNest.Contracts/Streaming/StreamChunk.cs`)

```csharp
// Intermediate reasoning token emitted by a thinking-capable model.
// Only present when ChatRequest.EnableThinking is true and the model supports it.
public record ThinkingChunk(string ThinkingContent) : StreamChunk;
```

### `ChatRequest.EnableThinking` (`WissensNest.Contracts/Models/ChatRequest.cs`)

```csharp
public record ChatRequest(
    Guid ConversationId,
    IReadOnlyList<ChatMessage> History,
    string UserMessage,
    IReadOnlyList<string>? EnabledTools = null,
    bool EnableThinking = false);          // ← new
```

---

## Layer 1 — OllamaLanguageModelClient

`ChatRequest.Think` is set to `true` when `enableThinking` is true. On each streaming chunk,
`response.Message?.Thinking` is read alongside `response.Message?.Content`:

```csharp
var thinking = response.Message?.Thinking;
if (!string.IsNullOrEmpty(thinking))
    await writer.WriteAsync(new ThinkingChunk(thinking), ct);

var token = response.Message?.Content;
if (!string.IsNullOrEmpty(token))
    await writer.WriteAsync(new TextTokenChunk(token), ct);
```

For the non-streamed path (when tools are active, `Stream = false`), the full thinking block
is read from `lastChunk?.Message?.Thinking` after the loop and emitted as a single
`ThinkingChunk`.

---

## Layer 2 — ToolOrchestrator

`enableThinking` is forwarded to `ILanguageModelClient.StreamChatAsync`. `ThinkingChunk`
is yielded as-is — the orchestrator does not accumulate reasoning into the tool-loop history.

---

## Layer 3 — ChatService

Two parallel `StringBuilder` instances accumulate during the LLM task:

```csharp
var responseBuffer  = new StringBuilder();   // final answer
var thinkingBuffer  = new StringBuilder();   // reasoning

// inside the await foreach:
if (chunk is TextTokenChunk t)        responseBuffer.Append(t.Token);
else if (chunk is ThinkingChunk th)   thinkingBuffer.Append(th.ThinkingContent);
```

After the stream ends, both are passed to `PersistMessageAsync`:

```csharp
var thinkingContent = thinkingBuffer.Length > 0 ? thinkingBuffer.ToString() : null;
await PersistMessageAsync(..., thinkingContent, ct);
```

---

## Layer 4 — NDJSON (HandleChatStream in Program.cs)

`ThinkingChunk` is serialised to:

```json
{ "type": "thinking", "content": "...", "elapsedMs": 1234 }
```

---

## Layer 5 — MyAiClient

```csharp
"thinking" => new ThinkingChunk(root.GetProperty("content").GetString() ?? "")
             { Elapsed = elapsed },
```

---

## Layer 6 — ConversationStreamState / StreamSnapshot

```csharp
// New field
private string _thinkingText = string.Empty;

public void AppendThinking(string content)
{
    lock (_lock) _thinkingText += content;
}

// StreamSnapshot gains ThinkingText
public record struct StreamSnapshot(
    string AccumulatedText,
    string ThinkingText,
    IReadOnlyList<ToolActivityItem> LiveToolActivity,
    bool IsStreaming,
    bool IsComplete,
    long ElapsedMs);
```

`StreamingService.RunStreamAsync` dispatches `ThinkingChunk` to `state.AppendThinking`.

---

## Layer 7 — Chat.razor (UI)

### Streaming panel

Inside `@if (_isStreaming)`, rendered first (above tool activity and the streaming bubble):

```razor
<details class="thinking-details active" open>
    <summary class="thinking-summary">
        <svg class="thinking-wave" ...> <!-- animated brainwave --> </svg>
        <span class="thinking-summary-label">Thinking...</span>
    </summary>
    <div class="thinking-body">@_thinkingBuffer</div>
</details>
```

The `active` CSS class triggers the `@keyframes thinking-slide` animation on `.wave-inner`.
The `open` attribute is always present during streaming (Blazor re-renders override any
user collapse attempt — acceptable UX during active generation).

### Historical panel

Inside `@foreach (var message in _messages)`, above `<MessageBubble>`:

```razor
@if (message.Role == "assistant" && !string.IsNullOrEmpty(message.ThinkingContent))
{
    <details class="thinking-details">
        <summary class="thinking-summary">
            <svg class="thinking-wave" ...> <!-- static brainwave --> </svg>
            <span class="thinking-summary-label">
                Thought for @FormatElapsed(...)
            </span>
            <button class="tb-btn thinking-copy-btn" @onclick="() => CopyThinking(...)">
                Copy
            </button>
        </summary>
        <div class="thinking-body">@message.ThinkingContent</div>
    </details>
}
```

No `open` attribute → collapsed by default. Native `<details>` expand/collapse; no
Blazor state required. The `Copy` button calls `window.copyToClipboard` via JS interop.

### UI state removed

`_thinkingExpanded` and `_collapsedThinking` / `ToggleThinkingExpanded` are not used.
The `<details>` element manages its own open/closed state natively.

---

## Layer 8 — DB Persistence

Migration `20260512014612_AddThinkingContentToMessages` adds:

```sql
ALTER TABLE Messages ADD COLUMN ThinkingContent TEXT;
```

`Message.ThinkingContent` (nullable string) is mapped in both:

- `MessageRepository.ToDomain` / `ToEntity`
- `ConversationRepository.ToDomainWithMessages` (inline mapping used by `HandleGetMessages`)

**Important:** `ConversationRepository.ToDomainWithMessages` is a separate inline mapping
that does NOT delegate to `MessageRepository`. Both must be kept in sync whenever
`Message` gains a new field.

---

## CSS — Unified Classes

Both streaming and historical panels share the same CSS classes:

| Class | Purpose |
| --- | --- |
| `.thinking-details` | Container (`<details>` element) — dark background, border, radius |
| `.thinking-summary` | Header row (`<summary>`) — flex, padding, no default marker |
| `.thinking-wave` | SVG brainwave glyph — `overflow: hidden` |
| `.thinking-details.active .wave-inner` | Scrolling animation (streaming only) |
| `.thinking-summary-label` | Purple monospace label |
| `.thinking-body` | Content area — `max-height: 400px`, `overflow-y: auto` |
| `.thinking-copy-btn` | Small Copy button (historical only) |

---

## Ribbon Toggle

`ToolbarState.EnableThinking` (bool, default `false`) is toggled by the lightbulb button
in the **View** group of `RibbonToolbar`. The View group uses a 2×2 grid
(`.ribbon-group-view`) to fit A+, A−, AL, and Think in the fixed 111 px ribbon height.

`Chat.razor` reads `ToolbarState.EnableThinking` when constructing `ChatRequest` for both
`SendMessage` and `RegenerateFrom`.

---

## Model Compatibility

`ChatRequest.Think = true` is silently ignored by models that do not declare thinking
support in their Ollama manifest. No error is thrown; `ThinkingChunk` is simply never
emitted, `ThinkingContent` stays null, and no panel appears in the UI. Testing the feature
requires pulling a thinking-capable model (`qwen3:8b`, `qwen3:14b`, `deepseek-r1:8b`,
`phi4-reasoning`, `gemma4:e4b`, etc.).
