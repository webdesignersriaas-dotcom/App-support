# ERPNext/Frappe Integration Guide for Support Tickets

## 📋 Overview

This guide explains how ERPNext/Frappe agents can:
1. **View ticket messages** from your Flutter app's support ticket system
2. **Reply to tickets** via API
3. **Manage tickets** (update status, assign, etc.)

---

## 🔌 Backend API Status

Your backend is **ready** and supports:
- ✅ Get ticket details with messages
- ✅ Send agent replies
- ✅ View all messages in a ticket
- ✅ Update ticket status
- ✅ Use ticket number OR ticket ID

**Base URL:** `http://localhost:3000` (or your production URL)

---

## 🎯 Step-by-Step: How Agents View & Reply

### **Step 1: Get Ticket Details (View Messages)**

**Endpoint:** `GET /api/v1/support/tickets/:id`

**You can use:**
- Ticket ID (UUID): `c863dfbb-1db8-412d-b52d-b767d9be0a34`
- **OR** Ticket Number: `TKT-2026-000001` ⭐ (Easier for agents!)

**Example Request:**
```bash
GET http://localhost:3000/api/v1/support/tickets/TKT-2026-000001
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
      "priority": "high",
      "created_at": "2026-01-08T08:05:21.080Z"
    },
    "messages": [
      {
        "id": "msg-001",
        "sender_name": "John Doe",
        "sender_type": "user",
        "message": "Hello, I need help with my order #12345",
        "created_at": "2026-01-08T10:00:00.000Z",
        "is_read": false
      },
      {
        "id": "msg-002",
        "sender_name": "Support Agent",
        "sender_type": "agent",
        "message": "Hi John, I'll help you with that.",
        "created_at": "2026-01-08T10:05:00.000Z",
        "is_read": true
      }
    ]
  }
}
```

---

### **Step 2: Reply to Ticket (Send Agent Message)**

**Endpoint:** `POST /api/v1/support/tickets/:id/messages`

**Important:** Set `sender_type: "agent"` to mark it as an agent reply!

**Example Request:**
```bash
POST http://localhost:3000/api/v1/support/tickets/TKT-2026-000001/messages
Content-Type: application/json

{
  "message": "Hi John, I've checked your order. It's currently being processed and will be shipped within 24 hours.",
  "sender_type": "agent",
  "sender_id": "agent-001",
  "sender_name": "Support Agent",
  "attachments": []
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "message": {
      "id": "msg-003",
      "ticket_id": "c863dfbb-1db8-412d-b52d-b767d9be0a34",
      "sender_id": "agent-001",
      "sender_name": "Support Agent",
      "sender_type": "agent",
      "message": "Hi John, I've checked your order...",
      "created_at": "2026-01-08T10:10:00.000Z",
      "is_read": false
    }
  }
}
```

---

### **Step 3: Update Ticket Status (Optional)**

**Endpoint:** `PATCH /api/v1/support/tickets/:id`

**Example Request:**
```bash
PATCH http://localhost:3000/api/v1/support/tickets/TKT-2026-000001
Content-Type: application/json

{
  "status": "in_progress",
  "assigned_to": "agent-001",
  "assigned_to_name": "Support Agent",
  "priority": "high"
}
```

---

## 🔧 ERPNext/Frappe Integration Methods

### **Method 1: Python Script (Recommended)**

Create a Python script in ERPNext to interact with your API:

```python
# File: erpnext_integration/support_ticket_api.py

import requests
import json
from frappe import _

class SupportTicketAPI:
    def __init__(self, base_url="http://localhost:3000"):
        self.base_url = base_url
        self.api_base = f"{base_url}/api/v1/support"
    
    def get_ticket_details(self, ticket_number):
        """Get ticket details with all messages"""
        url = f"{self.api_base}/tickets/{ticket_number}"
        response = requests.get(url)
        
        if response.status_code == 200:
            return response.json()
        else:
            frappe.throw(f"Error fetching ticket: {response.text}")
    
    def send_agent_reply(self, ticket_number, message, agent_name, agent_id=None):
        """Send agent reply to ticket"""
        url = f"{self.api_base}/tickets/{ticket_number}/messages"
        
        payload = {
            "message": message,
            "sender_type": "agent",
            "sender_name": agent_name,
            "sender_id": agent_id or agent_name,
            "attachments": []
        }
        
        headers = {"Content-Type": "application/json"}
        response = requests.post(url, json=payload, headers=headers)
        
        if response.status_code == 201:
            return response.json()
        else:
            frappe.throw(f"Error sending message: {response.text}")
    
    def update_ticket_status(self, ticket_number, status, assigned_to=None, assigned_to_name=None):
        """Update ticket status"""
        url = f"{self.api_base}/tickets/{ticket_number}"
        
        payload = {"status": status}
        if assigned_to:
            payload["assigned_to"] = assigned_to
        if assigned_to_name:
            payload["assigned_to_name"] = assigned_to_name
        
        headers = {"Content-Type": "application/json"}
        response = requests.patch(url, json=payload, headers=headers)
        
        if response.status_code == 200:
            return response.json()
        else:
            frappe.throw(f"Error updating ticket: {response.text}")
```

---

### **Method 2: ERPNext Custom DocType (Using Server Script & Client Script)**

Create a custom DocType in ERPNext to manage support tickets using **Server Scripts** and **Client Scripts**:

**1. Create DocType: "Support Ticket Integration"**

**Fields:**
- `ticket_number` (Data) - Ticket number from Flutter app
- `subject` (Data) - Ticket subject
- `status` (Select) - open, in_progress, resolved, closed
- `customer_name` (Data) - Customer name
- `customer_email` (Data) - Customer email
- `priority` (Select) - low, medium, high, urgent
- `agent_message` (Text Editor) - For replying
- `refresh_messages` (Button) - Button to refresh messages
- `send_reply` (Button) - Button to send reply

**2. Create Server Script:**

Go to **Customization → Server Script** and create a new script:

**Script Type:** `DocType Event`
**Reference DocType:** `Support Ticket Integration`
**Event:** `on_update` or `before_save`

```python
# Server Script (Python) - Runs on server side
import frappe
import requests
import json

def on_update(doc, method):
    """When agent updates ticket in ERPNext"""
    
    # Your API base URL
    API_BASE_URL = "http://localhost:3000"  # Change to your server URL
    
    if not doc.ticket_number:
        frappe.throw("Ticket Number is required")
    
    # If agent sent a message, send it via API
    if doc.agent_message and doc.agent_message.strip():
        api_url = f"{API_BASE_URL}/api/v1/support/tickets/{doc.ticket_number}/messages"
        
        payload = {
            "message": doc.agent_message,
            "sender_type": "agent",
            "sender_name": frappe.session.user_fullname or frappe.session.user,
            "sender_id": frappe.session.user,
            "attachments": []
        }
        
        try:
            response = requests.post(api_url, json=payload, timeout=10)
            if response.status_code == 201:
                frappe.msgprint("Message sent successfully!")
                # Clear message after sending
                doc.agent_message = ""
            else:
                frappe.throw(f"Error sending message: {response.text}")
        except Exception as e:
            frappe.throw(f"Failed to send message: {str(e)}")
    
    # Update status if changed
    if doc.status:
        api_url = f"{API_BASE_URL}/api/v1/support/tickets/{doc.ticket_number}"
        payload = {
            "status": doc.status,
            "assigned_to": frappe.session.user,
            "assigned_to_name": frappe.session.user_fullname or frappe.session.user
        }
        
        try:
            response = requests.patch(api_url, json=payload, timeout=10)
            if response.status_code != 200:
                frappe.throw(f"Error updating status: {response.text}")
        except Exception as e:
            frappe.throw(f"Failed to update status: {str(e)}")

def on_load(doc, method):
    """When ticket is loaded, fetch latest data from API"""
    
    API_BASE_URL = "http://localhost:3000"  # Change to your server URL
    
    if not doc.ticket_number:
        return
    
    try:
        api_url = f"{API_BASE_URL}/api/v1/support/tickets/{doc.ticket_number}"
        response = requests.get(api_url, timeout=10)
        
        if response.status_code == 200:
            ticket_data = response.json()
            if ticket_data.get('success') and ticket_data.get('data'):
                ticket = ticket_data['data']['ticket']
                
                # Update local fields
                doc.subject = ticket.get('subject', '')
                doc.status = ticket.get('status', 'open')
                doc.customer_name = ticket.get('user_name', '')
                doc.customer_email = ticket.get('user_email', '')
                doc.priority = ticket.get('priority', 'medium')
    except Exception as e:
        frappe.msgprint(f"Could not fetch ticket details: {str(e)}", indicator="orange")
```

**3. Create Client Script:**

Go to **Customization → Client Script** and create a new script:

**Script Type:** `Form`
**Reference DocType:** `Support Ticket Integration`
**Script:** (JavaScript)

```javascript
// Client Script (JavaScript) - Runs in browser

frappe.ui.form.on('Support Ticket Integration', {
    refresh: function(frm) {
        // Add custom button to refresh messages
        if (frm.doc.ticket_number) {
            frm.add_custom_button(__('Refresh Messages'), function() {
                refresh_ticket_messages(frm);
            });
            
            frm.add_custom_button(__('View All Messages'), function() {
                view_all_messages(frm);
            });
        }
    },
    
    ticket_number: function(frm) {
        // Auto-load ticket when ticket number is entered
        if (frm.doc.ticket_number) {
            refresh_ticket_messages(frm);
        }
    }
});

// Function to refresh ticket messages
function refresh_ticket_messages(frm) {
    if (!frm.doc.ticket_number) {
        frappe.msgprint("Please enter a ticket number");
        return;
    }
    
    frappe.call({
        method: 'frappe.client.get',
        args: {
            doctype: 'Support Ticket Integration',
            name: frm.doc.name || frm.doc.ticket_number
        },
        callback: function(r) {
            if (r.message) {
                frm.reload_doc();
            }
        }
    });
}

// Function to view all messages in a dialog
function view_all_messages(frm) {
    if (!frm.doc.ticket_number) {
        frappe.msgprint("Please enter a ticket number");
        return;
    }
    
    // Call server script to get messages
    frappe.call({
        method: 'your_app.api.support_tickets.get_ticket_messages',  // See Method 3 for this
        args: {
            ticket_number: frm.doc.ticket_number
        },
        callback: function(r) {
            if (r.message && r.message.success) {
                show_messages_dialog(r.message.data.messages);
            } else {
                frappe.msgprint("Could not fetch messages");
            }
        }
    });
}

// Show messages in a dialog
function show_messages_dialog(messages) {
    let html = '<div style="max-height: 500px; overflow-y: auto;">';
    
    messages.forEach(function(msg) {
        const isAgent = msg.sender_type === 'agent';
        const bgColor = isAgent ? '#e3f2fd' : '#f5f5f5';
        const align = isAgent ? 'right' : 'left';
        
        html += `
            <div style="margin: 10px 0; padding: 10px; background: ${bgColor}; border-radius: 5px; text-align: ${align};">
                <strong>${msg.sender_name}</strong> (${msg.sender_type})
                <br>
                <div style="margin-top: 5px;">${msg.message}</div>
                <small style="color: #666;">${frappe.datetime.str_to_user(msg.created_at)}</small>
            </div>
        `;
    });
    
    html += '</div>';
    
    let d = new frappe.ui.Dialog({
        title: 'Ticket Messages',
        fields: [
            {
                fieldtype: 'HTML',
                options: html
            }
        ]
    });
    
    d.show();
}

// Auto-save when agent message is entered
frappe.ui.form.on('Support Ticket Integration', {
    agent_message: function(frm) {
        // Optional: Auto-save when message is entered
        // frm.save();
    }
});
```

**4. Create Server Script for Getting Messages (API Method):**

Go to **Customization → Server Script** and create another script:

**Script Type:** `API`
**API Method:** `your_app.api.support_tickets.get_ticket_messages`

```python
# Server Script - API Method
import frappe
import requests

@frappe.whitelist()
def get_ticket_messages(ticket_number):
    """Get ticket messages for ERPNext"""
    API_BASE_URL = "http://localhost:3000"  # Change to your server URL
    api_url = f"{API_BASE_URL}/api/v1/support/tickets/{ticket_number}"
    
    try:
        response = requests.get(api_url, timeout=10)
        if response.status_code == 200:
            return response.json()
        else:
            frappe.throw(f"Error: {response.text}")
    except Exception as e:
        frappe.throw(f"Failed to fetch ticket: {str(e)}")

@frappe.whitelist()
def reply_to_ticket(ticket_number, message):
    """Send agent reply from ERPNext"""
    API_BASE_URL = "http://localhost:3000"  # Change to your server URL
    api_url = f"{API_BASE_URL}/api/v1/support/tickets/{ticket_number}/messages"
    
    payload = {
        "message": message,
        "sender_type": "agent",
        "sender_name": frappe.session.user_fullname or frappe.session.user,
        "sender_id": frappe.session.user,
        "attachments": []
    }
    
    try:
        response = requests.post(api_url, json=payload, timeout=10)
        if response.status_code == 201:
            return response.json()
        else:
            frappe.throw(f"Error: {response.text}")
    except Exception as e:
        frappe.throw(f"Failed to send message: {str(e)}")
```

---

### **📝 How to Set Up Server Scripts & Client Scripts in ERPNext:**

**Step 1: Create Server Script**
1. Go to **Customization → Server Script**
2. Click **New**
3. Fill in:
   - **Script Type:** `DocType Event` or `API`
   - **Reference DocType:** `Support Ticket Integration` (if DocType Event)
   - **Event:** `on_update`, `on_load`, etc.
   - **Script:** Paste the Python code above
4. **Save** and **Enable**

**Step 2: Create Client Script**
1. Go to **Customization → Client Script**
2. Click **New**
3. Fill in:
   - **Script Type:** `Form`
   - **Reference DocType:** `Support Ticket Integration`
   - **Script:** Paste the JavaScript code above
4. **Save** and **Enable**

**Step 3: Test**
1. Open a **Support Ticket Integration** document
2. Enter a ticket number (e.g., `TKT-2026-000001`)
3. Click **Refresh Messages** button
4. Enter a message in `agent_message` field
5. **Save** the document - message will be sent automatically!

---

### **🎯 Alternative: Simple Client Script Only (No Server Script)**

If you prefer to make API calls directly from the browser (simpler setup):

**Client Script Only:**

```javascript
// Client Script (JavaScript) - Direct API calls from browser

frappe.ui.form.on('Support Ticket Integration', {
    refresh: function(frm) {
        if (frm.doc.ticket_number) {
            // Button to load ticket details
            frm.add_custom_button(__('Load Ticket'), function() {
                load_ticket_details(frm);
            });
            
            // Button to send reply
            frm.add_custom_button(__('Send Reply'), function() {
                send_agent_reply(frm);
            });
            
            // Button to view messages
            frm.add_custom_button(__('View Messages'), function() {
                view_ticket_messages(frm);
            });
        }
    }
});

// Load ticket details from API
function load_ticket_details(frm) {
    const API_BASE_URL = "http://localhost:3000";  // Change to your server URL
    const ticket_number = frm.doc.ticket_number;
    
    if (!ticket_number) {
        frappe.msgprint("Please enter a ticket number");
        return;
    }
    
    frappe.show_progress("Loading ticket...");
    
    // Make direct API call from browser
    fetch(`${API_BASE_URL}/api/v1/support/tickets/${ticket_number}`)
        .then(response => response.json())
        .then(data => {
            frappe.hide_progress();
            
            if (data.success && data.data) {
                const ticket = data.data.ticket;
                
                // Update form fields
                frm.set_value('subject', ticket.subject || '');
                frm.set_value('status', ticket.status || 'open');
                frm.set_value('customer_name', ticket.user_name || '');
                frm.set_value('customer_email', ticket.user_email || '');
                frm.set_value('priority', ticket.priority || 'medium');
                
                frappe.msgprint("Ticket loaded successfully!");
            } else {
                frappe.msgprint("Could not load ticket");
            }
        })
        .catch(error => {
            frappe.hide_progress();
            frappe.msgprint(`Error: ${error.message}`);
        });
}

// Send agent reply
function send_agent_reply(frm) {
    const API_BASE_URL = "http://localhost:3000";  // Change to your server URL
    const ticket_number = frm.doc.ticket_number;
    const message = frm.doc.agent_message;
    
    if (!ticket_number) {
        frappe.msgprint("Please enter a ticket number");
        return;
    }
    
    if (!message || !message.trim()) {
        frappe.msgprint("Please enter a message");
        return;
    }
    
    frappe.show_progress("Sending message...");
    
    const payload = {
        message: message,
        sender_type: "agent",
        sender_name: frappe.boot.user.full_name || frappe.boot.user.name,
        sender_id: frappe.boot.user.name,
        attachments: []
    };
    
    fetch(`${API_BASE_URL}/api/v1/support/tickets/${ticket_number}/messages`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(payload)
    })
    .then(response => response.json())
    .then(data => {
        frappe.hide_progress();
        
        if (data.success) {
            frappe.msgprint("Message sent successfully!");
            frm.set_value('agent_message', '');  // Clear message field
        } else {
            frappe.msgprint(`Error: ${data.message || 'Failed to send message'}`);
        }
    })
    .catch(error => {
        frappe.hide_progress();
        frappe.msgprint(`Error: ${error.message}`);
    });
}

// View all messages
function view_ticket_messages(frm) {
    const API_BASE_URL = "http://localhost:3000";  // Change to your server URL
    const ticket_number = frm.doc.ticket_number;
    
    if (!ticket_number) {
        frappe.msgprint("Please enter a ticket number");
        return;
    }
    
    frappe.show_progress("Loading messages...");
    
    fetch(`${API_BASE_URL}/api/v1/support/tickets/${ticket_number}`)
        .then(response => response.json())
        .then(data => {
            frappe.hide_progress();
            
            if (data.success && data.data && data.data.messages) {
                show_messages_dialog(data.data.messages);
            } else {
                frappe.msgprint("Could not load messages");
            }
        })
        .catch(error => {
            frappe.hide_progress();
            frappe.msgprint(`Error: ${error.message}`);
        });
}

// Show messages in dialog
function show_messages_dialog(messages) {
    let html = '<div style="max-height: 500px; overflow-y: auto; padding: 10px;">';
    
    if (messages.length === 0) {
        html += '<p>No messages yet.</p>';
    } else {
        messages.forEach(function(msg) {
            const isAgent = msg.sender_type === 'agent';
            const bgColor = isAgent ? '#e3f2fd' : '#f5f5f5';
            const align = isAgent ? 'right' : 'left';
            const date = new Date(msg.created_at).toLocaleString();
            
            html += `
                <div style="margin: 10px 0; padding: 10px; background: ${bgColor}; border-radius: 5px; text-align: ${align};">
                    <strong>${msg.sender_name}</strong> <span style="color: #666;">(${msg.sender_type})</span>
                    <div style="margin-top: 5px; white-space: pre-wrap;">${msg.message}</div>
                    <small style="color: #666;">${date}</small>
                </div>
            `;
        });
    }
    
    html += '</div>';
    
    let d = new frappe.ui.Dialog({
        title: 'Ticket Messages',
        fields: [
            {
                fieldtype: 'HTML',
                options: html
            }
        ],
        primary_action_label: 'Close',
        primary_action: function() {
            d.hide();
        }
    });
    
    d.show();
}
```

**Note:** This approach makes API calls directly from the browser. For production, you may need to handle CORS or use Server Scripts instead.

---

### **Method 3: ERPNext API Integration (REST API)**

Create a custom API endpoint in ERPNext that calls your ticket API:

```python
# File: erpnext_integration/api/support_tickets.py

import frappe
from frappe import _
import requests

@frappe.whitelist()
def get_ticket_messages(ticket_number):
    """Get ticket messages for ERPNext"""
    api_url = f"http://localhost:3000/api/v1/support/tickets/{ticket_number}"
    
    try:
        response = requests.get(api_url)
        if response.status_code == 200:
            return response.json()
        else:
            frappe.throw(f"Error: {response.text}")
    except Exception as e:
        frappe.throw(f"Failed to fetch ticket: {str(e)}")

@frappe.whitelist()
def reply_to_ticket(ticket_number, message, agent_name=None):
    """Send agent reply from ERPNext"""
    api_url = f"http://localhost:3000/api/v1/support/tickets/{ticket_number}/messages"
    
    payload = {
        "message": message,
        "sender_type": "agent",
        "sender_name": agent_name or frappe.session.user_fullname,
        "sender_id": frappe.session.user,
        "attachments": []
    }
    
    try:
        response = requests.post(api_url, json=payload)
        if response.status_code == 201:
            return response.json()
        else:
            frappe.throw(f"Error: {response.text}")
    except Exception as e:
        frappe.throw(f"Failed to send message: {str(e)}")
```

**Usage in ERPNext:**
```javascript
// In ERPNext client script or button
frappe.call({
    method: "erpnext_integration.api.support_tickets.get_ticket_messages",
    args: {
        ticket_number: "TKT-2026-000001"
    },
    callback: function(r) {
        console.log("Messages:", r.message);
    }
});
```

---

## 📱 Complete Agent Workflow

### **Scenario: Agent receives ticket TKT-2026-000001**

**1. View Ticket & Messages:**
```bash
GET http://localhost:3000/api/v1/support/tickets/TKT-2026-000001
```
→ Agent sees all messages and ticket details

**2. Reply to Customer:**
```bash
POST http://localhost:3000/api/v1/support/tickets/TKT-2026-000001/messages
Body: {
  "message": "Hi, I'm looking into your issue...",
  "sender_type": "agent",
  "sender_name": "John Agent",
  "sender_id": "agent-001"
}
```
→ Message is saved and customer sees it in Flutter app

**3. Update Status (Optional):**
```bash
PATCH http://localhost:3000/api/v1/support/tickets/TKT-2026-000001
Body: {
  "status": "in_progress",
  "assigned_to": "agent-001",
  "assigned_to_name": "John Agent"
}
```

---

## 🔑 Key Points for ERPNext Integration

1. **Ticket Number is Key:** Use `ticket_number` (e.g., `TKT-2026-000001`) instead of UUID - it's easier for agents!

2. **Agent Messages:** Always set `sender_type: "agent"` when replying

3. **Authentication:** Currently no auth required, but you should add API keys for production

4. **Real-time Updates:** Consider polling every 30-60 seconds for new messages, or implement webhooks

5. **Error Handling:** Always check `success: true` in API responses

---

## 🚀 Next Steps

1. **Test API endpoints** using Postman or curl
2. **Create Python script** in ERPNext to call your API
3. **Build ERPNext UI** (DocType or custom page) to display tickets
4. **Add authentication** (API keys) for production
5. **Set up webhooks** (optional) for real-time updates

---

## 📞 Example: Complete ERPNext Integration

```python
# Complete example for ERPNext

import frappe
import requests
from datetime import datetime

class SupportTicketManager:
    BASE_URL = "http://localhost:3000"
    
    @staticmethod
    def get_ticket(ticket_number):
        """Fetch ticket from Flutter app"""
        url = f"{SupportTicketManager.BASE_URL}/api/v1/support/tickets/{ticket_number}"
        response = requests.get(url)
        return response.json() if response.status_code == 200 else None
    
    @staticmethod
    def reply(ticket_number, message):
        """Agent replies to ticket"""
        url = f"{SupportTicketManager.BASE_URL}/api/v1/support/tickets/{ticket_number}/messages"
        
        payload = {
            "message": message,
            "sender_type": "agent",
            "sender_name": frappe.session.user_fullname,
            "sender_id": frappe.session.user
        }
        
        response = requests.post(url, json=payload)
        return response.json() if response.status_code == 201 else None
    
    @staticmethod
    def update_status(ticket_number, status):
        """Update ticket status"""
        url = f"{SupportTicketManager.BASE_URL}/api/v1/support/tickets/{ticket_number}"
        payload = {"status": status}
        response = requests.patch(url, json=payload)
        return response.json() if response.status_code == 200 else None

# Usage in ERPNext:
# ticket = SupportTicketManager.get_ticket("TKT-2026-000001")
# SupportTicketManager.reply("TKT-2026-000001", "Your issue is resolved!")
# SupportTicketManager.update_status("TKT-2026-000001", "resolved")
```

---

## ✅ Summary

**Your backend is ready!** Agents can:
- ✅ View tickets using ticket number
- ✅ See all messages in a ticket
- ✅ Reply to tickets (set `sender_type: "agent"`)
- ✅ Update ticket status

**For ERPNext:**
- Use Python scripts to call your API
- Create custom DocTypes to manage tickets
- Build custom pages to display ticket conversations

Need help with specific ERPNext implementation? Let me know!
