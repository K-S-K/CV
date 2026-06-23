# My AI

## Persistence - Interfaces

Now we add Interfaces, that Core will depend on.

### Step 1: Specific repository interfaces in WissensNest.Contracts

```csharp
// Libraries/WissensNest.Contracts/Interfaces/IProjectRepository.cs
using WissensNest.Contracts.Entities;

namespace WissensNest.Contracts.Interfaces;

public interface IProjectRepository : IRepository<Project>
{
    Task<IReadOnlyList<Project>> GetAllWithConversationsAsync(
        CancellationToken ct = default);
}
```

```csharp
// Libraries/WissensNest.Contracts/Interfaces/IPromptCollectionRepository.cs
using WissensNest.Contracts.Entities;

namespace WissensNest.Contracts.Interfaces;

public interface IPromptCollectionRepository : IRepository<PromptCollection>
{
}
```

```csharp
// Libraries/WissensNest.Contracts/Interfaces/IConversationRepository.cs
using WissensNest.Contracts.Entities;

namespace WissensNest.Contracts.Interfaces;

public interface IConversationRepository : IRepository<Conversation>
{
    Task<IReadOnlyList<Conversation>> GetByProjectAsync(
        Guid projectId,
        CancellationToken ct = default);

    Task<Conversation?> GetWithMessagesAsync(
        Guid id,
        CancellationToken ct = default);
}
```

```csharp
// Libraries/WissensNest.Contracts/Interfaces/IMessageRepository.cs
using WissensNest.Contracts.Entities;

namespace WissensNest.Contracts.Interfaces;

public interface IMessageRepository : IRepository<Message>
{
    Task<IReadOnlyList<Message>> GetByConversationAsync(
        Guid conversationId,
        CancellationToken ct = default);

    Task ToggleIgnoreAsync(
        Guid id,
        CancellationToken ct = default);
}
```

### Step 2: Make concrete repositories implement the interfaces

Update each repository in _WissensNest.Persistent.SQLite_ to implement its interface:

```csharp
// Libraries/WissensNest.Persistent.SQLite/Repositories/ProjectRepository.cs
using Microsoft.EntityFrameworkCore;
using WissensNest.Contracts.Entities;
using WissensNest.Contracts.Interfaces;

namespace WissensNest.Persistent.SQLite.Repositories;

public class ProjectRepository : BaseRepository<Project>, IProjectRepository
{
    public ProjectRepository(WissensNestDbContext context) : base(context) { }

    public async Task<IReadOnlyList<Project>> GetAllWithConversationsAsync(
        CancellationToken ct = default) =>
        await DbSet
            .Include(p => p.Conversations)
            .ToListAsync(ct);
}
```

```csharp
// Libraries/WissensNest.Persistent.SQLite/Repositories/PromptCollectionRepository.cs
using WissensNest.Contracts.Entities;
using WissensNest.Contracts.Interfaces;

namespace WissensNest.Persistent.SQLite.Repositories;

public class PromptCollectionRepository
    : BaseRepository<PromptCollection>, IPromptCollectionRepository
{
    public PromptCollectionRepository(WissensNestDbContext context) : base(context) { }
}
```

```csharp
// Libraries/WissensNest.Persistent.SQLite/Repositories/ConversationRepository.cs
using Microsoft.EntityFrameworkCore;
using WissensNest.Contracts.Entities;
using WissensNest.Contracts.Interfaces;

namespace WissensNest.Persistent.SQLite.Repositories;

public class ConversationRepository
    : BaseRepository<Conversation>, IConversationRepository
{
    public ConversationRepository(WissensNestDbContext context) : base(context) { }

    public async Task<IReadOnlyList<Conversation>> GetByProjectAsync(
        Guid projectId, CancellationToken ct = default) =>
        await DbSet
            .Where(c => c.ProjectId == projectId)
            .OrderByDescending(c => c.UpdatedAt)
            .ToListAsync(ct);

    public async Task<Conversation?> GetWithMessagesAsync(
        Guid id, CancellationToken ct = default) =>
        await DbSet
            .Include(c => c.Messages
                .Where(m => !m.IsDeleted && !m.IsIgnored)
                .OrderBy(m => m.CreatedAt))
            .FirstOrDefaultAsync(c => c.Id == id, ct);
}
```

```csharp
// Libraries/WissensNest.Persistent.SQLite/Repositories/MessageRepository.cs
using Microsoft.EntityFrameworkCore;
using WissensNest.Contracts.Entities;
using WissensNest.Contracts.Interfaces;

namespace WissensNest.Persistent.SQLite.Repositories;

public class MessageRepository : BaseRepository<Message>, IMessageRepository
{
    public MessageRepository(WissensNestDbContext context) : base(context) { }

    public async Task<IReadOnlyList<Message>> GetByConversationAsync(
        Guid conversationId, CancellationToken ct = default) =>
        await DbSet
            .Where(m => m.ConversationId == conversationId)
            .OrderBy(m => m.CreatedAt)
            .ToListAsync(ct);

    public async Task ToggleIgnoreAsync(
        Guid id, CancellationToken ct = default)
    {
        var message = await GetByIdAsync(id, ct);
        if (message is null) return;
        message.IsIgnored = !message.IsIgnored;
        DbSet.Update(message);
    }
}
```

### Step 3: Update DI registration to register interfaces

Update _ServiceCollectionExtensions_ in _WissensNest.Persistent.SQLite_ to register both the interface and the implementation:

```csharp
// Libraries/WissensNest.Persistent.SQLite/ServiceCollectionExtensions.cs
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using WissensNest.Contracts.Interfaces;
using WissensNest.Persistent.SQLite.Repositories;

namespace WissensNest.Persistent.SQLite;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddSQLitePersistence(
        this IServiceCollection services,
        string connectionString)
    {
        services.AddDbContext<WissensNestDbContext>(opts =>
            opts.UseSqlite(connectionString));

        services.AddScoped<IProjectRepository, ProjectRepository>();
        services.AddScoped<IPromptCollectionRepository, PromptCollectionRepository>();
        services.AddScoped<IConversationRepository, ConversationRepository>();
        services.AddScoped<IMessageRepository, MessageRepository>();

        return services;
    }
}
```

Note the change — now registering against the interface, not the concrete class. Core and any other consumer resolves _IConversationRepository_, never _ConversationRepository_ directly.

### Step 4: Add a ConversationService to WissensNest.Core

_ChatService_ handles streaming. Conversation lifecycle — creating, loading, saving messages — deserves its own service:

```csharp
// Libraries/WissensNest.Core/Services/ConversationService.cs
using WissensNest.Contracts.Entities;
using WissensNest.Contracts.Interfaces;

namespace WissensNest.Core.Services;

public sealed class ConversationService
{
    private readonly IConversationRepository _conversations;
    private readonly IMessageRepository _messages;
    private readonly IProjectRepository _projects;

    public ConversationService(
        IConversationRepository conversations,
        IMessageRepository messages,
        IProjectRepository projects)
    {
        _conversations = conversations;
        _messages = messages;
        _projects = projects;
    }

    public async Task<Conversation> StartConversationAsync(
        Guid projectId,
        string title,
        string? promptSnapshot = null,
        CancellationToken ct = default)
    {
        var conversation = new Conversation
        {
            ProjectId = projectId,
            Title = title,
            PromptSnapshot = promptSnapshot
        };

        await _conversations.AddAsync(conversation, ct);
        await _conversations.SaveChangesAsync(ct);

        return conversation;
    }

    public async Task SaveMessageAsync(
        Guid conversationId,
        string role,
        string originalContent,
        string normalizedContent,
        CancellationToken ct = default)
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

    public async Task<IReadOnlyList<Conversation>> GetProjectConversationsAsync(
        Guid projectId,
        CancellationToken ct = default) =>
        await _conversations.GetByProjectAsync(projectId, ct);

    public async Task<Conversation?> LoadConversationAsync(
        Guid conversationId,
        CancellationToken ct = default) =>
        await _conversations.GetWithMessagesAsync(conversationId, ct);

    public async Task UpdateTitleAsync(
        Guid conversationId,
        string title,
        CancellationToken ct = default)
    {
        var conversation = await _conversations.GetByIdAsync(conversationId, ct);
        if (conversation is null) return;
        conversation.Title = title;
        await _conversations.UpdateAsync(conversation, ct);
        await _conversations.SaveChangesAsync(ct);
    }
}
```

### Step 5: Register ConversationService in Core DI

```csharp
// Libraries/WissensNest.Core/ServiceCollectionExtensions.cs
public static IServiceCollection AddCoreServices(
    this IServiceCollection services,
    Action<ChatOptions>? configureChatOptions = null)
{
    services.AddOptions();

    services.Configure<ChatOptions>(opts =>
        configureChatOptions?.Invoke(opts));

    services.AddSingleton<IResponseFormatter, MarkdownResponseFormatter>();
    services.AddScoped<ChatService>();
    services.AddScoped<ConversationService>(); // ← add this

    return services;
}
```

## What we have now

```text
WissensNest.Contracts
  └── IProjectRepository
  └── IConversationRepository
  └── IMessageRepository
  └── IPromptCollectionRepository

WissensNest.Persistent.SQLite
  └── Concrete repositories implement interfaces

WissensNest.Core
  └── ConversationService — uses IConversationRepository, IMessageRepository
  └── ChatService — streaming (unchanged so far)

WissensNest.API
  └── All wired via DI
```

The next step is updating _ChatService_ to accept a _ConversationId_ and persist messages, then updating the API endpoint, _WissensNest.Client_, and finally _Chat.razor_ to manage conversation lifecycle.
