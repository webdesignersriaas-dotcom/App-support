# App Support Backend API

Backend-only Node.js API for support tickets, integrated with ERPNext/Frappe.

## Project Files

- `server.js` - Express API server and all routes
- `package.json` - scripts and dependencies
- `package-lock.json` - dependency lock file

## Setup

1. Install dependencies:
   - `npm install`
2. Create `.env` in repo root:

```env
PORT=3000
NODE_ENV=development

# ERPNext/Frappe
ERP_BASE_URL=https://your-erpnext-domain.com

# Option 1 (recommended): API key auth
ERP_API_KEY=your_erp_api_key
ERP_API_SECRET=your_erp_api_secret

# Option 2: Bearer token auth (leave empty if using API key/secret)
ERP_BEARER_TOKEN=

# Optional DocType overrides
ERP_TICKET_DOCTYPE=Support Ticket
ERP_MESSAGE_DOCTYPE=Support Ticket Message

# Request signing (recommended for production)
SUPPORT_ENFORCE_REQUEST_SIGNING=true
SUPPORT_APP_ID=your_mobile_app_id
SUPPORT_SIGNING_SECRET=a_long_random_secret
# Optional (default 300000 = 5 minutes)
REQUEST_SIGNATURE_MAX_SKEW_MS=300000

# Basic API protection (recommended)
# Comma-separated browser origins; leave empty to allow all.
CORS_ALLOWED_ORIGINS=https://yourapp.com,https://admin.yourapp.com
# In-memory IP rate limiting defaults:
REQUESTS_PER_WINDOW=120
REQUEST_WINDOW_MS=60000
```

3. Start server:
   - `npm start`
4. Base URL locally:
   - `http://localhost:3000`

### Flutter app signing config

When request signing is enabled on the backend, run Flutter with matching defines:

```bash
flutter run \
  --dart-define=SUPPORT_APP_ID=your_mobile_app_id \
  --dart-define=SUPPORT_SIGNING_SECRET=a_long_random_secret
```

## API Overview

- Base path: `/api/v1/support`
- Health check: `/api/health`
- ID in routes (`:id`) supports both ticket doc `name` and `ticket_number`
- JSON responses use this shape:
  - success case: `{ "success": true, "data": ... }`
  - error case: `{ "success": false, "message": "...", "error": "..." }`

---

## Endpoints Guide

### 1) Health Check

- **Method/URL:** `GET /api/health`
- **Purpose:** check API is running

Example:

```bash
curl -X GET "http://localhost:3000/api/health"
```

---

### 2) Create Ticket

- **Method/URL:** `POST /api/v1/support/tickets`
- **Required body fields:**
  - `user_id`
  - `user_name`
  - `user_email`
  - `user_phone`
  - `subject`
  - `description`
- **Optional body fields:**
  - `category`
  - `priority` (`low | medium | high | urgent`, default `medium`)

Example:

```bash
curl -X POST "http://localhost:3000/api/v1/support/tickets" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "USER_123",
    "user_name": "Rahul",
    "user_email": "rahul@example.com",
    "user_phone": "9999999999",
    "subject": "Order not delivered",
    "description": "My order is delayed by 5 days",
    "category": "delivery",
    "priority": "high"
  }'
```

---

### 3) Get User Tickets

- **Method/URL:** `GET /api/v1/support/tickets`
- **Query params:**
  - `user_id` (required)
  - `status` (optional: `open | in_progress | resolved | closed`)
  - `page` (optional, default `1`)
  - `limit` (optional, default `20`, max `100`)

Example:

```bash
curl -X GET "http://localhost:3000/api/v1/support/tickets?user_id=USER_123&status=open&page=1&limit=20"
```

---

### 4) Get Ticket Details (with messages)

- **Method/URL:** `GET /api/v1/support/tickets/:id`
- **Path param:**
  - `:id` can be ticket ID or ticket number (`TKT-2026-000001`)

Example:

```bash
curl -X GET "http://localhost:3000/api/v1/support/tickets/TKT-2026-000001"
```

---

### 5) Send Message to Ticket

- **Method/URL:** `POST /api/v1/support/tickets/:id/messages`
- **Required body fields:**
  - `message`
- **Common user message fields:**
  - `user_id`
  - `user_name`
  - `attachments` (array)
- **Agent message fields:**
  - `sender_type`: `"agent"`
  - `sender_id`
  - `sender_name`
  - `attachments` (array)

User message example:

```bash
curl -X POST "http://localhost:3000/api/v1/support/tickets/TKT-2026-000001/messages" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Any update on this ticket?",
    "user_id": "USER_123",
    "user_name": "Rahul",
    "attachments": []
  }'
```

Agent message example:

```bash
curl -X POST "http://localhost:3000/api/v1/support/tickets/TKT-2026-000001/messages" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "We are checking this and will update shortly.",
    "sender_type": "agent",
    "sender_id": "AGENT_1",
    "sender_name": "Support Team",
    "attachments": []
  }'
```

---

### 6) Get Ticket Messages

- **Method/URL:** `GET /api/v1/support/tickets/:id/messages`
- **Query params:**
  - `page` (optional, default `1`)
  - `limit` (optional, default `50`, max `100`)
  - `since` (optional ISO datetime, returns newer messages)

Example:

```bash
curl -X GET "http://localhost:3000/api/v1/support/tickets/TKT-2026-000001/messages?page=1&limit=50&since=2026-04-07T10:00:00.000Z"
```

---

### 7) Update Ticket

- **Method/URL:** `PATCH /api/v1/support/tickets/:id`
- **Allowed body fields (send at least one):**
  - `status` (`open | in_progress | resolved | closed`)
  - `priority` (`low | medium | high | urgent`)
  - `assigned_to`
  - `assigned_to_name`
  - `category`

Example:

```bash
curl -X PATCH "http://localhost:3000/api/v1/support/tickets/TKT-2026-000001" \
  -H "Content-Type: application/json" \
  -d '{
    "status": "in_progress",
    "assigned_to": "AGENT_1",
    "assigned_to_name": "Support Team",
    "priority": "high"
  }'
```

---

### 8) Mark Messages as Read

- **Method/URL:** `POST /api/v1/support/tickets/:id/messages/read`
- **Body options:**
  - send `message_ids` array to mark only selected messages
  - send empty body `{}` to mark all agent messages for that ticket

Example (specific IDs):

```bash
curl -X POST "http://localhost:3000/api/v1/support/tickets/TKT-2026-000001/messages/read" \
  -H "Content-Type: application/json" \
  -d '{
    "message_ids": ["MSG-0001", "MSG-0002"]
  }'
```

Example (all agent messages):

```bash
curl -X POST "http://localhost:3000/api/v1/support/tickets/TKT-2026-000001/messages/read" \
  -H "Content-Type: application/json" \
  -d '{}'
```

## Notes

- API internally stores tickets/messages in ERPNext DocTypes configured by:
  - `ERP_TICKET_DOCTYPE`
  - `ERP_MESSAGE_DOCTYPE`
- If ERP auth is missing (`ERP_API_KEY` + `ERP_API_SECRET`, or `ERP_BEARER_TOKEN`), calls will fail.
