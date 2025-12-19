#!/bin/bash
# Automatically open GitHub Codespace in VS Code
# Usage: ./open-codespace.sh [repo] [display-name]

REPO="${1:-878313233/untitledRandD}"
DISPLAY_NAME="${2:-untitledRandD}"

echo "🔍 Finding codespace for $REPO with display name '$DISPLAY_NAME'..."

CODESPACE_NAME=$(gh codespace list --repo "$REPO" --json name,displayName --jq ".[] | select(.displayName == \"$DISPLAY_NAME\") | .name" | head -1)

if [ -z "$CODESPACE_NAME" ]; then
    echo "❌ No codespace found matching '$DISPLAY_NAME'"
    echo "Available codespaces:"
    gh codespace list --repo "$REPO" --json name,displayName --jq '.[] | "  - \(.displayName) (\(.name))"'
    exit 1
fi

echo "✅ Found codespace: $CODESPACE_NAME"
echo "🚀 Opening in VS Code..."

gh codespace code -c "$CODESPACE_NAME"

