# 🚀 Agent Quick Reference - View & Reply to Tickets

## 📋 What You Need

- **Base URL:** `http://localhost:3000` (or your server URL)
- **Ticket Number:** `TKT-2026-000001` (from customer or ticket list)

---

## 🔍 STEP 1: View Ticket & Messages

**Get all ticket details including messages:**

```bash
GET http://localhost:3000/api/v1/support/tickets/TKT-2026-000001
```

**Response includes:**
- Ticket info (subject, status, customer name, etc.)
- All messages (user + agent messages)

**Example Response:**
```json
{
  "success": true,
  "data": {
    "ticket": {
      "ticket_number": "TKT-2026-000001",
      "subject": "Need help with order",
      "user_name": "John Doe",
      "status": "open"
    },
    "messages": [
      {
        "sender_name": "John Doe",
        "sender_type": "user",
        "message": "Hello, I need help...",
        "created_at": "2026-01-08T10:00:00.000Z"
      }
    ]
  }
}
```

---

## 💬 STEP 2: Reply to Ticket

**Send agent message:**

```bash
POST http://localhost:3000/api/v1/support/tickets/TKT-2026-000001/messages
Content-Type: application/json

{
  "message": "Hi John, I'm here to help!",
  "sender_type": "agent",
  "sender_name": "Support Agent",
  "sender_id": "agent-001"
}
```

**⚠️ IMPORTANT:** Always set `"sender_type": "agent"` for agent replies!

**Response:**
```json
{
  "success": true,
  "data": {
    "message": {
      "id": "msg-123",
      "sender_type": "agent",
      "message": "Hi John, I'm here to help!",
      "created_at": "2026-01-08T10:05:00.000Z"
    }
  }
}
```

---

## 📝 STEP 3: Update Ticket Status (Optional)

**Change ticket status:**

```bash
PATCH http://localhost:3000/api/v1/support/tickets/TKT-2026-000001
Content-Type: application/json

{
  "status": "in_progress",
  "assigned_to": "agent-001",
  "assigned_to_name": "Support Agent"
}
```

**Status Options:**
- `"open"` - New ticket
- `"in_progress"` - Agent working on it
- `"resolved"` - Issue resolved
- `"closed"` - Ticket closed

---

## 🧪 Test with cURL

**1. View Ticket:**
```bash
curl http://localhost:3000/api/v1/support/tickets/TKT-2026-000001
```

**2. Reply:**
```bash
curl -X POST http://localhost:3000/api/v1/support/tickets/TKT-2026-000001/messages \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Hello, I can help you with that!",
    "sender_type": "agent",
    "sender_name": "Support Agent",
    "sender_id": "agent-001"
  }'
```

**3. Update Status:**
```bash
curl -X PATCH http://localhost:3000/api/v1/support/tickets/TKT-2026-000001 \
  -H "Content-Type: application/json" \
  -d '{
    "status": "in_progress",
    "assigned_to": "agent-001",
    "assigned_to_name": "Support Agent"
  }'
```

---

## 📱 For ERPNext/Frappe

**Python Example:**
```python
import requests

# View ticket
ticket_number = "TKT-2026-000001"
response = requests.get(f"http://localhost:3000/api/v1/support/tickets/{ticket_number}")
ticket_data = response.json()

# Reply
requests.post(
    f"http://localhost:3000/api/v1/support/tickets/{ticket_number}/messages",
    json={
        "message": "Your issue is resolved!",
        "sender_type": "agent",
        "sender_name": "Support Agent",
        "sender_id": "agent-001"
    }
)
```

---

## ✅ Complete Workflow

1. **Customer creates ticket** → Gets ticket number `TKT-2026-000001`
2. **Agent views ticket:**
   ```
   GET /api/v1/support/tickets/TKT-2026-000001
   ```
3. **Agent replies:**
   ```
   POST /api/v1/support/tickets/TKT-2026-000001/messages
   Body: { "message": "...", "sender_type": "agent", ... }
   ```
4. **Customer sees reply** in Flutter app
5. **Agent updates status** (optional):
   ```
   PATCH /api/v1/support/tickets/TKT-2026-000001
   Body: { "status": "resolved" }
   ```

---

## 🎯 Key Points

✅ Use **ticket number** (`TKT-2026-000001`) - easier than UUID  
✅ Always set `"sender_type": "agent"` when replying  
✅ Messages appear in Flutter app immediately  
✅ No authentication needed (add for production)

---

**Need help?** Check `ERPNext_INTEGRATION_GUIDE.md` for detailed ERPNext integration!
