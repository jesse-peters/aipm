#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print section headers
print_section() {
    echo ""
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}=====================================${NC}"
}

# Function to print success message
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Function to print error message
print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Function to print warning message
print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Function to print info message
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Exit on error
set -e

print_section "Environment File Generator"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --supabase-url)
            SUPABASE_URL="$2"
            shift 2
            ;;
        --supabase-anon-key)
            SUPABASE_ANON_KEY="$2"
            shift 2
            ;;
        --supabase-service-role-key)
            SUPABASE_SERVICE_ROLE_KEY="$2"
            shift 2
            ;;
        --project-ref)
            PROJECT_REF="$2"
            shift 2
            ;;
        --project-dir)
            PROJECT_DIR="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --supabase-url URL               Supabase API URL"
            echo "  --supabase-anon-key KEY          Supabase anonymous key"
            echo "  --supabase-service-role-key KEY  Supabase service role key"
            echo "  --project-ref REF                Supabase project reference"
            echo "  --project-dir DIR                Project directory (default: current)"
            echo "  -h, --help                       Show this help message"
            echo ""
            echo "If no arguments are provided, the script will use local Supabase defaults."
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Set defaults
PROJECT_DIR="${PROJECT_DIR:-.}"

# Track whether we're using local or production credentials
IS_LOCAL=true

# If no Supabase credentials provided, use local defaults
if [ -z "$SUPABASE_URL" ]; then
    print_info "No Supabase URL provided, using local default"
    SUPABASE_URL="http://127.0.0.1:54321"
else
    # Check if this is a production URL
    if [[ "$SUPABASE_URL" == *"supabase.co"* ]] || [[ "$SUPABASE_URL" != "http://127.0.0.1"* ]]; then
        IS_LOCAL=false
    fi
fi

if [ -z "$SUPABASE_ANON_KEY" ]; then
    print_info "No Supabase anon key provided, using local default"
    # This is the default local Supabase anon key
    SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"
fi

if [ -z "$SUPABASE_SERVICE_ROLE_KEY" ]; then
    print_info "No Supabase service role key provided, using local default"
    # This is the default local Supabase service role key
    SUPABASE_SERVICE_ROLE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU"
fi

# Change to project directory
cd "$PROJECT_DIR"

# Get the absolute path after cd
PROJECT_DIR="$(pwd)"

# Create apps directories if they don't exist
mkdir -p apps/web
mkdir -p apps/mcp-server

echo ""
print_info "Generating environment files..."

# Generate apps/web/.env.local
print_info "Creating apps/web/.env.local..."
cat > apps/web/.env.local << EOF
# Supabase Configuration
# These are local development credentials by default
NEXT_PUBLIC_SUPABASE_URL=$SUPABASE_URL
NEXT_PUBLIC_SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY

# For server-side operations (optional, only if needed)
# SUPABASE_SERVICE_ROLE_KEY=$SUPABASE_SERVICE_ROLE_KEY
EOF

print_success "Created apps/web/.env.local"

# Generate apps/mcp-server/.env.local
print_info "Creating apps/mcp-server/.env.local..."
cat > apps/mcp-server/.env.local << EOF
# Supabase Configuration
# These are local development credentials by default
SUPABASE_URL=$SUPABASE_URL
SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
SUPABASE_SERVICE_ROLE_KEY=$SUPABASE_SERVICE_ROLE_KEY
EOF

print_success "Created apps/mcp-server/.env.local"

# Generate .env.example for web app
print_info "Creating apps/web/.env.example..."
cat > apps/web/.env.example << EOF
# Supabase Configuration
# Get these values from your Supabase project settings

# For local development, use:
# NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321

# For production, use your project URL:
# NEXT_PUBLIC_SUPABASE_URL=https://your-project-ref.supabase.co

NEXT_PUBLIC_SUPABASE_URL=your_supabase_url_here
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_anon_key_here

# Optional: Service role key for server-side operations
# SUPABASE_SERVICE_ROLE_KEY=your_service_role_key_here
EOF

print_success "Created apps/web/.env.example"

# Generate .env.example for MCP server
print_info "Creating apps/mcp-server/.env.example..."
cat > apps/mcp-server/.env.example << EOF
# Supabase Configuration
# Get these values from your Supabase project settings

# For local development, use:
# SUPABASE_URL=http://127.0.0.1:54321

# For production, use your project URL:
# SUPABASE_URL=https://your-project-ref.supabase.co

SUPABASE_URL=your_supabase_url_here
SUPABASE_ANON_KEY=your_anon_key_here
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key_here
EOF

print_success "Created apps/mcp-server/.env.example"

# Update .gitignore to ensure .env.local files are ignored
print_info "Updating .gitignore..."

GITIGNORE_PATH=".gitignore"

# Create .gitignore if it doesn't exist
if [ ! -f "$GITIGNORE_PATH" ]; then
    touch "$GITIGNORE_PATH"
fi

# Add env file patterns if they don't exist
ENV_PATTERNS=(
    ".env.local"
    ".env*.local"
    "apps/web/.env.local"
    "apps/mcp-server/.env.local"
)

for pattern in "${ENV_PATTERNS[@]}"; do
    if ! grep -Fxq "$pattern" "$GITIGNORE_PATH" 2>/dev/null; then
        echo "$pattern" >> "$GITIGNORE_PATH"
    fi
done

print_success "Updated .gitignore"

# Summary
print_section "Summary"
echo ""
print_success "Environment files generated successfully!"
echo ""
echo -e "${GREEN}Files created:${NC}"
echo "  • apps/web/.env.local (local development)"
echo "  • apps/web/.env.example (template)"
echo "  • apps/mcp-server/.env.local (local development)"
echo "  • apps/mcp-server/.env.example (template)"
echo ""

if [ "$IS_LOCAL" = true ]; then
    print_info "Using local Supabase credentials (default)"
    echo ""
    echo -e "${BLUE}Local Supabase URLs:${NC}"
    echo "  • API: http://127.0.0.1:54321"
    echo "  • Studio: http://127.0.0.1:54323"
    echo "  • InBucket (Email testing): http://127.0.0.1:54324"
    echo ""
    echo -e "${YELLOW}Note:${NC} Make sure Supabase is running locally with:"
    echo "  supabase start"
else
    print_info "Using production Supabase credentials"
    echo ""
    echo -e "${BLUE}Project Details:${NC}"
    if [ -n "$PROJECT_REF" ]; then
        echo "  • Project Ref: $PROJECT_REF"
    fi
    echo "  • API URL: $SUPABASE_URL"
fi

echo ""
print_info "For production deployment:"
echo "  1. Set environment variables in Vercel dashboard"
echo "  2. Or use: vercel env add NEXT_PUBLIC_SUPABASE_URL"
echo "  3. Or use: vercel env add NEXT_PUBLIC_SUPABASE_ANON_KEY"
echo ""

print_success "✓ Environment setup complete!"
echo ""

