# My AI

## Persistence - Concepts

### 1. The requirements-related QA session

Q: What should the initial schema include?
A: Projects -> Conversations -> Messages + SystemPrompts

Q: How should deletion work for conversations?
A: Soft delete and hard delete for everything, also IgnoreFlag for messages and for conversations

Q: What audit fields should every entity have?
A: CreatedAt + UpdatedAt + soft delete timestamp

#### Recap 1

Excellent — a well-thought-out schema. The _IgnoreFlag_ is a particularly good idea — it maps directly to your context curation vision, where you can hide irrelevant messages from the model without destroying them.

Before I write anything, let me reflect the full schema back to you so we agree on it before touching code.

#### Proposed entity model

##### A few design decisions worth discussing before we proceed

**RawContent vs DisplayContent in the DB** — storing both is correct for your debugging needs, but _DisplayContent_ is derived from _RawContent_ via _IResponseFormatter_. This means that on schema changes or formatter improvements, you could regenerate _DisplayContent_ from _RawContent_. Worth keeping both as planned.

**IsDeleted + DeletedAt together** — _IsDeleted_ is a fast boolean for query filtering. _DeletedAt_ tells you when it was deleted, useful for auditing and for "undo" within a time window. Both are worth having.

**IsIgnored on both Conversation and Message** — clean separation: _IsIgnored_ controls context inclusion, _IsDeleted_ controls visibility. A message can be ignored (excluded from model context) without being deleted (still visible in UI history). This is exactly right.

**SystemPromptId on Conversation** — this captures which prompt was active when the conversation started, not just a foreign key to the current state of the template. Important for reproducibility — if you later edit the template, old conversations remember what prompt they used. Worth also storing a _SystemPromptSnapshot_ string on the conversation for the same reason.

##### Tables / Entities

**Project** — the top-level container. A clock project, a language learning project, a cooking project.

```text
Project
  Id               Guid
  Name             string
  Description      string?
  CreatedAt        DateTimeOffset
  UpdatedAt        DateTimeOffset
  DeletedAt        DateTimeOffset?   ← soft delete
  IsDeleted        bool
```

**SystemPromptTemplate** — named, reusable prompts. Belongs to a project or is global (ProjectId nullable).

```text
SystemPromptTemplate
  Id               Guid
  Name             string
  Description      string?
  Content          string
  ProjectId        Guid?             ← null = global
  CreatedAt        DateTimeOffset
  UpdatedAt        DateTimeOffset
  DeletedAt        DateTimeOffset?
  IsDeleted        bool
```

**Conversation** — a chat session within a project.

```text
Conversation
  Id               Guid
  Title            string
  ProjectId        Guid              ← required
  SystemPromptId   Guid?             ← which prompt was active
  IsIgnored        bool              ← hide from context without deleting
  CreatedAt        DateTimeOffset
  UpdatedAt        DateTimeOffset
  DeletedAt        DateTimeOffset?
  IsDeleted        bool
```

**Message** — a single turn within a conversation.

```text
Message
  Id               Guid
  ConversationId   Guid
  Role             string            ← "user" | "assistant" | "system" | "tool"
  RawContent       string            ← exactly what model returned
  DisplayContent   string            ← after normalization
  IsIgnored        bool              ← exclude from context without deleting
  CreatedAt        DateTimeOffset
  UpdatedAt        DateTimeOffset
  DeletedAt        DateTimeOffset?
  IsDeleted        bool
```

### 2. The second QA session

Q: What should the initial schema include?
A: Projects -> Conversations -> Messages{original; modified} + System Prompts

Q: How should deletion work for conversations?
A: Disabling (soft delete) and also Hard Delete for messages, and also Hard Delete for others

Q: What audit fields should every entity have?
A: CreatedAt + UpdatedAt + soft delete timestamp

Q (user): Is it a good idea to make SystemPrompt buildable from several parts, reusable in different projects, and linkable in many-to-many table PromptReferences (PromptPartId, PromptCollectionId), and optionally link PromptCollections to Projects (1-1)?

Q (user): Is it a good idea to have the field not Message.DisplayContent, but Message.NormalizedContent? And, content for display can be formatted in the client for both versions, but not stored in the DB?

#### Recap 2

Both of your additional questions show excellent database design instincts. Let me answer them honestly.

#### On composable system prompts

Yes — this is a genuinely good idea and maps to real patterns used in production AI systems. The mental model is:

```text
PromptPart        — a reusable fragment: "Always respond in Markdown"
PromptCollection  — an ordered set of parts assembled into a full prompt
Project           — optionally linked to one default PromptCollection
Conversation      — linked to the PromptCollection active at start time
                    + snapshot of the assembled text for reproducibility
```

The many-to-many _PromptPartReference_ table would carry an _Order_ field, so parts assemble in a defined sequence.

**Honest caution though:** this is significantly more complex to implement, and the UI to manage it needs careful design. For the initial schema, I'd suggest a simpler stepping stone — store _SystemPrompt_ as a flat string on _PromptCollection_, get the full pipeline working end to end, then refactor into composable parts in a second migration once you understand your actual usage patterns. Premature composition adds schema complexity before you know which parts you'll actually reuse.

So: **good idea, right time is after the first working version.**

#### On NormalizedContent vs DisplayContent

This is the better name and the better design. You're right on both counts:

_DisplayContent_ implies presentation — it belongs in the client, not the database. The database should store facts, not rendering artifacts. _NormalizedContent_ describes what it actually is: the model output after structural normalization (line endings, table structure, blank lines). That's a stable, meaningful transformation worth persisting.

Rendering to HTML is a client-side concern that _MarkdownContent.razor_ already handles. The database never needs to know about HTML.

### Revised entity model

```text
Project
  Id                    Guid
  Name                  string
  Description           string?
  DefaultPromptId       Guid?         ← optional link to PromptCollection
  CreatedAt             DateTimeOffset
  UpdatedAt             DateTimeOffset
  DeletedAt             DateTimeOffset?
  IsDeleted             bool

PromptCollection
  Id                    Guid
  Name                  string
  Description           string?
  Content               string        ← flat for now, composable later
  CreatedAt             DateTimeOffset
  UpdatedAt             DateTimeOffset
  DeletedAt             DateTimeOffset?
  IsDeleted             bool

Conversation
  Id                    Guid
  Title                 string
  ProjectId             Guid
  PromptCollectionId    Guid?
  PromptSnapshot        string?       ← assembled prompt text at start time
  IsIgnored             bool
  CreatedAt             DateTimeOffset
  UpdatedAt             DateTimeOffset
  DeletedAt             DateTimeOffset?
  IsDeleted             bool

Message
  Id                    Guid
  ConversationId        Guid
  Role                  string
  OriginalContent       string        ← raw model output, never modified
  NormalizedContent     string        ← after IResponseFormatter
  IsIgnored             bool
  CreatedAt             DateTimeOffset
  UpdatedAt             DateTimeOffset
  DeletedAt             DateTimeOffset?
  IsDeleted             bool
```

#### On hard delete

Hard delete is destructive and irreversible — in a system where you're building context and history, I'd suggest reserving it for explicit "purge" operations rather than routine delete. The pattern I'd recommend:

```text
Soft delete   → IsDeleted = true, DeletedAt = now   (reversible, UI hides it)
Hard delete   → actual DELETE FROM — admin/purge operation only
```

Expose hard delete in the UI as a separate "Purge" action, distinct from the normal delete, perhaps with a confirmation. This protects against accidental data loss while still giving you the ability to truly remove data when needed.

### Before we write code — one more decision

For the _PromptCollection.Content_ field — since we're keeping it flat for now, should it be:

- A simple _string_ — the full assembled prompt text
- Or a _string_ with a defined internal format (e.g., sections separated by ---) that prepares for future composability without changing the schema

The second option costs nothing now and makes the later refactor to composable parts much easier. Worth thinking about before the first migration.

Ready to start building once you confirm the schema?
