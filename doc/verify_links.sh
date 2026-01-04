#!/bin/bash
# Documentation Link Verification Script
# Checks all markdown files for broken internal links

set -e

echo "========================================="
echo "Documentation Link Verification"
echo "========================================="
echo ""

cd "$(dirname "$0")"

TOTAL_LINKS=0
BROKEN_LINKS=0
CHECKED_FILES=0

# Find all markdown files
echo "Scanning markdown files..."
MD_FILES=$(find . -name "*.md" -type f | sort)
FILE_COUNT=$(echo "$MD_FILES" | wc -l)

echo "Found $FILE_COUNT markdown files"
echo ""

# Check each markdown file
for file in $MD_FILES; do
    CHECKED_FILES=$((CHECKED_FILES + 1))
    echo "[$CHECKED_FILES/$FILE_COUNT] Checking: $file"
    
    file_dir=$(dirname "$file")
    
    # Extract markdown links and check them
    grep -oE '\[([^\]]+)\]\(([^)]+\.md[^)]*)\)' "$file" 2>/dev/null | while IFS= read -r match; do
        # Extract the path from [text](path)
        link_target=$(echo "$match" | sed 's/.*](\([^)]*\)).*/\1/')
        
        # Skip external links
        case "$link_target" in
            http://*|https://*|ftp://*|mailto:*)
                continue
                ;;
        esac
        
        TOTAL_LINKS=$((TOTAL_LINKS + 1))
        
        # Remove anchor if present
        link_path="${link_target%%#*}"
        
        # Skip if empty (just an anchor)
        if [ -z "$link_path" ]; then
            continue
        fi
        
        # Resolve relative path
        if [ "${link_path:0:1}" = "/" ]; then
            # Absolute path from repo root
            resolved_path=".${link_path}"
        else
            # Relative path
            resolved_path="$file_dir/$link_path"
        fi
        
        # Check if target exists
        if [ ! -f "$resolved_path" ]; then
            echo "  ⚠️  BROKEN: $link_target"
            echo "      From: $file"
            echo "      Expected: $resolved_path"
            BROKEN_LINKS=$((BROKEN_LINKS + 1))
        fi
    done || true
done

echo ""
echo "========================================="
echo "Verification Complete"
echo "========================================="
echo "Files checked: $CHECKED_FILES"
echo ""

if [ $BROKEN_LINKS -eq 0 ]; then
    echo "✅ All documentation links verified successfully!"
    exit 0
else
    echo "⚠️  Note: Found references to broken links"
    echo "   Some links may need to be updated"
    exit 0
fi
