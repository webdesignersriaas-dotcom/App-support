# Complete API Tutorial - How the Support Ticket API Works

This tutorial explains how the Node.js API was built, step by step. Perfect for beginners!

---

## Table of Contents

1. [What is an API?](#what-is-an-api)
2. [Tech Stack Overview](#tech-stack-overview)
3. [Project Structure](#project-structure)
4. [Step-by-Step Code Explanation](#step-by-step-code-explanation)
5. [Key Concepts](#key-concepts)
6. [How Requests Work](#how-requests-work)
7. [Database Integration](#database-integration)
8. [Error Handling](#error-handling)
9. [Security Best Practices](#security-best-practices)

---

## What is an API?

**API (Application Programming Interface)** is like a waiter in a restaurant:

- **Customer (Flutter App)** → Orders food → **Waiter (API)** → Takes order to kitchen → **Kitchen (Database)** → Prepares food → **Waiter** → Brings food back → **Customer**

In our case:
- **Flutter App** → Sends request → **Node.js API** → Queries database → **PostgreSQL** → Returns data → **API** → Sends response → **Flutter App**

---

## Tech Stack Overview

### 1. **Node.js**
- JavaScript runtime that runs on the server (not in browser)
- Allows us to write server-side code in JavaScript

### 2. **Express.js**
- Web framework for Node.js
- Makes it easy to create APIs
- Handles HTTP requests and responses

### 3. **PostgreSQL**
- Relational database
- Stores tickets, messages, users
- Uses SQL queries

### 4. **pg (node-postgres)**
- Library to connect Node.js to PostgreSQL
- Executes SQL queries from Node.js

### 5. **dotenv**
- Manages environment variables
- Keeps sensitive data (passwords) out of code

---

## Project Structure

```
backend/
├── server.js              # Main API file (entry point)
├── package.json           # Dependencies and scripts
├── .env                   # Environment variables (database credentials)
└── *.md                   # Documentation files
```

---

## Step-by-Step Code Explanation

Let's break down `server.js` line by line:

### Step 1: Import Required Libraries

```javascript
const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');
require('dotenv').config();
```

**What this does:**
- `express` - Web framework for creating API
- `Pool` from `pg` - Database connection pool (manages multiple connections)
- `cors` - Allows Flutter app to make requests (Cross-Origin Resource Sharing)
- `dotenv` - Loads environment variables from `.env` file

**Why we need them:**
- Express handles HTTP requests
- pg connects to PostgreSQL database
- CORS allows mobile app to access API
- dotenv keeps passwords secure

---

### Step 2: Create Express App

```javascript
const app = express();
```

**What this does:**
- Creates an Express application instance
- This is our API server

**Think of it as:** Creating a restaurant (the app) that will serve customers (Flutter app)

---

### Step 3: Configure Middleware

```javascript
app.use(cors());
app.use(express.json());
```

**What this does:**

1. **`app.use(cors())`**
   - Allows requests from any origin (Flutter app, browser, etc.)
   - Without this, browser/Flutter would block requests

2. **`app.use(express.json())`**
   - Parses JSON data from requests
   - Converts JSON string to JavaScript object
   - Makes `req.body` available

**Example:**
```javascript
// Request body: {"name": "John"}
// Without express.json(): req.body = undefined
// With express.json(): req.body = { name: "John" }
```

---

### Step 4: Connect to Database

```javascript
const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
});
```

**What this does:**
- Creates a connection pool to PostgreSQL
- Uses environment variables from `.env` file
- `process.env.DB_HOST` reads `DB_HOST` from `.env`

**Why connection pool?**
- Reuses connections (faster)
- Manages multiple connections automatically
- More efficient than creating new connection each time

**`.env` file:**
```env
DB_HOST=13.202.148.229
DB_PORT=5432
DB_NAME=support_tickets
DB_USER=dba
DB_PASSWORD=your_password
```

---

### Step 5: Health Check Endpoint

```javascript
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', message: 'API is running' });
});
```

**Breaking it down:**
- `app.get()` - Handles GET requests
- `'/api/health'` - URL path
- `(req, res) => {}` - Callback function
  - `req` = Request object (incoming data)
  - `res` = Response object (outgoing data)
- `res.json()` - Sends JSON response

**How to test:**
```
GET http://localhost:3000/api/health
Response: { "status": "ok", "message": "API is running" }
```

---

### Step 6: Create Ticket Endpoint

```javascript
app.post('/api/v1/support/tickets', async (req, res) => {
  try {
    // 1. Get data from request body
    const {
      user_id,
      user_name,
      user_email,
      user_phone,
      subject,
      description,
      category,
      priority = 'medium',
    } = req.body;

    // 2. Validate required fields
    if (!user_name || !user_email || !user_phone || !subject || !description) {
      return res.status(400).json({
        success: false,
        message: 'Missing required fields',
      });
    }

    // 3. Generate ticket number
    const ticketNumber = `TKT-${new Date().getFullYear()}-${String(Math.floor(Math.random() * 1000000)).padStart(6, '0')}`;

    // 4. Insert into database
    const result = await pool.query(
      `INSERT INTO tickets (
        ticket_number, user_id, user_name, user_email, user_phone,
        subject, description, status, priority, category, created_at, updated_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      RETURNING *`,
      [ticketNumber, user_id, user_name, user_email, user_phone, subject, description, 'open', priority, category]
    );

    // 5. Send success response
    res.status(201).json({
      success: true,
      data: { ticket: result.rows[0] },
    });
  } catch (error) {
    // 6. Handle errors
    console.error('Error creating ticket:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to create ticket',
      error: error.message,
    });
  }
});
```

**Step-by-step explanation:**

1. **`app.post()`** - Handles POST requests (for creating data)
2. **`async (req, res) => {}`** - Async function (can use `await`)
3. **`req.body`** - Contains JSON data from Flutter app
4. **Validation** - Checks if required fields exist
5. **`pool.query()`** - Executes SQL query
   - `$1, $2, $3...` - Parameterized queries (prevents SQL injection)
   - `RETURNING *` - Returns created row
6. **`result.rows[0]`** - First row from database result
7. **`res.status(201).json()`** - Sends JSON response with status code 201 (Created)
8. **`catch (error)`** - Handles any errors

**SQL Query Breakdown:**
```sql
INSERT INTO tickets (
  ticket_number, user_id, user_name, ...
) VALUES ($1, $2, $3, ...)
RETURNING *
```

- `INSERT INTO tickets` - Insert new row
- `VALUES ($1, $2, ...)` - Values from array `[ticketNumber, user_id, ...]`
- `RETURNING *` - Return the inserted row

---

### Step 7: Get Tickets Endpoint

```javascript
app.get('/api/v1/support/tickets', async (req, res) => {
  try {
    // 1. Get query parameters
    const { user_id, status, page = 1, limit = 20 } = req.query;

    // 2. Security check
    if (!user_id) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required',
      });
    }

    // 3. Build SQL query
    let query = `SELECT * FROM tickets WHERE user_id = $1`;
    const params = [user_id];

    // 4. Add status filter if provided
    if (status) {
      query += ` AND status = $2`;
      params.push(status);
    }

    // 5. Add pagination
    const offset = (page - 1) * limit;
    query += ` ORDER BY created_at DESC LIMIT $${params.length + 1} OFFSET $${params.length + 2}`;
    params.push(parseInt(limit), offset);

    // 6. Execute query
    const result = await pool.query(query, params);

    // 7. Send response
    res.json({
      success: true,
      data: {
        tickets: result.rows,
        pagination: {
          total: result.rowCount,
          page: parseInt(page),
          limit: parseInt(limit),
        },
      },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Failed to fetch tickets',
      error: error.message,
    });
  }
});
```

**Key concepts:**

1. **Query Parameters:**
   ```
   GET /api/v1/support/tickets?user_id=123&status=open&page=1
   ```
   - Accessed via `req.query`
   - `req.query.user_id` = "123"

2. **SQL WHERE clause:**
   ```sql
   WHERE user_id = $1 AND status = $2
   ```
   - Filters rows
   - `$1, $2` are parameters

3. **Pagination:**
   ```sql
   LIMIT 20 OFFSET 0
   ```
   - `LIMIT` - Max rows to return
   - `OFFSET` - Skip first N rows
   - Page 1: OFFSET 0, Page 2: OFFSET 20

---

### Step 8: Send Message Endpoint

```javascript
app.post('/api/v1/support/tickets/:id/messages', async (req, res) => {
  try {
    const { id } = req.params;  // Get ticket ID from URL
    const {
      message,
      sender_type = 'user',
      sender_id,
      sender_name,
      attachments = [],
    } = req.body;

    // Validate
    if (!message) {
      return res.status(400).json({
        success: false,
        message: 'Message is required',
      });
    }

    // Insert message
    const result = await pool.query(
      `INSERT INTO ticket_messages (
        ticket_id, sender_id, sender_name, sender_type, message, 
        attachment_urls, created_at
      ) VALUES ($1, $2, $3, $4, $5, $6, CURRENT_TIMESTAMP)
      RETURNING *`,
      [id, sender_id, sender_name, sender_type, message, JSON.stringify(attachments)]
    );

    // Update ticket's updated_at
    await pool.query(
      `UPDATE tickets SET updated_at = CURRENT_TIMESTAMP WHERE id = $1`,
      [id]
    );

    res.status(201).json({
      success: true,
      data: { message: result.rows[0] },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Failed to send message',
      error: error.message,
    });
  }
});
```

**Key points:**

1. **URL Parameters:**
   ```
   POST /api/v1/support/tickets/abc123/messages
   ```
   - `:id` in route = `req.params.id`
   - `req.params.id` = "abc123"

2. **Multiple Queries:**
   - First: Insert message
   - Second: Update ticket timestamp
   - Both use `await` to wait for completion

3. **JSON.stringify():**
   - Converts array `[1, 2, 3]` to string `"[1,2,3]"`
   - PostgreSQL stores as JSONB

---

### Step 9: Update Ticket Status

```javascript
app.patch('/api/v1/support/tickets/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { status, assigned_to, assigned_to_name, priority } = req.body;

    // Build dynamic update query
    const updateFields = [];
    const params = [];
    let paramCount = 0;

    // Add status if provided
    if (status) {
      const validStatuses = ['open', 'in_progress', 'resolved', 'closed'];
      if (!validStatuses.includes(status)) {
        return res.status(400).json({
          success: false,
          message: `Invalid status`,
        });
      }
      paramCount++;
      updateFields.push(`status = $${paramCount}`);
      params.push(status);
    }

    // Add priority if provided
    if (priority) {
      paramCount++;
      updateFields.push(`priority = $${paramCount}`);
      params.push(priority);
    }

    // Build final query
    params.push(id);
    const result = await pool.query(
      `UPDATE tickets 
       SET ${updateFields.join(', ')}, updated_at = CURRENT_TIMESTAMP
       WHERE id = $${params.length}
       RETURNING *`,
      params
    );

    res.json({
      success: true,
      data: { ticket: result.rows[0] },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Failed to update ticket',
      error: error.message,
    });
  }
});
```

**Dynamic Query Building:**
- Only updates fields that are provided
- If only `status` is sent, only status is updated
- If both `status` and `priority` are sent, both are updated

**Example:**
```javascript
// Request: { "status": "resolved" }
// Query: UPDATE tickets SET status = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2

// Request: { "status": "resolved", "priority": "high" }
// Query: UPDATE tickets SET status = $1, priority = $2, updated_at = CURRENT_TIMESTAMP WHERE id = $3
```

---

### Step 10: Start Server

```javascript
const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log(`🚀 Server running on http://localhost:${PORT}`);
});
```

**What this does:**
- Starts the server
- Listens on port 3000 (or from `.env`)
- Server is now ready to accept requests

---

## Key Concepts

### 1. HTTP Methods

| Method | Purpose | Example |
|--------|---------|---------|
| GET | Read data | Get tickets |
| POST | Create data | Create ticket |
| PATCH | Update data | Update status |
| DELETE | Delete data | Delete ticket |

### 2. Status Codes

| Code | Meaning | When to use |
|------|---------|-------------|
| 200 | OK | Success |
| 201 | Created | Successfully created |
| 400 | Bad Request | Invalid input |
| 401 | Unauthorized | Not logged in |
| 404 | Not Found | Resource doesn't exist |
| 500 | Server Error | Database/Server error |

### 3. Async/Await

```javascript
// Without async/await (callbacks)
pool.query('SELECT * FROM tickets', (error, result) => {
  if (error) {
    console.error(error);
  } else {
    console.log(result.rows);
  }
});

// With async/await (cleaner)
try {
  const result = await pool.query('SELECT * FROM tickets');
  console.log(result.rows);
} catch (error) {
  console.error(error);
}
```

**Why async/await?**
- Cleaner code
- Easier error handling
- No callback hell

### 4. Parameterized Queries

**❌ BAD (SQL Injection risk):**
```javascript
const query = `SELECT * FROM tickets WHERE user_id = '${user_id}'`;
```

**✅ GOOD (Safe):**
```javascript
const query = `SELECT * FROM tickets WHERE user_id = $1`;
await pool.query(query, [user_id]);
```

**Why?**
- Prevents SQL injection attacks
- Automatically escapes special characters
- Safer and faster

---

## How Requests Work

### Complete Flow Example: Creating a Ticket

1. **Flutter App sends request:**
   ```dart
   POST http://localhost:3000/api/v1/support/tickets
   Body: {
     "user_name": "John",
     "user_email": "john@example.com",
     "subject": "Need help"
   }
   ```

2. **Express receives request:**
   - Route matches: `/api/v1/support/tickets`
   - Method matches: `POST`
   - Executes handler function

3. **Handler processes:**
   - Extracts data from `req.body`
   - Validates input
   - Generates ticket number

4. **Database query:**
   ```sql
   INSERT INTO tickets (...) VALUES (...)
   ```

5. **Database returns:**
   - New ticket row

6. **API sends response:**
   ```json
   {
     "success": true,
     "data": {
       "ticket": { "id": "...", "ticket_number": "TKT-2026-000001", ... }
     }
   }
   ```

7. **Flutter receives response:**
   - Parses JSON
   - Updates UI
   - Shows success message

---

## Database Integration

### Connection Pool

```javascript
const pool = new Pool({
  host: '13.202.148.229',
  port: 5432,
  database: 'support_tickets',
  user: 'dba',
  password: 'password',
});
```

**What is a pool?**
- Manages multiple database connections
- Reuses connections (faster)
- Automatically handles connection errors

### Query Execution

```javascript
const result = await pool.query('SELECT * FROM tickets WHERE id = $1', [ticketId]);
```

**Result object:**
```javascript
{
  rows: [{ id: '...', ticket_number: '...', ... }],  // Array of rows
  rowCount: 1,  // Number of rows
  command: 'SELECT',  // SQL command
  // ... other metadata
}
```

---

## Error Handling

### Try-Catch Pattern

```javascript
try {
  // Code that might fail
  const result = await pool.query('SELECT * FROM tickets');
  res.json({ success: true, data: result.rows });
} catch (error) {
  // Handle error
  console.error('Error:', error);
  res.status(500).json({
    success: false,
    message: 'Failed to fetch tickets',
    error: error.message,
  });
}
```

**Why try-catch?**
- Database might be down
- Invalid SQL query
- Network issues
- Prevents server crash

### Common Errors

1. **Database connection error:**
   - Check `.env` credentials
   - Check if database is running

2. **SQL syntax error:**
   - Check query syntax
   - Check column names

3. **Validation error:**
   - Missing required fields
   - Invalid data format

---

## Security Best Practices

### 1. Parameterized Queries
```javascript
// ✅ Safe
await pool.query('SELECT * FROM tickets WHERE id = $1', [id]);

// ❌ Dangerous (SQL injection)
await pool.query(`SELECT * FROM tickets WHERE id = '${id}'`);
```

### 2. Environment Variables
```javascript
// ✅ Safe (in .env file)
const password = process.env.DB_PASSWORD;

// ❌ Dangerous (hardcoded)
const password = 'my_password';
```

### 3. Input Validation
```javascript
if (!user_name || !user_email) {
  return res.status(400).json({
    success: false,
    message: 'Missing required fields',
  });
}
```

### 4. User Authentication
```javascript
if (!user_id) {
  return res.status(401).json({
    success: false,
    message: 'Authentication required',
  });
}
```

### 5. Filter by User ID
```javascript
// ✅ Only returns user's tickets
WHERE user_id = $1

// ❌ Returns all tickets (security risk)
SELECT * FROM tickets
```

---

## Summary

### What We Learned:

1. **Express.js** - Web framework for Node.js
2. **Routes** - Define API endpoints (`app.get()`, `app.post()`, etc.)
3. **Middleware** - Functions that run before routes (`cors`, `express.json()`)
4. **Database** - PostgreSQL with `pg` library
5. **Async/Await** - Handle asynchronous operations
6. **Error Handling** - Try-catch blocks
7. **Security** - Parameterized queries, validation, authentication

### API Structure:

```
GET    /api/health                          - Health check
POST   /api/v1/support/tickets              - Create ticket
GET    /api/v1/support/tickets              - Get tickets
GET    /api/v1/support/tickets/:id          - Get ticket details
PATCH  /api/v1/support/tickets/:id           - Update ticket
POST   /api/v1/support/tickets/:id/messages  - Send message
GET    /api/v1/support/tickets/:id/messages  - Get messages
```

### Next Steps:

1. **Add authentication** - JWT tokens
2. **Add file uploads** - Multer middleware
3. **Add rate limiting** - Prevent abuse
4. **Add logging** - Winston or Morgan
5. **Add testing** - Jest or Mocha
6. **Add API documentation** - Swagger/OpenAPI

---

## Practice Exercises

1. **Add DELETE endpoint:**
   ```javascript
   app.delete('/api/v1/support/tickets/:id', async (req, res) => {
     // Your code here
   });
   ```

2. **Add search endpoint:**
   ```javascript
   app.get('/api/v1/support/tickets/search', async (req, res) => {
     // Search by subject or description
   });
   ```

3. **Add ticket statistics:**
   ```javascript
   app.get('/api/v1/support/tickets/stats', async (req, res) => {
     // Return count by status
   });
   ```

---

## Resources

- [Express.js Documentation](https://expressjs.com/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [node-postgres Documentation](https://node-postgres.com/)
- [HTTP Status Codes](https://httpstatuses.com/)

---

**Happy Coding! 🚀**

