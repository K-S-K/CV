# WissensNest — Temperature Control

## Overview

The temperature parameter controls the randomness of model output. A value near `0.0`
makes responses more deterministic and focused; values toward `2.0` increase creativity
and variation. When the user leaves **Default** checked, `null` is passed and Ollama uses
its built-in default (0.8).

Temperature is selected per message, persisted on both the user message (what was requested)
and the assistant message (what was applied), and displayed as a badge in the bubble header.

---

## Affected Layers

```text
ChatRequest.Temperature (nullable float)
  → ChatService.StreamResponseAsync
    → ToolOrchestrator.OrchestrateAsync
      → ILanguageModelClient.StreamChatAsync
        → OllamaLanguageModelClient  (sets request.Options.Temperature)
  → PersistMessageAsync             (stored on user + assistant Message)
    → MessageRepository / ConversationRepository.ToDomainWithMessages
      → MessageInfo.Temperature
        → ChatMessageViewModel.Temperature
          → MessageBubble (T: badge in header)
```

---

## New Fields

### `ChatRequest.Temperature` (`WissensNest.Contracts/Models/ChatRequest.cs`)

```csharp
public record ChatRequest(
    Guid ConversationId,
    IReadOnlyList<ChatMessage> History,
    string UserMessage,
    IReadOnlyList<string>? EnabledTools = null,
    bool EnableThinking = false,
    float? Temperature = null);   // ← new; null → model default
```

### `Message.Temperature` (`WissensNest.Contracts/Entities/Message.cs`)

```csharp
public float? Temperature { get; set; }
```

Stored on both the user message (what the user had selected when sending) and the
assistant message (what was passed to the model for that response).

### `MessageInfo.Temperature` (`WissensNest.Contracts/Models/MessageInfo.cs`)

```csharp
public record MessageInfo(
    ...
    string? ThinkingContent = null,
    float? Temperature = null);    // ← new
```

### `ChatMessageViewModel.Temperature` (`WissensNest.UI/Models/ChatMessageViewModel.cs`)

```csharp
public float? Temperature { get; init; }
```

Added to `FromAssistant(... float? temperature = null)` and
`FromPersisted(... float? temperature = null)`.

---

## Layer 1 — OllamaLanguageModelClient

`ILanguageModelClient.StreamChatAsync` gains `float? temperature = null`.
The client applies it only when the value is present:

```csharp
Options = temperature.HasValue
    ? new OllamaSharp.Models.RequestOptions { Temperature = temperature.Value }
    : null
```

`null` Options → Ollama uses its own default (0.8).

---

## Layer 2 — ToolOrchestrator

`temperature` is forwarded to `_client.StreamChatAsync` without modification. Temperature
is not accumulated or reset between tool-calling rounds.

---

## Layer 3 — ChatService

`PersistMessageAsync` gains a `float? temperature` parameter. It is called twice:

```csharp
// user message — records what the user had selected
await PersistMessageAsync(..., request.Temperature, ct);

// assistant message — records what was sent to the model
await PersistMessageAsync(..., request.Temperature, ct);
```

---

## Layer 4 — DB Persistence

Migration `20260513113546_AddTemperatureToMessages`:

```sql
ALTER TABLE Messages ADD COLUMN Temperature REAL;   -- nullable
```

### Dual-mapping pitfall

`ConversationRepository.ToDomainWithMessages` contains an **inline** message projection
that does NOT delegate to `MessageRepository.ToDomain`. Both mappings must include
`Temperature` (and every other new `Message` field):

- `MessageRepository.ToDomain` / `ToEntity` — used by `GetByConversationAsync`
- `ConversationRepository.ToDomainWithMessages` — used by `GetWithMessagesAsync`,
  which is the path called by `HandleGetMessages` in the API

Forgetting either mapping causes the field to appear `null` on one of the two load paths.
`ThinkingContent` had the same pitfall — the pattern is documented here to prevent recurrence.

---

## Layer 5 — API Serialisation

The anonymous type in `HandleGetMessages` (Program.cs) includes `m.Temperature`:

```csharp
var messages = conversation.Messages.Select(m => new
{
    m.Id, m.Role, ..., m.ThinkingContent, m.Temperature
});
```

---

## Layer 6 — UI: Temperature Row

The control lives in `Chat.razor` inside `<div class="chat-input-col">`, above the textarea:

```html
<div class="temperature-row">
    <label>
        <input type="checkbox" @bind="_useDefaultTemperature" disabled="@_isStreaming" />
        default
    </label>
    <input type="range" min="0" max="2" step="0.05"
           value="@_temperature.ToString("F2", CultureInfo.InvariantCulture)"
           @oninput="OnTemperatureInput"
           disabled="@(_useDefaultTemperature || _isStreaming)" />
    <span class="temperature-value">
        @(_useDefaultTemperature ? "—" : _temperature.ToString("F2", CultureInfo.InvariantCulture))
    </span>
</div>
```

State fields:

```csharp
private float _temperature = 0.8f;
private bool  _useDefaultTemperature = true;
```

Temperature is passed in both `SendMessage` and `HandleRegenerate`:

```csharp
Temperature = _useDefaultTemperature ? null : _temperature
```

### InvariantCulture — mandatory for range inputs

HTML range inputs always emit their value with a dot as the decimal separator, regardless
of browser locale. Blazor Server's default `@bind:event="oninput"` parses the event value
using the current **server** culture. If that culture uses `.` as the thousands separator
(e.g. Russian: `"1.15"` → 115), the stored float becomes wildly wrong and the slider
snaps to the DOM max on the next render.

Fix: explicit `@oninput` handler that parses with `InvariantCulture`:

```csharp
private void OnTemperatureInput(ChangeEventArgs e)
{
    if (float.TryParse(e.Value?.ToString(),
            NumberStyles.Float,
            CultureInfo.InvariantCulture,
            out var val))
        _temperature = val;
}
```

The `value` attribute and the readout span are also formatted with
`CultureInfo.InvariantCulture` so the round-trip is consistent.

---

## Layer 7 — MessageBubble Display

A badge is shown in the bubble header for any message that has a stored temperature:

```razor
@if (Message.Temperature.HasValue)
{
    <span class="temperature-badge" title="Temperature">
        T:@Message.Temperature.Value.ToString("F2")
    </span>
}
```

The badge appears on both user and assistant bubbles, immediately after the model-name
span and before the elapsed-time span.

---

## CSS

| Class | Location | Purpose |
| --- | --- | --- |
| `.chat-input-col` | `app.css` | Column flex wrapper replacing direct `flex: 1` on textarea-wrapper |
| `.temperature-row` | `app.css` | Flex row: checkbox + slider + readout |
| `.temperature-row input[type="range"]` | `app.css` | `accent-color: #534AB7`; `flex: 1` |
| `.temperature-row input[type="range"]:disabled` | `app.css` | `opacity: 0.7`; `cursor: not-allowed` |
| `.temperature-value` | `app.css` | Monospace readout; `min-width: 2.5rem`; right-aligned |
| `.temperature-badge` | `app.css` | Inline badge in bubble header; monospace; `opacity: 0.55` |
