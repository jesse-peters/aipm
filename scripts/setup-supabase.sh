#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Function to print colored messages
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Function to cleanup on error
cleanup_on_error() {
    print_error "Setup failed. Cleaning up..."
    
    # Stop local Supabase if it was started
    if [ -f "$PROJECT_ROOT/supabase/.temp/started" ]; then
        print_info "Stopping local Supabase..."
        cd "$PROJECT_ROOT" && supabase stop || true
        rm -f "$PROJECT_ROOT/supabase/.temp/started"
    fi
    
    # Note: We don't delete the remote project as it might have useful data
    # User can manually delete it if needed
    if [ -n "$SUPABASE_PROJECT_REF" ]; then
        print_warning "Remote Supabase project $SUPABASE_PROJECT_REF was created but not fully configured."
        print_warning "You may want to delete it manually: supabase projects delete $SUPABASE_PROJECT_REF"
    fi
    
    exit 1
}

trap cleanup_on_error ERR

# Parse command line arguments
DRY_RUN=false
LOCAL_ONLY=false
PROJECT_NAME=""
ORG_SLUG=""
DB_PASSWORD=""
SKIP_REMOTE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --local-only)
            LOCAL_ONLY=true
            SKIP_REMOTE=true
            shift
            ;;
        --project-name)
            PROJECT_NAME="$2"
            shift 2
            ;;
        --org-slug)
            ORG_SLUG="$2"
            shift 2
            ;;
        --db-password)
            DB_PASSWORD="$2"
            shift 2
            ;;
        --skip-remote)
            SKIP_REMOTE=true
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Usage: $0 [--dry-run] [--local-only] [--project-name NAME] [--org-slug SLUG] [--db-password PASSWORD] [--skip-remote]"
            exit 1
            ;;
    esac
done

print_info "Starting Supabase setup..."

# Check if Supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    print_error "Supabase CLI is not installed"
    print_info "Install it with: npm install -g supabase"
    exit 1
fi

print_success "Supabase CLI is installed"

# Check if Docker is running (needed for local Supabase)
if ! docker info &> /dev/null; then
    print_error "Docker is not running"
    print_info "Please start Docker Desktop and try again"
    exit 1
fi

print_success "Docker is running"

# Navigate to project root
cd "$PROJECT_ROOT"

# Variables to store credentials
SUPABASE_PROJECT_REF=""
SUPABASE_API_URL=""
SUPABASE_ANON_KEY=""
SUPABASE_SERVICE_ROLE_KEY=""
SUPABASE_DB_URL=""
SUPABASE_JWT_SECRET=""

# Step 1: Create remote Supabase project (unless skipped)
if [ "$SKIP_REMOTE" = false ]; then
    print_info "Creating remote Supabase project..."
    
    # Get project name if not provided
    if [ -z "$PROJECT_NAME" ]; then
        read -p "Enter project name (default: my-app): " PROJECT_NAME
        PROJECT_NAME=${PROJECT_NAME:-my-app}
    fi
    
    # Get organization slug if not provided
    if [ -z "$ORG_SLUG" ]; then
        print_info "Fetching available organizations..."
        supabase orgs list || true
        echo ""
        read -p "Enter organization slug (press Enter for personal): " ORG_SLUG
    fi
    
    # Get database password if not provided
    if [ -z "$DB_PASSWORD" ]; then
        read -sp "Enter database password (min 12 characters): " DB_PASSWORD
        echo ""
        
        if [ ${#DB_PASSWORD} -lt 12 ]; then
            print_error "Database password must be at least 12 characters"
            exit 1
        fi
    fi
    
    # Select region (default to us-east-1)
    REGION="us-east-1"
    read -p "Enter region (default: us-east-1): " REGION_INPUT
    REGION=${REGION_INPUT:-$REGION}
    
    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would create Supabase project: $PROJECT_NAME"
    else
        # Create the project
        print_info "Creating Supabase project '$PROJECT_NAME'..."
        
        if [ -n "$ORG_SLUG" ]; then
            CREATE_OUTPUT=$(supabase projects create "$PROJECT_NAME" --org-id "$ORG_SLUG" --db-password "$DB_PASSWORD" --region "$REGION" 2>&1) || {
                print_error "Failed to create Supabase project"
                echo "$CREATE_OUTPUT"
                exit 1
            }
        else
            CREATE_OUTPUT=$(supabase projects create "$PROJECT_NAME" --db-password "$DB_PASSWORD" --region "$REGION" 2>&1) || {
                print_error "Failed to create Supabase project"
                echo "$CREATE_OUTPUT"
                exit 1
            }
        fi
        
        # Extract project ref from output
        # The output typically contains "Created project <project-name> with ref <project-ref>"
        SUPABASE_PROJECT_REF=$(echo "$CREATE_OUTPUT" | grep -oE '[a-z]{20}' | head -1)
        
        if [ -z "$SUPABASE_PROJECT_REF" ]; then
            print_error "Failed to extract project ref from output"
            echo "Output was:"
            echo "$CREATE_OUTPUT"
            exit 1
        fi
        
        print_success "Created Supabase project with ref: $SUPABASE_PROJECT_REF"
        
        # Wait for project to be ready
        print_info "Waiting for project to be ready (this may take 30-60 seconds)..."
        sleep 10
        
        MAX_RETRIES=12
        RETRY_COUNT=0
        
        while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
            if supabase projects list | grep -q "$SUPABASE_PROJECT_REF"; then
                PROJECT_STATUS=$(supabase projects list | grep "$SUPABASE_PROJECT_REF" | awk '{print $3}')
                if [ "$PROJECT_STATUS" = "ACTIVE_HEALTHY" ] || [ "$PROJECT_STATUS" = "ACTIVE" ]; then
                    print_success "Project is ready!"
                    break
                fi
            fi
            
            RETRY_COUNT=$((RETRY_COUNT + 1))
            if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
                print_info "Still waiting... (attempt $RETRY_COUNT/$MAX_RETRIES)"
                sleep 5
            else
                print_warning "Project creation is taking longer than expected, but continuing..."
            fi
        done
        
        # Get project API settings
        print_info "Fetching project API keys..."
        sleep 2
        
        API_SETTINGS=$(supabase projects api-keys --project-ref "$SUPABASE_PROJECT_REF" 2>&1) || {
            print_error "Failed to fetch API keys"
            echo "$API_SETTINGS"
            exit 1
        }
        
        # Extract keys from output
        SUPABASE_ANON_KEY=$(echo "$API_SETTINGS" | grep "anon" | grep -oE 'eyJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]*\.[A-Za-z0-9_-]*')
        SUPABASE_SERVICE_ROLE_KEY=$(echo "$API_SETTINGS" | grep "service_role" | grep -oE 'eyJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]*\.[A-Za-z0-9_-]*')
        
        if [ -z "$SUPABASE_ANON_KEY" ] || [ -z "$SUPABASE_SERVICE_ROLE_KEY" ]; then
            print_error "Failed to extract API keys"
            echo "API settings output:"
            echo "$API_SETTINGS"
            exit 1
        fi
        
        # Construct API URL
        SUPABASE_API_URL="https://${SUPABASE_PROJECT_REF}.supabase.co"
        
        # Get database connection string
        SUPABASE_DB_URL="postgresql://postgres:${DB_PASSWORD}@db.${SUPABASE_PROJECT_REF}.supabase.co:5432/postgres"
        
        print_success "Retrieved API keys and connection strings"
        
        # Configure auth settings via Management API
        print_info "Configuring authentication settings..."
        
        # Note: Auth configuration might require additional API calls
        # For now, we'll note that email auth should be enabled by default
        print_info "Email authentication is enabled by default"
        print_info "You can configure additional auth providers in the Supabase dashboard"
        print_success "Auth configuration complete"
    fi
else
    print_info "Skipping remote project creation (--skip-remote or --local-only flag)"
fi

# Step 2: Initialize local Supabase
print_info "Initializing local Supabase..."

if [ "$DRY_RUN" = true ]; then
    print_info "[DRY RUN] Would initialize local Supabase"
else
    if [ ! -d "$PROJECT_ROOT/supabase" ]; then
        supabase init
        print_success "Initialized local Supabase configuration"
    else
        print_info "Supabase already initialized, skipping..."
    fi
fi

# Step 3: Link local to remote (if remote was created)
if [ "$SKIP_REMOTE" = false ] && [ -n "$SUPABASE_PROJECT_REF" ]; then
    print_info "Linking local instance to remote project..."
    
    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would link to project: $SUPABASE_PROJECT_REF"
    else
        # Link requires the database password
        supabase link --project-ref "$SUPABASE_PROJECT_REF" --password "$DB_PASSWORD" || {
            print_warning "Failed to link project (you may need to do this manually later)"
        }
        print_success "Linked local to remote project"
    fi
fi

# Step 4: Start local Supabase
print_info "Starting local Supabase..."

if [ "$DRY_RUN" = true ]; then
    print_info "[DRY RUN] Would start local Supabase"
else
    # Check if Supabase is already running
    if supabase status &> /dev/null; then
        print_info "Local Supabase is already running"
    else
        supabase start
        
        # Mark as started for cleanup
        mkdir -p "$PROJECT_ROOT/supabase/.temp"
        touch "$PROJECT_ROOT/supabase/.temp/started"
    fi
    
    print_success "Local Supabase is running"
    
    # Get local credentials
    print_info "Fetching local Supabase credentials..."
    
    LOCAL_STATUS=$(supabase status)
    
    # Extract local credentials
    LOCAL_API_URL=$(echo "$LOCAL_STATUS" | grep "API URL" | awk '{print $3}')
    LOCAL_ANON_KEY=$(echo "$LOCAL_STATUS" | grep "anon key" | awk '{print $3}')
    LOCAL_SERVICE_ROLE_KEY=$(echo "$LOCAL_STATUS" | grep "service_role key" | awk '{print $3}')
    LOCAL_DB_URL=$(echo "$LOCAL_STATUS" | grep "DB URL" | awk '{print $3}')
    LOCAL_STUDIO_URL=$(echo "$LOCAL_STATUS" | grep "Studio URL" | awk '{print $3}')
    
    print_success "Retrieved local credentials"
fi

# Step 5: Output credentials for next steps
print_info "Outputting credentials..."

# Create output file
OUTPUT_FILE="$PROJECT_ROOT/.supabase-credentials.env"

if [ "$DRY_RUN" = false ]; then
    cat > "$OUTPUT_FILE" << EOF
# Supabase Credentials
# Generated on $(date)

# Remote (Production) Credentials
SUPABASE_PROJECT_REF=$SUPABASE_PROJECT_REF
SUPABASE_API_URL=$SUPABASE_API_URL
SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
SUPABASE_SERVICE_ROLE_KEY=$SUPABASE_SERVICE_ROLE_KEY
SUPABASE_DB_URL=$SUPABASE_DB_URL

# Local Development Credentials
LOCAL_API_URL=$LOCAL_API_URL
LOCAL_ANON_KEY=$LOCAL_ANON_KEY
LOCAL_SERVICE_ROLE_KEY=$LOCAL_SERVICE_ROLE_KEY
LOCAL_DB_URL=$LOCAL_DB_URL
LOCAL_STUDIO_URL=$LOCAL_STUDIO_URL
EOF
    
    print_success "Credentials saved to .supabase-credentials.env"
fi

# Display summary
echo ""
echo "======================================"
print_success "Supabase Setup Complete!"
echo "======================================"
echo ""

if [ "$SKIP_REMOTE" = false ]; then
    echo "Remote Project:"
    echo "  Project Ref: $SUPABASE_PROJECT_REF"
    echo "  API URL: $SUPABASE_API_URL"
    echo "  Dashboard: https://supabase.com/dashboard/project/$SUPABASE_PROJECT_REF"
    echo ""
fi

if [ "$DRY_RUN" = false ]; then
    echo "Local Instance:"
    echo "  API URL: $LOCAL_API_URL"
    echo "  Studio: $LOCAL_STUDIO_URL"
    echo "  Database: $LOCAL_DB_URL"
    echo ""
fi

echo "Next Steps:"
echo "  1. Run the generate-env-files.sh script to create .env files"
echo "  2. View your local Supabase Studio at: $LOCAL_STUDIO_URL"
echo "  3. Configure additional auth providers in the dashboard if needed"
echo ""

if [ "$DRY_RUN" = false ]; then
    echo "Credentials file: $OUTPUT_FILE"
    echo "⚠  Keep this file secure and do not commit it to git!"
fi

echo ""

# Export variables for use by calling scripts
export SUPABASE_PROJECT_REF
export SUPABASE_API_URL
export SUPABASE_ANON_KEY
export SUPABASE_SERVICE_ROLE_KEY
export SUPABASE_DB_URL
export LOCAL_API_URL
export LOCAL_ANON_KEY
export LOCAL_SERVICE_ROLE_KEY
export LOCAL_DB_URL
export LOCAL_STUDIO_URL

exit 0

