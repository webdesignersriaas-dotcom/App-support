# Support ticket system

Plug-and-play **Flutter** UI package plus **Node.js + PostgreSQL** REST API for customer support tickets (create, list, chat, agent messages).

## Repository layout

| Path | Description |
|------|----------------|
| [`flutter_support_tickets/`](./flutter_support_tickets/) | Dart package: screens, API client, `SupportTicketsScope` config. |
| [`backend/`](./backend/) | Express server: `/api/v1/support/...` endpoints. |

## Quick links

- **Flutter integration:** [flutter_support_tickets/README.md](./flutter_support_tickets/README.md)
- **API & database:** [backend/README.md](./backend/README.md)

## Minimal integration

1. Deploy **backend** (set `backend/.env` from `backend/.env.example`).
2. Add the package to your Flutter `pubspec.yaml` (path or Git dependency pointing at `flutter_support_tickets/`).
3. Wrap your app with `SupportTicketsScope` and set `SupportTicketsConfig.apiBaseUrl` to your deployed API origin.

Do **not** commit real `.env` files; use `.env.example` as a template.

## Use this repo from another Flutter app (Git dependency)

```yaml
dependencies:
  flutter_support_tickets:
    git:
      url: https://github.com/jagmohan0908/support-ticket-app.git
      ref: main
      path: flutter_support_tickets
```
