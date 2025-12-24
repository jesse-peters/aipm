# Setup Scripts

This directory contains scripts for automating the monorepo setup process.

## Available Scripts

### `generate-files.sh`

Generates all TypeScript/TSX files for authentication, Supabase clients, and MCP server.

**Usage:**
```bash
./scripts/generate-files.sh <project_root>
```

**Example:**
```bash
./scripts/generate-files.sh ./my-app
```

**Files Generated:**

#### Supabase Clients
- `apps/web/src/lib/supabase-client.ts` - Browser client for client-side operations
- `apps/web/src/lib/supabase-server.ts` - Server client for server-side operations

#### Middleware
- `apps/web/src/middleware.ts` - Route protection and auth redirects

#### Auth Components
- `apps/web/src/components/auth/signup-form.tsx` - Sign up form component
- `apps/web/src/components/auth/login-form.tsx` - Login form component

#### Auth Pages
- `apps/web/src/app/(auth)/login/page.tsx` - Login page
- `apps/web/src/app/(auth)/signup/page.tsx` - Sign up page
- `apps/web/src/app/(auth)/check-email/page.tsx` - Email verification prompt
- `apps/web/src/app/auth/callback/route.ts` - OAuth callback handler

#### Auth Actions
- `apps/web/src/lib/auth-actions.ts` - Server actions for auth (logout, etc.)

#### Dashboard
- `apps/web/src/app/(dashboard)/dashboard/page.tsx` - Protected dashboard page

#### MCP Server
- `apps/mcp-server/package.json` - MCP server package configuration
- `apps/mcp-server/tsconfig.json` - TypeScript configuration
- `apps/mcp-server/src/index.ts` - MCP server entry point
- `apps/mcp-server/.env.local` - Environment variables template

### `check-prerequisites.sh`

Checks that all required tools are installed before running the setup.

**Usage:**
```bash
./scripts/check-prerequisites.sh
```

**Checks for:**
- Docker (running)
- Node.js >= 18
- pnpm
- Supabase CLI
- GitHub CLI (authenticated)
- Vercel CLI (authenticated)
- Git

## Script Organization

Each script is designed to be:
- **Idempotent**: Safe to run multiple times
- **Self-contained**: Can be run independently
- **Well-documented**: Clear output and error messages
- **Error-safe**: Uses `set -e` and proper error handling

## Future Scripts

Additional scripts planned for the automated setup:
- `setup-supabase.sh` - Automate Supabase project creation
- `generate-env-files.sh` - Generate environment files from templates
- `setup-migrations.sh` - Create and apply database migrations
- `setup-github-actions.sh` - Configure GitHub Actions workflows
- `deploy-vercel.sh` - Deploy to Vercel with proper configuration
- `setup.sh` - Main orchestrator that runs all scripts in order

