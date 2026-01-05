# Production Startup Guide

**Date**: January 5, 2026  
**Status**: ✅ **COMPLETE**

## Single Command Production Startup

We now have a **single command** to build and start the entire application in production mode:

```bash
bin/start-production
```

## What It Does

The `bin/start-production` script automatically:

1. ✅ **Checks for `.env` file** - Ensures configuration exists
2. ✅ **Builds frontend** - Runs `npm run build` to create production assets
3. ✅ **Installs dependencies** - Ensures Ruby gems and npm packages are installed
4. ✅ **Sets up database** - Creates database if needed and runs migrations
5. ✅ **Precompiles assets** - Prepares any Rails assets
6. ✅ **Starts Rails server** - Launches in production mode on configured port

## Prerequisites

Before running production mode, ensure you have:

- Ruby 3.4.4 installed
- PostgreSQL running and accessible
- Node.js installed (for frontend build)
- `.env` file configured for production

## Configuration

### Step 1: Create `.env` File

```bash
cp env.example .env
```

### Step 2: Edit `.env` for Production

```bash
# Server Configuration
PORT=4000                    # Production port
HOST=0.0.0.0                # Bind to all interfaces

# Database Configuration  
DB_USERNAME=prod_user
DB_PASSWORD=secure_password
DB_HOST=localhost
DB_PORT=5432

# LLM Service Configuration
LLM_URL=http://your-llm-server:52003
API_KEY=your-production-api-key

# Rails Environment
RAILS_ENV=production        # ← Set to production!
```

### Step 3: Run Production Startup

```bash
bin/start-production
```

## Output

You'll see progress through each step:

```
======================================================================
Production Startup
======================================================================

Step 1: Building Frontend
----------------------------------------------------------------------
Building frontend assets...
✅ Frontend built successfully

Step 2: Preparing Rails Application
----------------------------------------------------------------------
Checking database...
Running migrations...
Precompiling assets...
✅ Rails application ready

Step 3: Starting Production Server
----------------------------------------------------------------------
Server will start on 0.0.0.0:4000
Press Ctrl+C to stop the server
======================================================================

=> Booting Puma
=> Rails 8.0.2 application starting in production
=> Run `bin/rails server --help` for more startup options
Puma starting in single mode...
* Puma version: 6.5.0
* Min threads: 5
* Max threads: 5
* Environment: production
* Listening on http://0.0.0.0:4000
```

## Troubleshooting

### Error: .env file not found

**Problem**: The script can't find your `.env` file.

**Solution**:
```bash
cp env.example .env
# Edit .env with your configuration
```

### Error: Frontend build failed

**Problem**: npm build failed.

**Solution**:
```bash
cd frontend
npm install
npm run build
cd ..
```

### Error: Database connection failed

**Problem**: Can't connect to PostgreSQL.

**Solution**:
1. Check PostgreSQL is running:
   ```bash
   sudo systemctl status postgresql
   ```
2. Verify credentials in `.env`
3. Ensure database exists:
   ```bash
   RAILS_ENV=production bundle exec rails db:create
   ```

### Error: Port already in use

**Problem**: Another process is using the configured port.

**Solution**:
1. Change PORT in `.env` to a different port
2. Or stop the process using the port:
   ```bash
   lsof -i:4000  # Find process
   kill <PID>    # Stop it
   ```

## Architecture

### What Gets Built

**Frontend**:
- React components compiled to static JavaScript
- CSS bundled and minified
- Output directory: `frontend/dist/`
- Served by Rails in production

**Backend**:
- Rails runs in production mode
- Database connections from production config
- Logging to production log file
- Asset serving enabled

### Port Configuration

By default, production runs on **port 4000**. Change via `.env`:

```bash
PORT=8080  # Or any other port
```

### Host Binding

By default, binds to `0.0.0.0` (all interfaces). Change via `.env`:

```bash
HOST=127.0.0.1  # Localhost only
HOST=0.0.0.0    # All interfaces (default)
```

## Development vs Production

| Aspect | Development | Production |
|--------|-------------|------------|
| **Startup** | `ruby lib/server.rb` | `bin/start-production` |
| **Frontend** | Dev server (hot reload) | Built static files |
| **Rails Mode** | `development` | `production` |
| **Port** | 52020 (default) | 4000 (default) |
| **Logs** | Verbose | Minimal |
| **Caching** | Disabled | Enabled |
| **Asset Serving** | Rails serves | Pre-built assets |

## README Location

The production startup command is prominently documented in the main `README.md`:

### Quick Start Section (Top of README)
```markdown
## ⚡ Quick Start

### Production Mode (Single Command)
```bash
bin/start-production
```
```

### Detailed Setup Section
Under "4. Start the Server" → "Production Mode"

### Deployment Section
Comprehensive production deployment information

## Files Modified

| File | Change |
|------|--------|
| `bin/start-production` | ✅ **NEW** - Production startup script |
| `README.md` | ✅ Updated - Added Quick Start + Production sections |
| `env.example` | ✅ Updated - Added HOST variable + production comment |
| `docs/production_startup_guide.md` | ✅ **NEW** - This guide |

## Verification

To verify the production startup works:

```bash
# 1. Create .env with production settings
cp env.example .env
nano .env  # Set RAILS_ENV=production

# 2. Run production startup
bin/start-production

# 3. Test the server (in another terminal)
curl http://localhost:4000/api/sisyphus/config

# 4. Stop server
Ctrl+C
```

Expected output: JSON response with configuration data.

## Best Practices

### Before Deploying

1. ✅ Test production mode locally first
2. ✅ Verify all environment variables are set
3. ✅ Run full test suite: `ruby lib/test_runner.rb --speed all`
4. ✅ Check database backups exist
5. ✅ Verify LLM service is accessible

### In Production

1. ✅ Use process manager (systemd, Docker, etc.)
2. ✅ Set up reverse proxy (nginx, Apache)
3. ✅ Enable HTTPS
4. ✅ Monitor logs: `tail -f log/production.log`
5. ✅ Set up database backups
6. ✅ Configure firewalls

### Systemd Service (Optional)

Create `/etc/systemd/system/translator-ruby.service`:

```ini
[Unit]
Description=Translator Ruby Production Server
After=network.target postgresql.service

[Service]
Type=simple
User=your_user
WorkingDirectory=/path/to/translator_ruby
ExecStart=/path/to/translator_ruby/bin/start-production
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl enable translator-ruby
sudo systemctl start translator-ruby
sudo systemctl status translator-ruby
```

## Summary

✅ **Single command**: `bin/start-production`  
✅ **Documented**: In main README.md Quick Start section  
✅ **Automated**: Builds frontend + starts Rails  
✅ **Configurable**: Via `.env` file  
✅ **Production-ready**: Includes all necessary setup steps

---

**Status**: ✅ Production startup is fully implemented and documented.

