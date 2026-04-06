# Fix Password Error - "client password must be a string"

## ❌ Error You're Seeing:
```
"error": "SASL: SCRAM-SERVER-FIRST-MESSAGE: client password must be a string"
```

This means the password in your `.env` file is not being read correctly.

---

## ✅ Solution:

### Step 1: Check Your .env File

Open your `backend/.env` file and make sure it looks EXACTLY like this:

```
DB_HOST=13.202.148.229
DB_PORT=5432
DB_NAME=support_tickets
DB_USER=dba
DB_PASSWORD=your_actual_password_here
PORT=3000
```

**Important Rules:**
- ❌ NO quotes around values
- ❌ NO spaces around the `=` sign
- ❌ NO empty password
- ✅ Password should be directly after `DB_PASSWORD=`

### Step 2: Common Mistakes

**WRONG:**
```
DB_PASSWORD= "mypassword"     ❌ Has quotes and spaces
DB_PASSWORD = mypassword      ❌ Has space before =
DB_PASSWORD=                  ❌ Empty password
DB_PASSWORD='mypassword'      ❌ Has quotes
```

**CORRECT:**
```
DB_PASSWORD=mypassword        ✅ No quotes, no spaces
```

### Step 3: Restart Backend Server

After fixing `.env` file:

1. **Stop the server** (Press `Ctrl + C` in the terminal)
2. **Start again:**
   ```bash
   npm start
   ```

---

## 🔍 Verify Password is Being Read

Add this temporary debug line in `server.js` (after line 23):

```javascript
console.log('🔐 DB Config:', {
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  database: process.env.DB_NAME,
  password: process.env.DB_PASSWORD ? '***SET***' : '❌ NOT SET',
});
```

This will show if password is being read. **Remove this after testing!**

---

## 🐛 Still Not Working?

### Option 1: Hardcode Password Temporarily (for testing only)

In `server.js`, change line 17-23 to:

```javascript
const pool = new Pool({
  host: '13.202.148.229',
  port: 5432,
  database: 'support_tickets',
  user: 'dba',
  password: 'YOUR_ACTUAL_PASSWORD_HERE',  // Put your password here temporarily
});
```

**⚠️ WARNING:** Remove this after testing! Never commit passwords in code!

### Option 2: Check .env File Location

Make sure `.env` file is in the `backend` folder, same location as `server.js`:

```
backend/
├── .env          ← Must be here
├── server.js
├── package.json
```

### Option 3: Check File Encoding

Make sure `.env` file is saved as:
- **UTF-8 encoding** (not UTF-16 or other)
- **No BOM** (Byte Order Mark)

---

## ✅ Test After Fix

1. Restart server: `npm start`
2. Check logs - should see: `✅ Database connected successfully`
3. Test creating ticket again

---

## 📝 Example .env File

Your `.env` file should look exactly like this (with your real password):

```
DB_HOST=13.202.148.229
DB_PORT=5432
DB_NAME=support_tickets
DB_USER=dba
DB_PASSWORD=MySecurePassword123
PORT=3000
```

**No quotes, no spaces, no empty values!**

