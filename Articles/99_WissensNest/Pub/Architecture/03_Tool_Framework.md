# WissensNest — Tool Framework

## What Tools Are

Tools extend the language model beyond text generation. Instead of asking the model to reason
about things it cannot know — current time, live weather, external documents — you give it
declared functions it can invoke. The model decides when a tool is needed, calls it with
structured arguments, receives the result as text, and continues generating. The user sees only
the final natural-language answer.

---

## The `ITool` Interface

```csharp
public interface ITool
{
    string Name              { get; }   // snake_case, unique, sent to the model verbatim
    string Description       { get; }   // ≤ 3 sentences; the model's only signal for when to call
    string ParametersSchema  { get; }   // JSON Schema "object" string
    Task<string> ExecuteAsync(string inputJson, CancellationToken ct = default);
}
```

`ExecuteAsync` receives the model's argument JSON, runs the tool, and returns a plain-text
string. That string is injected into the conversation as a `tool` role message.

---

## Registered Tools

| Name | Assembly | What it does |
| --- | --- | --- |
| `get_current_time` | Tools.GetCurrentTime | Current UTC time + optional IANA timezone |
| `geocode` | Tools.Geocoding | Place name → lat/lon/timezone via open-meteo |
| `get_weather` | Tools.Weather | Current weather via open-meteo (requires lat/lon) |
| `web_search` | Tools.WebSearch | DuckDuckGo HTML scraping; returns titles, URLs, snippets |
| `fetch_page` | Tools.FetchPage | Full text of a URL — HTML via AngleSharp, PDF via PdfPig; 200 MB byte cache |
| `library_search` | Tools.Library | Keyword scan of local `.md` descriptors + undescribed PDF filenames |
| `library_read` | Tools.Library | Local PDF page-range extraction via PdfPig |
| `library_describe` | Tools.Library | Writes a YAML-frontmatter `.md` sidecar for a new library document |

---

## Tool Registration

Each tool assembly exposes a `ServiceCollectionExtensions` class with an `Add*` method
that registers the tool as a singleton `ITool`:

```csharp
services.AddSingleton<ITool, GetCurrentTimeTool>();
```

`WissensNest.API/Program.cs` calls all `Add*` methods. `ToolOrchestrator` receives
`IEnumerable<ITool>` via constructor injection and indexes tools by name — no configuration
required when a new tool is added.

---

## The Model ↔ Tool Loop

![Tool calling flow](../../Images/16_01_WissensNest_Tool_Calling_Flow.svg)

`ChatService.StreamResponseAsync` delegates entirely to `ToolOrchestrator.OrchestrateAsync`:

1. Call the model with the current message list and the schemas of the user's enabled tools.
2. If the model returns one or more `ToolCallRequestChunk` events, execute each tool.
3. Append the assistant message (with embedded tool calls) and the tool result messages to history.
4. Loop back to step 1 until the model returns a `CompletionChunk` with no pending tool calls.

All events — text tokens, tool call requests, tool results — are yielded upstream in real time
as `StreamChunk` values.

**Ollama constraint:** when tools are present in a request, Ollama requires `stream = false`.
`OllamaLanguageModelClient` handles this transparently: it sets `Stream = tools is null` and
emits a single `TextTokenChunk` with the full content string when streaming is off.

---

## The `StreamChunk` Discriminated Union

Everything that flows out of the tool loop is a `StreamChunk`:

| Type | Meaning |
| --- | --- |
| `TextTokenChunk(Token)` | A text fragment from the model |
| `ToolCallRequestChunk(CallId, ToolName, InputJson)` | The model requested a tool call |
| `ToolResultChunk(CallId, ToolName, OutputText, Duration, Success)` | Tool executed and returned |
| `CompletionChunk(FinishReason, PromptTokens?, CompletionTokens?)` | Model finished; always last |
| `ErrorChunk(Stage, Message, Exception?)` | Something failed; `Stage` is `"model"` or `"tool:Name"` |

`StreamingService` in the UI processes `ToolCallRequestChunk` and `ToolResultChunk` events into
`ConversationStreamState.LiveToolActivity`, which `Chat.razor` renders as a collapsible
activity panel inside the streaming assistant bubble. In parallel, `ChatService` accumulates
the same events and serializes them as JSON into `Messages.ToolActivityJson` — so the activity
panel is restored identically when the conversation is loaded again later.

---

## User Tool Selection

The user controls which tools are available per message. `GET /tools` returns all registered
tools (name + description). The UI renders a toggle button per tool in the ribbon and above
the chat input. The user's selection is sent as `ChatRequest.EnabledTools` — a list of names.
`ToolOrchestrator.ResolveTools` maps these to their `ITool` instances. Tools not in the list
are never shown to the model for that request.

---

## Adding a New Tool — Checklist

1. Create `Src/Tools/WissensNest.Tools.<Name>/` — reference `WissensNest.Contracts` only.
2. Implement `ITool`: `snake_case` name, focused description (≤ 3 sentences), valid JSON Schema, `ExecuteAsync` with graceful error strings (never throw).
3. Add `ServiceCollectionExtensions` with `AddSingleton<ITool, YourTool>()`.
4. Add the project reference in `WissensNest.API.csproj` and call `services.Add<Name>()` in `Program.cs`.
5. The tool immediately appears via `GET /tools` and is selectable in the UI.
