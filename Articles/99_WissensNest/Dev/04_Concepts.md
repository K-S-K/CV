# My AI

## Concepts

## What will be discussed in this document

To better understand the product, let's imagine a dialogue between a student and a teacher and set up a list of subjects we need to clarify.

_Let's think about the architecture of our project._  
_Where is a better place to have the system prompt library? In the DB or in storable files? Let's suggest that in the DB._

_We also need a better understanding of how to store and restore contexts across different scopes. We need the assistant to have  context for the current chat, the user's common interests, and the user's current level of expertise. Users may also want narrow-purpose contexts, such as language translation, with a strict format for discussions. They might like to have big contexts for the projects, like a project for making an STM32-based clock, so the user loads the documentation on components, their source code, and schematics into this context._

_So please, explain to us how this technology can be used in this scope of tasks and maybe suggest some other use cases._

## What "context" actually means for an LLM

Every time you send a message to the model, you send the entire conversation history as one big block of text. The model is stateless. It has no memory between calls — it only knows what's in that block at any given request processing.

That block has a size limit called the **context window**. For Phi-4, it's ~16K tokens. For Qwen 2.5 32B, it's ~128K tokens. One token ≈ 0.75 words in English, fewer in Russian or German.

So "managing context" means: **deciding what text goes into that block on each request**.

## The four layers of context you described

You intuitively described exactly the right mental model. Let me name the layers formally:

| Layer                      | Description                  |
|----------------------------|------------------------------|
|System prompt               |who the assistant is          |
|Long-term memory            |what it knows about you       |
|Project / domain context    |what it knows about this topic|
|Current conversation history|what was just said            |

Each layer adds text to the context window before the model sees your message. The model responds as if it has always known it all.

### Layer 1: System prompt

**What it is:** A fixed instruction block prepended to every conversation.  
Defines personality, language, format rules, and constraints.

**Your use cases:**

- General assistant: "You are a helpful family assistant..."
- Language learning: "You are a German language tutor. Always correct grammar mistakes. Respond in German unless asked otherwise."
- Translation: "Always respond in this exact format: Term | Translation | IPA | Definition."
- Embedded assistant: "You are an expert in STM32 microcontrollers. Always reference register names from the datasheet."

**Where to store:** Database. A _SystemPromptTemplate_ table with _Name_, _Description_, _Content_. Selected per conversation.

### Layer 2: Long-term memory

**What it is:** Persistent facts about the user that are injected into every conversation. Things the assistant should always know.

**Your use cases:**

- "User is a .NET developer with 15 years of experience."
- "User is learning German — B1 level"
- "User is interested in history and biology."
- "User works with STM32 and ESP32 microcontrollers."
- "User prefers concise answers with code examples."

**How it works technically:** After each conversation, you ask the model: "_Extract any new facts about the user from this conversation worth remembering._" Store the result. In the next conversation, inject the stored facts as a block of text after the system prompt.

**Where to store:** Database. A _UserMemory_ table — key/value pairs with timestamps and optional expiry. Injected as a formatted block.

**Context window cost:** Small — a few hundred tokens for a well-maintained memory.

### Layer 3: Project/domain context

**What it is:** A large body of reference material relevant to a specific topic. Documentation, source code, schematics, notes.

**Your use cases**:

- Clock project: STM32 datasheet sections + your schematic + your source code
- Language learning: German grammar rules + your vocabulary list + previous corrections
- Cooking: saved recipes + dietary preferences + seasonal ingredients

**The challenge:** This layer can be enormous. A full STM32 reference manual is 2000+ pages — far too large to fit in any context window.

**The solution — RAG (Retrieval Augmented Generation):**

```text
At storage time:
  Document → split into chunks of ~500 tokens
           → store chunks in DB with metadata

At query time:
  User message → search chunks for relevance
               → retrieve top 3-5 most relevant chunks
               → inject only those chunks into context
```

The model never sees the whole document — only the parts relevant to the current question. For your clock project: if you ask about UART configuration, only the UART-related datasheet chunks are injected.

**Where to store:** SQLite with FTS5 (full text search) for keyword matching. Later, you can add vector embeddings for semantic search — but FTS5 gets you 80% of the way there with zero extra dependencies.

### Layer 4: Current conversation history

**What it is:** The actual back-and-forth of the current session. What you already have in __history_.

**The challenge:** Long conversations consume the context window. A 2-hour embedded development session could easily fill 32K tokens.

**Strategies:**

- Sliding window: Keep only the last N messages
- Summarization: When history grows large, ask the model to summarize the first half, and replace those messages with the summary
- Selective retention: Keep all user messages but summarize long assistant responses

**Where to store:** Database. Your planned WissensNest.Persistent.SQLite assembly. A Conversation table with Messages.

## How these layers combine in practice

For your clock project session, the context block sent to the model looks like this:

```text
[System prompt: embedded expert, STM32 specialist]

[Long-term memory: 
  - User is an experienced .NET developer
  - Currently building STM32-based clock
  - Prefers register-level explanations]

[Project context — RAG retrieved chunks:
  - STM32H7 RTC register description (chunk 47)
  - Your ClockInit() source code
  - Schematic note about 32.768kHz crystal]

[Conversation history:
  User: How do I configure the RTC prescaler?
  Assistant: ...
  User: The seconds aren't incrementing correctly
  Assistant: ...]

[Current message:
  User: Could it be related to the LSE startup time?]
```

## Additional use cases you might not have considered

- **Cooking context with seasonal awareness:** Store your family's dietary preferences, allergies, and favorite cuisines. Inject current season. Ask for meal plans, and the model already knows everything.
- **German learning portfolio:** Store your known vocabulary, grammar mistakes you repeatedly make, and topics you've covered. Each lesson session injects your learning history — no need to re-explain your level each time.
- **Family knowledge base:** Your family member's history interests, children's homework topics. Each family member has their own memory layer.
- **Code review context:** Load your entire WissensNest solution into chunks. Ask architectural questions and the model answers based on your actual code, not generic advice.

- **Meeting/decision log:** Store key decisions made in past conversations. Inject relevant ones when continuing a project. The model remembers why you made certain architecture choices.

## What to build and in what order

Given your project structure, here's the natural progression:

```text
Phase 1 — Foundation (implement now)
  SystemPromptTemplate table + UI selector
  Basic conversation persistence

Phase 2 — Memory (implement after persistence works)
  UserMemory table
  Memory extraction after conversations
  Memory injection into context

Phase 3 — RAG (implement when you have a real project to load)
  Document chunking
  SQLite FTS5 search
  Chunk injection into context

Phase 4 — Advanced (future)
  Vector embeddings for semantic search
  Conversation summarization
  Cross-conversation memory consolidation
```

Each phase builds on the previous one and is independently useful.

## Let's imagine that the students got additional questions to ask

_Now we can imagine a tool for editing the history to remove irrelevant parts and adjust the context to get more precise answers from the model._

_And we have more questions._

_Do some other parts of the structure of the context or conversations exist that we didn't discuss?_

_When we discussed with the model, it said it didn't know the current time. And we got an idea. Can we, in some level of context, maybe at the system prompt, define some keywords, and if the answer needs the current time value to make, the assistant ask me some GET_CURRENT_TIME, and my service responds with the time, and the assistant builds an answer, for instance, about how many days remain until the Chinese New Year. And it can be about not only time but also temperature, light, wind, and other measured values. Can it be like this, or should I put the full set of possible parameters in the same metadata header-like structure for every request?_

The teacher answered: _Your instinct is exactly right — and you've independently invented one of the most important concepts in modern AI: tool calling._

### What you described is a tool calling

Instead of keywords the model asks for, the modern approach is structured — you tell the model upfront what "tools" it has available, and it decides when to call them. The flow is:

```text
You → model: "How many days until Chinese New Year?"
              + Here are tools you can use: [GetCurrentTime, GetWeather, ...]

Model → you: I need the current time first.
             { "tool": "GetCurrentTime" }

You → model: Here is the result: 2025-04-11T09:23:00

Model → you: "Chinese New Year 2026 is on January 29th.
              That's 293 days from today."
```

The model doesn't guess — it explicitly requests a tool call, your service executes it, injects the result, and the model continues. This is exactly what you imagined.

### Does Ollama support tool calling?

Yes — and OllamaSharp already supports it. Both Phi-4 and Qwen 2.5 support tool calling natively.

```csharp
// In WissensNest.Contracts/Interfaces/ITool.cs
public interface ITool
{
    string Name { get; }
    string Description { get; }
    Task<string> ExecuteAsync(string parametersJson);
}
```

Tools you could implement immediately:

```csharp
// WissensNest.Core/Tools/CurrentTimeTool.cs
public sealed class CurrentTimeTool: ITool
{
    public string Name => "get_current_time";
    public string Description => 
        "Returns the current date and time. " +
        "Use when the user asks about time, dates, " +
        "days remaining, schedules, or anything time-dependent."

    public Task<string> ExecuteAsync(string parametersJson) =>
        Task.FromResult(DateTimeOffset.Now.ToString("R"));
}
```

### Other tools that make natural sense for your project

```text
GetCurrentTime      → date, time, timezone
GetWeather          → temperature, conditions (calls a weather API)
SearchWeb           → your IWebSearchTool — already planned!
ReadUrl             → fetch and return page content
GetSystemInfo       → RAM available, disk space, Ollama status
QueryLocalDatabase  → search your conversation history or notes
GetCalendarEvents   → upcoming reminders from your scheduler
```

Notice that _IWebSearchTool_ you built is already a tool — it just isn't wired as a formal tool call yet. The tool calling architecture gives it a proper home.

## Parts of context we haven't discussed yet

Since you asked — yes, there are a few more structural elements worth knowing:

- **Tool definitions** — injected into the context as a structured schema describing available tools, their parameters, and return types. The model reads this and decides when to invoke them.
- **Tool results** — when a tool is called, the result is injected back as a special tool role message in the conversation history. The model sees it as part of the conversation.
- **Assistant prefill** — you can start the model's response for it. Useful for enforcing output format: "Respond only with JSON: {" — the model continues from where you left it.
- **Conversation roles** — beyond _user_, _assistant_, _system_ there is also _tool_ for tool results. Your _ChatMessage_ record will need to support this role when you implement tool calling.
- **Temperature and sampling parameters** — not context exactly, but they shape how the model uses it. Low temperature = more deterministic, better for structured tasks like translation format. High temperature = more creative, better for open conversation. Worth exposing per system prompt template.
- **Stop sequences** — tokens that tell the model to stop generating. Useful for enforcing strict response formats — if the model should never write more than one paragraph, you can stop it after the first \n\n.

## Two approaches to injecting dynamic values

You asked whether to use keyword placeholders or a metadata header. Both are valid — here's when to use each:

- **Tool calling** — for values the model needs to decide to fetch based on the question. Current time, weather, search results. The model requests them on demand.

- **Metadata header** — for values that are always relevant regardless of the question. Inject them unconditionally at the top of every request:

```text
[Context metadata]
Current time: Friday, April 11 2025, 09:23 CET
User location: Karlsruhe, Germany
Active project: Clock build (STM32H7)
Season: Spring
```

This is cheap — a few tokens — and means the model always knows basic environmental facts without needing to ask.

**My recommendation: both.** Use the metadata header for cheap, always-relevant facts. Use a tool calling for expensive or conditional lookups like web search, database queries, or sensor readings.

## How this fits your architecture

```text
WissensNest.Contracts
  └── ITool interface

WissensNest.Core
  ├── Tools/CurrentTimeTool.cs
  ├── Tools/GetWeatherTool.cs
  ├── ToolOrchestrator.cs  ← decides when to call tools, injects results
  └── ChatService.cs       ← updated to use ToolOrchestrator

WissensNest.Tools.WebSearch
  └── WebSearchTool: ITool  ← already planned, now fits formally
```

_ToolOrchestrator_ becomes a new Core component sitting between _ChatService_ and _ILanguageModelClient_ — it handles the tool call loop:

```text
Send message → model responds with tool request
→ orchestrator executes the tool
→ injects result into conversation
→ sends again → model gives final answer
→ stream final answer to UI
```

This loop can repeat multiple times — the model might call GetCurrentTime, then GetWeather, then compose the final answer.

## The history editing idea

Your idea about editing conversation history to remove irrelevant parts is excellent and connects directly to context management. It's called context curation, and it's genuinely useful — a simple UI where you can:

- Delete irrelevant exchanges
- Edit a long assistant response to keep only the useful part
- Mark certain exchanges as "always keep" even when summarizing
- Star important facts to promote them to long-term memory

This is something no off-the-shelf tool provides — but your architecture supports it naturally, since you own the history store in its entirety.
