# My AI

## Message Editing

### Data layer (9 files)

- [Message.cs](../../Src/Libraries/WissensNest.Contracts/Entities/Message.cs) + [MessageDBEntity.cs](../../Src/Libraries/WissensNest.Persistent.SQLite/Entities/MessageDBEntity.cs) — added _IsStale bool_
- [MessageInfo.cs](../../Src/Libraries/WissensNest.Contracts/Models/MessageInfo.cs) — added _IsStale_ to the record
- [IMessageRepository.cs](../../Src/Libraries/WissensNest.Contracts/Interfaces/Repo/IMessageRepository.cs) — added _UpdateContentAsync_, _MarkStaleAfterAsync_, - _SoftDeleteFromAsync_
- [MessageRepository.cs](../../Src/Libraries/WissensNest.Persistent.SQLite/Repositories/MessageRepository.cs) — implemented all three, updated _ToDomain/ToEntity_ mappings

### API layer

- [Program.cs](../../Src/Services/WissensNest.API/Program.cs) — two new endpoints: _PATCH /messages/{id}/content_ (edit + mark later messages stale) and _DELETE /messages/{id}/from_ (remove stale tail before regenerate); _HandleGetMessages_ now returns IsStale
- [IMyAiClient.cs](../../Src/Libraries/WissensNest.Contracts/Interfaces/IMyAiClient.cs) + MyAiClient.cs — _UpdateMessageContentAsync_ and _DeleteMessagesFromAsync_

### UI layer

- [ChatMessageViewModel.cs](../../Src/Services/WissensNest.UI/Models/ChatMessageViewModel.cs) — added _IsStale_, updated constructor and _FromPersisted_
- [MessageBubble.razor](../../Src/Services/WissensNest.UI/Components/MessageBubble.razor) — Edit button (user messages only, Ctrl+Enter to save / - Escape to cancel), _stale-badge_ + _Regenerate_ button on stale assistant messages, - new _OnEditSaved_ and _OnRegenerate_ callbacks
- [Chat.razor](../../Src/Services/WissensNest.UI/Components/Pages/Chat.razor) — _HandleEditSaved_ (updates content, marks tail stale), _HandleRegenerate_ (deletes stale tail from DB, truncates local state, re-streams via StreamingService), _RebuildHistory_ helper. Note: the original _StreamResponseAsync_ extracted here has since been replaced by `StreamingService` (see article 18).
- [app.css](../../Src/Services/WissensNest.UI/wwwroot/app.css) — amber left-border for stale bubbles, _stale-badge_, amber _Regenerate_ button, edit-mode textarea styles

### Migration

[20260417120000_AddIsStaleToMessages.cs](../../Src/Libraries/WissensNest.Persistent.SQLite/Migrations/20260417120000_AddIsStaleToMessages.cs) + [snapshot](../../Src/Libraries/WissensNest.Persistent.SQLite/Migrations/WissensNestDbContextModelSnapshot.cs) updated — _IsStale bool DEFAULT false_ on the Messages table; applied automatically on next startup
