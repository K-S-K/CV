# WissensNest — Documentation

## Published (in-app encyclopedia)

See [Doc/Pub/](./Pub/index.md) for the user guide and architecture reference that is also served
as the in-app help system.

| Section | Contents |
| --- | --- |
| [User Guide](./Pub/User/) | Getting started, chat, articles, tools, prompts, quick reference |
| [Architecture](./Pub/Architecture/) | System overview, data model, tool framework, streaming, Knowledge Workbench design, voice roadmap |

## Developer notes (internal)

`Doc/Dev/` contains implementation diaries, architecture decision records, and design explorations
written during development. They are not served in the app and are intended for the developer only.

| File | Topic |
| --- | --- |
| [00_Prerequisites](./Dev/00_Prerequisites.md) | Ollama install and configuration |
| [01_Architecture](./Dev/01_Architecture.md) | Early top-level architecture notes |
| [02_Assemblies](./Dev/02_Assemblies.md) | Assembly purposes and dependency diagram |
| [03_ChatService](./Dev/03_ChatService.md) | Chat implementation notes |
| [04_Concepts](./Dev/04_Concepts.md) | AI assistant concepts |
| [05–10 Persistence](./Dev/05_Persistence.md) | Persistence design, entities, interfaces, serialization, reading to UI |
| [11_SidebarUI](./Dev/11_SidebarUI.md) | Sidebar implementation notes |
| [12–15 Context / Prompts](./Dev/12_ProjectContext.md) | Project context, conversation mode, prompt collections |
| [13_MessageEditing](./Dev/13_MessageEditing.md) | Message editing and stale-message flow |
| [16_Tools](./Dev/16_Tools.md) | Tool framework implementation |
| [17_RagAndAdr](./Dev/17_RagAndAdr.md) | RAG concepts and ADRs |
| [18_StreamingService](./Dev/18_StreamingService.md) | StreamingService decoupling from Blazor lifecycle |
| [19_WebSearch](./Dev/19_WebSearch.md) | DuckDuckGo HTML scraping implementation |
| [20_FamilyAccess](./Dev/20_FamilyAccess.md) | LAN sharing |
| [21_SystemMetrics](./Dev/21_SystemMetrics.md) | MemoryGauge and ribbon metrics |
| [22_Voice](./Dev/22_Voice.md) | Voice interface design |
| [23_KnowledgeWorkbench](./Dev/23_KnowledgeWorkbench.md) | Knowledge Workbench full design |
| [24_FetchPage](./Dev/24_FetchPage.md) | FetchPage tool implementation |
| [25_LibrarianTool](./Dev/25_LibrarianTool.md) | Library tools implementation |
| [99_Useful_Hints](./Dev/99_Useful_Hints.md) | Developer hints and gotchas |
