# WissensNest — Quick Reference

## Keyboard Shortcuts

| Context | Key | Action |
| --- | --- | --- |
| Chat input | **Enter** | Send message |
| Chat input | **Shift+Enter** | Insert line break without sending |
| Message edit mode | **Ctrl+Enter** | Save edit |
| Message edit mode | **Escape** | Cancel edit, discard changes |
| Block edit mode | **Ctrl+Enter** | Save block |
| Block edit mode | **Escape** | Cancel, discard changes (if link picker is open, closes picker only) |
| Block edit mode — link picker open | **Escape** | Close the `[[` link picker without cancelling edit |
| Block edit mode → Split | click **Split here** | Split block at cursor position |
| Prompt editor edit mode | **Ctrl+Enter** | Save prompt content |
| Prompt editor edit mode | **Escape** | Cancel |
| Prompt editor title | **Enter** | Save renamed title |
| Profile description edit | **Ctrl+Enter** | Save description |
| Profile description edit | **Escape** | Cancel |
| Inline rename (sidebar) | **Enter** | Confirm rename |
| Inline rename (sidebar) | **Escape** | Cancel rename |
| New item form (sidebar) | **Enter** | Confirm creation |
| New item form (sidebar) | **Escape** | Cancel |

---

## Sidebar — Action Buttons by Entity

Buttons appear on hover.

### Projects tab (⊞)

**Project row:**

| Button | Action |
| --- | --- |
| ⊞ | Set or clear the project's default prompt |
| ⇄ / → | Toggle context mode: multi-turn (⇄) or single-turn (→) |
| ✎ | Rename project inline |
| ✕ | Delete project (confirmation required) |
| + | New conversation in this project |

**Section row:**

| Button | Action |
| --- | --- |
| ✎ | Rename section inline |
| ✕ | Delete section and all its articles (confirmation required) |
| + | New article in this section |

**Article and Conversation rows:**

| Button | Action |
| --- | --- |
| ✎ | Rename inline |
| ✕ | Delete (confirmation required) |

### Prompts tab (✎)

**Category row:**

| Button | Action |
| --- | --- |
| ✎ | Rename category inline |
| ✕ | Delete category and all its prompts |
| + | New prompt in this category |

**Prompt row:**

| Button | Action |
| --- | --- |
| ✕ | Delete prompt (confirmation required) |

### Profiles tab (◈)

**Folder row:**

| Button | Action |
| --- | --- |
| ✎ | Rename folder inline |
| ✕ | Delete folder |
| + | New profile in this folder |

**Profile row:**

| Button | Action |
| --- | --- |
| ✕ | Delete profile (confirmation required) |

---

## Message Bubble Toolbar

Appears on hover. Different buttons for user vs. assistant messages.

### User messages

| Button | Action |
| --- | --- |
| ✎ | Edit message content; marks all subsequent messages stale |
| 🚫 | Ignore — greys out bubble, excludes from model context |
| ✓ | Restore ignored message |
| → Block | Open article picker and promote message to a block |
| **Link** | Copy a Markdown link to this message to the clipboard |

### Assistant messages

| Button | Action |
| --- | --- |
| **Raw** / **Md** | Toggle between raw text and rendered Markdown |
| 👁 | Show / hide the tool activity log |
| 🚫 | Ignore — greys out bubble, excludes from model context |
| ✓ | Restore ignored message |
| **Regenerate** | *(stale only)* Delete this message and all after it, then re-stream |

---

## Article Editor Header

Buttons in the article title bar.

| Button | Condition | Action |
| --- | --- | --- |
| ⊙ Editing | A block is in edit mode | Scroll the page to the block currently being edited |
| ✎ | Always | Rename article inline |
| **Export** | Always | Enter / exit export mode |
| **PDF (all)** | Export mode, no selection | Download PDF of all blocks |
| **PDF (n)** | Export mode, blocks selected | Download PDF of the *n* selected blocks |

## Block Toolbar

Appears on hover in the Article Editor.

| Button | Condition | Action |
| --- | --- | --- |
| ↑ | Not first block | Move block one position up |
| ↓ | Not last block | Move block one position down |
| ✎ | Always | Enter edit mode |
| ⊕ | Not last block | Merge with the block directly below |
| ⋯ | Always | Context menu: **Move to…** / **Copy to…** |
| → Chat | Always | Send block content to a new conversation as seed text |
| **Link** | Always | Copy a Markdown link to this block to the clipboard |
| ✕ | Always | Delete block (inline confirmation) |
| ☐ | Export mode only | Select / deselect block for PDF export |

### Block edit mode buttons (below the textarea)

| Button | Action |
| --- | --- |
| **Save** | Save content and return to preview — also Ctrl+Enter |
| **Split here** | Split block at cursor position |
| **Cancel** | Discard changes — also Escape |

---

## Ribbon Toolbar

| Group | Controls |
| --- | --- |
| **Metrics** | Memory gauge — click to cycle: Donut → Bars → Dashboard |
| **Navigation** | ⇈ top · ↑ up · ↓ down · ⇊ bottom · **← back** · **→ forward** · **Auto** toggle |
| **View** | **A+** larger font · **A−** smaller font · **AL** toggle activity log |
| **Tools** | One toggle per registered tool; highlighted border = active; disabled while streaming |

Click **▾** top-right to collapse the ribbon. Click **▴** to expand.

**← / →** navigate the in-app history stack (like a browser). Greyed out when the stack is empty.

---

## Context Mode

Set per-project via the **⇄ / →** button in the project header.

| Mode | Icon | Behaviour |
| --- | --- | --- |
| **Multi-turn** | ⇄ | Full conversation history sent with every message (default) |
| **Single-turn** | → | Only the current message sent; no history — useful for quick lookups |

---

## Prompt Layers

| Layer | Source | Scope |
| --- | --- | --- |
| **1 Global** | `Chat:SystemPrompt` in appsettings.json | Every conversation, always |
| **2 Project** | Default prompt set on the project (⊞ button) | All new conversations in this project |
| **3 Conversation** | Prompt selected before the first message ("Add context") | This conversation only |

Layers are joined with `---` separators. The combined result is stored as a snapshot
at conversation creation and never changes after that.

---

## Tool Icons Reference

| Icon | Tool name | What it does |
| --- | --- | --- |
| 🌐 | `web_search` | DuckDuckGo search — returns titles, URLs, and snippets |
| 📄 | `fetch_page` | Fetches and reads the full text of a URL (HTML or PDF) |
| 🔍 | `library_search` | Searches the local document library by keyword |
| 📖 | `library_read` | Reads pages from a local library PDF |
| ✎ | `library_describe` | Writes a description file for a new library document |
| 🕐 | `get_current_time` | Returns the current time in any timezone |
| ☁ | `get_weather` | Current weather for a location (via open-meteo) |
| 📍 | `geocode` | Resolves a place name to coordinates and timezone |

---

## Cross-References

| Method | Where | What you get |
| --- | --- | --- |
| Click **Link** on a block | Article Editor toolbar | Markdown link → `/article/{id}#block-{id}` |
| Click **Link** on a message | Chat bubble toolbar | Markdown link → `/chat?conversationId={id}&highlight={id}` |
| Type `[[` in a block | Block edit textarea | Floating search picker; click a result to insert the link |

**Link picker result types:**

| Icon | Kind | Searched by |
| --- | --- | --- |
| 📄 | Article | Title |
| 🧱 | Block | Content |
| 💬 | Message | Original text (non-ignored only) |

**Navigation after following a link:** use **← back** in the ribbon to return to where you were.

**On arrival via a link:** the target message or block is scrolled into view and pulsed with an amber highlight for 2.5 s.
