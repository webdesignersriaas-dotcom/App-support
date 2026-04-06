# Postman Testing Guide for Support Ticket API

This guide explains how to test the Support Ticket API endpoints using Postman, especially for replying to tickets as an agent.

## Base URL
```
http://localhost:3000
```

For remote server, replace `localhost:3000` with your server IP and port.

---

## 1. CREATE A TICKET (User)

**Endpoint:** `POST /api/v1/support/tickets`

**Headers:**
```
Content-Type: application/json
```

**Body (JSON):**
```json
{
  "user_id": "gid://shopify/Customer/8971995087157",
  "user_name": "John Doe",
  "user_email": "john@example.com",
  "user_phone": "+1234567890",
  "subject": "Need help with my order",
  "description": "I haven't received my order yet. Can you please check?",
  "priority": "high",
  "category": "Order Issue"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "ticket": {
      "id": "c863dfbb-1db8-412d-b52d-b767d9be0a34",
      "ticket_number": "TKT-2026-000001",
      "user_id": null,
      "user_name": "John Doe",
      "user_email": "john@example.com",
      "user_phone": "+1234567890",
      "subject": "Need help with my order",
      "description": "I haven't received my order yet. Can you please check?",
      "status": "open",
      "priority": "high",
      "category": "Order Issue",
      "created_at": "2026-01-08T08:05:21.080Z",
      "updated_at": "2026-01-08T08:05:21.080Z",
      "metadata": {
        "original_user_id": "gid://shopify/Customer/8971995087157"
      }
    }
  }
}
```

**Note:** Save the `ticket.id` from the response - you'll need it for sending replies!

---

## 2. GET USER TICKETS

**Endpoint:** `GET /api/v1/support/tickets`

**Query Parameters:**
```
user_id: gid://shopify/Customer/8971995087157
status: open (optional)
page: 1 (optional)
limit: 20 (optional)
```

**Example URL:**
```
http://localhost:3000/api/v1/support/tickets?user_id=gid://shopify/Customer/8971995087157&status=open
```

**Response:**
```json
{
  "success": true,
  "data": {
    "tickets": [
      {
        "id": "c863dfbb-1db8-412d-b52d-b767d9be0a34",
        "ticket_number": "TKT-2026-000001",
        "user_id": null,
        "user_name": "John Doe",
        "user_email": "john@example.com",
        "subject": "Need help with my order",
        "status": "open",
        "priority": "high",
        "created_at": "2026-01-08T08:05:21.080Z"
      }
    ],
    "pagination": {
      "total": 1,
      "page": 1,
      "limit": 20,
      "pages": 1
    }
  }
}
```

---

## 3. GET TICKET DETAILS (With Messages)

**Endpoint:** `GET /api/v1/support/tickets/:id`

**URL Parameter:**
- `:id` = Ticket ID (UUID) **OR** Ticket Number (e.g., `TKT-2026-000001`)

**Example URLs:**
```
# Using Ticket ID (UUID)
http://localhost:3000/api/v1/support/tickets/c863dfbb-1db8-412d-b52d-b767d9be0a34

# Using Ticket Number
http://localhost:3000/api/v1/support/tickets/TKT-2026-000001
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
      "subject": "Need help with my order",
      "status": "open",
      "messages": []
    },
    "messages": []
  }
}
```

---

## 4. SEND MESSAGE (User Reply)

**Endpoint:** `POST /api/v1/support/tickets/:id/messages`

**Headers:**
```
Content-Type: application/json
```

**URL Parameter:**
- `:id` = Ticket ID (UUID) **OR** Ticket Number (e.g., `TKT-2026-000001`)

**Body (JSON) - User Message:**
```json
{
  "message": "Hello, I need an update on my order status.",
  "user_id": "gid://shopify/Customer/8971995087157",
  "user_name": "John Doe",
  "attachments": []
}
```

**Example URL:**
```
POST http://localhost:3000/api/v1/support/tickets/c863dfbb-1db8-412d-b52d-b767d9be0a34/messages
```

**Response:**
```json
{
  "success": true,
  "data": {
    "message": {
      "id": "abc123-def456-ghi789",
      "ticket_id": "c863dfbb-1db8-412d-b52d-b767d9be0a34",
      "sender_id": null,
      "sender_name": "John Doe",
      "sender_type": "user",
      "message": "Hello, I need an update on my order status.",
      "attachment_urls": [],
      "created_at": "2026-01-08T10:00:00.000Z",
      "is_read": false
    }
  }
}
```

---

## 5. SEND MESSAGE (Agent Reply) ⭐

**Endpoint:** `POST /api/v1/support/tickets/:id/messages`

**Headers:**
```
Content-Type: application/json
```

**URL Parameter:**
- `:id` = Ticket ID (UUID) **OR** Ticket Number (e.g., `TKT-2026-000001`)

**💡 Tip for Agents:** You can use the ticket number (e.g., `TKT-2026-000001`) instead of the UUID if you only have the ticket number from the customer!

**Body (JSON) - Agent Message:**
```json
{
  "message": "Hi John, I've checked your order. It's currently being processed and will be shipped within 24 hours.",
  "sender_id": "agent-001",
  "sender_name": "Support Agent",
  "sender_type": "agent",
  "attachments": []
}
```

**Example URLs:**
```
# Using Ticket ID (UUID)
POST http://localhost:3000/api/v1/support/tickets/c863dfbb-1db8-412d-b52d-b767d9be0a34/messages

# Using Ticket Number (easier for agents!)
POST http://localhost:3000/api/v1/support/tickets/TKT-2026-000001/messages
```

**Key Points for Agent Replies:**
- Set `sender_type: "agent"` (not "user")
- Provide `sender_id` and `sender_name` for the agent
- The message will appear as coming from the agent in the ticket chat

**Response:**
```json
{
  "success": true,
  "data": {
    "message": {
      "id": "xyz789-abc123-def456",
      "ticket_id": "c863dfbb-1db8-412d-b52d-b767d9be0a34",
      "sender_id": "agent-001",
      "sender_name": "Support Agent",
      "sender_type": "agent",
      "message": "Hi John, I've checked your order. It's currently being processed and will be shipped within 24 hours.",
      "attachment_urls": [],
      "created_at": "2026-01-08T10:05:00.000Z",
      "is_read": false
    }
  }
  }
}
```

---

## 6. GET TICKET MESSAGES

**Endpoint:** `GET /api/v1/support/tickets/:id/messages`

**URL Parameter:**
- `:id` = Ticket ID (UUID) **OR** Ticket Number (e.g., `TKT-2026-000001`)

**Query Parameters:**
```
page: 1 (optional)
limit: 50 (optional)
```

**Example URLs:**
```
# Using Ticket ID (UUID)
http://localhost:3000/api/v1/support/tickets/c863dfbb-1db8-412d-b52d-b767d9be0a34/messages?page=1&limit=50

# Using Ticket Number
http://localhost:3000/api/v1/support/tickets/TKT-2026-000001/messages?page=1&limit=50
```

**Response:**
```json
{
  "success": true,
  "data": {
    "messages": [
      {
        "id": "abc123-def456-ghi789",
        "ticket_id": "c863dfbb-1db8-412d-b52d-b767d9be0a34",
        "sender_name": "John Doe",
        "sender_type": "user",
        "message": "Hello, I need an update on my order status.",
        "created_at": "2026-01-08T10:00:00.000Z"
      },
      {
        "id": "xyz789-abc123-def456",
        "ticket_id": "c863dfbb-1db8-412d-b52d-b767d9be0a34",
        "sender_name": "Support Agent",
        "sender_type": "agent",
        "message": "Hi John, I've checked your order...",
        "created_at": "2026-01-08T10:05:00.000Z"
      }
    ],
    "pagination": {
      "total": 2,
      "page": 1,
      "limit": 50,
      "pages": 1
    }
  }
}
```

---

## 7. UPDATE TICKET STATUS (Agent Action) ⭐

**Endpoint:** `PATCH /api/v1/support/tickets/:id`

**Headers:**
```
Content-Type: application/json
```

**URL Parameter:**
- `:id` = Ticket ID (UUID) **OR** Ticket Number (e.g., `TKT-2026-000001`)

**Body (JSON) - Update Status:**
```json
{
  "status": "in_progress",
  "assigned_to": "agent-001",
  "assigned_to_name": "Support Agent",
  "priority": "high"
}
```

**Available Status Values:**
- `"open"` - Ticket is newly created
- `"in_progress"` - Agent is working on it
- `"resolved"` - Issue has been resolved
- `"closed"` - Ticket is closed

**Available Priority Values:**
- `"low"` - Low priority
- `"medium"` - Medium priority (default)
- `"high"` - High priority
- `"urgent"` - Urgent priority

**Example URLs:**
```
# Using Ticket ID (UUID)
PATCH http://localhost:3000/api/v1/support/tickets/c863dfbb-1db8-412d-b52d-b767d9be0a34

# Using Ticket Number
PATCH http://localhost:3000/api/v1/support/tickets/TKT-2026-000001
```

**Example 1: Change Status to "In Progress"**
```json
{
  "status": "in_progress",
  "assigned_to": "agent-001",
  "assigned_to_name": "John Agent"
}
```

**Example 2: Change Status to "Resolved"**
```json
{
  "status": "resolved"
}
```

**Example 3: Change Priority**
```json
{
  "priority": "urgent"
}
```

**Example 4: Assign Ticket to Agent**
```json
{
  "assigned_to": "agent-001",
  "assigned_to_name": "Support Agent",
  "status": "in_progress"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "ticket": {
      "id": "c863dfbb-1db8-412d-b52d-b767d9be0a34",
      "ticket_number": "TKT-2026-000001",
      "status": "in_progress",
      "priority": "high",
      "assigned_to": "agent-001",
      "assigned_to_name": "Support Agent",
      "updated_at": "2026-01-08T10:30:00.000Z"
    }
  }
}
```

---

## 8. MARK MESSAGES AS READ

**Endpoint:** `POST /api/v1/support/tickets/:id/messages/read`

**Headers:**
```
Content-Type: application/json
```

**URL Parameter:**
- `:id` = Ticket ID (UUID) **OR** Ticket Number (e.g., `TKT-2026-000001`)

**Body (JSON):**
```json
{
  "message_ids": ["abc123-def456-ghi789", "xyz789-abc123-def456"]
}
```

**Example URLs:**
```
# Using Ticket ID (UUID)
POST http://localhost:3000/api/v1/support/tickets/c863dfbb-1db8-412d-b52d-b767d9be0a34/messages/read

# Using Ticket Number
POST http://localhost:3000/api/v1/support/tickets/TKT-2026-000001/messages/read
```

---

## Complete Testing Flow Example

### Step 1: Create a ticket
```
POST http://localhost:3000/api/v1/support/tickets
Body: { "user_id": "gid://shopify/Customer/8971995087157", "user_name": "John Doe", ... }
→ Save ticket.id from response
```

### Step 2: Get ticket details
```
GET http://localhost:3000/api/v1/support/tickets/{ticket.id}
→ Verify ticket was created
```

### Step 3: User sends a message
```
POST http://localhost:3000/api/v1/support/tickets/{ticket.id}/messages
Body: { "message": "Hello, I need help", "user_id": "...", "user_name": "John Doe" }
```

### Step 4: Agent replies
```
POST http://localhost:3000/api/v1/support/tickets/{ticket.id}/messages
Body: { 
  "message": "Hi, how can I help you?", 
  "sender_id": "agent-001",
  "sender_name": "Support Agent",
  "sender_type": "agent"
}
```

### Step 5: Get all messages
```
GET http://localhost:3000/api/v1/support/tickets/{ticket.id}/messages
→ Verify both user and agent messages appear
```

---

## Important Notes

1. **Targeting a User:** To reply to a specific user's ticket, you need:
   - The `ticket.id` (UUID) **OR** `ticket.ticket_number` (e.g., `TKT-2026-000001`) from GET /api/v1/support/tickets with user_id
   - Use that ticket ID or ticket number in the URL: `/api/v1/support/tickets/{ticket.id}/messages` or `/api/v1/support/tickets/{ticket.ticket_number}/messages`
   - **💡 Tip:** Agents can use ticket numbers directly if they only have the ticket number from the customer!

2. **Agent vs User Messages:**
   - User messages: `sender_type: "user"` (default)
   - Agent messages: `sender_type: "agent"` (must be specified)

3. **Security:**
   - All endpoints require `user_id` for user operations
   - Agent operations should ideally have authentication (not implemented yet)

4. **Testing Different Users:**
   - Change `user_id` in query params to test different users
   - Each user will only see their own tickets

---

## Postman Collection Setup

1. Create a new Collection: "Support Ticket API"
2. Add environment variables:
   - `base_url`: `http://localhost:3000`
   - `ticket_id`: (will be set from responses)
   - `user_id`: `gid://shopify/Customer/8971995087157`
3. Use variables in requests:
   - `{{base_url}}/api/v1/support/tickets`
   - `{{base_url}}/api/v1/support/tickets/{{ticket_id}}/messages`

---

## Troubleshooting

**Error: "Authentication required"**
- Make sure `user_id` is included in the request

**Error: "Ticket not found"**
- Verify the ticket ID (UUID) or ticket number is correct
- Check if the ticket belongs to the user_id you're querying
- Make sure you're using the correct format: UUID (e.g., `c863dfbb-1db8-412d-b52d-b767d9be0a34`) or ticket number (e.g., `TKT-2026-000001`)

**Messages not appearing:**
- Check `sender_type` is set correctly ("user" or "agent")
- Verify ticket ID in URL matches the ticket you're replying to

