# My AI

## Persistence - Serialization

Let's wire persistence into the chat flow. The goal is: every message sent and received gets saved automatically, and the UI manages which conversation it's in.

At this stage, we should update _ChatService_ to accept a _ConversationId_ and persist messages, then updating the API endpoint, _WissensNest.Client_, and finally _Chat.razor_ to manage conversation lifecycle.

### Step 1: Update ChatRequest in WissensNest.Contracts

Add ConversationId — the UI tells the API which conversation this message belongs to:

```csharp
// Libraries/WissensNest.Contracts/Models/ChatRequest.cs
namespace WissensNest.Contracts.Models;

public record ChatRequest(
    Guid ConversationId,
    IReadOnlyList<ChatMessage> History,
    string UserMessage,
    bool UseWebSearch = false);
```

### Step 2: Update ChatService to persist messages

```csharp
// Libraries/WissensNest.Core/Services/ChatService.cs
using System.Runtime.CompilerServices;
using WissensNest.Contracts.Entities;
using WissensNest.Contracts.Interfaces;
using WissensNest.Contracts.Models;
using Microsoft.Extensions.Options;

namespace WissensNest.Core.Services;

public sealed class ChatService
{
    private readonly ILanguageModelClient _client;
    private readonly IWebSearchTool _search;
    private readonly IMessageRepository _messages;
    private readonly IResponseFormatter _formatter;
    private readonly ChatOptions _options;

    public ChatService(
        ILanguageModelClient client,
        IWebSearchTool search,
        IMessageRepository messages,
        IResponseFormatter formatter,
        IOptions<ChatOptions> options)
    {
        _client = client;
        _search = search;
        _messages = messages;
        _formatter = formatter;
        _options = options.Value;
    }

    public async IAsyncEnumerable<string> StreamResponseAsync(
        ChatRequest request,
        [EnumeratorCancellation] CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(request.UserMessage))
            throw new ArgumentException(
                "Message cannot be empty.", nameof(request));

        // Persist user message before streaming
        await PersistMessageAsync(
            request.ConversationId,
            "user",
            request.UserMessage,
            request.UserMessage,  // user messages need no normalization
            ct);

        var history = request.UseWebSearch
            ? await BuildHistoryWithSearchAsync(request, ct)
            : request.History;

        // Collect full response for persistence
        var responseBuffer = new System.Text.StringBuilder();

        await foreach (var token in _client.StreamChatAsync(
            history,
            request.UserMessage,
            _options.SystemPrompt,
            ct))
        {
            responseBuffer.Append(token);
            yield return token;
        }

        // Persist assistant response after streaming completes
        var rawResponse = responseBuffer.ToString();
        var normalizedResponse = _formatter.Format(rawResponse);

        await PersistMessageAsync(
            request.ConversationId,
            "assistant",
            rawResponse,
            normalizedResponse,
            ct);
    }

    private async Task PersistMessageAsync(
        Guid conversationId,
        string role,
        string originalContent,
        string normalizedContent,
        CancellationToken ct)
    {
        var message = new Message
        {
            ConversationId = conversationId,
            Role = role,
            OriginalContent = originalContent,
            NormalizedContent = normalizedContent
        };

        await _messages.AddAsync(message, ct);
        await _messages.SaveChangesAsync(ct);
    }

    private async Task<IReadOnlyList<ChatMessage>> BuildHistoryWithSearchAsync(
        ChatRequest request,
        CancellationToken ct)
    {
        IReadOnlyList<SearchResult> results;

        try
        {
            results = await _search.SearchAsync(request.UserMessage, ct);
        }
        catch (NotImplementedException)
        {
            return request.History;
        }

        if (results.Count == 0)
            return request.History;

        var searchContext = BuildSearchContextMessage(results);

        var augmentedHistory = new List<ChatMessage>
        {
            new("system", searchContext, DateTimeOffset.UtcNow)
        };
        augmentedHistory.AddRange(request.History);

        return augmentedHistory;
    }

    private static string BuildSearchContextMessage(
        IReadOnlyList<SearchResult> results)
    {
        var sb = new System.Text.StringBuilder();
        sb.AppendLine("The following web search results may help answer the question.");
        sb.AppendLine("Use them as context but rely on your own reasoning.");
        sb.AppendLine();

        foreach (var result in results)
        {
            sb.AppendLine($"Source: {result.Title} ({result.Url})");
            sb.AppendLine(result.Snippet);
            sb.AppendLine();
        }

        return sb.ToString();
    }
}
```

One important note: _IResponseFormatter_ moved from _WissensNest.Client_ to being injected into _ChatService_ in Core. This means _MarkdownResponseFormatter_ should move to _WissensNest.Core/Processing/_ — Core owns the formatting logic, Client just used it temporarily. Update the DI registration accordingly.

### Step 3: Add conversation management endpoints to WissensNest.API

```csharp
// Services/WissensNest.API/Program.cs
using WissensNest.Contracts.Models;
using WissensNest.Core.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOptions();
builder.Services
    .AddOllamaLanguageModel(opts =>
        builder.Configuration.GetSection("LanguageModel").Bind(opts))
    .AddCoreServices(opts =>
        builder.Configuration.GetSection("Chat").Bind(opts))
    .AddWebSearch()
    .AddSQLitePersistence(
        builder.Configuration.GetConnectionString("SQLite")!);

var app = builder.Build();

// Auto-migrate on startup
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<WissensNestDbContext>();
    await db.Database.MigrateAsync();
}

// ── Chat streaming ──────────────────────────────────────────
app.MapPost("/chat/stream", async (
    ChatRequest request,
    ChatService chatService,
    HttpResponse response,
    CancellationToken ct) =>
{
    response.Headers.ContentType = "text/event-stream";
    response.Headers.CacheControl = "no-cache";

    await foreach (var token in chatService.StreamResponseAsync(request, ct))
    {
        await response.WriteAsync(token, ct);
        await response.Body.FlushAsync(ct);
    }
});

// ── Conversation management ─────────────────────────────────
app.MapPost("/conversations", async (
    CreateConversationRequest request,
    ConversationService conversationService,
    CancellationToken ct) =>
{
    var conversation = await conversationService.StartConversationAsync(
        request.ProjectId,
        request.Title,
        request.PromptSnapshot,
        ct);

    return Results.Ok(new { conversation.Id, conversation.Title });
});

app.MapGet("/conversations/{projectId:guid}", async (
    Guid projectId,
    ConversationService conversationService,
    CancellationToken ct) =>
{
    var conversations = await conversationService
        .GetProjectConversationsAsync(projectId, ct);

    return Results.Ok(conversations.Select(c => new
    {
        c.Id,
        c.Title,
        c.CreatedAt,
        c.UpdatedAt
    }));
});

app.MapGet("/conversations/{id:guid}/messages", async (
    Guid id,
    ConversationService conversationService,
    CancellationToken ct) =>
{
    var conversation = await conversationService
        .LoadConversationAsync(id, ct);

    if (conversation is null)
        return Results.NotFound();

    return Results.Ok(conversation.Messages.Select(m => new
    {
        m.Id,
        m.Role,
        m.OriginalContent,
        m.NormalizedContent,
        m.CreatedAt,
        m.IsIgnored
    }));
});

app.MapPatch("/conversations/{id:guid}/title", async (
    Guid id,
    UpdateTitleRequest request,
    ConversationService conversationService,
    CancellationToken ct) =>
{
    await conversationService.UpdateTitleAsync(id, request.Title, ct);
    return Results.Ok();
});

app.Run();

// ── Request DTOs ──────────────────────────────────────────── TODO: Ask
public record CreateConversationRequest(
    Guid ProjectId,
    string Title,
    string? PromptSnapshot = null);

public record UpdateTitleRequest(string Title);
```

### Step 4: Update WissensNest.Client

Add typed methods for all new endpoints:

```csharp
// Libraries/WissensNest.Client/MyAiClient.cs
using System.Net.Http.Json;
using System.Runtime.CompilerServices;
using System.Text;
using System.Text.Json;
using WissensNest.Contracts.Interfaces;
using WissensNest.Contracts.Models;

namespace WissensNest.Client;

public sealed class WissensNestClient : IWissensNestClient
{
    private readonly HttpClient _http;

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true
    };

    public WissensNestClient(HttpClient http)
    {
        _http = http;
    }

    public async IAsyncEnumerable<string> StreamChatAsync(
        ChatRequest request,
        [EnumeratorCancellation] CancellationToken ct = default)
    {
        var requestMessage = new HttpRequestMessage(HttpMethod.Post, "chat/stream")
        {
            Content = new StringContent(
                JsonSerializer.Serialize(request),
                Encoding.UTF8,
                "application/json")
        };

        using var response = await _http.SendAsync(
            requestMessage,
            HttpCompletionOption.ResponseHeadersRead,
            ct);

        response.EnsureSuccessStatusCode();

        await using var stream = await response.Content
            .ReadAsStreamAsync(ct);
        using var reader = new StreamReader(stream);

        while (!reader.EndOfStream && !ct.IsCancellationRequested)
        {
            var chunk = await reader.ReadLineAsync(ct);
            if (!string.IsNullOrEmpty(chunk))
                yield return chunk;
        }
    }

    public async Task<ConversationInfo> CreateConversationAsync(
        Guid projectId,
        string title,
        string? promptSnapshot = null,
        CancellationToken ct = default)
    {
        var response = await _http.PostAsJsonAsync(
            "conversations",
            new { projectId, title, promptSnapshot },
            ct);

        response.EnsureSuccessStatusCode();
        return await response.Content
            .ReadFromJsonAsync<ConversationInfo>(JsonOptions, ct)
            ?? throw new InvalidOperationException(
                "Failed to deserialize conversation response.");
    }

    public async Task<IReadOnlyList<ConversationInfo>> GetConversationsAsync(
        Guid projectId,
        CancellationToken ct = default)
    {
        var result = await _http.GetFromJsonAsync<List<ConversationInfo>>(
            $"conversations/{projectId}",
            JsonOptions,
            ct);

        return result ?? [];
    }

    public async Task<IReadOnlyList<MessageInfo>> GetMessagesAsync(
        Guid conversationId,
        CancellationToken ct = default)
    {
        var result = await _http.GetFromJsonAsync<List<MessageInfo>>(
            $"conversations/{conversationId}/messages",
            JsonOptions,
            ct);

        return result ?? [];
    }

    public async Task UpdateConversationTitleAsync(
        Guid conversationId,
        string title,
        CancellationToken ct = default)
    {
        await _http.PatchAsJsonAsync(
            $"conversations/{conversationId}/title",
            new { title },
            ct);
    }
}
```

Add the DTOs to WissensNest.Contracts/Models:

```csharp
// Libraries/WissensNest.Contracts/Models/ConversationInfo.cs
namespace WissensNest.Contracts.Models;

public record ConversationInfo(
    Guid Id,
    string Title,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt);
```

```csharp
// Libraries/WissensNest.Contracts/Models/MessageInfo.cs
namespace WissensNest.Contracts.Models;

public record MessageInfo(
    Guid Id,
    string Role,
    string OriginalContent,
    string NormalizedContent,
    DateTimeOffset CreatedAt,
    bool IsIgnored);
```

Update IWissensNestClient in Contracts to match:

```csharp
// Libraries/WissensNest.Contracts/Interfaces/IWissensNestClient.cs
using WissensNest.Contracts.Models;

namespace WissensNest.Contracts.Interfaces;

public interface IWissensNestClient
{
    IAsyncEnumerable<string> StreamChatAsync(
        ChatRequest request,
        CancellationToken cancellationToken = default);

    Task<ConversationInfo> CreateConversationAsync(
        Guid projectId,
        string title,
        string? promptSnapshot = null,
        CancellationToken ct = default);

    Task<IReadOnlyList<ConversationInfo>> GetConversationsAsync(
        Guid projectId,
        CancellationToken ct = default);

    Task<IReadOnlyList<MessageInfo>> GetMessagesAsync(
        Guid conversationId,
        CancellationToken ct = default);

    Task UpdateConversationTitleAsync(
        Guid conversationId,
        string title,
        CancellationToken ct = default);
}
```

### Step 5: Update Chat.razor

The UI now manages conversation lifecycle — creates a conversation on first message, sends ConversationId with every request:

```csharp
@* Services/WissensNest.UI/Components/Pages/Chat.razor *@
@page "/chat"
@rendermode InteractiveServer
@inject IWissensNestClient AIClient
@inject IResponseFormatter Formatter
@implements IDisposable

<div class="chat-container">
    <div class="chat-history" id="chat-history">
        @foreach (var message in _messages)
        {
            <MessageBubble Message="@message"/>
        }
        @if (_isStreaming)
        {
            <div class="bubble-wrapper assistant">
                <div class="bubble streaming">@_streamingBuffer</div>
            </div>
        }
    </div>

    <div class="chat-input">
        <label class="search-toggle">
            <input type="checkbox" @bind="_useWebSearch"
                   disabled="@_isStreaming"/>
            Search web
        </label>
        <textarea
            @bind="_userInput"
            @bind:event="oninput"
            @onkeydown="HandleKeyDown"
            placeholder="Ask anything..."
            disabled="@_isStreaming"
            rows="2"/>
        <button @onclick="SendMessage"
                disabled="@(_isStreaming ||
                           string.IsNullOrWhiteSpace(_userInput))">
            Send
        </button>
    </div>
</div>

@code {
    // Well-known project ID — we'll make this selectable later
    // For now use a fixed default project
    private static readonly Guid DefaultProjectId =
        new("00000000-0000-0000-0000-000000000001");

    private readonly List<ChatMessageViewModel> _messages = new();
    private readonly List<ChatMessage> _history = new();

    private Guid? _conversationId;
    private string _userInput = string.Empty;
    private string _streamingBuffer = string.Empty;
    private bool _isStreaming;
    private bool _useWebSearch;
    private CancellationTokenSource? _cts;

    private async Task SendMessage()
    {
        if (string.IsNullOrWhiteSpace(_userInput) || _isStreaming)
            return;

        var userMessage = _userInput.Trim();
        _userInput = string.Empty;
        _isStreaming = true;
        _streamingBuffer = string.Empty;

        _messages.Add(ChatMessageViewModel.FromUser(userMessage));
        _history.Add(new ChatMessage("user", userMessage, DateTimeOffset.UtcNow));

        // Create conversation on first message
        if (_conversationId is null)
        {
            var conversation = await AIClient.CreateConversationAsync(
                DefaultProjectId,
                // Use first message as title, trimmed to 80 chars
                userMessage.Length > 80
                    ? userMessage[..80] + "…"
                    : userMessage);

            _conversationId = conversation.Id;
        }

        _cts = new CancellationTokenSource();

        try
        {
            var request = new ChatRequest(
                _conversationId.Value,
                _history,
                userMessage,
                _useWebSearch);

            await foreach (var token in AIClient.StreamChatAsync(
                request, _cts.Token))
            {
                _streamingBuffer += token;
                StateHasChanged();
            }
        }
        catch (OperationCanceledException) { }
        finally
        {
            _isStreaming = false;

            var formatted = Formatter.Format(_streamingBuffer);

            _messages.Add(ChatMessageViewModel.FromAssistant(
                rawContent: _streamingBuffer,
                displayContent: formatted));

            _history.Add(new ChatMessage(
                "assistant",
                _streamingBuffer,
                DateTimeOffset.UtcNow));

            _streamingBuffer = string.Empty;
            StateHasChanged();
        }
    }

    private async Task HandleKeyDown(KeyboardEventArgs e)
    {
        if (e.Key == "Enter" && !e.ShiftKey)
            await SendMessage();
    }

    public void Dispose()
    {
        _cts?.Cancel();
        _cts?.Dispose();
    }
}
```

## One thing to sort out — the default project

The _DefaultProjectId_ hardcoded in Chat.razor is a temporary placeholder. The database needs a seed project with that ID, otherwise _CreateConversationAsync_ will fail with a foreign key violation.

Add a seed in _Program.cs_ after migration:

```csharp
// Services/WissensNest.API/Program.cs — after MigrateAsync
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider
        .GetRequiredService<WissensNestDbContext>();

    await db.Database.MigrateAsync();

    // Seed default project if it doesn't exist
    var defaultProjectId = new Guid("00000000-0000-0000-0000-000000000001");
    if (!await db.Projects.AnyAsync(p => p.Id == defaultProjectId))
    {
        db.Projects.Add(new Project
        {
            Id = defaultProjectId,
            Name = "Default",
            Description = "Default project for general conversations"
        });
        await db.SaveChangesAsync();
    }
}
```

## What we have after this step

Every message sent and received is now persisted automatically. The conversation is created on the first message with the user's opening text as the title. The ConversationId travels from UI → Client → API → ChatService → repository on every request.

Build and run — conversations and messages should start appearing in myai.db. You can verify with DB Browser for SQLite.
