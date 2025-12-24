#!/bin/bash

# GitHub Actions Setup Script
# Creates workflow file and configures GitHub secrets for Supabase migrations

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Function to check if gh CLI is available
check_gh_cli() {
    if ! command -v gh &> /dev/null; then
        print_error "GitHub CLI (gh) is not installed"
        echo "Install it with:"
        echo "  macOS: brew install gh"
        echo "  Linux: See https://cli.github.com/manual/installation"
        return 1
    fi
    
    # Check if authenticated
    if ! gh auth status &> /dev/null; then
        print_error "GitHub CLI is not authenticated"
        echo "Run: gh auth login"
        return 1
    fi
    
    return 0
}

# Function to check if we're in a git repository
check_git_repo() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        print_error "Not in a git repository"
        return 1
    fi
    return 0
}

# Function to check if GitHub remote exists
check_github_remote() {
    if ! git remote get-url origin &> /dev/null; then
        print_error "No GitHub remote (origin) configured"
        echo "Add a remote with: git remote add origin <repo-url>"
        return 1
    fi
    
    local remote_url=$(git remote get-url origin)
    if [[ ! "$remote_url" =~ github\.com ]]; then
        print_error "Remote origin is not a GitHub repository"
        return 1
    fi
    
    return 0
}

# Function to extract repo owner and name from git remote
get_repo_info() {
    local remote_url=$(git remote get-url origin)
    
    # Handle both SSH and HTTPS URLs
    if [[ "$remote_url" =~ github\.com[:/]([^/]+)/([^/.]+) ]]; then
        REPO_OWNER="${BASH_REMATCH[1]}"
        REPO_NAME="${BASH_REMATCH[2]}"
        return 0
    else
        print_error "Could not parse GitHub repository from remote URL"
        return 1
    fi
}

# Function to create .github/workflows directory
create_workflows_dir() {
    local workflows_dir=".github/workflows"
    
    if [[ ! -d "$workflows_dir" ]]; then
        mkdir -p "$workflows_dir"
        print_success "Created $workflows_dir directory"
    else
        print_info "Directory $workflows_dir already exists"
    fi
}

# Function to create GitHub Actions workflow file
create_workflow_file() {
    local workflow_file=".github/workflows/supabase-migrations.yml"
    
    if [[ -f "$workflow_file" ]]; then
        print_warning "Workflow file already exists: $workflow_file"
        read -p "Overwrite? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Skipping workflow file creation"
            return 0
        fi
    fi
    
    cat > "$workflow_file" << 'EOF'
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
EOF
    
    print_success "Created GitHub Actions workflow: $workflow_file"
}

# Function to set GitHub secret
set_github_secret() {
    local secret_name="$1"
    local secret_value="$2"
    local repo="${REPO_OWNER}/${REPO_NAME}"
    
    if [[ -z "$secret_value" ]]; then
        print_error "No value provided for secret: $secret_name"
        return 1
    fi
    
    # Use gh CLI to set the secret
    if echo "$secret_value" | gh secret set "$secret_name" -R "$repo"; then
        print_success "Set GitHub secret: $secret_name"
        return 0
    else
        print_error "Failed to set GitHub secret: $secret_name"
        return 1
    fi
}

# Function to prompt for secret value
prompt_for_secret() {
    local secret_name="$1"
    local description="$2"
    local secret_value=""
    
    echo
    print_info "$description"
    read -s -p "Enter value for $secret_name: " secret_value
    echo
    
    if [[ -z "$secret_value" ]]; then
        print_warning "No value entered for $secret_name"
        return 1
    fi
    
    echo "$secret_value"
    return 0
}

# Function to get Supabase access token
get_supabase_access_token() {
    local token=""
    
    # Try to read from Supabase CLI config
    local supabase_config="$HOME/.supabase/access-token"
    if [[ -f "$supabase_config" ]]; then
        token=$(cat "$supabase_config" 2>/dev/null | tr -d '\n')
        if [[ -n "$token" ]]; then
            print_info "Found Supabase access token in CLI config"
            echo "$token"
            return 0
        fi
    fi
    
    # Prompt user if not found
    print_warning "Supabase access token not found in CLI config"
    echo "Get your access token from: https://app.supabase.com/account/tokens"
    token=$(prompt_for_secret "SUPABASE_ACCESS_TOKEN" "Supabase Personal Access Token")
    
    echo "$token"
    return 0
}

# Function to get Supabase project ref from local config
get_supabase_project_ref() {
    local project_ref=""
    
    # Try to read from supabase/config.toml
    if [[ -f "supabase/config.toml" ]]; then
        project_ref=$(grep "project_id" supabase/config.toml | cut -d '"' -f 2 | tr -d '\n')
        if [[ -n "$project_ref" ]]; then
            print_info "Found Supabase project ref in config: $project_ref"
            echo "$project_ref"
            return 0
        fi
    fi
    
    # Prompt user if not found
    print_warning "Supabase project ref not found in config"
    echo "Get your project ref from: Supabase Dashboard > Project Settings > API > Project ID"
    project_ref=$(prompt_for_secret "SUPABASE_PROJECT_REF" "Supabase Project Reference ID")
    
    echo "$project_ref"
    return 0
}

# Function to get database URL
get_database_url() {
    local db_url=""
    
    print_warning "Database URL required"
    echo "Get your database URL from: Supabase Dashboard > Project Settings > Database > URI"
    echo "Format: postgresql://postgres:[YOUR-PASSWORD]@db.[PROJECT-REF].supabase.co:5432/postgres"
    db_url=$(prompt_for_secret "SUPABASE_DB_URL_PRODUCTION" "Production Database Connection String")
    
    echo "$db_url"
    return 0
}

# Function to setup all GitHub secrets
setup_github_secrets() {
    print_info "Setting up GitHub secrets..."
    echo
    
    # Get Supabase credentials
    local access_token=$(get_supabase_access_token)
    if [[ -z "$access_token" ]]; then
        print_error "Failed to get Supabase access token"
        return 1
    fi
    
    local project_ref=$(get_supabase_project_ref)
    if [[ -z "$project_ref" ]]; then
        print_error "Failed to get Supabase project ref"
        return 1
    fi
    
    local db_url=$(get_database_url)
    if [[ -z "$db_url" ]]; then
        print_error "Failed to get database URL"
        return 1
    fi
    
    # Set the secrets
    echo
    print_info "Setting GitHub secrets for repository: ${REPO_OWNER}/${REPO_NAME}"
    
    set_github_secret "SUPABASE_ACCESS_TOKEN" "$access_token" || return 1
    set_github_secret "SUPABASE_PROJECT_REF" "$project_ref" || return 1
    set_github_secret "SUPABASE_DB_URL_PRODUCTION" "$db_url" || return 1
    
    return 0
}

# Function to commit workflow file
commit_workflow() {
    if [[ -n "$(git status --porcelain .github/workflows/)" ]]; then
        print_info "Committing GitHub Actions workflow..."
        git add .github/workflows/supabase-migrations.yml
        git commit -m "Add GitHub Actions workflow for Supabase migrations"
        print_success "Committed workflow file"
    else
        print_info "No changes to commit"
    fi
}

# Main execution
main() {
    echo
    echo "================================================"
    echo "  GitHub Actions Setup for Supabase Migrations"
    echo "================================================"
    echo
    
    # Perform checks
    print_info "Checking prerequisites..."
    check_gh_cli || exit 1
    check_git_repo || exit 1
    check_github_remote || exit 1
    get_repo_info || exit 1
    
    print_success "Prerequisites check passed"
    print_info "Repository: ${REPO_OWNER}/${REPO_NAME}"
    echo
    
    # Create workflow directory and file
    create_workflows_dir
    create_workflow_file
    echo
    
    # Setup GitHub secrets
    print_info "Now setting up GitHub secrets..."
    print_warning "You will need:"
    echo "  1. Supabase personal access token"
    echo "  2. Supabase project reference ID"
    echo "  3. Production database connection string"
    echo
    
    read -p "Continue with secrets setup? (Y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        print_warning "Skipping secrets setup"
        print_info "You can set secrets manually later:"
        echo "  gh secret set SUPABASE_ACCESS_TOKEN -R ${REPO_OWNER}/${REPO_NAME}"
        echo "  gh secret set SUPABASE_PROJECT_REF -R ${REPO_OWNER}/${REPO_NAME}"
        echo "  gh secret set SUPABASE_DB_URL_PRODUCTION -R ${REPO_OWNER}/${REPO_NAME}"
    else
        setup_github_secrets || {
            print_error "Failed to setup GitHub secrets"
            exit 1
        }
    fi
    
    echo
    
    # Offer to commit
    if [[ -n "$(git status --porcelain .github/workflows/)" ]]; then
        read -p "Commit workflow file to git? (Y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            commit_workflow
        fi
    fi
    
    echo
    echo "================================================"
    print_success "GitHub Actions setup complete!"
    echo "================================================"
    echo
    print_info "Workflow file created: .github/workflows/supabase-migrations.yml"
    print_info "GitHub secrets configured for: ${REPO_OWNER}/${REPO_NAME}"
    echo
    print_info "Next steps:"
    echo "  1. Push your code to trigger the workflow:"
    echo "     git push origin main"
    echo "  2. View workflow runs in GitHub:"
    echo "     https://github.com/${REPO_OWNER}/${REPO_NAME}/actions"
    echo "  3. The workflow will run automatically when migrations change"
    echo
}

# Run main function
main "$@"

