# WissensNest — Using the Help System

## Overview

The built-in help system is accessible from the **?** button in the ribbon toolbar (top-right
corner, next to the collapse toggle). It opens the help page at `/help`.

The page has two areas:

- **Left sidebar** — table of contents, search input, and search results.
- **Right panel** — the selected article, or an AI-generated answer to your question.

---

## Keyword Search {#keyword-search}

Type any word or phrase in the search box at the top of the sidebar.

Results appear immediately as you type — no button press needed.

**What is searched:**

- Article titles (matched first, shown as "— article title")
- The full text of every article, line by line

**Reading the results:**

Each result shows the article name and a short excerpt from the first matching line.
Click any result to open that article. The search is cleared automatically when you
click a TOC link — the full article list reappears.

Click **✕** next to the search box to clear the query at any time.

**Tips:**

- Search is case-insensitive.
- Use a specific term rather than a question — *"regenerate"* finds the right section
  faster than *"how do I redo a message"*.
- If a term appears in several articles, the most relevant one (by title match) appears first.

---

## AI Help {#ai-help}

The **Ask AI →** button appears below the search results (or below the "No results" message).
Click it to send your current search query to the local AI model, which reads all the
documentation and writes a direct answer to your question.

### What to expect

- The model reads the entire documentation (~12 articles) every time.
- Responses take **5–30 seconds** depending on the model and hardware.
- The answer appears in the right panel with a purple **AI answer** badge and your original question.
- Click **✕** in the answer header to dismiss it and return to the article view.

### What makes a good AI question

The model answers best when the question is specific and matches a topic the documentation covers:

| Better | Why |
| --- | --- |
| *"How do I split a block at the cursor?"* | Maps to a specific documented procedure |
| *"What is the difference between ignore and delete?"* | Both terms appear with context in the articles |
| *"How do I export only selected blocks?"* | Step-by-step procedure is documented |

| Less effective | Why |
| --- | --- |
| *"Why is the model slow?"* | Performance tuning is not yet covered in the docs |
| *"How do I install the app?"* | Setup/deployment is not in the user guide |
| Vague questions like *"explain everything"* | Model will summarize broadly without specific guidance |

### How the AI uses the documentation

The model is instructed to answer **only** from the documentation content — it will not guess
or fill in gaps from general knowledge. If the answer is not in the docs, it says so.

When it finds the answer, it typically names the article section where the information comes from.
You can then search for that section title in the keyword search to jump directly to the source.

### Improving AI answer quality

Because the model works directly from the documentation text, the answers improve as the
documentation improves. If an AI answer is vague or incomplete, the most likely reason is
that the relevant article needs more detail, a clearer procedure, or a concrete example.

---

## Navigating the Article Tree

The left sidebar (when no search is active) shows two sections:

| Section | Contents |
| --- | --- |
| **User Guide** | Getting started, chat, Knowledge Workbench, tools, prompts, quick reference, this article |
| **Architecture** | System overview, data model, tool framework, streaming design, Knowledge Workbench design, voice roadmap |

Click any article title to open it. The active article is highlighted with a purple left border.

Some articles contain internal anchors — links like `/help/User/02_Chat#chat-edit` open the
chat article and scroll directly to the "Editing a user message" section. These links are used
by the **?** context-help icons placed next to specific UI elements.
