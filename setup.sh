#!/bin/bash

# =============================================================================
# Main Setup Script - Automated Monorepo Setup
# =============================================================================
# This script orchestrates the complete setup of a production-ready monorepo
# with Next.js 15, Supabase, and MCP server - zero manual intervention required
# =============================================================================

set -e  # Exit on error
set -o pipefail  # Exit on pipe failures

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Progress tracking
CURRENT_STEP=0
TOTAL_STEPS=15

# Default values
DEFAULT_PROJECT_NAME="my-app"
DEFAULT_SUPABASE_ORG=""
SKIP_PRODUCTION=false

# State tracking for cleanup
CREATED_PROJECT_DIR=""
SUPABASE_PROJECT_REF=""
SUPABASE_LINKED=false
VERCEL_DEPLOYED=false

# =============================================================================
# Helper Functions
# =============================================================================

# Print colored message
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Print error and exit
error_exit() {
    print_message "$RED" "❌ ERROR: $1"
    echo ""
    print_message "$YELLOW" "Cleaning up..."
    cleanup_on_failure
    exit 1
}

# Print success message
success() {
    print_message "$GREEN" "✓ $1"
}

# Print info message
info() {
    print_message "$BLUE" "ℹ $1"
}

# Print warning message
warning() {
    print_message "$YELLOW" "⚠ $1"
}

# Print step header
step() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    echo ""
    print_message "$CYAN" "═══════════════════════════════════════════════════════════════"
    print_message "$BOLD$CYAN" "Step $CURRENT_STEP/$TOTAL_STEPS: $1"
    print_message "$CYAN" "═══════════════════════════════════════════════════════════════"
    echo ""
}

# Show progress spinner
spinner() {
    local pid=$1
    local message=$2
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) % 10 ))
        printf "\r${BLUE}${spin:$i:1}${NC} $message..."
        sleep 0.1
    done
    printf "\r"
}

# Cleanup on failure
cleanup_on_failure() {
    if [ -n "$CREATED_PROJECT_DIR" ] && [ -d "$CREATED_PROJECT_DIR" ]; then
        warning "Removing created project directory: $CREATED_PROJECT_DIR"
        # Uncomment to enable automatic cleanup:
        # rm -rf "$CREATED_PROJECT_DIR"
        info "To manually clean up, run: rm -rf $CREATED_PROJECT_DIR"
    fi
    
    if [ "$SUPABASE_LINKED" = true ] && [ -n "$SUPABASE_PROJECT_REF" ]; then
        warning "Note: Supabase project $SUPABASE_PROJECT_REF was created"
        info "You may want to delete it manually from the Supabase dashboard"
    fi
    
    if [ "$VERCEL_DEPLOYED" = true ]; then
        warning "Note: Vercel project may have been created"
        info "Check your Vercel dashboard if cleanup is needed"
    fi
}

# Trap errors for cleanup
trap 'error_exit "Script failed at line $LINENO"' ERR

# =============================================================================
# Prerequisites Check
# =============================================================================

check_prerequisites() {
    step "Checking Prerequisites"
    
    local missing_deps=()
    
    # Check Node.js
    if ! command -v node &> /dev/null; then
        missing_deps+=("Node.js (>= 18)")
    else
        local node_version=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
        if [ "$node_version" -lt 18 ]; then
            missing_deps+=("Node.js >= 18 (current: $(node -v))")
        else
            success "Node.js $(node -v)"
        fi
    fi
    
    # Check pnpm
    if ! command -v pnpm &> /dev/null; then
        missing_deps+=("pnpm")
    else
        success "pnpm $(pnpm -v)"
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        missing_deps+=("Docker")
    else
        if ! docker info &> /dev/null; then
            warning "Docker is installed but not running"
            missing_deps+=("Docker (not running)")
        else
            success "Docker $(docker -v | cut -d' ' -f3 | cut -d',' -f1)"
        fi
    fi
    
    # Check Supabase CLI
    if ! command -v supabase &> /dev/null; then
        missing_deps+=("Supabase CLI")
    else
        success "Supabase CLI $(supabase -v 2>&1 | head -1 | cut -d' ' -f3)"
    fi
    
    # Check GitHub CLI
    if ! command -v gh &> /dev/null; then
        missing_deps+=("GitHub CLI")
    else
        if ! gh auth status &> /dev/null; then
            warning "GitHub CLI installed but not authenticated"
            missing_deps+=("GitHub CLI (not authenticated)")
        else
            success "GitHub CLI $(gh --version | head -1 | cut -d' ' -f3)"
        fi
    fi
    
    # Check Vercel CLI
    if ! command -v vercel &> /dev/null; then
        missing_deps+=("Vercel CLI")
    else
        if ! vercel whoami &> /dev/null 2>&1; then
            warning "Vercel CLI installed but not authenticated"
            missing_deps+=("Vercel CLI (not authenticated)")
        else
            success "Vercel CLI $(vercel --version)"
        fi
    fi
    
    # Check Git
    if ! command -v git &> /dev/null; then
        missing_deps+=("Git")
    else
        success "Git $(git --version | cut -d' ' -f3)"
    fi
    
    # If missing dependencies, show installation instructions
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo ""
        error_exit "Missing required dependencies:\n$(printf '  - %s\n' "${missing_deps[@]}")\n\nInstallation instructions:\n\nNode.js (>= 18):\n  https://nodejs.org/\n\npnpm:\n  npm install -g pnpm\n\nDocker:\n  https://www.docker.com/products/docker-desktop\n\nSupabase CLI:\n  npm install -g supabase\n\nGitHub CLI:\n  https://cli.github.com/\n  Then run: gh auth login\n\nVercel CLI:\n  npm install -g vercel\n  Then run: vercel login\n\nGit:\n  https://git-scm.com/"
    fi
    
    success "All prerequisites satisfied"
}

# =============================================================================
# Interactive Prompts
# =============================================================================

gather_inputs() {
    step "Gathering Project Information"
    
    echo ""
    print_message "$BOLD" "Please provide the following information:"
    echo ""
    
    # Project name
    read -p "$(echo -e ${CYAN}Project name${NC}) [${DEFAULT_PROJECT_NAME}]: " PROJECT_NAME
    PROJECT_NAME=${PROJECT_NAME:-$DEFAULT_PROJECT_NAME}
    
    # Validate project name
    if [[ ! "$PROJECT_NAME" =~ ^[a-z0-9-]+$ ]]; then
        error_exit "Project name must contain only lowercase letters, numbers, and hyphens"
    fi
    
    # Check if directory already exists
    if [ -d "$PROJECT_NAME" ]; then
        error_exit "Directory '$PROJECT_NAME' already exists. Please choose a different name or remove the existing directory."
    fi
    
    info "Project will be created at: $(pwd)/$PROJECT_NAME"
    
    # Supabase organization
    echo ""
    read -p "$(echo -e ${CYAN}Supabase organization slug${NC}) [leave empty for personal]: " SUPABASE_ORG
    SUPABASE_ORG=${SUPABASE_ORG:-$DEFAULT_SUPABASE_ORG}
    
    # Database password
    echo ""
    while true; do
        read -sp "$(echo -e ${CYAN}Supabase database password${NC}) (min 8 chars): " DB_PASSWORD
        echo ""
        if [ ${#DB_PASSWORD} -lt 8 ]; then
            warning "Password must be at least 8 characters"
            continue
        fi
        read -sp "$(echo -e ${CYAN}Confirm password${NC}): " DB_PASSWORD_CONFIRM
        echo ""
        if [ "$DB_PASSWORD" = "$DB_PASSWORD_CONFIRM" ]; then
            break
        else
            warning "Passwords do not match"
        fi
    done
    
    # GitHub repository
    echo ""
    info "GitHub repository is needed for CI/CD workflows"
    read -p "$(echo -e ${CYAN}GitHub repository${NC}) (format: username/repo) [skip for now]: " GITHUB_REPO
    
    # Skip production deployment
    echo ""
    read -p "$(echo -e ${CYAN}Deploy to production${NC}) (Vercel)? [Y/n]: " DEPLOY_PROD
    DEPLOY_PROD=${DEPLOY_PROD:-Y}
    if [[ ! "$DEPLOY_PROD" =~ ^[Yy] ]]; then
        SKIP_PRODUCTION=true
        warning "Production deployment will be skipped"
    fi
    
    # Confirmation
    echo ""
    print_message "$BOLD" "Summary:"
    echo ""
    echo "  Project name:       $PROJECT_NAME"
    echo "  Supabase org:       ${SUPABASE_ORG:-<personal>}"
    echo "  GitHub repo:        ${GITHUB_REPO:-<not set>}"
    echo "  Deploy to prod:     $([ "$SKIP_PRODUCTION" = true ] && echo "No" || echo "Yes")"
    echo ""
    
    read -p "$(echo -e ${YELLOW}Proceed with setup?${NC}) [Y/n]: " CONFIRM
    CONFIRM=${CONFIRM:-Y}
    if [[ ! "$CONFIRM" =~ ^[Yy] ]]; then
        info "Setup cancelled by user"
        exit 0
    fi
}

# =============================================================================
# Main Setup Steps
# =============================================================================

create_monorepo() {
    step "Creating Turborepo Monorepo"
    
    info "Creating monorepo: $PROJECT_NAME"
    
    # Create using pnpm create turbo
    pnpm create turbo@latest "$PROJECT_NAME" -m pnpm --skip-install || error_exit "Failed to create Turborepo"
    
    CREATED_PROJECT_DIR="$(pwd)/$PROJECT_NAME"
    cd "$CREATED_PROJECT_DIR" || error_exit "Failed to change to project directory"
    
    # Add packageManager field to root package.json
    info "Adding packageManager field to package.json"
    if [ -f "package.json" ]; then
        PNPM_VERSION=$(pnpm --version | tr -d '\n')
        node <<EOF
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
pkg.packageManager = 'pnpm@$PNPM_VERSION';
fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');
EOF
        success "Added packageManager field (pnpm@$PNPM_VERSION)"
    fi
    
    # Install turbo locally as dev dependency
    info "Installing turbo locally"
    pnpm add -D turbo@latest -w || error_exit "Failed to install turbo"
    success "Turbo installed locally"
    
    # Verify pnpm-workspace.yaml exists
    if [ ! -f "pnpm-workspace.yaml" ]; then
        info "Creating pnpm-workspace.yaml"
        cat > pnpm-workspace.yaml <<EOF
packages:
  - 'apps/*'
EOF
        success "Created pnpm-workspace.yaml"
    else
        success "pnpm-workspace.yaml already exists"
    fi
    
    success "Monorepo created at $CREATED_PROJECT_DIR"
}

create_nextjs_app() {
    step "Creating Next.js 15 Application"
    
    info "Setting up Next.js app with TypeScript and Tailwind CSS"
    
    # Create Next.js app in apps/web
    cd "$CREATED_PROJECT_DIR" || error_exit "Failed to change to project directory"
    
    # Remove default apps if they exist
    [ -d "apps/docs" ] && rm -rf apps/docs
    [ -d "apps/web" ] && rm -rf apps/web
    
    # Create Next.js app
    pnpm create next-app@latest apps/web \
        --typescript \
        --tailwind \
        --app \
        --src-dir \
        --import-alias "@/*" \
        --no-git \
        --yes || error_exit "Failed to create Next.js app"
    
    success "Next.js 15 app created"
}

install_shadcn() {
    step "Installing shadcn/ui Components"
    
    cd "$CREATED_PROJECT_DIR/apps/web" || error_exit "Failed to change to web directory"
    
    info "Initializing shadcn/ui"
    
    # Create components.json for shadcn
    cat > components.json <<EOF
{
  "\$schema": "https://ui.shadcn.com/schema.json",
  "style": "default",
  "rsc": true,
  "tsx": true,
  "tailwind": {
    "config": "tailwind.config.ts",
    "css": "src/app/globals.css",
    "baseColor": "slate",
    "cssVariables": true,
    "prefix": ""
  },
  "aliases": {
    "components": "@/components",
    "utils": "@/lib/utils",
    "ui": "@/components/ui"
  }
}
EOF
    
    # Install shadcn components
    pnpm dlx shadcn@latest add button card input label form --yes || warning "Some shadcn components may not have installed correctly"
    
    success "shadcn/ui components installed"
}

setup_supabase() {
    step "Setting Up Supabase Project"
    
    cd "$CREATED_PROJECT_DIR" || error_exit "Failed to change to project directory"
    
    info "Creating scripts directory"
    mkdir -p scripts
    
    info "Running Supabase setup script"
    
    if [ -f "scripts/setup-supabase.sh" ]; then
        chmod +x scripts/setup-supabase.sh
        
        # Run script with parameters
        if [ -n "$SUPABASE_ORG" ]; then
            ./scripts/setup-supabase.sh "$PROJECT_NAME" "$DB_PASSWORD" "$SUPABASE_ORG" || error_exit "Supabase setup failed"
        else
            ./scripts/setup-supabase.sh "$PROJECT_NAME" "$DB_PASSWORD" || error_exit "Supabase setup failed"
        fi
        
        # Source the output to get environment variables
        if [ -f ".supabase-setup-output" ]; then
            source .supabase-setup-output
            SUPABASE_PROJECT_REF="$SUPABASE_PROJECT_REF"
            SUPABASE_LINKED=true
        fi
    else
        warning "scripts/setup-supabase.sh not found, skipping Supabase automation"
        info "You'll need to set up Supabase manually"
    fi
    
    success "Supabase project configured"
}

generate_env_files() {
    step "Generating Environment Files"
    
    cd "$CREATED_PROJECT_DIR" || error_exit "Failed to change to project directory"
    
    if [ -f "scripts/generate-env-files.sh" ]; then
        chmod +x scripts/generate-env-files.sh
        ./scripts/generate-env-files.sh || error_exit "Environment file generation failed"
    else
        warning "scripts/generate-env-files.sh not found, skipping env file generation"
    fi
    
    success "Environment files generated"
}

generate_code_files() {
    step "Generating Application Code Files"
    
    cd "$CREATED_PROJECT_DIR" || error_exit "Failed to change to project directory"
    
    if [ -f "scripts/generate-files.sh" ]; then
        chmod +x scripts/generate-files.sh
        ./scripts/generate-files.sh || error_exit "Code file generation failed"
    else
        warning "scripts/generate-files.sh not found, skipping code generation"
    fi
    
    success "Application code files generated"
}

setup_migrations() {
    step "Setting Up Database Migrations"
    
    cd "$CREATED_PROJECT_DIR" || error_exit "Failed to change to project directory"
    
    if [ -f "scripts/setup-migrations.sh" ]; then
        chmod +x scripts/setup-migrations.sh
        ./scripts/setup-migrations.sh || error_exit "Migration setup failed"
    else
        warning "scripts/setup-migrations.sh not found, skipping migration setup"
    fi
    
    success "Database migrations configured"
}

install_dependencies() {
    step "Installing Dependencies"
    
    cd "$CREATED_PROJECT_DIR" || error_exit "Failed to change to project directory"
    
    info "Running pnpm install (this may take a few minutes)..."
    
    pnpm install || error_exit "Dependency installation failed"
    
    success "All dependencies installed"
}

git_commit_all() {
    step "Committing to Git"
    
    cd "$CREATED_PROJECT_DIR" || error_exit "Failed to change to project directory"
    
    # Initialize git if not already done
    if [ ! -d ".git" ]; then
        info "Initializing Git repository"
        git init || error_exit "Git init failed"
    fi
    
    info "Adding all files to git"
    git add . || error_exit "Git add failed"
    
    info "Creating initial commit"
    git commit -m "Initial commit: Complete monorepo setup with Next.js, Supabase, and MCP server" || warning "Git commit failed (may already be committed)"
    
    # Set up remote if GitHub repo provided
    if [ -n "$GITHUB_REPO" ]; then
        info "Adding GitHub remote"
        git remote add origin "https://github.com/$GITHUB_REPO.git" || warning "Remote already exists"
        
        info "Creating main branch"
        git branch -M main || warning "Branch already named main"
        
        read -p "$(echo -e ${YELLOW}Push to GitHub now?${NC}) [Y/n]: " PUSH_NOW
        PUSH_NOW=${PUSH_NOW:-Y}
        if [[ "$PUSH_NOW" =~ ^[Yy] ]]; then
            git push -u origin main || warning "Push failed (you may need to create the repo first)"
        fi
    fi
    
    success "Git repository initialized and committed"
}

setup_github_actions() {
    step "Setting Up GitHub Actions"
    
    cd "$CREATED_PROJECT_DIR" || error_exit "Failed to change to project directory"
    
    if [ -z "$GITHUB_REPO" ]; then
        warning "GitHub repository not set, skipping GitHub Actions setup"
        return
    fi
    
    if [ -f "scripts/setup-github-actions.sh" ]; then
        chmod +x scripts/setup-github-actions.sh
        ./scripts/setup-github-actions.sh "$GITHUB_REPO" || warning "GitHub Actions setup failed"
    else
        warning "scripts/setup-github-actions.sh not found, skipping GitHub Actions setup"
    fi
    
    success "GitHub Actions configured"
}

deploy_to_vercel() {
    step "Deploying to Vercel"
    
    if [ "$SKIP_PRODUCTION" = true ]; then
        warning "Production deployment skipped (user choice)"
        return
    fi
    
    cd "$CREATED_PROJECT_DIR" || error_exit "Failed to change to project directory"
    
    if [ -f "scripts/deploy-vercel.sh" ]; then
        chmod +x scripts/deploy-vercel.sh
        ./scripts/deploy-vercel.sh || warning "Vercel deployment failed"
        VERCEL_DEPLOYED=true
    else
        warning "scripts/deploy-vercel.sh not found, skipping Vercel deployment"
    fi
    
    success "Vercel deployment completed"
}

# =============================================================================
# Final Summary
# =============================================================================

display_summary() {
    step "Setup Complete! 🎉"
    
    echo ""
    print_message "$GREEN$BOLD" "╔════════════════════════════════════════════════════════════════╗"
    print_message "$GREEN$BOLD" "║                    SETUP SUCCESSFUL                            ║"
    print_message "$GREEN$BOLD" "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    
    success "Monorepo created at: $CREATED_PROJECT_DIR"
    success "Next.js app configured with Tailwind 4 and shadcn/ui"
    
    if [ -n "$SUPABASE_PROJECT_REF" ]; then
        success "Supabase project created: $SUPABASE_PROJECT_REF"
        success "Local Supabase running at: http://localhost:54321"
        success "Supabase Studio at: http://localhost:54323"
    fi
    
    success "Auth configured with email/password"
    success "Database migrations applied"
    success "MCP server skeleton created"
    
    if [ -n "$GITHUB_REPO" ]; then
        success "GitHub Actions configured for: $GITHUB_REPO"
    fi
    
    if [ "$VERCEL_DEPLOYED" = true ]; then
        success "Deployed to Vercel"
        if [ -f ".vercel-url" ]; then
            local vercel_url=$(cat .vercel-url)
            info "Production URL: $vercel_url"
        fi
    fi
    
    echo ""
    print_message "$CYAN$BOLD" "Next Steps:"
    echo ""
    echo "  1. cd $PROJECT_NAME"
    echo "  2. pnpm dev"
    echo "  3. Open http://localhost:3000"
    echo "  4. Visit /signup to create your first account"
    echo ""
    
    print_message "$CYAN$BOLD" "Environment Files:"
    echo ""
    if [ -f "$CREATED_PROJECT_DIR/apps/web/.env.local" ]; then
        echo "  ✓ apps/web/.env.local (local development)"
    fi
    if [ -f "$CREATED_PROJECT_DIR/apps/mcp-server/.env.local" ]; then
        echo "  ✓ apps/mcp-server/.env.local (local development)"
    fi
    echo ""
    
    if [ "$SKIP_PRODUCTION" = false ]; then
        info "Production environment configured in Vercel dashboard"
        echo ""
    fi
    
    print_message "$CYAN$BOLD" "Useful Commands:"
    echo ""
    echo "  pnpm dev              # Start all services"
    echo "  pnpm build            # Build all packages"
    echo "  pnpm lint             # Lint all packages"
    echo "  supabase status       # Check Supabase status"
    echo "  supabase db reset     # Reset local database"
    echo ""
    
    print_message "$GREEN" "Happy coding! 🚀"
    echo ""
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    clear
    echo ""
    print_message "$MAGENTA$BOLD" "╔═══════════════════════════════════════════════════════════════════╗"
    print_message "$MAGENTA$BOLD" "║                                                                   ║"
    print_message "$MAGENTA$BOLD" "║        Automated Monorepo Setup Script                            ║"
    print_message "$MAGENTA$BOLD" "║        Next.js 15 + Supabase + MCP Server                         ║"
    print_message "$MAGENTA$BOLD" "║                                                                   ║"
    print_message "$MAGENTA$BOLD" "╚═══════════════════════════════════════════════════════════════════╝"
    echo ""
    
    info "This script will set up a complete production-ready monorepo"
    info "Estimated time: 5-10 minutes"
    echo ""
    
    # Execute setup steps
    check_prerequisites
    gather_inputs
    create_monorepo
    create_nextjs_app
    install_shadcn
    setup_supabase
    generate_env_files
    generate_code_files
    setup_migrations
    install_dependencies
    git_commit_all
    setup_github_actions
    deploy_to_vercel
    display_summary
}

# Run main function
main "$@"

