#!/usr/bin/env bash
# ==============================================================================
# Script: install.sh
# Purpose: Activate git hooks in .githooks directory
# ==============================================================================

set -e

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

echo "Configuring Git hooks in: $REPO_ROOT"

# Set core.hooksPath
git config core.hooksPath .githooks
echo " [OK] git config core.hooksPath set to .githooks"

# Make hook files executable
chmod +x .githooks/pre-commit .githooks/pre-push .githooks/commit-msg .githooks/check-emdash.sh 2>/dev/null || true

# Copy into .git/hooks as fallback
if [ -d ".git/hooks" ]; then
  cp .githooks/* .git/hooks/ 2>/dev/null || true
  echo " [OK] Copied hooks to .git/hooks/"
fi

echo "Git hooks installed successfully! Em dash enforcement is active."
