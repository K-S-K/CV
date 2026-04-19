# WissensNest — Professional Self-Presentation (EN)

---

## 1. Skills & Experience for a Resume

### Skills Section

- **.NET Application Architecture** — multi-layer solution following Clean Architecture principles: Contracts / Core / Infrastructure / UI with strict dependency boundaries (dependency inversion, no leaky abstractions)
- **ASP.NET Core Minimal API** — REST API design and implementation: routing, response streaming (`IAsyncEnumerable`), middleware, DI container
- **Blazor Server** — interactive web UI: component model, circuit-scoped state, server-side rendering, real-time token streaming via SignalR
- **Entity Framework Core + SQLite** — Code-First migrations, soft-delete, separation of domain entities from EF entities (DBEntity ↔ Domain), SQLite limitation workarounds (DateTimeOffset)
- **LLM Integration** — Ollama API via OllamaSharp, conversation history management, multi-layer system prompt composition (global / project / conversation)
- **Tool / Function Calling** — ITool abstraction, DI-based tool registration, Ollama function-calling protocol, streaming discriminated union (TextToken / ToolCallRequest / ToolResult / Completion / Error); implemented tools: GetCurrentTime, GetWeather (open-meteo.com), Geocoding
- **Domain Model Design** — Projects, Conversations, Messages, PromptCollections; soft delete, message editing, response regeneration, context modes (MultiTurn / SingleTurn)
- **Testing** — unit tests (xUnit), test-driven development for Markdown response formatter
- **AI-Assisted Development** — production use of Claude Code (Anthropic) as a primary pair-programmer: architecture review, multi-file refactoring, migration generation, continuous codebase documentation via CLAUDE.md
- **Local DevOps** — deployment scripts, configuration management via `appsettings.json`

### Experience Section (project entry)

**WissensNest — Personal AI Assistant (Ollama + .NET 10)** *(2025 — present)*

Built a locally-deployed AI assistant from scratch, operating entirely in an air-gapped environment with no data leaving the machine. Stack: ASP.NET Core Minimal API + Blazor Server, OllamaSharp (qwen2.5:14b, phi4), EF Core + SQLite.

Key architectural decisions and implemented features:

- Three-layer prompt system (global → project → conversation) with prompt snapshot persisted in the database
- Full message history editing cycle: edit messages, mark downstream responses stale, regenerate
- Tool/function-calling framework: ITool interface, DI-based registration, working tools — GetCurrentTime, GetWeather (open-meteo.com), Geocoding; model selects and invokes tools automatically
- SingleTurn mode for projects requiring independent, context-free requests (expert systems, translators)
- Strict EF-layer isolation from domain model; enforced assembly dependency rules
- Developed with Claude Code as a primary AI pair-programmer throughout the entire project lifecycle

---

## 2. Portfolio Description

### What Is WissensNest

WissensNest is a personal AI assistant that runs entirely locally on a standard computer (MacBook Pro M3, 36 GB RAM). No cloud, no subscriptions, no data leakage. All conversation history is stored in a local SQLite database; models run through Ollama.

The interface is a web app accessible in any browser. Projects separate contexts: each project has its own system instruction (prompt) and its own conversation history.

The GitHub repository is currently named MyAI and will be renamed to WissensNest.

---

### Use Cases

#### Use Case 1 — Reading Literature in a Foreign Language

You are reading a book in German (or any other language). You encounter an unfamiliar phrase or a complex sentence. Paste the excerpt into the chat — the assistant:

- builds a mini-glossary of unknown words with translations and usage examples
- explains the grammatical constructions used (Konjunktiv II, Passiv, Modalpartikeln, etc.)
- provides a translation preserving the original style if needed

The entire breakdown is saved in the local database under the relevant project — you can return and review the material at any time.

> **Suggested visuals:**
>
> - Screenshot: chat showing a German sentence breakdown (vocabulary + grammar)
> - Screenshot: conversation list under a "German" project

---

#### Use Case 2 — General-Purpose Local Knowledge Base

Unlike ChatGPT or Google, WissensNest:

- requires no internet and sends nothing to external servers
- stores all history locally, browsable by project and conversation
- responds in a configured format: Markdown tables, lists, code blocks — rendered and readable
- retains context: multi-turn dialogue allows you to refine and rephrase

Example uses: history and biology questions for schoolchildren, recipe scaling, help drafting letters and documents.

> **Suggested visuals:**
>
> - Screenshot: a history answer rendered as a Markdown table
> - Screenshot: sidebar with projects and conversation list

---

#### Use Case 3 — Assistant That Reaches Into the Real World

A language model knows only what it was trained on. WissensNest goes further — it calls real external services automatically when a question requires live data.

Ask *"What's the weather like in Munich right now?"* — the assistant:

1. Calls **GeocodingTool** → resolves "Munich" to coordinates (lat/lon/timezone)
2. Calls **GetWeatherTool** → fetches current temperature, wind, and precipitation from open-meteo.com
3. Answers in natural language with the live data embedded

Ask *"What time is it in Tokyo?"* — **GetCurrentTimeTool** is called immediately.

The model decides when a tool is needed and invokes it silently. There is no *"Should I check the weather for you?"* — it just does it. The tool result flows back into the response as naturally as if the model always had that information.

From an architecture perspective: adding a new tool requires only implementing the `ITool` interface and registering it in DI. The ChatService, streaming layer, and UI pick it up with zero additional changes.

> **Suggested visuals:**
>
> - Screenshot: a weather query with the tool call activity visible in the response stream
> - Diagram: query → GeocodingTool → GetWeatherTool → answer

---

#### Use Case 4 — Specialized Expert System for Engineers

For technical work (electronics design, firmware architecture, component selection), a dedicated project is created with a detailed system prompt: domain, standards in use, expected answer format, preferred reasoning style.

SingleTurn mode lets you use the assistant as an on-demand independent advisor — without accumulated context between sessions, which matters when iterating over design alternatives.

The assistant helps to:

- evaluate and compare technical solutions (MCU selection, power supply topology, communication interfaces)
- draft sections of technical documentation and requirements specifications
- identify and articulate risks in a proposed design

> **Suggested visuals:**
>
> - Screenshot: project prompt configuration for "Electronics"
> - Screenshot: dialogue with a comparative MCU analysis rendered as a Markdown table
> - Diagram: three-layer prompt architecture (Layer 1 → Layer 2 → Layer 3)

---

### Architecture (for a technical audience)

```text
Browser (Blazor Server)
    │  HTTP / SSE stream
    ▼
ASP.NET Core Minimal API
    │
    ├─ ChatService          ← business logic, system prompt assembly
    ├─ ConversationService  ← history management
    │
    ├─ Tools                ← GetCurrentTime · GetWeather · Geocoding · (WebSearch — planned)
    │      ITool — DI-registered, zero-change extensibility
    │
    ├─ OllamaSharp          ← token streaming from local model
    └─ EF Core + SQLite     ← full history persistence
```

Strict layer separation: no EF types escape the Persistent assembly; no UI dependency on infrastructure.

> **Suggested visuals:**
>
> - Assembly dependency diagram (from CLAUDE.md)
> - ER diagram (Projects → Conversations → Messages, PromptCollections)

---

## 3. Claude Code — AI-Assisted Development Experience

### Developing WissensNest with Claude Code

WissensNest was built in close collaboration with **Claude Code** (Anthropic's CLI AI assistant), used as a primary pair-programmer from initial architecture through feature implementation and refactoring.

### How it was used in practice

- **Architecture design** — discussing layer boundaries, EF tracking patterns, SQLite workarounds, tool-calling protocol — getting concrete, project-aware recommendations rather than generic advice
- **Multi-file refactoring** — renaming interfaces, propagating DTO changes, adjusting DI wiring across assemblies in a single coherent session
- **Migration and schema work** — generating EF Core migrations with proper Designer.cs scaffolding, validating schema evolution against live data
- **CLAUDE.md as a living contract** — a `CLAUDE.md` file at the project root documents architecture decisions, dependency rules, naming conventions, and known SQLite pitfalls; Claude Code reads it at session start and applies all context automatically, making every session immediately productive
- **Debugging** — tracking down EF ChangeTracker conflicts, Blazor rendermode silent failures, DateTimeOffset LINQ translation errors

### The effective working pattern at this level

The most productive approach is treating Claude Code as a context-aware collaborator rather than a code generator. Feed it architecture constraints upfront via CLAUDE.md. Describe *what you want to achieve*, not *how to implement it*. Let it reason about the correct approach across multiple files simultaneously. The persistent memory system means established preferences — code style, testing approach, naming conventions — carry over without repeating them.

A well-maintained CLAUDE.md, combined with session memory and explicit architecture documentation, turns Claude Code from a smart autocomplete into a genuine architectural sounding board for a solo developer.

---

## 4. LinkedIn / Facebook Post

---

### I Built a Personal AI Assistant from Scratch — Here's What I Got Out of It

Over the past several months I've been working on a project that serves two purposes at once: a practical everyday tool and a deliberate exercise in modern .NET architecture.

**WissensNest** is a locally-hosted AI assistant built on ASP.NET Core + Blazor Server, running open-weight models through Ollama (phi4, qwen2.5:14b). No cloud. All conversation history lives in a local SQLite database on my machine.

---

**Why not just use ChatGPT?**

Because I want:

- complete data ownership (my family uses this for learning and work)
- fine-grained control over model behavior per use case
- persistent history that won't disappear when a pricing tier changes
- a real understanding of how these systems work under the hood

---

**What the system can do today:**

✦ Projects with their own system prompts — German language, history, electronics, cooking each live in a separate context  
✦ Three-layer prompt composition: global → project → individual conversation  
✦ History editing: correct a user message, stale model responses are flagged and can be regenerated  
✦ SingleTurn mode — for tasks that need a fresh perspective with no memory of prior exchanges  
✦ **Real-world tool calling** — ask about the weather and the assistant silently calls a geocoding API, then a weather API, then answers with live data. No asking permission, no announcing intentions — it just does it  
✦ Clean Markdown rendering: tables, lists, code — readable right in the browser  

---

**What I gained as a developer:**

Working on this project I deliberately studied and applied:

- Clean Architecture on a real, non-tutorial project
- Blazor Server with live streaming data
- Proper separation of the EF persistence layer from the domain model
- Tool/function-calling protocol: ITool interface, streaming discriminated union, DI-based zero-friction extensibility
- API design where you are also the primary user
- **AI-assisted development with Claude Code** — maintaining a live CLAUDE.md contract, persistent cross-session memory, multi-file refactoring with full architectural context

That changes the motivation level entirely compared to abstract pet projects.

---

**What's next:**

- Web search tool (SearXNG / DuckDuckGo)
- LocalFileAccess tool — read files from a configured path
- Persistent memory — user facts automatically injected into every conversation

---

If you're interested in local LLM deployment, .NET architecture for AI applications, AI-assisted development workflows, or just want to discuss the approach — drop a comment or send a message.

Code is open: [github.com/K-S-K/MyAI](https://github.com/K-S-K/MyAI)

\#dotnet \#blazor \#llm \#ollama \#AIassistant \#localdevelopment \#cleanarchitecture \#petproject \#selfhosted \#buildinpublic \#claudecode

---

> **Suggested visuals for the post:**
>
> 1. Hero screenshot — chat with a well-formatted Markdown response
> 2. Screenshot of a tool call in action: weather question → geocoding → live answer
> 3. Screenshot of the sidebar with several projects visible
> 4. Simplified architecture diagram — for the technical audience
