# Debug 500 Server Error

## ❌ Error:
```
Status code: 500 - Server error
```

This means:
- ✅ Connection is working (app can reach backend)
- ❌ Backend is throwing an error when creating ticket

---

## 🔍 Check Backend Logs

**Look at your backend terminal** (where you ran `npm start`). You should see an error message like:

```
❌ Error creating ticket: [error message]
```

**Common errors:**

### 1. Database Connection Error
```
❌ Database connection error: ...
```
**Solution:** Check `.env` file has correct password

### 2. Table Doesn't Exist
```
relation "tickets" does not exist
```
**Solution:** Run `database_setup.sql` on your database

### 3. Column Doesn't Exist
```
column "ticket_number" does not exist
```
**Solution:** Tables not created properly - run SQL script again

### 4. Permission Error
```
permission denied for table tickets
```
**Solution:** Check database user has proper permissions

---

## ✅ Quick Fixes

### Fix 1: Check Backend Terminal

**Look at the terminal where backend is running** - it will show the exact error!

### Fix 2: Verify Tables Exist

In pgAdmin, run:
```sql
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name IN ('tickets', 'ticket_messages');
```

If tables don't exist, run `database_setup.sql`

### Fix 3: Test Database Connection

In backend terminal, you should see:
```
✅ Database connected successfully
```

If you see an error, fix the `.env` file

---

## 📝 Share the Error

**Copy the error message from your backend terminal** and share it with me. It will show exactly what's wrong!

The error will look like:
```
❌ Error creating ticket: [specific error message]
```

