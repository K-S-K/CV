# WissensNest — Reading Telegram Channels

## Overview

The `telegram_read_channel` tool downloads messages from a Telegram channel or group chat and saves them as Blocks in a Knowledge Workbench Article. You point the tool at a channel and an Article, and it fills the Article with the channel's messages — one Block per message, each showing the date, author, and full text. On subsequent calls, only new messages are downloaded; nothing is re-imported.

This makes it easy to collect messages from a research channel, a family group, or any chat you belong to, and have them searchable and cross-referenceable alongside your other notes.

---

## Prerequisites {#prerequisites}

Before using `telegram_read_channel` you need to complete a one-time setup for each Telegram account you want to use:

1. Your API credentials (`ApiId`, `ApiHash`, `PhoneNumber`) must be stored in `appsettings.Telegram.json` on the server. This file is never committed to version control. Ask the person who runs the server to add your account.

2. The session file must exist for your account. A developer runs the Setup helper once per account to create it:

```bash
dotnet run --project Src/Tools/WissensNest.Tools.Telegram.Setup -- personal
```

The Setup helper connects to Telegram, sends a login code to your phone, and writes a session file when you enter the code. After this you do not need to log in again.

3. In the Knowledge Workbench, create the Article you want to import messages into (or use an existing one, such as the Scratch area for a Section).

Once the session file exists, `telegram_read_channel` is available in the tool bar and ready to use.

---

## First Use {#first-use}

Enable the `telegram_read_channel` tool in the ribbon, then ask the assistant to read a channel:

> "Read the last 50 messages from @wissen_updates into the article on my current page."

The assistant will call the tool with the channel identifier, the Article ID, and a `maxMessages` limit. The tool:

1. Looks up the channel on Telegram.
2. Checks whether any messages have been downloaded before (for resumable sync).
3. Fetches the requested number of new messages.
4. Writes one Block per message into the Article.
5. Reports how many messages were downloaded and their ID range.

If the channel is private and you are not a member, or if you mistype the identifier, the tool returns a clear error message.

---

## Resuming After the First Import {#resuming}

The tool remembers the last message ID it downloaded for each channel and account. On subsequent calls it downloads only messages that arrived after that point. You can call the tool every day and only new messages will be added — the Article will never contain duplicates from the same account.

The sync state is stored per account and per channel independently. Switching between two different channels does not affect each other's sync state.

---

## Controlling Batch Size {#maxmessages}

The `maxMessages` parameter limits how many new messages are downloaded in a single call. The default is 200. For channels with high traffic, or when importing a channel for the first time, you may want a smaller batch:

> "Read the next 30 messages from @news_channel into Article [id]."

You can call the tool repeatedly to page through a large backlog in manageable chunks. Each call picks up where the previous one left off.

If there are no new messages since the last sync, the tool reports "No new messages" and does not write any Blocks.

---

## What the Blocks Look Like {#block-format}

Each imported message becomes a single Block in the Article. The Block begins with a header line identifying the Telegram source:

```
**Telegram #12345** — 2026-06-14 09:32 UTC — *Ivan Petrov*

This is the message text as sent in the channel.
```

If the message has attachments (files, documents, images), each attachment appears on its own line below the text:

```
[Attachment: report.pdf, 2457600 bytes, file_id=..., message_id=12345, account_id=personal]
```

Attachments are not downloaded automatically. The attachment line records the metadata needed to retrieve the file in a future tool call.

---

## Tips {#tips}

**Use the Scratch area for initial imports.** When reading a channel for the first time, import into the Scratch Article for the relevant Section. You can review the content there and promote individual Blocks to proper Articles using the standard block operations.

**Use a small `maxMessages` for large channels.** A channel with thousands of unread messages will produce thousands of Blocks in one call if you do not limit the batch. Start with 50 or 100, review the output, and continue importing in batches.

**Sync state is per account, not per Article.** If you import messages from a channel into Article A on Monday and then import from the same channel into Article B on Wednesday, the Wednesday import will only download messages that arrived after the Monday run — because the sync state is tied to the channel, not to the target Article. To start fresh, ask the server administrator to clear the sync state for that channel.

**The tool reads, never writes.** `telegram_read_channel` cannot send messages, react to posts, or modify anything in your Telegram account. It connects as a read-only viewer.
