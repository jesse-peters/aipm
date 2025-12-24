# Monorepo Setup Automation

**One command to rule them all.** 🚀

Automate the complete setup of a production-ready monorepo with Next.js 15, Tailwind 4, shadcn/ui, Supabase, authentication, database migrations, MCP server, GitHub Actions, and Vercel deployment.

---

## Quick Start

### Prerequisites

Before running the setup, ensure you have:

- **Docker** (running)
- **Node.js** >= 18
- **pnpm** (`npm install -g pnpm`)
- **Supabase CLI** (`npm install -g supabase`)
- **GitHub CLI** (`brew install gh` and run `gh auth login`)
- **Vercel CLI** (`npm install -g vercel` and run `vercel login`)
- **Git** initialized

**Check prerequisites:**

```bash
./scripts/check-prerequisites.sh
```

---

## One-Command Setup

```bash
./setup.sh
```

That's it! The script will:

1. ✅ Create a Turborepo monorepo
2. ✅ Setup Next.js 15 app with Tailwind 4 and shadcn/ui
3. ✅ Create and configure Supabase project (local + production)
4. ✅ Generate environment files automatically
5. ✅ Setup authentication with email/password
6. ✅ Create database migrations with RLS policies
7. ✅ Generate all code files (auth forms, middleware, etc.)
8. ✅ Setup GitHub Actions for automated migrations
9. ✅ Deploy to Vercel
10. ✅ Display summary with all URLs and credentials

**Total setup time: ~10-15 minutes** (mostly waiting for installs)

---

## What You Get

After running `./setup.sh`, you'll have a complete stack:

### 📦 Monorepo Structure

```
my-app/
├── apps/
│   ├── web/                    # Next.js 15 app
│   │   ├── src/
│   │   │   ├── app/            # App Router
│   │   │   │   ├── (auth)/     # Auth pages
│   │   │   │   ├── (dashboard)/ # Protected pages
│   │   │   │   └── auth/       # Auth callbacks
│   │   │   ├── components/
│   │   │   │   ├── ui/         # shadcn/ui components
│   │   │   │   └── auth/       # Auth forms
│   │   │   ├── lib/
│   │   │   │   ├── supabase-client.ts
│   │   │   │   ├── supabase-server.ts
│   │   │   │   └── auth-actions.ts
│   │   │   └── middleware.ts   # Route protection
│   │   └── .env.local          # Local credentials (auto-generated)
│   │
│   └── mcp-server/             # MCP server
│       ├── src/
│       │   └── index.ts        # MCP entry point
│       └── .env.local          # Local credentials (auto-generated)
│
├── supabase/
│   ├── config.toml             # Supabase config
│   └── migrations/             # Database migrations
│       └── *_create_items_table.sql
│
├── .github/
│   └── workflows/
│       └── supabase-migrations.yml  # Auto-deploy migrations
│
└── scripts/                    # Setup automation scripts
```

### 🎨 Frontend Stack

- **Next.js 15** with App Router and React 19
- **Tailwind CSS 4** with modern `@import` syntax
- **shadcn/ui** components pre-installed (button, card, form, input)
- **TypeScript** configured throughout

### 🗄️ Backend Stack

- **Supabase** PostgreSQL with Row Level Security (RLS)
- **Authentication** with email/password, sessions, and middleware
- **Database migrations** tracked in Git, deployed via GitHub Actions
- **Local development** completely isolated from production

### 🤖 MCP Server

- **MCP server skeleton** ready for AI tool integration
- Connected to Supabase for database operations
- Configured with proper environment variables

### 🚀 Deployment

- **Vercel** production deployment (automatic on push to main)
- **GitHub Actions** for automated database migrations
- **Environment variables** configured in Vercel dashboard
- **CI/CD pipeline** ready to use

---

## Manual Scripts (Advanced)

If you want to run individual parts of the setup, all scripts are available in the `scripts/` directory:

### Check Prerequisites

```bash
./scripts/check-prerequisites.sh
```

Validates that all required tools are installed and authenticated.

### Generate Environment Files

```bash
./scripts/generate-env-files.sh \
  --supabase-url "https://xxx.supabase.co" \
  --supabase-anon-key "eyJhbGci..." \
  --project-dir ./my-app
```

Creates `.env.local` files for web app and MCP server. If no arguments provided, uses local Supabase defaults.

**Options:**

- `--supabase-url` - Supabase API URL (default: http://127.0.0.1:54321)
- `--supabase-anon-key` - Supabase anonymous key (default: local key)
- `--supabase-service-role-key` - Service role key (default: local key)
- `--project-ref` - Supabase project reference
- `--project-dir` - Project directory (default: current directory)

### Generate Code Files

```bash
./scripts/generate-files.sh ./my-app
```

Creates all TypeScript/TSX files for auth, Supabase clients, middleware, and MCP server.

### Setup Supabase

```bash
./scripts/setup-supabase.sh \
  --project-name "my-app" \
  --org-id "my-org" \
  --db-password "secure-password"
```

Creates Supabase project, initializes local instance, and links them together.

### Setup Database Migrations

```bash
./scripts/setup-migrations.sh ./my-app
```

Creates items table migration with RLS policies and applies it locally.

### Setup GitHub Actions

```bash
./scripts/setup-github-actions.sh ./my-app
```

Creates GitHub Actions workflow and sets up secrets for automated migrations.

### Deploy to Vercel

```bash
./scripts/deploy-vercel.sh ./my-app
```

Deploys the web app to Vercel with proper environment variables.

---

## Environment Variables

### Local Development

**`apps/web/.env.local`** (auto-generated):

```env
NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGci...
```

**`apps/mcp-server/.env.local`** (auto-generated):

```env
SUPABASE_URL=http://127.0.0.1:54321
SUPABASE_ANON_KEY=eyJhbGci...
SUPABASE_SERVICE_ROLE_KEY=eyJhbGci...
```

### Production (Vercel Dashboard)

Set these in Vercel project settings:

```
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGci...
```

### GitHub Secrets (for Actions)

Set these in GitHub repository settings:

```
SUPABASE_ACCESS_TOKEN=<from Supabase dashboard>
SUPABASE_PROJECT_REF=<your project ID>
SUPABASE_DB_URL_PRODUCTION=<production connection string>
```

---

## Development Workflow

### Start Local Development

**Terminal 1** - Start Supabase:

```bash
cd supabase
supabase start
```

**Terminal 2** - Start all apps:

```bash
pnpm dev
```

Your app is now running at:

- **Web app:** http://localhost:3000
- **Supabase Studio:** http://localhost:54323
- **Email testing (InBucket):** http://localhost:54324

### Create New Migration

```bash
cd supabase
supabase migration new my_migration_name
```

Edit the generated SQL file, then apply locally:

```bash
supabase db push
```

Commit and push to trigger production deployment via GitHub Actions:

```bash
git add supabase/migrations/
git commit -m "Add new migration"
git push origin main
```

### Deploy Changes

```bash
git add .
git commit -m "Your changes"
git push origin main
```

Vercel automatically deploys on push to `main`. GitHub Actions automatically applies migrations to production.

---

## Testing

### Test Authentication

1. Start local development (`pnpm dev`)
2. Visit http://localhost:3000/signup
3. Create an account with email/password
4. Check http://localhost:54324 for confirmation email (InBucket)
5. Click confirmation link
6. Should redirect to dashboard at http://localhost:3000/dashboard

### Test Login

1. Visit http://localhost:3000/login
2. Enter your credentials
3. Should redirect to dashboard

### Test Database

1. Visit http://localhost:54323 (Supabase Studio)
2. Go to **Table Editor** > **items**
3. Verify RLS policies are enabled
4. Go to **Authentication** > **Users**
5. Verify your test user exists

### Test Migrations

1. Create a new migration: `cd supabase && supabase migration new test`
2. Add a simple change (e.g., add a column)
3. Apply locally: `supabase db push`
4. Commit and push to GitHub
5. Check GitHub Actions for successful deployment
6. Verify in production Supabase dashboard

---

## Troubleshooting

### Docker Not Running

**Error:** `Cannot connect to Docker daemon`

**Solution:**

```bash
# Start Docker Desktop
open -a Docker

# Wait for Docker to start, then retry
./setup.sh
```

### Supabase Won't Start

**Error:** `Supabase failed to start`

**Solution:**

```bash
# Stop and restart Supabase
cd supabase
supabase stop --no-backup
supabase start

# Check Docker containers
docker ps

# If ports are in use, stop conflicting services
lsof -i :54321  # Check what's using the port
```

### Authentication Not Working

**Error:** `Session not persisting` or `Redirect not working`

**Solution:**

```bash
# 1. Verify environment variables
cat apps/web/.env.local
# Should show: NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321

# 2. Check middleware is in correct location
ls apps/web/src/middleware.ts

# 3. Restart Next.js dev server
# In terminal, press Ctrl+C and run: pnpm dev

# 4. Clear browser cookies and try again
```

### Migrations Failed in GitHub Actions

**Error:** `Migration failed to apply`

**Solution:**

```bash
# 1. Check migration syntax locally
cd supabase
supabase migration list
supabase db push --dry-run

# 2. Verify GitHub secrets are set correctly
gh secret list

# 3. Check GitHub Actions logs for specific error
gh run list --limit 5
gh run view <run-id>

# 4. If schema conflict, may need to reset
# WARNING: This drops production data!
# Only do this in development
```

### Port Already in Use

**Error:** `Port 3000 is already in use`

**Solution:**

```bash
# Find process using the port
lsof -i :3000

# Kill the process
kill -9 <PID>

# Or use a different port
PORT=3001 pnpm dev
```

### pnpm Install Fails

**Error:** `Failed to install dependencies`

**Solution:**

```bash
# Clear pnpm cache
pnpm store prune

# Delete node_modules and lockfile
rm -rf node_modules pnpm-lock.yaml

# Reinstall
pnpm install

# If still fails, check Node version
node -v  # Should be >= 18
nvm use 18  # Or nvm use 20
```

### Vercel Deployment Fails

**Error:** `Build failed` or `Environment variables not set`

**Solution:**

```bash
# 1. Check Vercel environment variables
vercel env ls

# 2. Add missing variables
vercel env add NEXT_PUBLIC_SUPABASE_URL production
vercel env add NEXT_PUBLIC_SUPABASE_ANON_KEY production

# 3. Re-deploy
vercel --prod

# 4. Check build logs
vercel logs <deployment-url>
```

### GitHub CLI Not Authenticated

**Error:** `gh: command not found` or `Not authenticated`

**Solution:**

```bash
# Install GitHub CLI
brew install gh

# Login
gh auth login
# Follow prompts to authenticate with GitHub

# Verify
gh auth status
```

### Vercel CLI Not Authenticated

**Error:** `Not logged in`

**Solution:**

```bash
# Install Vercel CLI
npm install -g vercel

# Login
vercel login
# Follow prompts to authenticate

# Verify
vercel whoami
```

### Supabase Project Creation Fails

**Error:** `Failed to create Supabase project`

**Solution:**

```bash
# 1. Check Supabase CLI is logged in
supabase login

# 2. Verify organization exists
supabase orgs list

# 3. Create project manually if needed
# Visit https://app.supabase.com
# Create project, get credentials
# Run setup scripts with --skip-create flag
```

### Environment Files Not Generated

**Error:** `.env.local` files missing

**Solution:**

```bash
# Run the environment generator manually
./scripts/generate-env-files.sh --project-dir ./my-app

# Or with production credentials
./scripts/generate-env-files.sh \
  --supabase-url "https://xxx.supabase.co" \
  --supabase-anon-key "eyJhbGci..." \
  --project-dir ./my-app
```

### TypeScript Errors After Setup

**Error:** `Cannot find module` or type errors

**Solution:**

```bash
# 1. Ensure all dependencies are installed
pnpm install

# 2. Restart TypeScript server in your editor
# VSCode: Cmd+Shift+P > "Restart TypeScript Server"

# 3. Check tsconfig.json paths are correct
cat apps/web/tsconfig.json

# 4. If shadcn components missing, reinstall
cd apps/web
pnpm dlx shadcn-ui@latest add button card form input
```

### Database Connection Issues

**Error:** `Connection refused` or `Could not connect to database`

**Solution:**

```bash
# 1. Verify Supabase is running
cd supabase
supabase status

# 2. Check connection pooler settings
# In Supabase Studio: Settings > Database > Connection Pooling

# 3. Verify environment variables match
echo $NEXT_PUBLIC_SUPABASE_URL

# 4. Test connection directly
psql postgresql://postgres:postgres@localhost:54322/postgres
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                       LOCAL DEVELOPMENT                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Next.js (localhost:3000)                                       │
│      ↓                                                          │
│  Supabase Local (localhost:54321)                              │
│      ↓                                                          │
│  PostgreSQL (Docker container)                                  │
│                                                                 │
│  Supabase Studio: localhost:54323                              │
│  Email Testing: localhost:54324                                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                            ↓
                    git push origin main
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│                      GITHUB REPOSITORY                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  • Source code (apps/web, apps/mcp-server)                     │
│  • Database migrations (supabase/migrations/)                  │
│  • GitHub Actions workflows (.github/workflows/)               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
        ↓                                    ↓
    Vercel trigger                    Migration trigger
        ↓                                    ↓
┌──────────────────┐              ┌──────────────────┐
│  VERCEL          │              │ GITHUB ACTIONS   │
│                  │              │                  │
│  • Build app     │              │ • Validate SQL   │
│  • Deploy        │              │ • Apply to prod  │
│  • CDN           │              │                  │
└──────────────────┘              └──────────────────┘
        ↓                                    ↓
        └────────────────┬───────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────────┐
│                    PRODUCTION (SUPABASE)                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  • PostgreSQL database with RLS                                │
│  • Auth system (email/password)                                │
│  • API (RESTful + Realtime)                                    │
│  • Storage                                                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Next Steps

After setup is complete:

### 1. Build Your Features

Add your own database tables:

```bash
cd supabase
supabase migration new add_my_table
# Edit migration file
supabase db push
```

### 2. Customize UI

The app includes shadcn/ui components. Add more:

```bash
cd apps/web
pnpm dlx shadcn-ui@latest add dialog dropdown-menu
```

### 3. Add MCP Tools

Edit `apps/mcp-server/src/index.ts` to add your AI tools and connect them to Supabase.

### 4. Deploy

```bash
git add .
git commit -m "Added new features"
git push origin main
```

Automatic deployments will handle the rest!

---

## Resources

- **Complete Setup Guide:** See `complete-setup-guide.md` for step-by-step manual instructions
- **Scripts Documentation:** See `scripts/README.md` for individual script details
- **Next.js:** https://nextjs.org/docs
- **Supabase:** https://supabase.com/docs
- **Tailwind CSS:** https://tailwindcss.com/docs
- **shadcn/ui:** https://ui.shadcn.com
- **Turborepo:** https://turbo.build/repo/docs

---

## Contributing

Found a bug or want to improve the setup scripts? PRs welcome!

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a PR

---

## License

MIT

---

**Happy coding!** 🎉

If you run into issues not covered in troubleshooting, please open an issue on GitHub.
