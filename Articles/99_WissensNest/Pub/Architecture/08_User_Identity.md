# WissensNest — User Identity

## Why No Passwords

WissensNest is a private home assistant shared by a family of a few people on the same local network. Passwords would add friction without adding meaningful security: the network itself is already trusted, and the people using the tool are known to each other. Instead, identity is established through a simple two-layer model that gives each person a stable ID without requiring any sign-up process.

---

## Two Layers

### Browser Layer — localStorage

Each browser stores two values in `localStorage`:

| Key | Value |
| --- | --- |
| `wn_user_id` | A UUID that identifies this person on this browser |
| `wn_user_name` | The display name chosen by the person |

The UUID is generated automatically the first time someone opens the app in a browser that has no stored identity. It persists across page reloads, tab closes, and browser restarts — as long as the user does not clear their browser storage.

This layer alone is enough for a single device. The problem it does not solve is the second device.

### Server Layer — Users Table

A `Users` table in the database holds the canonical name registry. Each row maps a UUID to a display name:

| Column | Purpose |
| --- | --- |
| `Id` (UUID) | The same value stored as `wn_user_id` in the browser that registered |
| `Name` | Human-readable display name |

When someone enters their name for the first time, the app calls `POST /users` with their local UUID as the proposed ID. The server creates the record using that UUID. From this point on, the server and the browser agree on the same identity.

---

## Cross-Device Claim Flow

When someone opens the app on a device that has no stored identity, the app fetches the user list from the server and shows a picker:

```
"Who are you?"

  ○ Mama
  ○ Papa
  ○ Anna

  [ I'm new ]
```

Selecting a name copies that person's UUID from the server record into the new browser's localStorage. No server call is made for the selection itself — the server already has the record. After this, the new browser has the same UUID as the person's other devices, and the identity is consistent.

If the person is genuinely new (not yet in the list), they click "I'm new", enter their name, and a new record is created on the server.

---

## The Name Badge

After identity is established, the person's name appears in a small badge in the top-left corner of the sidebar, next to the application name. Clicking the badge opens a rename dialog. Renaming updates both the server record and the local browser storage.

The badge is the only visible sign of identity in the current version. There is no account dashboard, no login screen, and no session management — the browser localStorage is the session.

---

## Scope and Ownership — Planned

The current identity system is a foundation. The UUID is stored and stable, but the application does not yet use it to filter or restrict anything. All users see all projects, conversations, and articles regardless of who created them.

The next planned layer is **scopes**:

| Scope type | Description |
| --- | --- |
| **Common** | Visible and writable by everyone |
| **Personal** | Visible and writable by the owner only |
| **Shared** | Visible by everyone, writable by the owner |

Projects will carry an `OwnerId` (nullable — `null` means common) and a `Visibility` flag. The UI will let each person filter to see only their own content, only common content, or everything.

The identity system described in this article is the prerequisite for that work. No changes to identity infrastructure will be needed when scopes are introduced — the UUID is already stored in the database and in the browser.

---

## Security Boundary

This identity system provides **user association**, not **access control**. Anyone on the home network can open the app and pick any name from the list. This is acceptable for a trusted LAN environment.

When scopes are introduced, the same constraint applies: scope enforcement happens at the UI layer and relies on the client correctly reporting its identity. There is no server-side authentication token, no session cookie, and no cryptographic verification of identity claims. This is a deliberate design choice for a private home tool, not an oversight.
