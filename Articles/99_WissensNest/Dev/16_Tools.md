# WissensNest

## Tools — Design, Registration, and the Calling Loop

Tools extend the model's capability beyond text generation. Instead of asking the model to reason about things it cannot know (current time, live weather, external APIs), you give it declared functions it can invoke. The model decides when a tool is needed, calls it with structured arguments, receives the result as text, and continues generating. The user sees only the final natural-language answer.

This article covers how tools are defined with `ITool`, how the model learns about them, how to write effective descriptions and schemas, and how to format tool output for reliable model consumption.

---

### Flow Overview

![Tool Calling Flow](../Images/16_01_WissensNest_Tool_Calling_Flow.svg)

The sequence has two phases separated by the loop:

**Setup (startup):** Every `ITool` implementation is registered in DI in its assembly's `ServiceCollectionExtensions`. `ToolOrchestrator` receives all registered tools via constructor injection and indexes them by name.

**Per-request loop:** `ChatService.StreamResponseAsync` delegates entirely to `ToolOrchestrator.OrchestrateAsync`. The orchestrator calls the model with the current message list and the set of active tool schemas. If the model returns one or more `ToolCallRequestChunk`s, the orchestrator executes each tool, appends the assistant message (with embedded tool calls) and the tool result messages to history, then calls the model again. This repeats until the model produces a `CompletionChunk` with no pending tool calls. All chunks — text tokens, tool call events, tool results — are yielded upstream in real time.

---

### The `ITool` Interface

```csharp
public interface ITool
{
    string Name { get; }
    string Description { get; }
    string ParametersSchema { get; }
    Task<string> ExecuteAsync(string inputJson, CancellationToken ct = default);
}
```

**`Name`** — machine-readable identifier. Passed to the model verbatim. Use `snake_case` (Ollama's function-calling convention). Must be unique across all registered tools. Examples: `get_current_time`, `get_weather`, `geocode`.

**`Description`** — natural-language explanation sent to the model. The model uses this — and only this — to decide whether to call the tool. See the section on writing descriptions below.

**`ParametersSchema`** — a JSON Schema `object` string describing the tool's input. The `OllamaLanguageModelClient` deserializes this into `Parameters` and passes it to OllamaSharp as the function's parameter specification. The model reads the schema to know what JSON to produce.

**`ExecuteAsync`** — receives the model's argument object as a raw JSON string, runs the tool, and returns a plain-text string. The return value is injected back into the conversation as a `tool` role message.

---

### Tool Registration

Each tool assembly exposes a `ServiceCollectionExtensions` class with a single `Add*` method:

```csharp
// WissensNest.Tools.GetCurrentTime/ServiceCollectionExtensions.cs
public static IServiceCollection AddGetCurrentTime(this IServiceCollection services)
{
    services.AddSingleton<ITool, GetCurrentTimeTool>();
    return services;
}
```

`WissensNest.API/Program.cs` calls all `Add*` methods:

```csharp
builder.Services
    .AddGetCurrentTime()
    .AddGeocoding()
    .AddWeather()
    .AddWebSearch()
    .AddFetchPage()
    .AddLibrary(opts => builder.Configuration.GetSection("Library").Bind(opts));
```

`ToolOrchestrator` is registered in `WissensNest.Core` and receives `IEnumerable<ITool>` via DI — it gets every registered implementation automatically, no configuration required.

**The `GET /tools` endpoint** returns the name and description of every registered tool so the UI can present a checkbox list to the user. The user's selection becomes `ChatRequest.EnabledTools` — a list of tool names. `ToolOrchestrator.ResolveTools` maps these names to their `ITool` instances. Tools not in the list are never shown to the model for that request.

---

### How the Model Is Informed About Tools

When `EnabledTools` is non-empty, `OllamaLanguageModelClient.MapTools` converts each `ITool` into the OllamaSharp function format:

```csharp
new Tool
{
    Type = "function",
    Function = new Function
    {
        Name     = tool.Name,
        Description = tool.Description,
        Parameters = JsonSerializer.Deserialize<Parameters>(tool.ParametersSchema)
    }
}
```

This list is attached to the `ChatRequest` sent to Ollama. Ollama embeds the tool list in the model's context. The model sees the tool names, descriptions, and parameter schemas and uses them to decide when and how to call a tool.

**Important Ollama constraint:** When tools are included in a request, Ollama requires `stream = false`. The full response is returned in one shot, and tool call data appears in `response.Message.ToolCalls`. `OllamaLanguageModelClient` handles this transparently: it sets `Stream = tools is null` and emits a single `TextTokenChunk` with the full content string when streaming is disabled.

---

### Writing Effective Tool Descriptions

The description is the only signal the model has for deciding whether to call the tool. Poor descriptions cause missed calls, wrong calls, or incorrect argument construction.

**State the tool's purpose in one sentence.** Lead with what it returns or does, not with internal implementation details.

```csharp
// Bad — describes the implementation, not the contract
"Calls the open-meteo API to get weather data."

// Good — tells the model what it gets and when to use it
"Returns current weather conditions for a geographic location. " +
"Requires latitude and longitude — use the 'geocode' tool first if you only have a city name."
```

**Declare preconditions and dependencies explicitly.** If this tool requires output from another tool, say so. The model will chain calls correctly only if you tell it what order is required.

```csharp
// GeocodingTool
"Resolves a place name to geographic coordinates and timezone. " +
"Use this before any tool that requires latitude, longitude, or timezone."

// GetWeatherTool
"Returns current weather conditions for a geographic location. " +
"Requires latitude and longitude — use the 'geocode' tool first if you only have a city name."
```

**Describe the return value shape briefly.** This helps the model reason about what to do with the result.

```csharp
// GeocodingTool
"Returns a JSON object with name, country, latitude, longitude, timezone, and elevation_m."
```

**State what optional parameters change.** If an optional field significantly affects output, mention it.

```csharp
// GetCurrentTimeTool
"Accepts an optional IANA timezone name (e.g. 'Europe/Berlin', 'America/New_York'). " +
"Always also returns UTC for reference."
```

**Keep it under 3 sentences.** Longer descriptions degrade reliability as the model tries to parse too much context.

---

### Writing the Parameters Schema

`ParametersSchema` must be a valid JSON Schema `object` string. OllamaSharp deserializes it verbatim — malformed JSON is silently ignored and the tool is passed to the model without parameters.

**Minimal working schema (no required parameters):**

```csharp
public string ParametersSchema => """
    {
      "type": "object",
      "properties": {
        "timezone": {
          "type": "string",
          "description": "IANA timezone name (e.g. 'Europe/Berlin'). Omit for UTC only."
        }
      },
      "required": []
    }
    """;
```

**Schema with required parameters:**

```csharp
public string ParametersSchema => """
    {
      "type": "object",
      "properties": {
        "latitude":  { "type": "number", "description": "Latitude of the location."  },
        "longitude": { "type": "number", "description": "Longitude of the location." },
        "temperature_unit": {
          "type": "string",
          "description": "Temperature unit: 'celsius' (default) or 'fahrenheit'."
        }
      },
      "required": ["latitude", "longitude"]
    }
    """;
```

**Rules for property descriptions:**

- Include the unit when it matters (`"Latitude of the location."` — the model knows degrees).
- List valid enum values inline (`"'celsius' (default) or 'fahrenheit'"`) rather than relying on a JSON Schema `enum` — Ollama's tool schema support is partial.
- Use concrete examples for string fields where the format is non-obvious (`"IANA timezone name (e.g. 'Europe/Berlin')"`).- Mark fields as `required` only when the tool cannot run without them. Optional fields with defaults should be absent from `required`.

---

### Formatting Tool Output

`ExecuteAsync` returns a plain-text `string`. This string becomes the content of a `tool` role message in the conversation. The model reads it to compose its final answer. Formatting choices directly affect how reliably the model can extract and present the information.

**Use labelled key-value lines for structured data.** This is the most reliable format — easy to parse visually and programmatically, and models handle it well.

```csharp
return $"""
    Temperature:   {c.Temperature2m}{unit}
    Feels like:    {c.ApparentTemperature}{unit}
    Wind speed:    {c.WindSpeed10m} km/h
    Precipitation: {c.Precipitation} mm
    Condition:     {DescribeWeatherCode(c.WeatherCode)}
    """;
```

**Use JSON for data the model may need to pass to another tool.** If a downstream tool expects structured input, return JSON so the model can extract fields cleanly.

```csharp
// GeocodingTool — result will be consumed by GetWeatherTool
return JsonSerializer.Serialize(new {
    name = result.Name,
    country = result.Country,
    latitude = result.Latitude,
    longitude = result.Longitude,
    timezone = result.Timezone,
    elevation_m = result.Elevation
}, JsonOptions);
```

**Return errors as plain sentences, never as exceptions.** `ExecuteAsync` must never throw — exceptions are caught by `ToolOrchestrator` and surfaced as `ErrorChunk` events. A tool-level error should instead return a descriptive string the model can relay to the user.

```csharp
catch (Exception ex)
{
    return $"Weather request failed: {ex.Message}";
}

if (parsed?.Current is null)
    return "Weather data unavailable.";
```

**Avoid markdown in tool output.** The tool result is an intermediate message seen by the model, not by the user. Markdown headers and bullet points add noise that can confuse the model's extraction. Reserve formatting for the model's final response.

**Be concise.** Every token in the tool result is part of the next model input. Verbose output increases latency and token usage. Return only the values the model needs to answer the question.

---

### The `StreamChunk` Discriminated Union

Everything that flows out of `ToolOrchestrator` (and ultimately out of `ChatService`) is a `StreamChunk`:

| Type | Meaning |
| --- | --- |
| `TextTokenChunk(Token)` | A text fragment from the model (or the full response when streaming is off) |
| `ToolCallRequestChunk(CallId, ToolName, InputJson)` | The model requested a tool call |
| `ToolResultChunk(CallId, ToolName, OutputText, Duration, Success)` | A tool executed and returned a result |
| `CompletionChunk(FinishReason, PromptTokens?, CompletionTokens?)` | The model finished; always the last chunk |
| `ErrorChunk(Stage, Message, Exception?)` | Something failed; stage is `"model"` or `"tool:ToolName"` |

`StreamingService` (circuit-scoped, `WissensNest.UI/Services`) receives these over the NDJSON stream. It processes `ToolCallRequestChunk` and `ToolResultChunk` events into its `ConversationStreamState.LiveToolActivity` list, then notifies `Chat.razor` via a subscriber callback on every chunk. `Chat.razor` reads `LiveToolActivity` from the `StreamSnapshot` to render a collapsible tool-activity panel below the streaming bubble.

In parallel, `ChatService` accumulates the same `ToolCallRequestChunk` / `ToolResultChunk` pairs in a `Dictionary<string, ToolActivityItem>` keyed by `CallId`. After the stream ends, the accumulated list is serialized as JSON into `Messages.ToolActivityJson` (migration `20260513135639_AddToolActivityToMessages`). On subsequent conversation loads, the repository deserializes it back into `Message.ToolActivity`, the API projection carries it through `MessageInfo.ToolActivity`, and `Chat.razor` passes it to `ChatMessageViewModel.FromPersisted` — so the same tool-activity panel is shown for historical messages without any additional UI code. See [31_ToolActivityPersistence.md](./31_ToolActivityPersistence.md) for the full pipeline.

---

### Adding a New Tool — Checklist

1. Create `Src/Tools/WissensNest.Tools.<Name>/` — reference `WissensNest.Contracts` only.
2. Implement `ITool`: choose a `snake_case` name, write a focused description (≤ 3 sentences), define the JSON Schema, implement `ExecuteAsync` with graceful error strings (no throws).
3. Add `ServiceCollectionExtensions` with `AddSingleton<ITool, YourTool>()`.
4. Add the project reference in `WissensNest.API.csproj` and call `services.Add<Name>()` in `Program.cs`.
5. The tool is immediately discoverable via `GET /tools` and selectable in the UI.

---

### Modified and Referenced Files

| File | Role |
| --- | --- |
| [ITool.cs](../../Src/Foundation/WissensNest.Contracts/Interfaces/ITool.cs) | Interface contract |
| [StreamChunk.cs](../../Src/Foundation/WissensNest.Contracts/Streaming/StreamChunk.cs) | Discriminated union for all pipeline events |
| [ToolOrchestrator.cs](../../Src/Foundation/WissensNest.Core/Services/ToolOrchestrator.cs) | Drives the model ↔ tool loop |
| [ChatService.cs](../../Src/Foundation/WissensNest.Core/Services/ChatService.cs) | Entry point; delegates to ToolOrchestrator |
| [OllamaLanguageModelClient.cs](../../Src/Foundation/WissensNest.Ollama/OllamaLanguageModelClient.cs) | Maps ITool → OllamaSharp Tool; handles stream=false |
| [GetCurrentTimeTool.cs](../../Src/Tools/WissensNest.Tools.GetCurrentTime/GetCurrentTimeTool.cs) | Reference implementation — no external deps |
| [GeocodingTool.cs](../../Src/Tools/WissensNest.Tools.Geocoding/GeocodingTool.cs) | HTTP tool — returns JSON for downstream tools |
| [GetWeatherTool.cs](../../Src/Tools/WissensNest.Tools.Weather/GetWeatherTool.cs) | HTTP tool — key-value output, depends on geocode |
| [WebSearchTool.cs](../../Src/Tools/WissensNest.Tools.WebSearch/WebSearchTool.cs) | DuckDuckGo HTML scraping — see [19_WebSearch.md](./19_WebSearch.md) |
| [FetchPageTool.cs](../../Src/Tools/WissensNest.Tools.FetchPage/FetchPageTool.cs) | HTML + PDF page fetching — see [24_FetchPage.md](./24_FetchPage.md) |
| [LibrarySearchTool.cs](../../Src/Tools/WissensNest.Tools.Library/LibrarySearchTool.cs) | Local library keyword search — see [25_LibrarianTool.md](./25_LibrarianTool.md) |
| [LibraryReadTool.cs](../../Src/Tools/WissensNest.Tools.Library/LibraryReadTool.cs) | Local PDF reading — see [25_LibrarianTool.md](./25_LibrarianTool.md) |
| [LibraryDescribeTool.cs](../../Src/Tools/WissensNest.Tools.Library/LibraryDescribeTool.cs) | Descriptor writing — see [25_LibrarianTool.md](./25_LibrarianTool.md) |
