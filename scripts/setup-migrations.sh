#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check if PROJECT_ROOT is set
if [ -z "$PROJECT_ROOT" ]; then
    print_error "PROJECT_ROOT environment variable is not set"
    exit 1
fi

print_status "Setting up database migrations..."

# Create supabase directory if it doesn't exist
SUPABASE_DIR="$PROJECT_ROOT/supabase"
if [ ! -d "$SUPABASE_DIR" ]; then
    print_error "Supabase directory not found at $SUPABASE_DIR"
    print_error "Please run setup-supabase.sh first"
    exit 1
fi

# Navigate to supabase directory
cd "$SUPABASE_DIR"

# Generate timestamp for migration file
TIMESTAMP=$(date +%Y%m%d%H%M%S)
MIGRATION_NAME="create_items_table"
MIGRATION_FILE="migrations/${TIMESTAMP}_${MIGRATION_NAME}.sql"

print_status "Creating migration file: $MIGRATION_FILE"

# Create migrations directory if it doesn't exist
mkdir -p migrations

# Write the migration SQL
cat > "$MIGRATION_FILE" << 'EOF'
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
EOF

print_status "Migration file created successfully"

# Apply migration locally
print_status "Applying migration to local database..."

if command -v supabase &> /dev/null; then
    if supabase db push; then
        print_status "Migration applied successfully to local database"
    else
        print_error "Failed to apply migration. Is local Supabase running?"
        print_warning "You can apply it later with: cd supabase && supabase db push"
        exit 1
    fi
else
    print_error "Supabase CLI not found. Cannot apply migration."
    exit 1
fi

# Add migration to git
cd "$PROJECT_ROOT"
print_status "Adding migration to git..."

if git add "$SUPABASE_DIR/migrations/${TIMESTAMP}_${MIGRATION_NAME}.sql"; then
    print_status "Migration added to git staging"
    
    # Optionally commit
    if [ "${AUTO_COMMIT:-false}" = "true" ]; then
        if git commit -m "Add items table with RLS policies"; then
            print_status "Migration committed to git"
        else
            print_warning "Failed to commit migration (may already be committed)"
        fi
    else
        print_warning "Migration staged but not committed. Run 'git commit -m \"Add items table with RLS\"' to commit."
    fi
else
    print_warning "Failed to add migration to git (may already be tracked)"
fi

print_status "Migration setup complete!"
print_status "You can verify the migration in Supabase Studio at http://localhost:54323"

# Summary
echo ""
echo "Summary:"
echo "  Migration file: $MIGRATION_FILE"
echo "  Applied to:     Local Supabase database"
echo "  Git status:     Staged for commit"
echo ""

