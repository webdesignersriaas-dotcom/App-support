# Fix: .env File Not Loading

## ❌ Problem:
All environment variables show "NOT SET" even though you created .env file.

## ✅ Solutions (Try in order):

---

## Solution 1: Check File Location

**The `.env` file MUST be in the same folder as `server.js`**

Your folder structure should be:
```
backend/
├── .env          ← MUST BE HERE (same folder as server.js)
├── server.js
├── package.json
└── node_modules/
```

**Check:**
1. Open `backend` folder in File Explorer
2. Make sure `.env` file is there (it might be hidden)
3. If you don't see it, enable "Show hidden files" in Windows

---

## Solution 2: Check File Name

**The file must be named EXACTLY: `.env`**

**Common mistakes:**
- ❌ `.env.txt` (has .txt extension)
- ❌ `env` (missing the dot)
- ❌ `.env file` (has "file" in name)
- ❌ `env.txt`

**Correct:**
- ✅ `.env` (just `.env` with no extension)

**How to check:**
1. Right-click on the file
2. Click "Properties"
3. Check "Type of file" - should say "ENV File" or "File"
4. If it says "Text Document (.txt)", rename it to remove .txt

---

## Solution 3: Check File Content

Open `.env` file and make sure it looks EXACTLY like this:

```
DB_HOST=13.202.148.229
DB_PORT=5432
DB_NAME=support_tickets
DB_USER=dba
DB_PASSWORD=your_actual_password_here
PORT=3000
```

**Rules:**
- No quotes around values
- No spaces before or after `=`
- No empty lines at the top
- Each variable on its own line
- No trailing spaces

---

## Solution 4: Recreate .env File

Sometimes the file gets corrupted. Let's recreate it:

1. **Delete** the old `.env` file
2. **Create a NEW file** named `.env` (no extension)
3. **Copy this EXACT content:**
   ```
   DB_HOST=13.202.148.229
   DB_PORT=5432
   DB_NAME=support_tickets
   DB_USER=dba
   DB_PASSWORD=your_password_here
   PORT=3000
   ```
4. **Replace** `your_password_here` with your actual password
5. **Save** the file
6. **Restart** server: `npm start`

---

## Solution 5: Check File Encoding

Make sure file is saved as **UTF-8** (not UTF-16 or other):

1. Open `.env` in Notepad++
2. Go to Encoding → Convert to UTF-8
3. Save
4. Or use VS Code and save as UTF-8

---

## Solution 6: Verify dotenv is Installed

Run this command:
```bash
npm list dotenv
```

If it says "empty" or error, install it:
```bash
npm install dotenv
```

---

## Solution 7: Test if File is Being Read

Add this test at the top of `server.js` (after line 7):

```javascript
require('dotenv').config();
console.log('📁 Current directory:', __dirname);
console.log('📄 .env file path:', require('path').join(__dirname, '.env'));
console.log('🔍 File exists?', require('fs').existsSync(require('path').join(__dirname, '.env')));
```

This will show if the file exists and where it's looking.

---

## Solution 8: Hardcode Temporarily (Quick Test)

To verify everything else works, temporarily hardcode in `server.js`:

Change line 17-23 in `server.js` to:
```javascript
const pool = new Pool({
  host: '13.202.148.229',
  port: 5432,
  database: 'support_tickets',
  user: 'dba',
  password: 'YOUR_ACTUAL_PASSWORD_HERE',  // Put your real password here
});
```

**⚠️ WARNING:** This is just for testing! Remove after verifying it works!

---

## ✅ Step-by-Step Fix:

1. **Go to backend folder** in File Explorer
2. **Check if `.env` file exists** (enable hidden files if needed)
3. **If it doesn't exist or is wrong:**
   - Create new file
   - Name it exactly `.env` (no extension)
   - Copy the content from Solution 4
   - Save
4. **Restart server:**
   ```bash
   npm start
   ```
5. **Check output** - should see:
   ```
   DB_HOST: 13.202.148.229
   DB_USER: dba
   DB_NAME: support_tickets
   DB_PASSWORD: ***SET***
   ```

---

## 🐛 Still Not Working?

Share:
1. Screenshot of your backend folder (showing .env file)
2. Content of .env file (hide password, just show structure)
3. Output of `npm start`

