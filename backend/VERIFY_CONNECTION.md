# How to Verify Database Connection

## ✅ Your Connection Settings Look Correct:

From your screenshots, I can see:
- **Host:** 13.202.148.229 ✅
- **Port:** 5432 ✅
- **Username:** dba ✅
- **Database:** support_tickets ✅ (visible in tree)
- **Password:** Saved ✅

---

## 🔍 Step 1: Test Connection in pgAdmin

### In pgAdmin (what you're using):

1. **Right-click** on "Siya dba" connection
2. Click **"Refresh"** or **"Connect Server"**
3. If connected, you'll see the databases expand
4. If you see "support_tickets" database, connection is working! ✅

### Test Query:

1. **Right-click** on "support_tickets" database
2. Click **"Query Tool"**
3. Run this query:
   ```sql
   SELECT NOW();
   ```
4. If you see a timestamp, connection is working! ✅

---

## 🔍 Step 2: Check if Tables Exist

In pgAdmin Query Tool (connected to `support_tickets` database):

1. Run this query:
   ```sql
   SELECT table_name 
   FROM information_schema.tables 
   WHERE table_schema = 'public';
   ```

2. You should see these tables:
   - `tickets`
   - `ticket_messages`
   - `ticket_attachments`
   - `ticket_activity_log`

**If tables don't exist:**
- Run `database_setup.sql` in Query Tool
- Copy all SQL from `database_setup.sql` file
- Paste and execute in Query Tool

---

## 🔍 Step 3: Test Backend API Connection

### Step 3a: Check .env File

Make sure your `backend/.env` file has:
```
DB_HOST=13.202.148.229
DB_PORT=5432
DB_NAME=support_tickets
DB_USER=dba
DB_PASSWORD=your_password_here
PORT=3000
```

**Important:** Use the SAME password you use in pgAdmin!

### Step 3b: Restart Backend Server

1. Stop server (Ctrl + C)
2. Start again:
   ```bash
   cd backend
   npm start
   ```

### Step 3c: Check Debug Output

You should see:
```
🔍 Environment check:
  DB_HOST: 13.202.148.229
  DB_USER: dba
  DB_NAME: support_tickets
  DB_PASSWORD: ***SET***
✅ Database connected successfully
📅 Database time: [timestamp]
```

**If you see:**
- `DB_PASSWORD: ❌ NOT SET` → Your .env file is wrong
- `❌ Database connection error` → Check password or connection

---

## 🔍 Step 4: Test Creating a Ticket

### Option A: Using Browser/Postman

1. **POST** request to: `http://localhost:3000/api/v1/support/tickets`
2. **Headers:** `Content-Type: application/json`
3. **Body:**
   ```json
   {
     "user_name": "Test User",
     "user_email": "test@test.com",
     "user_phone": "1234567890",
     "subject": "Test Ticket",
     "description": "Testing connection"
   }
   ```

### Option B: Check in Database

After creating ticket, run in pgAdmin:
```sql
SELECT * FROM tickets ORDER BY created_at DESC LIMIT 1;
```

If you see your ticket, everything is working! ✅

---

## ✅ Quick Checklist

- [ ] pgAdmin connects to database ✅ (You can see support_tickets)
- [ ] Tables exist (check with query above)
- [ ] .env file has correct password
- [ ] Backend shows "Database connected successfully"
- [ ] Can create ticket via API
- [ ] Ticket appears in database

---

## 🐛 Troubleshooting

### Issue: "Database connection error" in backend

**Check:**
1. Password in `.env` matches pgAdmin password
2. Database name is `support_tickets` (not `postgres`)
3. Firewall allows connection from your IP

### Issue: Tables don't exist

**Solution:**
1. Open Query Tool in pgAdmin
2. Connect to `support_tickets` database
3. Copy all SQL from `database_setup.sql`
4. Paste and execute

### Issue: Can't connect from backend but pgAdmin works

**Possible causes:**
- Different password in `.env` vs pgAdmin
- Backend trying to connect to wrong database
- Firewall blocking Node.js connection

---

## 🎯 Next Steps

Once connection is verified:
1. ✅ Test creating ticket from Flutter app
2. ✅ Verify ticket appears in database
3. ✅ Test sending messages
4. ✅ Everything working! 🎉

