# WissensNest — Telegram Channel Reader

## What It Does

The `telegram_read_channel` tool downloads messages from a Telegram channel or group chat and appends them as Blocks inside a Knowledge Workbench Article. Each message becomes one Block with a header line showing the message ID, date, and author, followed by the message text and any attachment metadata. A sync state record tracks the last downloaded message ID per channel, so subsequent calls download only new messages without re-importing anything already in the Article.

---

## MTProto vs Bot API

Telegram offers two integration models. The Bot API is well-documented and easy to use, but bots can only read messages in channels where they have been explicitly added as members, and they cannot retrieve historical message lists from group chats or channels they do not moderate.

MTProto is the full Telegram client protocol — the same one the official Telegram apps use. An authenticated user account can read any channel or group the user has joined, including full message history, with no special admin rights. `WissensNest.Tools.Telegram` uses `WTelegramClient`, a fully managed .NET MTProto implementation, to connect as the user rather than as a bot.

The practical consequence is that `telegram_read_channel` can read any channel the user is a member of, without the channel owner having to add a bot or grant any permissions.

---

## Architecture

![Telegram Integration Architecture](../../Images/35_01_WissensNest_Telegram_Architecture.svg)

The integration is split across three layers:

**Session layer** (`WissensNest.Tools.Telegram`) — `TelegramSession` wraps the `WTelegramClient` connection and provides two operations: channel resolution (username, `t.me/` link, or numeric ID) and paginated message fetch. It retries automatically when Telegram's rate limiter responds with `FLOOD_WAIT`, and surfaces a clear error when the session is not yet authorized (directing the developer to the Setup helper).

**Tool layer** (`WissensNest.Tools.Telegram`) — `TelegramReaderTool` implements `ITool` and orchestrates the full read-and-write cycle: resolve channel, check sync state, fetch new messages, write Blocks, update sync state. It never throws past `ExecuteAsync`; all failure modes return descriptive error strings.

**Persistence layer** (`WissensNest.Contracts` + `WissensNest.Persistent.SQLite`) — `TelegramSyncState` is a domain entity that records the last downloaded message ID per `(AccountId, ChannelId)` pair. The repository interface lives in `WissensNest.Contracts`; the SQLite implementation and migration live in `WissensNest.Persistent.SQLite`.

---

## Session Design

`ITelegramSession` is a read-only interface by design. It provides no method for sending messages, uploading files, or reacting to messages. This is a deliberate structural constraint: a future `TelegramParticipantTool` will use a separate `ITelegramWriteSession` interface, keeping read-only code paths provably isolated from any write-capable code.

`TelegramSessionManager` holds one `TelegramSession` per named account, created lazily on the first use and cached for the lifetime of the API process. Each account uses its own session file, configured via `Telegram:Accounts:<id>:SessionPath`.

---

## First-Time Authentication

MTProto sessions require an interactive login the first time they are used on a device. A standalone console app, `WissensNest.Tools.Telegram.Setup`, handles this:

```bash
dotnet run --project Src/Tools/WissensNest.Tools.Telegram.Setup -- personal
```

The app reads the same configuration files as the API, connects to Telegram, and prompts for the SMS verification code and (if enabled) the 2FA password. On success it writes a session file to the configured `SessionPath`. The API reads that same file at runtime. Once the session file exists, no further interactive login is required.

`WissensNest.Tools.Telegram.Setup` is not referenced by `WissensNest.API` and is never started as a background process. It is a developer tool run once per account.

---

## Sync State Design

The `TelegramSyncStates` SQLite table holds one row per `(AccountId, ChannelId)` pair. The unique index on this combination ensures there is never more than one sync record per account-channel combination, regardless of how many times the tool is called.

On the first call for a channel the record does not exist, so the tool downloads from the beginning of the channel history (up to `maxMessages`). After each successful run the `LastMessageId` field is updated. On subsequent calls only messages with IDs greater than `LastMessageId` are fetched.

If a run fails mid-way (for example, the server returns a persistent error after writing some Blocks), the sync state is only updated when all blocks have been saved. Re-running the tool will re-download any messages whose blocks were not saved, but previously saved blocks will appear again in the Article as duplicates. This is acceptable for the current use case; a future revision could add idempotency checking.

---

## Block Content Format

Each Telegram message is stored as a single Knowledge Workbench Block. The header line makes the Telegram origin visible at a glance. Attachment metadata is embedded in the block text so that a future `TelegramAttachmentTool` can parse it and download the file on demand without re-scanning channel history.

No files are downloaded during a `telegram_read_channel` call. The `FileId` field in each attachment line encodes the Telegram `access_hash`, `file_reference`, and `dc_id` needed for a future download, serialised as a compact JSON blob.

---

## Credentials and Secrets

Non-secret configuration (session file path) is stored in `appsettings.json` and committed to version control. Secrets (`ApiId`, `ApiHash`, `PhoneNumber`) are stored in a gitignored `appsettings.Telegram.json` file in the same directory. Session files are excluded from version control via `.gitignore`. This pattern mirrors the established convention used for other sensitive configuration in the project.

---

## Planned Extensions

| Step | Tool | Capability |
| --- | --- | --- |
| 2 | `TelegramParticipantTool` | Send messages and reactions via MTProto user account; separate `ITelegramWriteSession` interface |
| 3 | `TelegramBotTool` | Push notifications and triggers via Bot API; bot token separate from user sessions |
| 4 | Multi-account | Additional named accounts under `Telegram:Accounts`; session manager already supports them |
