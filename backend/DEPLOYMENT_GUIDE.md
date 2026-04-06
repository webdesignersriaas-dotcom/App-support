# Deployment Guide - Support Ticket API

This guide explains how to upload your Node.js API to Git and deploy it to a server.

---

## Part 1: Upload to Git (GitHub/GitLab/Bitbucket)

### Step 1: Initialize Git Repository

1. **Open terminal in your backend folder:**
   ```bash
   cd backend
   ```

2. **Initialize Git:**
   ```bash
   git init
   ```

3. **Create .gitignore file** (already created - see `backend/.gitignore`)

### Step 2: Create GitHub Repository

1. Go to [GitHub.com](https://github.com) and sign in
2. Click **"New repository"** (or **"+"** → **"New repository"**)
3. Repository name: `support-ticket-api` (or any name you like)
4. Description: `Node.js API for Customer Support Ticket System`
5. Choose **Public** or **Private**
6. **DO NOT** initialize with README, .gitignore, or license
7. Click **"Create repository"**

### Step 3: Add Files and Commit

1. **Add all files:**
   ```bash
   git add .
   ```

2. **Check what will be committed:**
   ```bash
   git status
   ```

3. **Create first commit:**
   ```bash
   git commit -m "Initial commit: Support Ticket API with PostgreSQL"
   ```

### Step 4: Connect to GitHub and Push

1. **Add remote repository** (replace `YOUR_USERNAME` and `YOUR_REPO_NAME`):
   ```bash
   git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git
   ```

2. **Push to GitHub:**
   ```bash
   git branch -M main
   git push -u origin main
   ```

3. **Enter your GitHub credentials** when prompted

---

## Part 2: Deploy to Server

### Option A: Deploy to VPS (DigitalOcean, AWS EC2, etc.)

#### Prerequisites:
- VPS with Ubuntu/Debian Linux
- SSH access to server
- Domain name (optional)

#### Step 1: Connect to Server

```bash
ssh root@your-server-ip
```

#### Step 2: Install Node.js

```bash
# Update system
apt update && apt upgrade -y

# Install Node.js 18.x
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt install -y nodejs

# Verify installation
node --version
npm --version
```

#### Step 3: Install PostgreSQL Client (if needed)

```bash
apt install -y postgresql-client
```

#### Step 4: Clone Repository

```bash
# Create app directory
mkdir -p /var/www
cd /var/www

# Clone your repository
git clone https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git support-ticket-api
cd support-ticket-api/backend
```

#### Step 5: Install Dependencies

```bash
npm install --production
```

#### Step 6: Create .env File

```bash
nano .env
```

**Add your production environment variables:**
```env
PORT=3000
DB_HOST=13.202.148.229
DB_PORT=5432
DB_NAME=support_tickets
DB_USER=dba
DB_PASSWORD=Siya_A830-lsuhjJF
NODE_ENV=production
```

**Save and exit:** `Ctrl + X`, then `Y`, then `Enter`

#### Step 7: Install PM2 (Process Manager)

```bash
npm install -g pm2
```

#### Step 8: Start Application with PM2

```bash
pm2 start server.js --name "support-ticket-api"
pm2 save
pm2 startup
```

#### Step 9: Configure Firewall

```bash
# Allow port 3000
ufw allow 3000/tcp
ufw enable
```

#### Step 10: Test API

```bash
curl http://localhost:3000/api/health
```

**Access from browser:**
```
http://your-server-ip:3000/api/health
```

---

### Option B: Deploy to Heroku

#### Step 1: Install Heroku CLI

Download from: https://devcenter.heroku.com/articles/heroku-cli

#### Step 2: Login to Heroku

```bash
heroku login
```

#### Step 3: Create Heroku App

```bash
cd backend
heroku create your-app-name
```

#### Step 4: Set Environment Variables

```bash
heroku config:set DB_HOST=13.202.148.229
heroku config:set DB_PORT=5432
heroku config:set DB_NAME=support_tickets
heroku config:set DB_USER=dba
heroku config:set DB_PASSWORD=Siya_A830-lsuhjJF
heroku config:set NODE_ENV=production
```

#### Step 5: Deploy

```bash
git push heroku main
```

#### Step 6: Check Logs

```bash
heroku logs --tail
```

---

### Option C: Deploy to Railway

1. Go to [Railway.app](https://railway.app)
2. Sign up with GitHub
3. Click **"New Project"**
4. Select **"Deploy from GitHub repo"**
5. Choose your repository
6. Railway will auto-detect Node.js
7. Add environment variables in **Settings → Variables**
8. Deploy automatically!

---

### Option D: Deploy to Render

1. Go to [Render.com](https://render.com)
2. Sign up with GitHub
3. Click **"New +"** → **"Web Service"**
4. Connect your GitHub repository
5. Settings:
   - **Name:** `support-ticket-api`
   - **Environment:** `Node`
   - **Build Command:** `npm install`
   - **Start Command:** `node server.js`
6. Add environment variables
7. Click **"Create Web Service"**

---

## Part 3: Using PM2 (Recommended for VPS)

### PM2 Commands

```bash
# Start application
pm2 start server.js --name "support-ticket-api"

# Stop application
pm2 stop support-ticket-api

# Restart application
pm2 restart support-ticket-api

# View logs
pm2 logs support-ticket-api

# View status
pm2 status

# Monitor
pm2 monit

# Save current process list
pm2 save

# Auto-start on server reboot
pm2 startup
```

---

## Part 4: Using Nginx as Reverse Proxy (Optional)

If you want to use a domain name and HTTPS:

### Install Nginx

```bash
apt install -y nginx
```

### Configure Nginx

```bash
nano /etc/nginx/sites-available/support-api
```

**Add configuration:**
```nginx
server {
    listen 80;
    server_name api.yourdomain.com;  # Replace with your domain

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

**Enable site:**
```bash
ln -s /etc/nginx/sites-available/support-api /etc/nginx/sites-enabled/
nginx -t
systemctl restart nginx
```

---

## Part 5: Update Flutter App for Production

### Update Base URL

In `lib/services/support_ticket_service.dart`, update the base URL:

```dart
// For production server
_baseUrl = 'https://api.yourdomain.com';

// Or for VPS with IP
_baseUrl = 'http://your-server-ip:3000';
```

---

## Part 6: Security Checklist

### Before Going Live:

1. ✅ **Change default password** in `.env`
2. ✅ **Use environment variables** (never commit `.env` to Git)
3. ✅ **Enable HTTPS** (use Let's Encrypt with Certbot)
4. ✅ **Set up firewall** (only allow necessary ports)
5. ✅ **Use strong database password**
6. ✅ **Enable CORS** only for your Flutter app domain
7. ✅ **Add rate limiting** (optional, use `express-rate-limit`)
8. ✅ **Add authentication** for admin endpoints (optional)

---

## Part 7: Quick Deployment Checklist

### Git Upload:
- [ ] Initialize Git repository
- [ ] Create `.gitignore` file
- [ ] Create GitHub repository
- [ ] Add and commit files
- [ ] Push to GitHub

### Server Deployment:
- [ ] Set up VPS/Cloud server
- [ ] Install Node.js
- [ ] Clone repository
- [ ] Install dependencies
- [ ] Create `.env` file with production credentials
- [ ] Install PM2
- [ ] Start application with PM2
- [ ] Configure firewall
- [ ] Test API endpoint
- [ ] Update Flutter app base URL

---

## Troubleshooting

### API not accessible:
- Check firewall: `ufw status`
- Check if app is running: `pm2 status`
- Check logs: `pm2 logs support-ticket-api`
- Check port: `netstat -tulpn | grep 3000`

### Database connection error:
- Verify database credentials in `.env`
- Check if database allows remote connections
- Test connection: `psql -h 13.202.148.229 -U dba -d support_tickets`

### PM2 not starting on reboot:
- Run: `pm2 startup`
- Follow the command it shows
- Run: `pm2 save`

---

## Next Steps

1. **Upload to Git** (GitHub/GitLab)
2. **Choose deployment platform** (VPS/Heroku/Railway/Render)
3. **Deploy application**
4. **Update Flutter app** with production URL
5. **Test everything**
6. **Monitor logs** for any issues

---

## Support

If you encounter issues:
- Check PM2 logs: `pm2 logs`
- Check Nginx logs: `tail -f /var/log/nginx/error.log`
- Check system logs: `journalctl -u nginx -f`

