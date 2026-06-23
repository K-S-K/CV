# WissensNest

## AI-Powered Help Assistant — Design and Implementation

### Overview

The Help page offers two complementary search modes:

| Mode | How it works | Latency |
| --- | --- | --- |
| **Keyword search** | In-memory scan of all article files; first match per article | < 50 ms |
| **AI answer** | All doc content sent to the local model; model generates an answer | 5–30 s |

Both modes share the same `_allContent` cache — articles are loaded from `wwwroot/help/` once
on first search, then held in memory for the Blazor circuit's lifetime.

---

### API Endpoint: `POST /help/ask`

```csharp
app.MapPost("/help/ask", async (
    HelpAskRequest req,
    ILanguageModelClient modelClient,
    CancellationToken ct) =>
{
    const string SystemPromptHeader = "You are the WissensNest documentation assistant. " +
        "Answer the user's question using ONLY the documentation provided. " +
        "Format your answer in Markdown.\n\n--- DOCUMENTATION ---\n\n";

    var messages = new[] { new ChatMessage("user", req.Question, DateTimeOffset.UtcNow) };
    var answer   = new StringBuilder();

    await foreach (var chunk in modelClient.StreamChatAsync(messages,
                       SystemPromptHeader + req.Context, null, ct))
    {
        if (chunk is TextTokenChunk t) answer.Append(t.Token);
        else if (chunk is CompletionChunk) break;
    }
    return answer.ToString();
});

public record HelpAskRequest(string Question, string Context);
```

**Key design decisions:**

- **No tools** — `null` is passed for the tools parameter, so Ollama streams normally (no `stream=false` penalty).
- **No persistence** — no conversation is created in the database; the endpoint is stateless.
- **Collects server-side** — streaming happens inside the handler; the HTTP response returns only after the full answer is ready. Simple, but means the client waits for the whole answer. See *Future: streaming to the browser* below.
- **Plain string response** — the handler returns `answer.ToString()`. ASP.NET Minimal API serializes this as JSON (`"the answer text"`), and `response.Content.ReadAsStringAsync()` in `MyAiClient` returns it as-is. `MarkdownContent` renders it in the UI.

---

### Context Assembly

The UI sends all documentation content with every request:

```csharp
var context = string.Join("\n\n---\n\n", _allContent!
    .Select(kvp =>
    {
        var title = _toc
            .SelectMany(g => g.Entries)
            .FirstOrDefault(e => e.Path[..^3] == kvp.Key)?.Title ?? kvp.Key;
        return $"# {title}\n\n{kvp.Value}";
    }));
```

Each article is prefixed with its human-readable title as a `#` heading, separated by `---`.
This gives the model clear section boundaries to cite in its answer.

**Context size estimate:** 12 articles × ~4 KB ≈ 48 KB raw text ≈ 12,000 tokens.
`qwen2.5:14b` has a 128K token context window — comfortably within limits.

---

### System Prompt Design

```
You are the WissensNest documentation assistant.
Answer the user's question using ONLY the documentation provided below.
Be concise and specific. When referencing a topic, name the article section clearly.
If the question cannot be answered from the documentation, say so.
Format your answer in Markdown.

--- DOCUMENTATION ---

# Getting Started

... (all article content) ...
```

The key constraints in the prompt:
1. *ONLY from the documentation* — prevents hallucination about unimplemented features.
2. *Name the article section* — makes the model cite sources, which helps users navigate to the full article.
3. *If not answerable, say so* — avoids confident but wrong answers when the docs don't cover something.

---

### Error Handling

The UI wraps `AskHelpAsync` in a try/catch:

```csharp
try
{
    _aiAnswer = await AiClient.AskHelpAsync(question, context);
}
catch
{
    _aiAnswer = "_The AI assistant is unavailable right now. " +
                "Please check that the API is running._";
}
```

The fallback message is itself Markdown, rendered by `MarkdownContent`.
The most common failure is the API being down or the Ollama model not loaded.

---

### How to Improve the AI Answer Quality

The model's answer quality is directly proportional to the quality of the documentation.
Things that improve it:

1. **Add "how-to" articles.** Procedure-style content ("To do X: step 1, step 2…") is easier
   for the model to summarize than descriptive prose.

2. **Add examples.** If a user asks *"how do I export only selected blocks?"*, the model answers
   better when the article contains a concrete numbered sequence rather than just button names.

3. **Clarify section headings.** The model cites section names when it finds the answer.
   A heading like `### Exporting to PDF` is cited better than `### Step 3`.

4. **Fill in placeholder articles.** The Architecture articles are mostly complete, but
   `User/01_Getting_Started.md` lacks concrete troubleshooting examples.

5. **Add a troubleshooting article.** Questions like *"why is the response slow?"* or
   *"why doesn't the tool activate?"* don't appear in any current article.

---

### Known Limitations

| Limitation | Impact | Potential fix |
| --- | --- | --- |
| No streaming to browser | User waits 5–30 s with no progress | Server-Sent Events from `/help/ask` → `IAsyncEnumerable<string>` on client |
| All docs sent every request | 48 KB request body each time | Relevance-ranked retrieval: use keyword search results to pick top-3 articles |
| No conversation history | Model can't follow up on its own answer | Multi-turn: keep `_aiHistory` in the Help component, send it with each question |
| No persistent feedback | Can't tell which answers were helpful | Add a thumbs-up/down signal, log to DB for later review |

---

### Future: Streaming to the Browser

The current endpoint buffers the full answer server-side. A streaming version would:

1. Change the endpoint to return an SSE stream (`text/event-stream`).
2. Add a `StreamHelpAnswerAsync` method to `IWissensNestClient` returning `IAsyncEnumerable<string>`.
3. In `Help.razor`, accumulate tokens into `_aiAnswer` chunk by chunk, calling `StateHasChanged()` each time.

This mirrors the existing chat streaming architecture exactly.

---

### Future: Retrieval-Augmented Help

Instead of sending all docs, use the keyword search to pick the 2–3 most relevant articles
and send only those. This would:

- Reduce request size (better for privacy, lower latency).
- Give the model more focused context (less noise → better answers).
- Require a relevance score in the search function (currently first-match only).
