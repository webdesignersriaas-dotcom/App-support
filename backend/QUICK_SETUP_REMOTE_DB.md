# Quick Setup for Remote PostgreSQL Database

## ✅ Your Database Information:
- **Host/IP:** 13.202.148.229
- **User:** dba
- **Password:** [You have it - put in .env file]
- **Database:** support_tickets
- **Port:** 5432 (default)

---

## 🚀 Quick Setup Steps:

### Step 1: Create .env File

1. **In your `backend` folder**, create a file named `.env` (exactly `.env`, no extension)

2. **Copy this content:**
   ```
   DB_HOST=13.202.148.229
   DB_PORT=5432
   DB_NAME=support_tickets
   DB_USER=dba
   DB_PASSWORD=YOUR_PASSWORD_HERE
   PORT=3000
   ```

3. **Replace `YOUR_PASSWORD_HERE`** with your actual database password

4. **Save the file**

---

### Step 2: Make Sure Database Exists

**Connect to your remote database** and make sure:
- Database `support_tickets` exists
- Tables are created (run `database_setup.sql`)

**To connect remotely:**
```bash
psql -h 13.202.148.229 -U dba -d support_tickets
```

Or use pgAdmin:
- Host: 13.202.148.229
- Port: 5432
- Username: dba
- Password: [your password]
- Database: support_tickets

---

### Step 3: Create Tables (if not done)

If tables don't exist, run `database_setup.sql` on your remote database.

**Using psql:**
```bash
psql -h 13.202.148.229 -U dba -d support_tickets -f database_setup.sql
```

**Or copy SQL from `database_setup.sql`** and run in pgAdmin.

---

### Step 4: Start Backend Server

```bash
cd backend
npm start
```

**You should see:**
```
✅ Database connected successfully
🚀 Support Ticket API Server
📡 Server running on: http://localhost:3000
```

---

### Step 5: Test Connection

Open browser: `http://localhost:3000/api/health`

You should see:
```json
{
  "status": "ok",
  "message": "Support Ticket API is running"
}
```

---

## 🐛 Troubleshooting

### "Connection refused" or "Connection timeout"
**Possible causes:**
1. **Firewall blocking** - Remote server firewall might block your IP
   - Contact your server admin to whitelist your IP
   - Or allow port 5432 from your IP

2. **Wrong IP/Port** - Double check the IP address

3. **Database not running** - Check if PostgreSQL is running on remote server

### "Password authentication failed"
- ✅ Check password in `.env` file is correct
- ✅ No extra spaces in `.env` file
- ✅ Password doesn't have quotes

### "Database does not exist"
- ✅ Create database `support_tickets` on remote server
- ✅ Or change `DB_NAME` in `.env` to existing database name

### "Relation does not exist" (tables missing)
- ✅ Run `database_setup.sql` on remote database
- ✅ Make sure you're connected to correct database

---

## ✅ Checklist

- [ ] `.env` file created with correct credentials
- [ ] Database `support_tickets` exists on remote server
- [ ] Tables created (run database_setup.sql)
- [ ] Firewall allows connection from your IP
- [ ] Backend server starts successfully
- [ ] Health check works (`http://localhost:3000/api/health`)

---

## 📝 Example .env File

Your `.env` file should look like this (with your actual password):

```
DB_HOST=13.202.148.229
DB_PORT=5432
DB_NAME=support_tickets
DB_USER=dba
DB_PASSWORD=your_actual_password_here
PORT=3000
```

**Important:** Never commit `.env` file to git! It contains sensitive information.

---

## 🎯 Next Steps

Once backend is running:
1. ✅ Test health endpoint
2. ✅ Update Flutter app (already done!)
3. ✅ Test creating ticket from Flutter app
4. ✅ Check ticket appears in remote database

---

## 💡 Security Note

Since you're using a remote database:
- Keep `.env` file secure (don't share it)
- Use strong passwords
- Consider using SSL connection (can be added later)
- Make sure firewall is properly configured

