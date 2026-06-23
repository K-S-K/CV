# My AI

## Persistence - Entities

### Step 0: Install SQLite

```bash
brew install sqlite
```

The note from SQLite after installing:

```text
sqlite is keg-only, which means it was not symlinked into /opt/homebrew,
because macOS already provides this software and installing another version in
parallel can cause all kinds of trouble.

If you need to have sqlite first in your PATH, run:
  echo 'export PATH="/opt/homebrew/opt/sqlite/bin:$PATH"' >> ~/.zshrc

For compilers to find sqlite you may need to set:
  export LDFLAGS="-L/opt/homebrew/opt/sqlite/lib"
  export CPPFLAGS="-I/opt/homebrew/opt/sqlite/include"

For pkgconf to find sqlite you may need to set:
  export PKG_CONFIG_PATH="/opt/homebrew/opt/sqlite/lib/pkgconfig"
```

#### Check which SQLite is default

```bash
which sqlite3
```

It can be variety of answers:

- /usr/bin/sqlite3
- /opt/homebrew/opt/sqlite/bin/sqlite3

#### Install DB Browser for SQLite

[DB Browser for SQLite](https://sqlitebrowser.org/) (DB4S) is a high quality, visual, open source tool designed for people who want to create, search, and edit SQLite or SQLCipher database files.

```bash
brew install db-browser-for-sqlite
```

#### Navigate EFCore properly

Point the DB file in the appsettings. It should be relative path (./data/):

```json
{
  "ConnectionStrings": {
    "Default": "Data Source=./data/app.db"
  }
}
```

Wire up EF Core (Program.cs)

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlite(builder.Configuration.GetConnectionString("Default")));

var app = builder.Build();
```

Ensure DB folder exists. SQLite won’t create directories automatically.

Add at startup:

```csharp
var dbPath = builder.Configuration.GetConnectionString("Default");
var directory = Path.GetDirectoryName(dbPath!.Replace("Data Source=", ""));

if (!Directory.Exists(directory))
{
    Directory.CreateDirectory(directory!);
}
```

**Permissions.** Make sure app can write:

```bash
chmod 755 ./data
```

### Step 1: EF Core packages installation

```bash
# Persistence assembly — the EF Core implementation
cd Libraries/WissensNest.Persistent.SQLite
dotnet add package Microsoft.EntityFrameworkCore.Sqlite
dotnet add package Microsoft.EntityFrameworkCore.Design

# API — needs EF tools for migrations
cd ../../Services/WissensNest.API
dotnet add package Microsoft.EntityFrameworkCore.Design

# Install EF global tool if you don't have it yet
dotnet tool install --global dotnet-ef
```

How to verify the tool installed:

```bash
dotnet ef --version
```

### Step 2: Base entity in WissensNest.Contracts

Every entity inherits from this — one place for all audit fields:

```csharp
// Libraries/WissensNest.Contracts/Entities/BaseEntity.cs
namespace WissensNest.Contracts.Entities;

public abstract class BaseEntity
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset? DeletedAt { get; set; }
    public bool IsDeleted { get; set; }
}
```

And a base repository interface — also in Contracts:

```csharp
// Libraries/WissensNest.Contracts/Repositories/IRepository.cs
namespace WissensNest.Contracts.Repositories;

public interface IRepository<T> where T : class
{
    Task<T?> GetByIdAsync(Guid id, CancellationToken ct = default);
    Task<IReadOnlyList<T>> GetAllAsync(CancellationToken ct = default);
    Task AddAsync(T entity, CancellationToken ct = default);
    Task UpdateAsync(T entity, CancellationToken ct = default);
    Task SoftDeleteAsync(Guid id, CancellationToken ct = default);
    Task HardDeleteAsync(Guid id, CancellationToken ct = default);
    Task SaveChangesAsync(CancellationToken ct = default);
}
```

### Step 3: Domain entities in WissensNest.Contracts

```csharp
// Libraries/WissensNest.Contracts/Entities/Project.cs
using WissensNest.Contracts.Entities;

namespace WissensNest.Contracts.Entities;

public class Project : BaseEntity
{
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public Guid? DefaultPromptId { get; set; }

    public ICollection<Conversation> Conversations { get; set; } = new List<Conversation>();
    public PromptCollection? DefaultPrompt { get; set; }
}
```

```csharp
// Libraries/WissensNest.Contracts/Entities/PromptCollection.cs
using WissensNest.Contracts.Entities;

namespace WissensNest.Contracts.Entities;

public class PromptCollection : BaseEntity
{
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }

    /// <summary>
    /// Prompt content. Sections separated by --- for future composability.
    /// Example:
    /// You are a helpful assistant.
    /// ---
    /// Always respond in Markdown.
    /// ---
    /// Each table row must be on its own line.
    /// </summary>
    public string Content { get; set; } = string.Empty;

    public ICollection<Conversation> Conversations { get; set; } = new List<Conversation>();
}
```

```csharp
// Libraries/WissensNest.Contracts/Entities/Conversation.cs
using WissensNest.Contracts.Entities;

namespace WissensNest.Contracts.Entities;

public class Conversation : BaseEntity
{
    public string Title { get; set; } = string.Empty;
    public Guid ProjectId { get; set; }
    public Guid? PromptCollectionId { get; set; }

    /// <summary>
    /// Snapshot of the assembled prompt text at conversation start.
    /// Preserved for reproducibility even if the template is later edited.
    /// </summary>
    public string? PromptSnapshot { get; set; }

    public bool IsIgnored { get; set; }

    public Project Project { get; set; } = null!;
    public PromptCollection? PromptCollection { get; set; }
    public ICollection<Message> Messages { get; set; } = new List<Message>();
}
```

```csharp
// Libraries/WissensNest.Contracts/Entities/Message.cs
using WissensNest.Contracts.Entities;

namespace WissensNest.Contracts.Entities;

public class Message : BaseEntity
{
    public Guid ConversationId { get; set; }
    public string Role { get; set; } = string.Empty;

    /// <summary>Raw model output — never modified after creation.</summary>
    public string OriginalContent { get; set; } = string.Empty;

    /// <summary>After IResponseFormatter — structural normalization only.</summary>
    public string NormalizedContent { get; set; } = string.Empty;

    public bool IsIgnored { get; set; }

    public Conversation Conversation { get; set; } = null!;
}
```

### Step 4: DbContext in WissensNest.Persistent.SQLite

```csharp
// Libraries/WissensNest.Persistent.SQLite/WissensNestDbContext.cs
using Microsoft.EntityFrameworkCore;
using WissensNest.Contracts.Entities;

namespace WissensNest.Persistent.SQLite;

public class WissensNestDbContext : DbContext
{
    public WissensNestDbContext(DbContextOptions<WissensNestDbContext> options)
        : base(options) { }

    public DbSet<Project> Projects => Set<Project>();
    public DbSet<PromptCollection> PromptCollections => Set<PromptCollection>();
    public DbSet<Conversation> Conversations => Set<Conversation>();
    public DbSet<Message> Messages => Set<Message>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        // Global query filter — soft deleted entities invisible by default
        modelBuilder.Entity<Project>()
            .HasQueryFilter(e => !e.IsDeleted);
        modelBuilder.Entity<PromptCollection>()
            .HasQueryFilter(e => !e.IsDeleted);
        modelBuilder.Entity<Conversation>()
            .HasQueryFilter(e => !e.IsDeleted);
        modelBuilder.Entity<Message>()
            .HasQueryFilter(e => !e.IsDeleted);

        // Project
        modelBuilder.Entity<Project>(e =>
        {
            e.HasKey(x => x.Id);
            e.Property(x => x.Name).IsRequired().HasMaxLength(200);
            e.HasMany(x => x.Conversations)
             .WithOne(x => x.Project)
             .HasForeignKey(x => x.ProjectId)
             .OnDelete(DeleteBehavior.Restrict);
        });

        // PromptCollection
        modelBuilder.Entity<PromptCollection>(e =>
        {
            e.HasKey(x => x.Id);
            e.Property(x => x.Name).IsRequired().HasMaxLength(200);
            e.Property(x => x.Content).IsRequired();
        });

        // Conversation
        modelBuilder.Entity<Conversation>(e =>
        {
            e.HasKey(x => x.Id);
            e.Property(x => x.Title).IsRequired().HasMaxLength(500);
            e.HasMany(x => x.Messages)
             .WithOne(x => x.Conversation)
             .HasForeignKey(x => x.ConversationId)
             .OnDelete(DeleteBehavior.Cascade);
            e.HasOne(x => x.PromptCollection)
             .WithMany(x => x.Conversations)
             .HasForeignKey(x => x.PromptCollectionId)
             .OnDelete(DeleteBehavior.SetNull);
        });

        // Message
        modelBuilder.Entity<Message>(e =>
        {
            e.HasKey(x => x.Id);
            e.Property(x => x.Role).IsRequired().HasMaxLength(20);
            e.Property(x => x.OriginalContent).IsRequired();
            e.Property(x => x.NormalizedContent).IsRequired();
        });
    }

    public override Task<int> SaveChangesAsync(
        CancellationToken cancellationToken = default)
    {
        // Auto-update UpdatedAt on every save
        foreach (var entry in ChangeTracker.Entries<BaseEntity>()
            .Where(e => e.State == EntityState.Modified))
        {
            entry.Entity.UpdatedAt = DateTimeOffset.UtcNow;
        }

        return base.SaveChangesAsync(cancellationToken);
    }
}
```

### Step 5: Repository implementations

A base repository that handles all the common operations:

```csharp
// Libraries/WissensNest.Persistent.SQLite/Repositories/BaseRepository.cs
using Microsoft.EntityFrameworkCore;
using WissensNest.Contracts.Entities;
using WissensNest.Contracts.Repositories;

namespace WissensNest.Persistent.SQLite.Repositories;

public abstract class BaseRepository<T> : IRepository<T>
    where T : BaseEntity
{
    protected readonly WissensNestDbContext Context;
    protected readonly DbSet<T> DbSet;

    protected BaseRepository(WissensNestDbContext context)
    {
        Context = context;
        DbSet = context.Set<T>();
    }

    public async Task<T?> GetByIdAsync(Guid id, CancellationToken ct = default) =>
        await DbSet.FirstOrDefaultAsync(e => e.Id == id, ct);

    public async Task<IReadOnlyList<T>> GetAllAsync(CancellationToken ct = default) =>
        await DbSet.ToListAsync(ct);

    public async Task AddAsync(T entity, CancellationToken ct = default) =>
        await DbSet.AddAsync(entity, ct);

    public Task UpdateAsync(T entity, CancellationToken ct = default)
    {
        DbSet.Update(entity);
        return Task.CompletedTask;
    }

    public async Task SoftDeleteAsync(Guid id, CancellationToken ct = default)
    {
        var entity = await GetByIdAsync(id, ct);
        if (entity is null) return;
        entity.IsDeleted = true;
        entity.DeletedAt = DateTimeOffset.UtcNow;
        DbSet.Update(entity);
    }

    public async Task HardDeleteAsync(Guid id, CancellationToken ct = default)
    {
        // IgnoreQueryFilters needed — hard delete must find soft-deleted entities too
        var entity = await DbSet
            .IgnoreQueryFilters()
            .FirstOrDefaultAsync(e => e.Id == id, ct);
        if (entity is null) return;
        DbSet.Remove(entity);
    }

    public async Task SaveChangesAsync(CancellationToken ct = default) =>
        await Context.SaveChangesAsync(ct);
}
```

#### Concrete repositories for each entity

```csharp
// Libraries/WissensNest.Persistent.SQLite/Repositories/ProjectRepository.cs
using Microsoft.EntityFrameworkCore;
using WissensNest.Contracts.Entities;

namespace WissensNest.Persistent.SQLite.Repositories;

public class ProjectRepository : BaseRepository<Project>
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
// Libraries/WissensNest.Persistent.SQLite/Repositories/ConversationRepository.cs
using Microsoft.EntityFrameworkCore;
using WissensNest.Contracts.Entities;

namespace WissensNest.Persistent.SQLite.Repositories;

public class ConversationRepository : BaseRepository<Conversation>
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
            .Include(c => c.Messages.Where(m => !m.IsDeleted && !m.IsIgnored))
            .FirstOrDefaultAsync(c => c.Id == id, ct);
}
```

```csharp
// Libraries/WissensNest.Persistent.SQLite/Repositories/MessageRepository.cs
using Microsoft.EntityFrameworkCore;
using WissensNest.Contracts.Entities;

namespace WissensNest.Persistent.SQLite.Repositories;

public class MessageRepository : BaseRepository<Message>
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

```csharp
// Libraries/WissensNest.Persistent.SQLite/Repositories/PromptCollectionRepository.cs
using WissensNest.Contracts.Entities;

namespace WissensNest.Persistent.SQLite.Repositories;

public class PromptCollectionRepository : BaseRepository<PromptCollection>
{
    public PromptCollectionRepository(WissensNestDbContext context) : base(context) { }
}
```

### Step 6: DI registration in WissensNest.Persistent.SQLite

```csharp
// Libraries/WissensNest.Persistent.SQLite/ServiceCollectionExtensions.cs
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
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

        services.AddScoped<ProjectRepository>();
        services.AddScoped<ConversationRepository>();
        services.AddScoped<MessageRepository>();
        services.AddScoped<PromptCollectionRepository>();

        return services;
    }
}
```

### Step 7: Wire into WissensNest.API

Add the connection string to appsettings.json:

```json
{
  "ConnectionStrings": {
    "SQLite": "Data Source=myai.db"
  }
}
```

And register in _Program.cs_:

```csharp
builder.Services.AddSQLitePersistence(
    builder.Configuration.GetConnectionString("SQLite")!);
```

Add auto-migration on startup — useful during development:

```csharp
var app = builder.Build();

// Auto-apply migrations on startup
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<WissensNestDbContext>();
    await db.Database.MigrateAsync();
}
```

### Step 8: Create the first migration

```bash
cd Services/WissensNest.API

dotnet ef migrations add InitialSchema \
  --project ../../Libraries/WissensNest.Persistent.SQLite \
  --startup-project . \
  --output-dir Migrations
```

Then apply it:

```bash
dotnet ef database update \
  --project ../../Libraries/WissensNest.Persistent.SQLite \
  --startup-project .
```

Or simply run the API — MigrateAsync() applies it automatically.

### Step 9: Verify

Run the API and look for _myai.db_ in _Services/WissensNest.API/_. You can inspect it with any SQLite browser — _DB Browser for SQLite_ is free and excellent on macOS. You'll see four tables: _Projects_, _PromptCollections_, _Conversations_, _Messages_.

```csharp
```

### What we have now

```text
WissensNest.Contracts         → Project, Conversation, Message, PromptCollection, BaseEntity, IRepository<T>
WissensNest.Persistent.SQLite → WissensNestDbContext, BaseRepository<T>, 4 concrete repos
WissensNest.API               → wired, auto-migrates on startup
```

The next step is building the repository interfaces in WissensNest.Contracts so WissensNest.Core can depend on abstractions, not on the SQLite assembly directly.
