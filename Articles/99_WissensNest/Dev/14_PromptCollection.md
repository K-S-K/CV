# My AI

## Prompt Collection

Here's a summary of everything implemented:

### New files

- [PromptCollectionInfo.cs](../../Src/Libraries/WissensNest.Contracts/Models/PromptCollectionInfo.cs) — DTO record
- [PromptCollections.razor](../../Src/Services/WissensNest.UI/Components/Pages/PromptCollections.razor) — full CRUD page at /prompt-collections

### Modified files

- [IMyAiClient.cs](../../Src/Libraries/WissensNest.Contracts/Interfaces/IMyAiClient.cs) — 4 new methods
- [MyAiClient.cs](../../Src/Libraries/WissensNest.Client/MyAiClient.cs) — 4 implementations
- [Program.cs](../../Src/Services/WissensNest.API/Program.cs) — 4 endpoints + 2 request DTOs
- [NavMenu.razor](../../Src/Services/WissensNest.UI/Components/Layout/NavMenu.razor) — "Prompts" nav link
- [app.css](../../Src/Services/WissensNest.UI/wwwroot/app.css) — .pc-* styles for the page

**The page supports:** list with expand-to-preview, inline create form, inline edit form, delete with confirmation, and reuses existing .sidebar-confirm / .sidebar-icon-btn styles for consistency.
