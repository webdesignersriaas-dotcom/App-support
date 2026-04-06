# flutter_support_tickets

Self-contained **support ticket** UI for Flutter: ticket list, create form, and chat thread. Works with the REST API implemented in this repo under `backend/` (Node.js + PostgreSQL).

**Full backend architecture and end-to-end flow (API + DB + app + agents):** see [`../backend/README.md`](../backend/README.md) in this repository.

## Add to your app

### 1. Dependency

From your app `pubspec.yaml`:

```yaml
dependencies:
  flutter_support_tickets:
    path: ./flutter_support_tickets
```

Or from Git after you publish or use a submodule:

```yaml
dependencies:
  flutter_support_tickets:
    git:
      url: https://github.com/YOUR_ORG/YOUR_REPO.git
      path: flutter_support_tickets
```

### 2. Wrap your app

Above `MaterialApp` (so routes can read config), wrap with `SupportTicketsScope`:

```dart
import 'package:flutter_support_tickets/flutter_support_tickets.dart';

SupportTicketsScope(
  config: SupportTicketsConfig(
    apiBaseUrl: 'https://your-api.example.com',
    defaultAvatarUrlOrAsset: 'https://...' // or 'assets/images/avatar.png'
    ticketCreatedWebhookUrl: null, // optional n8n / automation URL
    resolveUser: (context) {
      // Map your auth user → SupportTicketsUser
      final u = YourAuth.of(context).currentUser;
      if (u == null) return null;
      return SupportTicketsUser(
        id: u.id,
        name: u.name,
        firstName: u.firstName,
        email: u.email,
        phone: u.phone,
        picture: u.avatarUrl,
        userUrl: u.profileImageUrl,
      );
    },
  ),
  child: MaterialApp(
    // routes: { ...supportTicketsRouteMap(), ...yourRoutes },
  ),
)
```

### 3. Routes

Use the same path strings as your app already uses, or import:

- `SupportTicketsPaths.list` → `TicketListScreen`
- `SupportTicketsPaths.create` → `CreateTicketScreen`

`TicketChatScreen(ticketId: id)` is opened via `Navigator.push` from the list (no global route required).

You can merge `supportTicketsRouteMap()` into your `routes` map.

### 4. Backend

Deploy the API from `backend/` (see `backend/README.md`). Point `apiBaseUrl` at that server (scheme + host, no path suffix).

## What you customize per app

| Item | Where |
|------|--------|
| API URL | `SupportTicketsConfig.apiBaseUrl` — **only this** changes the server; paths stay `/api/v1/support/...` unless you fork the package |
| Optional webhook after create | `ticketCreatedWebhookUrl` (or `null`) |
| Logged-in user mapping | `resolveUser` — swap in your auth layer |
| Default avatar | `defaultAvatarUrlOrAsset` (network or `assets/...`) |

**This Siya app** centralizes those values in **`lib/support_tickets_binding.dart`**. In another project, duplicate that pattern: one `SupportTicketsConfig` (or builder) and wrap **`MaterialApp`** with **`SupportTicketsScope`**.

**Database username/password** belong only on the **server** (`backend/.env`), not in the Flutter app. See **[`../backend/README.md`](../backend/README.md)** → “Where to change URLs and credentials”.

## Transitive dependencies

`dio`, `bot_toast`, `intl`, `cached_network_image` — ensure your app already uses compatible versions or let Pub resolve them.
