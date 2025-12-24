#!/bin/bash

# Vercel Deployment Script
# Deploys the Next.js app to Vercel with production environment variables

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Check if required arguments are provided
if [ $# -lt 4 ]; then
    print_error "Missing required arguments"
    echo "Usage: $0 <project_name> <supabase_url> <supabase_anon_key> <project_root>"
    echo "Example: $0 my-app https://xxx.supabase.co eyJhbG... /path/to/project"
    exit 1
fi

PROJECT_NAME="$1"
SUPABASE_URL="$2"
SUPABASE_ANON_KEY="$3"
PROJECT_ROOT="$4"

# Navigate to project root
cd "$PROJECT_ROOT" || {
    print_error "Failed to navigate to project root: $PROJECT_ROOT"
    exit 1
}

print_info "Starting Vercel deployment for $PROJECT_NAME..."

# Check if vercel CLI is installed
if ! command -v vercel &> /dev/null; then
    print_error "Vercel CLI is not installed"
    echo "Install it with: npm install -g vercel"
    exit 1
fi

# Check if vercel is authenticated
if ! vercel whoami &> /dev/null; then
    print_error "Vercel CLI is not authenticated"
    echo "Run: vercel login"
    exit 1
fi

print_status "Vercel CLI is installed and authenticated"

# Navigate to web app directory
WEB_APP_DIR="$PROJECT_ROOT/apps/web"
if [ ! -d "$WEB_APP_DIR" ]; then
    print_error "Web app directory not found: $WEB_APP_DIR"
    exit 1
fi

cd "$WEB_APP_DIR" || {
    print_error "Failed to navigate to web app directory"
    exit 1
}

print_status "Navigated to web app directory"

# Create .vercelignore if it doesn't exist
if [ ! -f ".vercelignore" ]; then
    cat > .vercelignore << 'EOF'
.env.local
.env*.local
node_modules
.next
EOF
    print_status "Created .vercelignore"
fi

# Link to Vercel project (or create new one)
print_info "Linking to Vercel project..."
if ! vercel link --yes; then
    print_error "Failed to link Vercel project"
    exit 1
fi
print_status "Linked to Vercel project"

# Set environment variables for production
print_info "Configuring production environment variables..."

# Function to set environment variable
set_env_var() {
    local var_name="$1"
    local var_value="$2"
    
    # Remove existing variable if it exists (suppress error if it doesn't exist)
    echo "$var_value" | vercel env rm "$var_name" production --yes 2>/dev/null || true
    
    # Add the variable
    if echo "$var_value" | vercel env add "$var_name" production --yes; then
        print_status "Set $var_name"
    else
        print_warning "Failed to set $var_name (it may already exist)"
    fi
}

# Set Supabase environment variables
set_env_var "NEXT_PUBLIC_SUPABASE_URL" "$SUPABASE_URL"
set_env_var "NEXT_PUBLIC_SUPABASE_ANON_KEY" "$SUPABASE_ANON_KEY"

print_status "Environment variables configured"

# Deploy to production
print_info "Deploying to Vercel production..."
DEPLOYMENT_OUTPUT=$(vercel --prod --yes 2>&1)
DEPLOYMENT_STATUS=$?

if [ $DEPLOYMENT_STATUS -ne 0 ]; then
    print_error "Deployment failed"
    echo "$DEPLOYMENT_OUTPUT"
    exit 1
fi

# Extract deployment URL from output
DEPLOYMENT_URL=$(echo "$DEPLOYMENT_OUTPUT" | grep -Eo 'https://[a-zA-Z0-9.-]+\.vercel\.app' | tail -1)

if [ -z "$DEPLOYMENT_URL" ]; then
    print_warning "Could not extract deployment URL from output"
    print_status "Deployment completed, but URL extraction failed"
    echo "$DEPLOYMENT_OUTPUT"
else
    print_status "Deployed successfully!"
    echo ""
    echo -e "${GREEN}Production URL:${NC} $DEPLOYMENT_URL"
fi

# Save deployment info to a file
DEPLOYMENT_INFO_FILE="$PROJECT_ROOT/.vercel-deployment-info"
cat > "$DEPLOYMENT_INFO_FILE" << EOF
DEPLOYMENT_URL=$DEPLOYMENT_URL
DEPLOYMENT_DATE=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
PROJECT_NAME=$PROJECT_NAME
SUPABASE_URL=$SUPABASE_URL
EOF

print_status "Deployment info saved to $DEPLOYMENT_INFO_FILE"

# Return to project root
cd "$PROJECT_ROOT"

echo ""
print_info "Deployment complete!"
echo ""
echo "Next steps:"
echo "  1. Visit your production site: $DEPLOYMENT_URL"
echo "  2. Test the authentication flow"
echo "  3. Configure custom domain in Vercel dashboard (optional)"
echo ""

exit 0

