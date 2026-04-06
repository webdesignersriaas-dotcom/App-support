# How to Fix Password Error

## ❌ Error:
```
"error": "SASL: SCRAM-SERVER-FIRST-MESSAGE: client password must be a string"
```

This means your `.env` file password is not being read correctly.

---

## ✅ Step-by-Step Fix:

### Step 1: Check if .env File Exists

1. Go to your `backend` folder
2. Look for a file named `.env` (it might be hidden)
3. If you don't see it, create it

### Step 2: Check .env File Content

Open `.env` file and make sure it looks EXACTLY like this:

```
DB_HOST=13.202.148.229
DB_PORT=5432
DB_NAME=support_tickets
DB_USER=dba
DB_PASSWORD=your_actual_password_here
PORT=3000
```

**CRITICAL RULES:**
- ❌ NO quotes around password
- ❌ NO spaces before or after `=`
- ❌ Password cannot be empty
- ✅ Password should be directly after `DB_PASSWORD=`

### Step 3: Common Mistakes to Avoid

**❌ WRONG Examples:**
```
DB_PASSWORD= "mypassword"     ← Has quotes and spaces
DB_PASSWORD = mypassword      ← Has space before =
DB_PASSWORD=                  ← Empty (no password)
DB_PASSWORD='mypassword'      ← Has quotes
DB_PASSWORD="mypassword"     ← Has quotes
```

**✅ CORRECT:**
```
DB_PASSWORD=mypassword        ← No quotes, no spaces
```

### Step 4: Restart Server

After fixing `.env` file:

1. **Stop server** (Press `Ctrl + C`)
2. **Start again:**
   ```bash
   npm start
   ```

3. **Check the debug output** - You should see:
   ```
   🔍 Environment check:
     DB_HOST: 13.202.148.229
     DB_USER: dba
     DB_NAME: support_tickets
     DB_PASSWORD: ***SET***
   ✅ Database connected successfully
   ```

If you see `DB_PASSWORD: ❌ NOT SET`, your `.env` file is not being read correctly.

---

## 🔍 Troubleshooting

### Issue 1: .env File Not Found

**Solution:**
- Make sure `.env` file is in `backend` folder
- Same folder as `server.js`
- File name is exactly `.env` (no extension)

### Issue 2: Password Still Not Working

**Try this temporary fix (for testing only):**

Edit `server.js` line 22, change to:
```javascript
password: process.env.DB_PASSWORD || 'YOUR_ACTUAL_PASSWORD_HERE',
```

Replace `YOUR_ACTUAL_PASSWORD_HERE` with your real password.

**⚠️ WARNING:** Remove this after testing! Never commit passwords to git!

### Issue 3: File Encoding Problem

Make sure `.env` file is saved as:
- **UTF-8** encoding
- **No BOM** (Byte Order Mark)

---

## ✅ Test After Fix

1. Restart server: `npm start`
2. Look for: `DB_PASSWORD: ***SET***` in the output
3. Look for: `✅ Database connected successfully`
4. Try creating ticket again

---

## 📝 Example .env File

Your `.env` file should look exactly like this:

```
DB_HOST=13.202.148.229
DB_PORT=5432
DB_NAME=support_tickets
DB_USER=dba
DB_PASSWORD=MySecurePassword123
PORT=3000
```

**No quotes, no spaces, password directly after `=`**

