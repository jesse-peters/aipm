#!/bin/bash
# generate-files.sh
# Generates all TypeScript/TSX files for auth, Supabase clients, MCP server

set -e

PROJECT_ROOT="$1"

if [ -z "$PROJECT_ROOT" ]; then
  echo "Usage: $0 <project_root>"
  exit 1
fi

echo "📝 Generating code files in $PROJECT_ROOT..."

# Color definitions
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

create_file() {
  local file_path="$1"
  local dir_path=$(dirname "$file_path")
  
  # Create directory if it doesn't exist
  mkdir -p "$dir_path"
  
  echo -e "${BLUE}Creating:${NC} $file_path"
}

# ============================================================================
# SUPABASE CLIENT FILES
# ============================================================================

echo -e "\n${GREEN}Creating Supabase client files...${NC}"

# 1. Browser client
create_file "$PROJECT_ROOT/apps/web/src/lib/supabase-client.ts"
cat > "$PROJECT_ROOT/apps/web/src/lib/supabase-client.ts" << 'EOF'
import { createBrowserClient } from "@supabase/ssr";

export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );
}
EOF

# 2. Server client
create_file "$PROJECT_ROOT/apps/web/src/lib/supabase-server.ts"
cat > "$PROJECT_ROOT/apps/web/src/lib/supabase-server.ts" << 'EOF'
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
EOF

# ============================================================================
# MIDDLEWARE
# ============================================================================

echo -e "\n${GREEN}Creating middleware...${NC}"

create_file "$PROJECT_ROOT/apps/web/src/middleware.ts"
cat > "$PROJECT_ROOT/apps/web/src/middleware.ts" << 'EOF'
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
EOF

# ============================================================================
# AUTH ACTIONS
# ============================================================================

echo -e "\n${GREEN}Creating auth actions...${NC}"

create_file "$PROJECT_ROOT/apps/web/src/lib/auth-actions.ts"
cat > "$PROJECT_ROOT/apps/web/src/lib/auth-actions.ts" << 'EOF'
"use server";

import { createClient } from "./supabase-server";
import { revalidatePath } from "next/cache";

export async function logout() {
  const supabase = await createClient();
  await supabase.auth.signOut();
  revalidatePath("/", "layout");
}
EOF

# ============================================================================
# AUTH FORMS
# ============================================================================

echo -e "\n${GREEN}Creating auth forms...${NC}"

# 3. Signup form
create_file "$PROJECT_ROOT/apps/web/src/components/auth/signup-form.tsx"
cat > "$PROJECT_ROOT/apps/web/src/components/auth/signup-form.tsx" << 'EOF'
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
EOF

# 4. Login form
create_file "$PROJECT_ROOT/apps/web/src/components/auth/login-form.tsx"
cat > "$PROJECT_ROOT/apps/web/src/components/auth/login-form.tsx" << 'EOF'
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
EOF

# ============================================================================
# AUTH PAGES
# ============================================================================

echo -e "\n${GREEN}Creating auth pages...${NC}"

# 5. Login page
create_file "$PROJECT_ROOT/apps/web/src/app/(auth)/login/page.tsx"
cat > "$PROJECT_ROOT/apps/web/src/app/(auth)/login/page.tsx" << 'EOF'
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
EOF

# 6. Signup page
create_file "$PROJECT_ROOT/apps/web/src/app/(auth)/signup/page.tsx"
cat > "$PROJECT_ROOT/apps/web/src/app/(auth)/signup/page.tsx" << 'EOF'
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
EOF

# 7. Check email page
create_file "$PROJECT_ROOT/apps/web/src/app/(auth)/check-email/page.tsx"
cat > "$PROJECT_ROOT/apps/web/src/app/(auth)/check-email/page.tsx" << 'EOF'
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
EOF

# 8. Auth callback route
create_file "$PROJECT_ROOT/apps/web/src/app/auth/callback/route.ts"
cat > "$PROJECT_ROOT/apps/web/src/app/auth/callback/route.ts" << 'EOF'
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
EOF

# ============================================================================
# DASHBOARD PAGE
# ============================================================================

echo -e "\n${GREEN}Creating dashboard page...${NC}"

create_file "$PROJECT_ROOT/apps/web/src/app/(dashboard)/dashboard/page.tsx"
cat > "$PROJECT_ROOT/apps/web/src/app/(dashboard)/dashboard/page.tsx" << 'EOF'
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
EOF

# ============================================================================
# MCP SERVER FILES
# ============================================================================

echo -e "\n${GREEN}Creating MCP server files...${NC}"

# 9. MCP package.json
create_file "$PROJECT_ROOT/apps/mcp-server/package.json"
cat > "$PROJECT_ROOT/apps/mcp-server/package.json" << 'EOF'
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
    "@modelcontextprotocol/sdk": "^1.11.0",
    "@supabase/supabase-js": "^2.0.0",
    "zod": "^3.0.0",
    "pino": "^9.0.0"
  },
  "devDependencies": {
    "typescript": "^5.5.4",
    "@types/node": "^20.0.0",
    "tsx": "^4.0.0"
  }
}
EOF

# 10. MCP tsconfig.json
create_file "$PROJECT_ROOT/apps/mcp-server/tsconfig.json"
cat > "$PROJECT_ROOT/apps/mcp-server/tsconfig.json" << 'EOF'
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
EOF

# 11. MCP index.ts
create_file "$PROJECT_ROOT/apps/mcp-server/src/index.ts"
cat > "$PROJECT_ROOT/apps/mcp-server/src/index.ts" << 'EOF'
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";

const server = new McpServer({
  name: "item-manager",
  version: "1.0.0",
});

const transport = new StdioServerTransport();
await server.connect(transport);
console.log("MCP Server started");
EOF

# 12. MCP .env.local (template)
create_file "$PROJECT_ROOT/apps/mcp-server/.env.local"
cat > "$PROJECT_ROOT/apps/mcp-server/.env.local" << 'EOF'
# This file will be populated by the setup script
# SUPABASE_URL=http://localhost:54321
# SUPABASE_ANON_KEY=your-anon-key
# SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
EOF

echo -e "\n${GREEN}✓ All code files generated successfully!${NC}"

# Summary
echo -e "\n${BLUE}Files created:${NC}"
echo "  ✓ apps/web/src/lib/supabase-client.ts"
echo "  ✓ apps/web/src/lib/supabase-server.ts"
echo "  ✓ apps/web/src/middleware.ts"
echo "  ✓ apps/web/src/lib/auth-actions.ts"
echo "  ✓ apps/web/src/components/auth/signup-form.tsx"
echo "  ✓ apps/web/src/components/auth/login-form.tsx"
echo "  ✓ apps/web/src/app/(auth)/login/page.tsx"
echo "  ✓ apps/web/src/app/(auth)/signup/page.tsx"
echo "  ✓ apps/web/src/app/(auth)/check-email/page.tsx"
echo "  ✓ apps/web/src/app/auth/callback/route.ts"
echo "  ✓ apps/web/src/app/(dashboard)/dashboard/page.tsx"
echo "  ✓ apps/mcp-server/package.json"
echo "  ✓ apps/mcp-server/tsconfig.json"
echo "  ✓ apps/mcp-server/src/index.ts"
echo "  ✓ apps/mcp-server/.env.local (template)"

exit 0

