# Complete Setup Guide: Zero-Config to Production

## Monorepo + Next.js 15 + Tailwind 4 + shadcn/ui + Supabase + Supabase Auth + MCP Server + GitHub Actions

**Total setup time: ~15 minutes. Zero configuration files to edit.**

---

## Overview

This guide takes you from zero to a fully deployed production app with:

- ✅ Local development environment (Next.js + Supabase + MCP)
- ✅ Email/password authentication with RLS
- ✅ Git-tracked database migrations
- ✅ GitHub Actions for automated deployments
- ✅ Vercel production deployment
- ✅ Local/production environment isolation

---

---

# Part 1: Create Monorepo (1 minute)

```bash
pnpm create turbo@latest my-app --use-pnpm
cd my-app
git init
```

**What you get automatically:**

- ✅ pnpm workspaces configured
- ✅ Turborepo orchestration
- ✅ Root `tsconfig.json`
- ✅ Root `package.json` with scripts
- ✅ `turbo.json` pipeline
- ✅ `.gitignore` (pnpm-lock.yaml, node_modules, .next, etc.)

---

# Part 2: Create Next.js App (1 minute)

```bash
rm -rf apps/web
pnpm create next-app@latest apps/web \
  --typescript \
  --eslint \
  --tailwind \
  --src-dir \
  --import-alias '@/*'
```

Just hit ENTER for all prompts. Auto-configured:

- ✅ TypeScript
- ✅ Tailwind CSS v4 (with `@import` in `globals.css`)
- ✅ App Router
- ✅ ESLint

---

# Part 3: Add shadcn/ui (1 minute)

```bash
cd apps/web
pnpm dlx shadcn-ui@latest init -d
pnpm dlx shadcn-ui@latest add button card form input
cd ../..
```

---

# Part 4: Add Supabase (5 minutes)

## 4a: Install Supabase CLI & Dependencies

```bash
npm install -g supabase@latest
pnpm --filter @repo/web add @supabase/ssr @supabase/supabase-js zod
```

## 4b: Create Supabase Clients

**Create `apps/web/src/lib/supabase-client.ts`:**

```typescript
import { createBrowserClient } from "@supabase/ssr";

export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );
}
```

**Create `apps/web/src/lib/supabase-server.ts`:**

```typescript
import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

export async function createClient() {
  const cookieStore = await cookies();

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value, options }) =>
            cookieStore.set(name, value, options)
          );
        },
      },
    }
  );
}
```

## 4c: Initialize Local Supabase

```bash
mkdir supabase
cd supabase
supabase init
supabase link --project-ref YOUR_PROJECT_REF
cd ..
```

Get your project reference from [app.supabase.com](https://app.supabase.com) > Settings > API > Project ID.

## 4d: Start Local Supabase

```bash
cd supabase
supabase start
```

**Save this output:**

```
API URL: http://localhost:54321
Anon Key: eyJhbGci...
Service Role Key: eyJhbGci...
Studio URL: http://localhost:54323
```

## 4e: Create Local `.env.local` Files

**Create `apps/web/.env.local`:**

```env
NEXT_PUBLIC_SUPABASE_URL=http://localhost:54321
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGci...
```

**Create `apps/mcp-server/.env.local`:**

```env
SUPABASE_URL=http://localhost:54321
SUPABASE_ANON_KEY=eyJhbGci...
SUPABASE_SERVICE_ROLE_KEY=eyJhbGci...
```

---

# Part 5: Setup Authentication (5 minutes)

## 5a: Enable Auth in Supabase

1. Open Supabase Studio at http://localhost:54323
2. Go to **Authentication > Providers**
3. Verify **Email** is enabled (default)
4. Enable **Email Verification** (toggle on)

## 5b: Create Middleware for Route Protection

**Create `apps/web/src/middleware.ts`:**

```typescript
import { type NextRequest, NextResponse } from "next/server";
import { createServerClient } from "@supabase/ssr";

export async function middleware(request: NextRequest) {
  let response = NextResponse.next({
    request: {
      headers: request.headers,
    },
  });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value, options }) =>
            response.cookies.set(name, value, options)
          );
        },
      },
    }
  );

  const {
    data: { user },
  } = await supabase.auth.getUser();

  // Redirect unauthenticated users to login
  if (
    !user &&
    (request.nextUrl.pathname.startsWith("/dashboard") ||
      request.nextUrl.pathname.startsWith("/account"))
  ) {
    return NextResponse.redirect(new URL("/login", request.url));
  }

  // Redirect authenticated users away from auth pages
  if (
    user &&
    (request.nextUrl.pathname === "/login" ||
      request.nextUrl.pathname === "/signup")
  ) {
    return NextResponse.redirect(new URL("/dashboard", request.url));
  }

  return response;
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico|public).*)"],
};
```

## 5c: Create Auth Forms

**Create `apps/web/src/components/auth/signup-form.tsx`:**

```typescript
"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase-client";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card } from "@/components/ui/card";

export function SignUpForm() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleSignUp = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    try {
      const supabase = createClient();

      const { error } = await supabase.auth.signUp({
        email,
        password,
        options: {
          emailRedirectTo: `${location.origin}/auth/callback`,
        },
      });

      if (error) throw error;
      router.push("/auth/check-email");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Sign up failed");
    } finally {
      setLoading(false);
    }
  };

  return (
    <Card className="w-full max-w-md p-6">
      <form onSubmit={handleSignUp} className="space-y-4">
        <div>
          <label htmlFor="email" className="block text-sm font-medium mb-2">
            Email
          </label>
          <Input
            id="email"
            type="email"
            placeholder="you@example.com"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
          />
        </div>

        <div>
          <label htmlFor="password" className="block text-sm font-medium mb-2">
            Password
          </label>
          <Input
            id="password"
            type="password"
            placeholder="••••••••"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />
        </div>

        {error && <div className="text-red-500 text-sm">{error}</div>}

        <Button type="submit" className="w-full" disabled={loading}>
          {loading ? "Creating account..." : "Sign Up"}
        </Button>

        <p className="text-center text-sm text-gray-600">
          Already have an account?{" "}
          <a href="/login" className="text-blue-600 hover:underline">
            Log in
          </a>
        </p>
      </form>
    </Card>
  );
}
```

**Create `apps/web/src/components/auth/login-form.tsx`:**

```typescript
"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase-client";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card } from "@/components/ui/card";

export function LoginForm() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    try {
      const supabase = createClient();

      const { error } = await supabase.auth.signInWithPassword({
        email,
        password,
      });

      if (error) throw error;
      router.push("/dashboard");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Login failed");
    } finally {
      setLoading(false);
    }
  };

  return (
    <Card className="w-full max-w-md p-6">
      <form onSubmit={handleLogin} className="space-y-4">
        <div>
          <label htmlFor="email" className="block text-sm font-medium mb-2">
            Email
          </label>
          <Input
            id="email"
            type="email"
            placeholder="you@example.com"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
          />
        </div>

        <div>
          <label htmlFor="password" className="block text-sm font-medium mb-2">
            Password
          </label>
          <Input
            id="password"
            type="password"
            placeholder="••••••••"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />
        </div>

        {error && <div className="text-red-500 text-sm">{error}</div>}

        <Button type="submit" className="w-full" disabled={loading}>
          {loading ? "Logging in..." : "Log In"}
        </Button>

        <p className="text-center text-sm text-gray-600">
          Don't have an account?{" "}
          <a href="/signup" className="text-blue-600 hover:underline">
            Sign up
          </a>
        </p>
      </form>
    </Card>
  );
}
```

## 5d: Create Auth Pages

**Create `apps/web/src/app/(auth)/login/page.tsx`:**

```typescript
import { LoginForm } from "@/components/auth/login-form";

export default function LoginPage() {
  return (
    <div className="min-h-screen flex items-center justify-center p-4">
      <div className="w-full max-w-md">
        <h1 className="text-3xl font-bold text-center mb-8">
          Log in to your account
        </h1>
        <LoginForm />
      </div>
    </div>
  );
}
```

**Create `apps/web/src/app/(auth)/signup/page.tsx`:**

```typescript
import { SignUpForm } from "@/components/auth/signup-form";

export default function SignUpPage() {
  return (
    <div className="min-h-screen flex items-center justify-center p-4">
      <div className="w-full max-w-md">
        <h1 className="text-3xl font-bold text-center mb-8">
          Create your account
        </h1>
        <SignUpForm />
      </div>
    </div>
  );
}
```

**Create `apps/web/src/app/(auth)/check-email/page.tsx`:**

```typescript
export default function CheckEmailPage() {
  return (
    <div className="min-h-screen flex items-center justify-center p-4">
      <div className="w-full max-w-md text-center">
        <h1 className="text-2xl font-bold mb-4">Check your email</h1>
        <p className="text-gray-600 mb-4">
          We've sent you a confirmation link. Click it to verify your email and
          complete your signup.
        </p>
        <p className="text-sm text-gray-500">
          Don't see it? Check your spam folder.
        </p>
      </div>
    </div>
  );
}
```

**Create `apps/web/src/app/auth/callback/route.ts`:**

```typescript
import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
import { NextRequest, NextResponse } from "next/server";

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const code = searchParams.get("code");

  if (code) {
    const cookieStore = await cookies();
    const supabase = createServerClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
      {
        cookies: {
          getAll() {
            return cookieStore.getAll();
          },
          setAll(cookiesToSet) {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options)
            );
          },
        },
      }
    );

    await supabase.auth.exchangeCodeForSession(code);
  }

  return NextResponse.redirect(new URL("/dashboard", request.url));
}
```

## 5e: Create Logout Function

**Create `apps/web/src/lib/auth-actions.ts`:**

```typescript
"use server";

import { createClient } from "./supabase-server";
import { revalidatePath } from "next/cache";

export async function logout() {
  const supabase = await createClient();
  await supabase.auth.signOut();
  revalidatePath("/", "layout");
}
```

## 5f: Create Dashboard Page

**Create `apps/web/src/app/(dashboard)/dashboard/page.tsx`:**

```typescript
import { createClient } from "@/lib/supabase-server";
import { logout } from "@/lib/auth-actions";
import { Button } from "@/components/ui/button";
import { redirect } from "next/navigation";

export default async function DashboardPage() {
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  return (
    <div className="min-h-screen">
      <nav className="flex justify-between items-center p-4 border-b">
        <h1 className="text-xl font-bold">My App</h1>
        <div className="flex items-center space-x-4">
          <span className="text-sm text-gray-600">{user.email}</span>
          <form action={logout}>
            <Button type="submit" variant="outline">
              Log out
            </Button>
          </form>
        </div>
      </nav>

      <div className="p-8">
        <h1 className="text-3xl font-bold mb-4">Welcome, {user.email}!</h1>
        <p className="text-gray-600">Your dashboard is ready to use.</p>
      </div>
    </div>
  );
}
```

---

# Part 6: Create Database Migrations (3 minutes)

## 6a: Create Items Table

```bash
cd supabase
supabase migration new create_items_table
```

**Edit `supabase/migrations/TIMESTAMP_create_items_table.sql`:**

```sql
-- Create items table
CREATE TABLE items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now()
);

-- Enable RLS
ALTER TABLE items ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can see own items"
  ON items FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own items"
  ON items FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own items"
  ON items FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own items"
  ON items FOR DELETE
  USING (auth.uid() = user_id);
```

## 6b: Apply Migration Locally

```bash
supabase db push
```

Verify in Supabase Studio at http://localhost:54323:

- Check **Tables > items**
- Check **Policies** for RLS enforcement

## 6c: Commit Migration

```bash
cd ..
git add supabase/migrations/
git commit -m "Add items table with RLS"
```

---

# Part 7: Add MCP Server (2 minutes)

```bash
mkdir -p apps/mcp-server/src
cd apps/mcp-server
pnpm init
```

**Create `package.json`:**

```json
{
  "name": "@repo/mcp-server",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "tsx src/index.ts",
    "build": "tsc"
  },
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.11.x",
    "@supabase/supabase-js": "^2.x",
    "zod": "^3.x",
    "pino": "^9.x"
  },
  "devDependencies": {
    "typescript": "^5.5.4",
    "@types/node": "^20.x",
    "tsx": "^4.x"
  }
}
```

**Create `tsconfig.json`:**

```json
{
  "extends": "../../tsconfig.json",
  "compilerOptions": {
    "target": "ES2020",
    "module": "ES2020",
    "outDir": "./dist",
    "rootDir": "./src"
  },
  "include": ["src/**/*.ts"]
}
```

**Create `src/index.ts`:**

```typescript
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";

const server = new McpServer({
  name: "item-manager",
  version: "1.0.0",
});

const transport = new StdioServerTransport();
await server.connect(transport);
console.log("MCP Server started");
```

---

# Part 8: Install & Run Everything (1 minute)

```bash
cd ../..
pnpm install
```

## In Terminal 1: Start Supabase

```bash
cd supabase
supabase start
cd ..
```

## In Terminal 2: Start All Apps

```bash
pnpm dev
```

Your app is now running at:

- **Next.js:** http://localhost:3000
- **Supabase Studio:** http://localhost:54323
- **MCP Server:** stdio (background)

---

# Part 9: Setup GitHub Actions for Migrations (5 minutes)

## 9a: Get Supabase Credentials

1. **Access Token:**

   - Go to [app.supabase.com/account/tokens](https://app.supabase.com/account/tokens)
   - Create new token
   - Copy it

2. **Project Reference:**

   - Go to Project Settings > API
   - Copy `Project ID`

3. **Database URL:**
   - Project Settings > Database > URI
   - Copy connection string

## 9b: Add GitHub Secrets

```bash
gh secret set SUPABASE_ACCESS_TOKEN
gh secret set SUPABASE_PROJECT_REF
gh secret set SUPABASE_DB_URL_PRODUCTION
```

Or manually in GitHub > Repository Settings > Secrets and variables > Actions.

## 9c: Create GitHub Actions Workflow

**Create `.github/workflows/supabase-migrations.yml`:**

```yaml
name: Supabase Migrations

on:
  push:
    branches:
      - main
    paths:
      - "supabase/migrations/**"
  pull_request:
    branches:
      - main
    paths:
      - "supabase/migrations/**"

jobs:
  deploy-migrations:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup Supabase CLI
        uses: supabase/setup-cli@v1
        with:
          version: latest

      - name: Link Supabase project
        run: |
          supabase link --project-ref ${{ secrets.SUPABASE_PROJECT_REF }} \
            --no-prompt
        env:
          SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}

      - name: Push migrations to production
        run: supabase db push --db-url ${{ secrets.SUPABASE_DB_URL_PRODUCTION }}
        if: github.ref == 'refs/heads/main'

      - name: Validate migrations
        run: supabase migration list
```

---

# Part 10: Deploy to Vercel (1 click)

## 10a: Push to GitHub

```bash
git add .
git commit -m "Add auth, migrations, MCP server"
git push origin main
```

## 10b: Deploy

1. Go to [vercel.com](https://vercel.com)
2. Click "Add New Project"
3. Select your repository
4. Vercel auto-detects monorepo
5. Select `apps/web` as root directory
6. **Add Environment Variables:**
   - `NEXT_PUBLIC_SUPABASE_URL` = `https://your-project.supabase.co`
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY` = (from Supabase)
7. Click "Deploy"

Future deployments: `git push origin main` → automatic

---

# Part 11: Complete Architecture

```
Local Development
├─ Next.js (localhost:3000)
├─ Supabase (localhost:54321)
├─ Supabase Studio (localhost:54323)
├─ MCP Server (stdio)
└─ PostgreSQL (local only)

        ↓ git push origin main

GitHub Repository
├─ Code (apps/web, apps/mcp-server)
├─ Migrations (supabase/migrations/)
└─ Workflows (.github/workflows/)

        ↓ Triggered on migration changes

GitHub Actions
├─ Validates migrations
└─ Applies to production Supabase

        ↓ Vercel detects push to main

Production (Vercel)
├─ Next.js deployed
├─ Environment vars from Vercel dashboard
└─ Connects to production Supabase
```

---

# Part 12: Environment Variables Summary

**Local (`apps/web/.env.local`):**

```env
NEXT_PUBLIC_SUPABASE_URL=http://localhost:54321
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGci...
```

**Production (Vercel Dashboard):**

```
NEXT_PUBLIC_SUPABASE_URL = https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY = eyJhbGci...
```

**GitHub Secrets (for GHA):**

```
SUPABASE_ACCESS_TOKEN = (from Supabase)
SUPABASE_PROJECT_REF = (your project ID)
SUPABASE_DB_URL_PRODUCTION = (production connection string)
```

---

# Part 13: Essential Commands

```bash
# Start local Supabase
cd supabase && supabase start && cd ..

# Run all apps
pnpm dev

# Create new migration
cd supabase && supabase migration new migration_name

# Apply migrations locally
cd supabase && supabase db push

# Commit and push (triggers GHA + Vercel)
git add .
git commit -m "Your message"
git push origin main

# View Supabase Studio
# Open http://localhost:54323

# View app
# Open http://localhost:3000
```

---

# Part 14: Testing Auth & Migrations

## Test Sign Up

1. Visit http://localhost:3000/signup
2. Enter email & password
3. Check email for confirmation link
4. Click link
5. Redirected to dashboard

## Test Login

1. Visit http://localhost:3000/login
2. Enter credentials
3. Redirected to dashboard

## Test Local Isolation

- Local database is separate from production
- Create test data at localhost:3000
- Nothing syncs to production
- Safe to experiment

## Test GitHub Actions

1. Create new migration
2. Commit & push to main
3. GitHub Actions runs automatically
4. Checks production dashboard for applied migration

---

# Part 15: What You Have

✅ **Monorepo** - pnpm + Turborepo  
✅ **Frontend** - Next.js 15 + React 19 + Tailwind 4 + shadcn/ui  
✅ **Database** - Supabase PostgreSQL with RLS  
✅ **Authentication** - Email/password with sessions  
✅ **Migrations** - Git-tracked, GHA-deployed  
✅ **MCP Server** - Ready for AI integration  
✅ **Local Dev** - Completely isolated environment  
✅ **Production** - Vercel + Supabase  
✅ **Automation** - GitHub Actions pipeline  
✅ **Security** - RLS policies, HTTP-only cookies, encrypted passwords

---

# Part 16: What's Next

1. **Add items API** - `apps/web/src/app/api/items/route.ts`
2. **Build dashboard** - `apps/web/src/app/(dashboard)/`
3. **Add MCP tools** - `apps/mcp-server/src/tools/`
4. **Deploy** - `git push origin main`

---

# Troubleshooting

### Supabase won't start

```bash
docker ps  # Check Docker running
supabase stop --no-backup && supabase start
```

### Auth not working

```bash
# Verify env vars
cat apps/web/.env.local
echo $NEXT_PUBLIC_SUPABASE_URL

# Check middleware.ts is in correct location
ls apps/web/src/middleware.ts
```

### Migrations failed

```bash
cd supabase
supabase migration list
supabase db push --dry-run
```

### Port already in use

```bash
supabase stop && supabase start
```

---

**You're done. From zero to production-ready in ~15 minutes.**

Next: Start building your features on top of this solid foundation.
