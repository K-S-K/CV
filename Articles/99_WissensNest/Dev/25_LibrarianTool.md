# WissensNest

## Librarian Tools — Local Document Library

The Librarian is a set of three tools that give the model access to a local directory of PDF documents. When a user asks about a datasheet, manual, or reference document, the model searches the library before going to the web. Documents the user has already downloaded are found instantly; the web is only queried for things that are not yet in the library.

---

### Why a Local Library

`web_search` returns snippets. `fetch_page` can read the full content — but many file-serving sites (notably ST.com for STM32 datasheets) block automated downloads. The library solves both problems:

- Files already in the library are read directly with no HTTP overhead and no bot-blocking risk.
- A human-written descriptor gives the model enough context to go straight to the right pages without reading the table of contents every time.
- The model can enrich the library itself by writing descriptors for newly dropped PDFs.

---

### Three-Tool Architecture

All three tools live in `WissensNest.Tools.Library` and are registered as singletons.

| Tool | Name | Purpose |
|---|---|---|
| `LibrarySearchTool` | `library_search` | Keyword search across `.md` descriptors and undescribed PDF filenames |
| `LibraryReadTool` | `library_read` | Read pages from a local PDF; prepend title + source header |
| `LibraryDescribeTool` | `library_describe` | Write a `.md` descriptor for a PDF the model has just read |

The model is instructed (via `Chat:SystemPrompt`) to call `library_search` before `web_search` whenever looking for a document.

---

### Library Directory

The root is configured in `appsettings.json`:

```json
"Library": {
  "Path": "/Users/ksk-work/Projects/AI/WissensNest/Library",
  "MaxSearchResults": 5
}
```

The directory can be flat or sub-divided however the user likes — the tools scan recursively:

```
Library/
  Datasheets/
    stm32g031k8.pdf
    stm32g031k8.md        ← descriptor
    nxp-lpc1769.pdf
    nxp-lpc1769.md
  Manuals/
    keil-mdk-guide.pdf    ← no descriptor yet
```

---

### Descriptor Format

Each PDF gets a sidecar `.md` file with the same filename stem:

```markdown
---
title: STM32G031K8 Datasheet
source: https://www.st.com/resource/en/datasheet/stm32g031k8.pdf
added: 2026-05-01
tags: stm32, cortex-m0+, microcontroller, embedded, STM32G0, GPIO, ADC, USART
---

STMicroelectronics STM32G031K8. 32-bit ARM Cortex-M0+, 64 KB Flash, 8 KB SRAM.
Packages: LQFP-32, QFN-32. Supply: 2.0–3.6 V.
Key sections: pinout (p.38), electrical characteristics (p.62),
power consumption tables (p.65), timers (p.120), ADC (p.155), I2C/SPI/USART (p.170–220).
```

The `body` is the most valuable field — page references like `"power consumption tables (p.65)"` let the model go directly to `library_read(..., pages="65-70")` without reading the TOC first.

`source` is optional — omit it if the original URL is unknown.

---

### `library_search` — How It Works

`DescriptorParser.TryParse` reads each `.md` file, extracts frontmatter fields, and builds a single lowercased `searchText` string: `title + tags + body + filename-stem`. The tool scores each descriptor by counting how many of the query's space-separated terms appear in `searchText`, then returns the top `MaxSearchResults` hits ordered by score.

Undescribed PDFs (no sidecar `.md`) are reported separately when the query terms match any part of the filename stem. This surfaces newly dropped files without polluting described-document results.

**`DescriptorParser` internals:**

```csharp
// Full parse for search — requires paired .pdf to exist
public static ParsedDescriptor? TryParse(string mdPath, string libraryRoot)

// Lightweight parse for library_read header
public static (string title, string source) ParseTitleAndSource(string mdPath)
```

Both split the file on `---` delimiters, parse key-value frontmatter lines, and return empty strings on any error — they never throw.

---

### `library_read` — Output Format

```
[Library: STM32G031K8 Datasheet | Source: https://… | Pages 65–70 of 891]

--- Page 65 ---
Table 18. Supply current at VDD = 3.3 V ...
```

The header is built from the sidecar `.md` if it exists; otherwise the filename stem is used as the title. PdfPig's `page.GetWords()` extracts all words in reading order.

Page range parsing accepts `"1-5"`, `"47-52"`, `"3"`, or omitted (defaults to pages 1–5).

---

### `library_describe` — Descriptor Writing

The tool:
1. Validates the `filename` path is within the library root (path-traversal guard).
2. Checks the paired PDF exists.
3. Refuses if a `.md` already exists — the user must delete it first.
4. Writes the descriptor with `DateTimeOffset.UtcNow` as `added`.

> **TODO:** Add a `force: true` parameter to allow the model to overwrite an existing descriptor on demand.

---

### `LibraryPathHelper` — Path Safety

All three tools call the same guard before resolving any user-supplied path:

```csharp
var candidate = Path.GetFullPath(Path.Combine(libraryRoot, relativePath));
if (!candidate.StartsWith(libraryRoot, StringComparison.OrdinalIgnoreCase))
    return false; // path traversal attempt
```

The check prevents `../../../etc/passwd`-style inputs. Only `.md` files are ever written by `library_describe` (the extension is set server-side with `Path.ChangeExtension`).

---

### Integration: Priority Chain

The system prompt addition steers the model's priority order:

> "When looking for a document, datasheet, manual, or specification, always call `library_search` first — only fall back to `web_search` if the library has no match."

The full priority chain the model follows:

```
library_search → found          → library_read → answer
library_search → not found      → web_search
                                    → fetch_page → answer
                                    → fetch_page fails → ask user to download manually
```

When `fetch_page` fails (bot-blocking CDN), the model tells the user the source URL and asks them to place the PDF in the library directory. On the user's next message, the model calls `library_search` → finds undescribed file → `library_read` first pages → `library_describe` → `library_read` target pages → answers.

---

### Typical Tool Call Sequences

**Case 1 — Library hit with navigation hint in descriptor:**

```
library_search("STM32G031K8 power consumption")
  → stm32g031k8.pdf, body: "power consumption tables (p.65)"

library_read("Datasheets/stm32g031k8.pdf", pages="65-70")
  → table data

→ Model answers with specific values.
```

**Case 2 — Undescribed file, model enriches library:**

```
library_search("keil mdk")
  → Undescribed: Manuals/keil-mdk-guide.pdf

library_read("Manuals/keil-mdk-guide.pdf", pages="1-5")
  → cover + TOC

library_describe("Manuals/keil-mdk-guide.pdf",
  title="Keil MDK Getting Started Guide v5.38",
  source="https://www.keil.com/…",
  tags="keil, mdk, arm, embedded, ide, debug, compiler",
  body="ARM Keil MDK setup guide. Installation (p.5), project creation (p.12), debug (p.35).")
  → "Descriptor written: Manuals/keil-mdk-guide.md"

library_read("Manuals/keil-mdk-guide.pdf", pages="12-20")
  → project creation steps

→ Model answers.
```

**Case 3 — Not in library, web fetch blocked, manual download requested:**

```
library_search("STM32G031K8") → not found
web_search("STM32G031K8 datasheet") → ST.com URL
fetch_page("https://www.st.com/…/stm32g031k8.pdf") → "Failed: connection timed out"

Model: "The datasheet is at https://www.st.com/resource/en/datasheet/stm32g031k8.pdf
        but ST.com blocks automated downloads.
        Please download it and place it at Library/Datasheets/stm32g031k8.pdf.
        Let me know when it's ready."

User: "Done."

library_search("stm32g031k8") → undescribed file found
library_read("Datasheets/stm32g031k8.pdf", pages="1-5") → TOC
library_describe(…) → descriptor written
library_read("Datasheets/stm32g031k8.pdf", pages="65-70") → answer
```

---

### Configuration

```json
"Library": {
  "Path": "/Users/ksk-work/Projects/AI/WissensNest/Library",
  "MaxSearchResults": 5
}
```

`AddLibrary` in `Program.cs`:

```csharp
.AddLibrary(opts => builder.Configuration.GetSection("Library").Bind(opts))
```

---

### Known Limitations

| Concern | Detail |
|---|---|
| No index | Full directory scan on every `library_search` call. Fine for < a few hundred files; consider a startup-built index if the library grows very large. |
| PDF-only | `library_read` handles `.pdf` only. `.txt` / plain `.md` files are not readable via `library_read` (sufficient for current use cases — technical documents are always PDF). |
| Descriptor overwrite | `library_describe` refuses to overwrite an existing descriptor. The user must delete the `.md` manually. A `force` parameter is a planned TODO. |
| PDF layout fidelity | PdfPig extracts words in reading order; complex multi-column layouts or scanned (image-only) PDFs may produce garbled or empty text. |

---

### Referenced Files

| File | Role |
|---|---|
| [LibrarySearchTool.cs](../../Src/Tools/WissensNest.Tools.Library/LibrarySearchTool.cs) | `library_search` — scan, score, report |
| [LibraryReadTool.cs](../../Src/Tools/WissensNest.Tools.Library/LibraryReadTool.cs) | `library_read` — PdfPig extraction + header |
| [LibraryDescribeTool.cs](../../Src/Tools/WissensNest.Tools.Library/LibraryDescribeTool.cs) | `library_describe` — write `.md` sidecar |
| [DescriptorParser.cs](../../Src/Tools/WissensNest.Tools.Library/DescriptorParser.cs) | YAML frontmatter parser shared by search and read |
| [LibraryPathHelper.cs](../../Src/Tools/WissensNest.Tools.Library/LibraryPathHelper.cs) | Path-traversal guard |
| [LibraryOptions.cs](../../Src/Tools/WissensNest.Tools.Library/LibraryOptions.cs) | `Path` + `MaxSearchResults` config |
| [ServiceCollectionExtensions.cs](../../Src/Tools/WissensNest.Tools.Library/ServiceCollectionExtensions.cs) | DI registration |
| [16_Tools.md](./16_Tools.md) | Tool framework — ITool, ParametersSchema, output formatting |
| [24_FetchPage.md](./24_FetchPage.md) | FetchPageTool — the web complement to library_read |
