# WissensNest

## Help System — Anchors and In-Article Navigation

### Overview

The help system supports deep links into specific headings inside any article.
A URL like `/help/User/02_Chat#sending-a-message` opens the Chat article and scrolls
directly to the "Sending a message" section. This page explains how the three pieces
that make this work fit together.

---

### Piece 1 — Heading IDs (`UseAutoIdentifiers`)

`MarkdownContent.razor` uses Markdig to render all markdown in the app.
The pipeline has `.UseAutoIdentifiers()` enabled:

```csharp
private static readonly MarkdownPipeline Pipeline =
    new MarkdownPipelineBuilder()
        .UsePipeTables()
        .UseEmphasisExtras()
        .UseTaskLists()
        .UseAutoIdentifiers()   // ← generates id= on headings
        .Build();
```

`UseAutoIdentifiers` converts every heading into an HTML element with a slug `id`:

| Markdown | Generated HTML |
| --- | --- |
| `## Sending a message` | `<h2 id="sending-a-message">Sending a message</h2>` |
| `### The Tool Activation Bar` | `<h3 id="the-tool-activation-bar">The Tool Activation Bar</h3>` |
| `## Overview` | `<h2 id="overview">Overview</h2>` |

The slug rule: lowercase, spaces → hyphens, punctuation stripped.
Duplicate headings get a numeric suffix (`overview`, `overview-1`, `overview-2`).

`UseAutoIdentifiers` is applied globally — it affects chat bubbles, article blocks, and the
help viewer. Adding `id=` attributes to headings is harmless in all those contexts.

---

### Piece 2 — Fragment Capture (`Help.razor`)

After loading an article, `Help.razor` reads the URL fragment from `NavigationManager.Uri`:

```csharp
var fragment = new Uri(Nav.Uri).Fragment;
_pendingAnchor = fragment.Length > 1 ? fragment[1..] : null; // strip leading #
```

The fragment is stored as `_pendingAnchor` rather than immediately calling JS, because the
DOM is not yet updated at this point — the markdown content has been assigned to `_content`
but `MarkdownContent` has not yet re-rendered.

---

### Piece 3 — Scroll after Render (`OnAfterRenderAsync` + JS)

`OnAfterRenderAsync` fires after every render cycle, once the DOM reflects the latest state:

```csharp
protected override async Task OnAfterRenderAsync(bool firstRender)
{
    if (_pendingAnchor is not null)
    {
        await JS.InvokeVoidAsync("scrollToAnchor", _pendingAnchor);
        _pendingAnchor = null;
    }
}
```

`scrollToAnchor` in `interop.js`:

```javascript
window.scrollToAnchor = (id) => {
    const el = document.getElementById(id);
    if (el) el.scrollIntoView({ behavior: 'smooth', block: 'start' });
};
```

`_pendingAnchor` is cleared immediately after the call so subsequent renders (triggered
by unrelated state changes) do not re-scroll.

---

### How to Link to a Specific Heading

To create a deep link to a heading inside a help article:

1. Find the heading text in the markdown file, e.g. `## Sending a message`
2. Convert it to a slug: lowercase, spaces → hyphens → `sending-a-message`
3. Build the URL: `/help/User/02_Chat#sending-a-message`

This URL can be used:
- In the browser address bar directly
- As `href` in a `<HelpLink>` component (Stage 4A)
- In `context-map.json` to map a UI element to a specific help section (Stage 4A)

---

### Explicit Anchor IDs in Markdown (Stage 4A)

Auto-generated IDs depend on heading text — if the heading is renamed, all links to it
break silently. Stage 4A will introduce **explicit anchor IDs** using the Markdig
`GenericAttributes` extension:

```markdown
## Sending a message {#chat-send}
```

This generates `<h2 id="chat-send">Sending a message</h2>`. The explicit ID is stable
across heading renames. The `context-map.json` file (Stage 4A) will map UI context tokens
to these stable IDs:

```json
{
  "chat.send":    { "article": "User/02_Chat",  "anchor": "chat-send" },
  "tools.toggle": { "article": "User/04_Tools", "anchor": "tool-activation-bar" }
}
```

Until Stage 4A is implemented, auto-generated IDs from `UseAutoIdentifiers` work correctly
— they are just more fragile in the face of heading renames.
