# WissensNest — Using Tools

## Overview

Tools extend what the AI can do beyond generating text from its training data. With tools enabled, the model can search the web, read web pages and PDF documents, check the weather, look up geographic coordinates, and read from a local document library — all within a single conversation turn, without any manual steps from the user.

This article covers how to activate tools, how to follow what the model is doing with them, and how to get the most out of the library.

---

## The Tool Activation Bar {#tool-activation-bar}

When at least one tool is registered in the system, a row of icon buttons appears **above the chat input box**.

Each button represents one tool:

- **Hover** over a button to see the tool's name and a short description in a tooltip.
- **Click** a button to toggle the tool on or off.
- An active tool shows a **highlighted (purple) border** around its icon.
- An inactive tool has no border.

Only active tools are visible to the model for the current message. The model decides independently whether to call any of them — you do not direct it to use a specific tool; you simply make tools available.

Tools that are active when you send a message stay active for subsequent messages in the same conversation. Toggle them off at any point to prevent the model from using them.

---

## Available Tools {#available-tools}

| Icon | Name | What it does |
| --- | --- | --- |
| 🔍 bookshelf | `library_search` | Searches the local document library for datasheets, manuals, and reference PDFs |
| ↓ bookshelf | `library_read` | Reads pages from a PDF stored in the local library |
| ✎ bookshelf | `library_describe` | Writes a description file for a newly added library document |
| 🌐 | `web_search` | Searches the web via DuckDuckGo; returns titles, URLs, and snippets |
| 📄 | `fetch_page` | Fetches and reads the full text of a URL (HTML or PDF) |
| 🕐 | `get_current_time` | Returns the current time in any timezone |
| ☁ | `get_weather` | Returns current weather for a location |
| 📍 | `geocode` | Resolves a place name to coordinates |

**Priority order for documents:** the model is instructed to call `library_search` before `web_search`. If the document is not in the library, it falls back to the web. See [the library workflow](#library-workflow) below.

---

## Tool Activity Log {#tool-activity-log}

While the model is using tools, a **collapsible activity panel** appears inside the assistant's response bubble.

The panel shows each tool call in order:

```text
▸ library_search  "STM32G031K8 datasheet"           12 ms
▸ library_read    "Datasheets/stm32g031k8.pdf" p.65  84 ms
```

Each row shows the tool name, the key argument it was called with, and how long it took. Click **▸** to expand a row and see the full input and output of that call.

After the response is complete, you can toggle the activity log on and off using the **👁** button in the assistant bubble's toolbar.

The activity log is saved to the database alongside the response. If you close the browser and return later, or navigate to a different conversation and back, the same tool activity panel appears — exactly as it looked during the original response.

---

## The Library Workflow {#library-workflow}

The local library is a directory on disk where you store PDF documents (datasheets, manuals, papers). The model searches this library first before going to the web.

### Dropping a document into the library

1. Place the PDF file anywhere inside the configured library directory:

```text
/Users/ksk-work/Projects/AI/WissensNest/Library/
```

You can organize it into sub-folders however you like — the tools scan recursively.

1. That's it. The model will find the file by filename on the next `library_search` call.

### Describing a new document

A plain PDF with no description file can be found by filename, but the model cannot navigate it efficiently without knowing which pages cover which topics. To add a description:

Tell the model:

> *"I added `stm32g031k8.pdf` to the library. Please read the first pages and add a description."*

The model will:

1. Call `library_read("stm32g031k8.pdf", pages="1-5")` to see the cover and table of contents.
2. Call `library_describe(...)` to write a `.md` description file alongside the PDF.

After this, `library_search` finds the document by topic (not just filename) and the model can jump directly to the right pages.

### Example description file

The model writes a file like this at `Library/Datasheets/stm32g031k8.md`:

```markdown
---
title: STM32G031K8 Datasheet
source: https://www.st.com/resource/en/datasheet/stm32g031k8.pdf
added: 2026-05-01
tags: stm32, cortex-m0+, microcontroller, embedded, ADC, USART
---

STMicroelectronics STM32G031K8. 32-bit ARM Cortex-M0+, 64 KB Flash, 8 KB SRAM.
Key sections: pinout (p.38), power consumption tables (p.65), ADC (p.155).
```

You can edit this file manually at any time — page references in the description body let the model skip the table of contents and go straight to the relevant chapter.

### What happens when a document is not in the library

If `library_search` finds nothing, the model falls back to the web:

1. `web_search` — finds a URL.
2. `fetch_page` — attempts to download and read the document.
3. If the download is blocked (some sites, including ST.com, block automated access), the model tells you the URL and asks you to download it manually.

After you place the file in the library and say *"Done"*, the model describes it and answers your question — all in the same conversation.

---

## Tips for Effective Tool Use

**Enable only the tools you need.** The model sees all active tools in every request. A long list of tools increases the chance of an unnecessary tool call. For a focused coding session, disable web search entirely.

**Write good descriptions when you add documents.** A description body that says *"power consumption tables (p.65)"* saves one round-trip through the table of contents every time you ask about power. The model uses the description body to decide which pages to read first.

**Ask about specific pages when you know them.** If you know the information is on page 47, say so: *"What does page 47 of the LPC1769 datasheet say about the ADC?"* The model will call `library_read` with `pages="47-52"` directly.

**Let the model describe undescribed files proactively.** If you see the tool activity log show `library_search` reporting an undescribed file during an unrelated query, you can say *"Please describe that undescribed file while you're at it."*

**You can edit `.md` descriptor files manually.** They are plain text with simple YAML frontmatter. If the model's auto-generated description missed something important (a key page number, a missing tag), open the file in any text editor and add it.
