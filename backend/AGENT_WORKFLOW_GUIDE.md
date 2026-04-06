# Agent Workflow Guide - Support Ticket System

This guide explains how agents can manage support tickets using the API (via Postman or admin panel).

---

## Agent Actions Overview

Agents can perform the following actions:
1. **View all tickets** - See all tickets in the system
2. **View ticket details** - See ticket info and chat history
3. **Change ticket status** - Update status (open → in_progress → resolved → closed)
4. **Assign tickets** - Assign tickets to themselves or other agents
5. **Change priority** - Update ticket priority (low, medium, high, urgent)
6. **Reply to tickets** - Send messages to users
7. **Mark messages as read** - Mark messages as read

---

## 1. VIEW ALL TICKETS (Agent View)

**Endpoint:** `GET /api/v1/support/tickets`

**Note:** Currently, this endpoint requires `user_id`. For admin/agent view, you can:
- Omit `user_id` to get all tickets (if backend allows)
- Or query without user_id filter (requires backend modification)

**Example URL:**
```
GET http://localhost:3000/api/v1/support/tickets?status=open&page=1&limit=50
```

**Query Parameters:**
- `status` (optional): Filter by status (`open`, `in_progress`, `resolved`, `closed`)
- `page` (optional): Page number (default: 1)
- `limit` (optional): Items per page (default: 20)

**Response:**
```json
{
  "success": true,
  "data": {
    "tickets": [
      {
        "id": "c863dfbb-1db8-412d-b52d-b767d9be0a34",
        "ticket_number": "TKT-2026-000001",
        "user_name": "John Doe",
        "user_email": "john@example.com",
        "subject": "Need help with my order",
        "status": "open",
        "priority": "high",
        "created_at": "2026-01-08T08:05:21.080Z"
      }
    ],
    "pagination": {
      "total": 10,
      "page": 1,
      "limit": 50,
      "pages": 1
    }
  }
}
```

---

## 2. VIEW TICKET DETAILS

**Endpoint:** `GET /api/v1/support/tickets/:id`

**Example URL:**
```
GET http://localhost:3000/api/v1/support/tickets/c863dfbb-1db8-412d-b52d-b767d9be0a34
```

**Response:**
```json
{
  "success": true,
  "data": {
    "ticket": {
      "id": "c863dfbb-1db8-412d-b52d-b767d9be0a34",
      "ticket_number": "TKT-2026-000001",
      "user_name": "John Doe",
      "user_email": "john@example.com",
      "user_phone": "+1234567890",
      "subject": "Need help with my order",
      "description": "I haven't received my order yet",
      "status": "open",
      "priority": "high",
      "assigned_to": null,
      "assigned_to_name": null,
      "created_at": "2026-01-08T08:05:21.080Z",
      "updated_at": "2026-01-08T08:05:21.080Z"
    },
    "messages": [
      {
        "id": "msg-123",
        "sender_name": "John Doe",
        "sender_type": "user",
        "message": "Hello, I need help",
        "created_at": "2026-01-08T10:00:00.000Z"
      }
    ]
  }
}
```

---

## 3. CHANGE TICKET STATUS

**Endpoint:** `PATCH /api/v1/support/tickets/:id`

**Headers:**
```
Content-Type: application/json
```

**Body (JSON):**
```json
{
  "status": "in_progress"
}
```

**Available Status Values:**
- `"open"` - New ticket, not yet assigned
- `"in_progress"` - Agent is working on it
- `"resolved"` - Issue has been resolved
- `"closed"` - Ticket is closed

**Example URL:**
```
PATCH http://localhost:3000/api/v1/support/tickets/c863dfbb-1db8-412d-b52d-b767d9be0a34
```

**Common Workflow:**

**Step 1: Assign and Start Working**
```json
{
  "status": "in_progress",
  "assigned_to": "agent-001",
  "assigned_to_name": "John Agent"
}
```

**Step 2: Mark as Resolved**
```json
{
  "status": "resolved"
}
```

**Step 3: Close Ticket**
```json
{
  "status": "closed"
}
```

---

## 4. ASSIGN TICKET TO AGENT

**Endpoint:** `PATCH /api/v1/support/tickets/:id`

**Body (JSON):**
```json
{
  "assigned_to": "agent-001",
  "assigned_to_name": "Support Agent",
  "status": "in_progress"
}
```

**Fields:**
- `assigned_to`: Agent ID (can be any identifier)
- `assigned_to_name`: Agent display name
- `status`: Usually set to `"in_progress"` when assigning

---

## 5. CHANGE TICKET PRIORITY

**Endpoint:** `PATCH /api/v1/support/tickets/:id`

**Body (JSON):**
```json
{
  "priority": "urgent"
}
```

**Available Priority Values:**
- `"low"` - Low priority
- `"medium"` - Medium priority (default)
- `"high"` - High priority
- `"urgent"` - Urgent priority

---

## 6. REPLY TO TICKET (Agent Message)

**Endpoint:** `POST /api/v1/support/tickets/:id/messages`

**Body (JSON):**
```json
{
  "message": "Hi John, I've checked your order. It will be shipped tomorrow.",
  "sender_type": "agent",
  "sender_id": "agent-001",
  "sender_name": "Support Agent",
  "attachments": []
}
```

**Important:** Always set `"sender_type": "agent"` for agent messages!

---

## 7. MARK MESSAGES AS READ

**Endpoint:** `POST /api/v1/support/tickets/:id/messages/read`

**Body (JSON) - Mark all as read:**
```json
{}
```

**Body (JSON) - Mark specific messages:**
```json
{
  "message_ids": ["msg-123", "msg-456"]
}
```

---

## Complete Agent Workflow Example

### Scenario: Agent handles a new ticket

**Step 1: View all open tickets**
```
GET /api/v1/support/tickets?status=open
→ Find ticket ID: c863dfbb-1db8-412d-b52d-b767d9be0a34
```

**Step 2: View ticket details**
```
GET /api/v1/support/tickets/c863dfbb-1db8-412d-b52d-b767d9be0a34
→ See user's question and messages
```

**Step 3: Assign ticket to yourself**
```
PATCH /api/v1/support/tickets/c863dfbb-1db8-412d-b52d-b767d9be0a34
Body: {
  "status": "in_progress",
  "assigned_to": "agent-001",
  "assigned_to_name": "Support Agent"
}
```

**Step 4: Change priority if needed**
```
PATCH /api/v1/support/tickets/c863dfbb-1db8-412d-b52d-b767d9be0a34
Body: {
  "priority": "high"
}
```

**Step 5: Reply to user**
```
POST /api/v1/support/tickets/c863dfbb-1db8-412d-b52d-b767d9be0a34/messages
Body: {
  "message": "Hi, I'm looking into your order. Let me check...",
  "sender_type": "agent",
  "sender_id": "agent-001",
  "sender_name": "Support Agent"
}
```

**Step 6: Continue conversation**
```
POST /api/v1/support/tickets/c863dfbb-1db8-412d-b52d-b767d9be0a34/messages
Body: {
  "message": "Your order will be shipped tomorrow. Tracking number: TRACK123",
  "sender_type": "agent",
  "sender_id": "agent-001",
  "sender_name": "Support Agent"
}
```

**Step 7: Mark as resolved**
```
PATCH /api/v1/support/tickets/c863dfbb-1db8-412d-b52d-b767d9be0a34
Body: {
  "status": "resolved"
}
```

**Step 8: Close ticket (optional)**
```
PATCH /api/v1/support/tickets/c863dfbb-1db8-412d-b52d-b767d9be0a34
Body: {
  "status": "closed"
}
```

---

## Status Flow Diagram

```
┌─────────┐
│  OPEN   │ ← New ticket created
└────┬────┘
     │
     │ Agent assigns & starts working
     ▼
┌──────────────┐
│ IN_PROGRESS  │ ← Agent is working on it
└────┬─────────┘
     │
     │ Issue resolved
     ▼
┌──────────┐
│ RESOLVED │ ← Issue fixed
└────┬─────┘
     │
     │ Final closure
     ▼
┌─────────┐
│ CLOSED  │ ← Ticket closed
└─────────┘
```

---

## Quick Reference

| Action | Method | Endpoint | Key Field |
|--------|--------|----------|-----------|
| View Tickets | GET | `/api/v1/support/tickets` | `status` (query param) |
| View Details | GET | `/api/v1/support/tickets/:id` | - |
| Change Status | PATCH | `/api/v1/support/tickets/:id` | `status` |
| Assign Ticket | PATCH | `/api/v1/support/tickets/:id` | `assigned_to` |
| Change Priority | PATCH | `/api/v1/support/tickets/:id` | `priority` |
| Reply | POST | `/api/v1/support/tickets/:id/messages` | `sender_type: "agent"` |
| Mark Read | POST | `/api/v1/support/tickets/:id/messages/read` | - |

---

## Tips for Agents

1. **Always set `sender_type: "agent"`** when replying - this ensures messages appear as agent messages
2. **Update status** as you work: `open` → `in_progress` → `resolved` → `closed`
3. **Assign tickets** to track who's handling what
4. **Use priority** to highlight urgent tickets
5. **Mark messages as read** to track what you've seen

---

## Postman Collection Setup

1. Create environment variables:
   - `base_url`: `http://localhost:3000`
   - `ticket_id`: (will be set from responses)
   - `agent_id`: `agent-001`
   - `agent_name`: `Support Agent`

2. Use variables in requests:
   - `{{base_url}}/api/v1/support/tickets/{{ticket_id}}`
   - `{{agent_id}}` and `{{agent_name}}` in request bodies

