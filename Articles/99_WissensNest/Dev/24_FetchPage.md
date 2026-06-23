# WissensNest

## FetchPageTool — URL Content Fetching

`FetchPageTool` lets the model read the actual content of a URL it has already found — typically a result from `web_search`. Without this tool the model can only see titles and snippets; with it the model can open a page or a specific section of a PDF datasheet and use the full text to answer a question.

---

### The Problem It Solves

`web_search` returns titles, snippets, and URLs. The snippets are 1–2 sentence previews scraped from the search results page — not the article body. When the model needs to cite specific details (a datasheet register address, a paper's methodology, a recipe's ingredient list), the snippet is not enough. The model needs to open the URL.

Without `fetch_page`, the model attempts to pass a URL as a search query, which returns irrelevant multi-result pages instead of the target article.

---

### Typical Tool Chain

The model drives this automatically within one response turn — no user interaction between steps:

```
1. web_search("LPC1769 datasheet")
       → titles + URLs for NXP results

2. fetch_page(url="https://…/LPC1769_68.pdf", pages="1-5")
       → cover page + table of contents (find "Power" chapter → page 45)

3. fetch_page(url="https://…/LPC1769_68.pdf", pages="45-52")
       → power supply chapter text

4. Model writes the answer citing specific values from the datasheet
```

`ToolOrchestrator` handles the loop; the model calls tools in sequence until it has enough information to produce a final answer.

---

### Parameters

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `url` | string | yes | The URL to fetch |
| `pages` | string | no | PDF page range only — `"1-5"`, `"45-52"`, or `"3"`. Ignored for HTML. Defaults to pages 1–5. |

---

### Content-Type Routing

The tool inspects the HTTP response `Content-Type` header (and the URL suffix as a fallback) to decide how to process the response:

| Content | Handler | Output |
| --- | --- | --- |
| `text/html` | AngleSharp DOM parser | Plain text, `script`/`style`/`nav`/`footer`/`header` removed, capped at 20 000 characters |
| `application/pdf` or `.pdf` URL | PdfPig page extractor | Plain text of the requested page range, prefixed with `[PDF — pages X–Y of N]` |

---

### HTML Processing

```csharp
// Remove noisy structural elements
foreach (var el in document.QuerySelectorAll("script, style, nav, footer, header").ToList())
    el.Remove();

// Extract body text, collapse excess whitespace
var text = document.Body?.TextContent ?? document.TextContent;
text = Regex.Replace(text, @"\s{3,}", "\n\n").Trim();
```

The 20 000-character cap is enforced after whitespace normalisation. If the page is truncated, the tool appends `[Truncated — N more characters]` so the model knows there is more content.

---

### PDF Processing

PdfPig (`PdfPig` NuGet, v0.1.14, pure C#) extracts words page by page:

```csharp
using var doc = PdfDocument.Open(bytes);
for (int pageNum = start; pageNum <= end; pageNum++)
{
    var page = doc.GetPage(pageNum);
    foreach (var word in page.GetWords())
        sb.Append(word.Text).Append(' ');
}
```

**Page range parsing** — the `pages` parameter accepts:

| Input | Meaning |
| --- | --- |
| `"1-5"` | Pages 1 through 5 |
| `"45-52"` | Pages 45 through 52 |
| `"3"` | Page 3 only |
| omitted | Pages 1–5 (default) |

Page numbers are clamped to `[1, totalPages]`.

---

### Byte Cache

Fetching a large PDF (20–30 MB) on every `fetch_page` call to the same URL would be wasteful when the model reads multiple page ranges in one conversation. The tool caches raw response bytes by URL:

```csharp
private readonly MemoryCache _cache = new(new MemoryCacheOptions
{
    SizeLimit = 200 * 1024 * 1024  // 200 MB total
});

// On cache miss:
_cache.Set(url, (bytes, contentType), new MemoryCacheEntryOptions
{
    SlidingExpiration = TimeSpan.FromMinutes(60),
    Size = bytes.Length
});
```

- **Key:** the URL string.
- **Value:** `(byte[], string)` — raw bytes + content-type from the first response.
- **Sliding expiration:** 60 minutes — covers a full research session; stale after an hour of inactivity.
- **Size limit:** 200 MB across all cached URLs. LRU eviction applies when the limit is approached.
- **Scope:** the `MemoryCache` instance is private to the tool singleton — it is not shared with the rest of the application.

Example: three calls to the same PDF URL produce one HTTP request:

```
fetch_page(url="…/LPC1769.pdf", pages="1-5")   → download + cache → extract pp. 1-5
fetch_page(url="…/LPC1769.pdf", pages="45-52") → cache hit       → extract pp. 45-52
fetch_page(url="…/LPC1769.pdf", pages="60-65") → cache hit       → extract pp. 60-65
```

---

### HTTP Client Configuration

The named client `"fetchpage"` is configured in `ServiceCollectionExtensions`:

```csharp
services.AddHttpClient("fetchpage", client =>
{
    client.DefaultRequestHeaders.UserAgent.ParseAdd("Mozilla/5.0 …Chrome/124…");
    client.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("text/html"));
    client.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/xhtml+xml", 0.9));
    client.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/pdf"));
    client.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("*/*", 0.8));
    client.DefaultRequestHeaders.AcceptLanguage.ParseAdd("ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7");
    client.DefaultRequestVersion = HttpVersion.Version11;
    client.DefaultVersionPolicy = HttpVersionPolicy.RequestVersionOrLower;
    // Browser security headers — servers doing bot-detection stall connections without these.
    client.DefaultRequestHeaders.Add("Upgrade-Insecure-Requests", "1");
    client.DefaultRequestHeaders.Add("Sec-Fetch-Dest", "document");
    client.DefaultRequestHeaders.Add("Sec-Fetch-Mode", "navigate");
    client.DefaultRequestHeaders.Add("Sec-Fetch-Site", "none");
    client.DefaultRequestHeaders.Add("Sec-Fetch-User", "?1");
    client.DefaultRequestHeaders.Add("Cache-Control", "no-cache");
    client.DefaultRequestHeaders.Add("Pragma", "no-cache");
    client.Timeout = TimeSpan.FromSeconds(90);
})
.ConfigurePrimaryHttpMessageHandler(() => new HttpClientHandler
{
    // Automatic decompression — servers may stall without gzip/brotli negotiation.
    AutomaticDecompression = DecompressionMethods.GZip | DecompressionMethods.Deflate | DecompressionMethods.Brotli,
    AllowAutoRedirect = true,
    MaxAutomaticRedirections = 10,
});
```

**Why HTTP/1.1 is forced:** some file-serving endpoints (notably ST.com) reset HTTP/2 streams for non-browser clients. .NET's `HttpClient` negotiates HTTP/2 by default for HTTPS connections, so a RST_STREAM from the server surfaces as a generic `HttpRequestException`. Pinning to HTTP/1.1 avoids the obscure error.

**Why `Sec-Fetch-*` headers matter:** modern browsers always send `Sec-Fetch-Dest: document`, `Sec-Fetch-Mode: navigate`, etc. Many servers treat their absence as a bot signal and hold the connection open until the client times out. Adding them resolves those silent 60-second hangs.

**Why automatic decompression:** servers that serve gzip/brotli-compressed content may stall or behave oddly if the client does not advertise support. `AutomaticDecompression` makes the handler advertise all standard encodings and transparently decompress responses.

**Timeout:** 90 seconds — extended from 60 s to accommodate slow-starting servers that pass bot-detection checks but take extra time to serve the first byte.

---

### Known Limitations

| Concern | Detail |
| --- | --- |
| Hardened bot-blocking CDNs | Some sites (ST.com / STMicroelectronics) block automated downloads entirely — they require a real browser session with cookies/JavaScript regardless of headers. The tool returns a descriptive error; the model should inform the user and suggest opening the URL manually. |
| JavaScript-rendered pages | AngleSharp is a static HTML parser — it does not execute JavaScript. SPAs that render their content via JS will return empty or skeleton HTML. |
| Very long HTML pages | Capped at 20 000 characters. If the target section is beyond the cap, the model should try a more specific URL or ask the user to copy the relevant text. |
| PDF layout fidelity | PdfPig extracts words in reading order but complex multi-column layouts or tables may extract in non-obvious order. |

---

### Referenced Files

| File | Role |
| --- | --- |
| [FetchPageTool.cs](../../Src/Tools/WissensNest.Tools.FetchPage/FetchPageTool.cs) | Full implementation — routing, HTML/PDF extraction, cache |
| [ServiceCollectionExtensions.cs](../../Src/Tools/WissensNest.Tools.FetchPage/ServiceCollectionExtensions.cs) | DI registration — named client, HTTP/1.1, timeout |
| [WissensNest.Tools.FetchPage.csproj](../../Src/Tools/WissensNest.Tools.FetchPage/WissensNest.Tools.FetchPage.csproj) | Project file — `AngleSharp`, `PdfPig`, `Microsoft.Extensions.Caching.Memory` |
| [16_Tools.md](./16_Tools.md) | Tool framework — ITool, ParametersSchema, output formatting rules |
| [19_WebSearch.md](./19_WebSearch.md) | WebSearchTool — natural upstream caller of fetch_page |
