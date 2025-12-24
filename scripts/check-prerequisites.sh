#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Track if any checks fail
CHECKS_FAILED=0

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
    CHECKS_FAILED=1
}

# Function to print warning message
print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Function to print info message
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_section "Checking Prerequisites"

# Check Docker
echo ""
print_info "Checking Docker..."
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version | cut -d ' ' -f3 | cut -d ',' -f1)
    if docker info &> /dev/null; then
        print_success "Docker installed and running (version $DOCKER_VERSION)"
    else
        print_error "Docker is installed but not running"
        echo "  Please start Docker Desktop or the Docker daemon"
        echo "  macOS: Open Docker Desktop application"
        echo "  Linux: sudo systemctl start docker"
    fi
else
    print_error "Docker is not installed"
    echo "  Install from: https://www.docker.com/get-started"
    echo "  macOS: brew install --cask docker"
    echo "  Linux: curl -fsSL https://get.docker.com | sh"
fi

# Check Node.js
echo ""
print_info "Checking Node.js..."
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version | cut -d 'v' -f2)
    NODE_MAJOR=$(echo $NODE_VERSION | cut -d '.' -f1)
    if [ "$NODE_MAJOR" -ge 18 ]; then
        print_success "Node.js installed (version $NODE_VERSION)"
    else
        print_error "Node.js version $NODE_VERSION is too old (minimum: 18.0.0)"
        echo "  Update Node.js:"
        echo "  Using nvm: nvm install 18"
        echo "  Using Homebrew: brew upgrade node"
        echo "  Or download from: https://nodejs.org/"
    fi
else
    print_error "Node.js is not installed"
    echo "  Install from: https://nodejs.org/"
    echo "  Recommended: Install via nvm (Node Version Manager)"
    echo "  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash"
    echo "  nvm install 18"
fi

# Check pnpm
echo ""
print_info "Checking pnpm..."
if command -v pnpm &> /dev/null; then
    PNPM_VERSION=$(pnpm --version)
    print_success "pnpm installed (version $PNPM_VERSION)"
else
    print_error "pnpm is not installed"
    echo "  Install pnpm:"
    echo "  npm install -g pnpm"
    echo "  Or via standalone script: curl -fsSL https://get.pnpm.io/install.sh | sh -"
fi

# Check Supabase CLI
echo ""
print_info "Checking Supabase CLI..."
if command -v supabase &> /dev/null; then
    SUPABASE_VERSION=$(supabase --version | cut -d ' ' -f1)
    print_success "Supabase CLI installed (version $SUPABASE_VERSION)"
else
    print_error "Supabase CLI is not installed"
    echo "  Install Supabase CLI:"
    echo "  npm install -g supabase"
    echo "  Or via Homebrew: brew install supabase/tap/supabase"
    echo "  Or download from: https://github.com/supabase/cli/releases"
fi

# Check GitHub CLI
echo ""
print_info "Checking GitHub CLI..."
if command -v gh &> /dev/null; then
    GH_VERSION=$(gh --version | head -n 1 | cut -d ' ' -f3)
    print_success "GitHub CLI installed (version $GH_VERSION)"
    
    # Check if authenticated
    if gh auth status &> /dev/null; then
        print_success "GitHub CLI is authenticated"
    else
        print_error "GitHub CLI is not authenticated"
        echo "  Authenticate with: gh auth login"
    fi
else
    print_error "GitHub CLI is not installed"
    echo "  Install GitHub CLI:"
    echo "  macOS: brew install gh"
    echo "  Linux: See https://github.com/cli/cli/blob/trunk/docs/install_linux.md"
    echo "  Or download from: https://cli.github.com/"
fi

# Check Vercel CLI
echo ""
print_info "Checking Vercel CLI..."
if command -v vercel &> /dev/null; then
    VERCEL_VERSION=$(vercel --version)
    print_success "Vercel CLI installed (version $VERCEL_VERSION)"
    
    # Check if authenticated
    if vercel whoami &> /dev/null; then
        VERCEL_USER=$(vercel whoami 2>/dev/null)
        print_success "Vercel CLI is authenticated (user: $VERCEL_USER)"
    else
        print_error "Vercel CLI is not authenticated"
        echo "  Authenticate with: vercel login"
    fi
else
    print_error "Vercel CLI is not installed"
    echo "  Install Vercel CLI:"
    echo "  npm install -g vercel"
fi

# Check Git
echo ""
print_info "Checking Git..."
if command -v git &> /dev/null; then
    GIT_VERSION=$(git --version | cut -d ' ' -f3)
    print_success "Git installed (version $GIT_VERSION)"
    
    # Check if git is initialized (only if in a directory)
    if [ -d .git ]; then
        print_success "Git repository initialized"
    else
        print_warning "Git repository not initialized in current directory"
        echo "  This will be initialized during setup if needed"
    fi
else
    print_error "Git is not installed"
    echo "  Install Git:"
    echo "  macOS: brew install git"
    echo "  Linux: sudo apt-get install git"
    echo "  Or download from: https://git-scm.com/downloads"
fi

# Summary
print_section "Summary"

if [ $CHECKS_FAILED -eq 0 ]; then
    echo ""
    print_success "All prerequisites are met! You're ready to run the setup."
    echo ""
    echo -e "${GREEN}Next step:${NC} Run ./setup.sh to begin the automated setup"
    echo ""
    exit 0
else
    echo ""
    print_error "Some prerequisites are missing or not configured correctly."
    echo ""
    echo -e "${YELLOW}Please install/configure the missing items and run this script again.${NC}"
    echo ""
    exit 1
fi

