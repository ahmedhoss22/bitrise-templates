#!/bin/bash
set -e

echo "=========================================="
echo "Azure DevOps Wiki Page Creator"
echo "=========================================="

# Set defaults for optional parameters
BUILD_NUM="${build_number:-${BITRISE_BUILD_NUMBER:-Unknown}}"
BUILD_LINK="${build_url:-${BITRISE_BUILD_URL:-#}}"
AUTHOR_NAME="${author:-${GIT_CLONE_COMMIT_AUTHOR_NAME:-Unknown}}"

echo "Configuration:"
echo "  ADO Project: $ado_project"
echo "  Wiki Repo: $wiki_repo"
echo "  Branch: $branch_name"
echo "  Platform: $platform"
echo "  New Version: $new_version"
echo "  New Tag: $new_tag"
echo "  Bump Type: $bump_type"
echo "  Build: $BUILD_NUM"
echo "  Author: $AUTHOR_NAME"
echo ""

# ============================================
# STEP 0: Check if we should skip
# ============================================
if [ "$bump_type" == "none" ]; then
  echo "ℹ️  Bump type is 'none', skipping wiki page creation"
  exit 0
fi

# ============================================
# STEP 1: List all available wikis
# ============================================
echo "=========================================="
echo "STEP 1: Fetching all wikis in project"
echo "=========================================="
WIKIS_URL="https://dev.azure.com/areebgroup/$ado_project/_apis/wiki/wikis?api-version=7.1"
echo "Wikis API URL: $WIKIS_URL"

curl -s -X GET "$WIKIS_URL" \
  -H "Authorization: Bearer $ado_token" \
  -o /tmp/wikis_list.json

echo "Available wikis:"
cat /tmp/wikis_list.json | jq -r '.value[] | "  - Name: \(.name), ID: \(.id), Type: \(.type)"' 2>/dev/null || cat /tmp/wikis_list.json
echo ""

# ============================================
# STEP 2: Verify the target wiki exists
# ============================================
echo "=========================================="
echo "STEP 2: Verifying wiki '$wiki_repo' exists"
echo "=========================================="
WIKI_EXISTS=$(cat /tmp/wikis_list.json | jq -r --arg wiki "$wiki_repo" '.value[] | select(.name == $wiki) | .name' 2>/dev/null || echo "")

if [ -z "$WIKI_EXISTS" ]; then
  echo "❌ ERROR: Wiki '$wiki_repo' not found!"
  echo "Please verify the wiki name is correct."
  exit 1
else
  echo "✓ Wiki '$wiki_repo' found successfully"
fi
echo ""

# ============================================
# STEP 3: Get tag information
# ============================================
echo "=========================================="
echo "STEP 3: Getting tag commit information"
echo "=========================================="

TAG_NAME="$new_tag"
echo "Fetching commit SHA for tag: $TAG_NAME"

# Get the commit SHA from the tag
TAG_COMMIT_SHA=$(git rev-list -n 1 "$TAG_NAME" 2>/dev/null || echo "")

if [ -z "$TAG_COMMIT_SHA" ]; then
  echo "⚠️  Warning: Could not find commit SHA for tag $TAG_NAME"
  TAG_COMMIT_SHA="HEAD"
else
  echo "Tag commit SHA: $TAG_COMMIT_SHA"
fi

# Build the tag URL
TAG_URL="https://dev.azure.com/areebgroup/$ado_project/_git/${BITRISE_GIT_REPOSITORY_SLUG:-repo}?version=GT$TAG_NAME"
echo "Tag URL: $TAG_URL"
echo ""

# ============================================
# STEP 4: Read and process commit details
# ============================================
echo "=========================================="
echo "STEP 4: Processing commit details"
echo "=========================================="

COMMIT_FILE="$commit_details_path"
if [ -n "$COMMIT_FILE" ] && [ -f "$COMMIT_FILE" ]; then
  echo "Commit details file: $COMMIT_FILE"
  echo "File exists, size: $(wc -l < "$COMMIT_FILE") lines"
  echo "Content preview:"
  head -n 5 "$COMMIT_FILE"
else
  echo "⚠️  No commit details file provided or file not found"
  COMMIT_FILE=""
fi
echo ""

# ============================================
# STEP 5: Build complete release notes content
# ============================================
echo "=========================================="
echo "STEP 5: Building complete release notes"
echo "=========================================="

# Build release notes content with version link
WIKI_CONTENT="# Release [$new_version]($TAG_URL)

**Date:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")  
**Author:** $AUTHOR_NAME  
**Build:** [$BUILD_NUM]($BUILD_LINK)  

## Release Notes

"

# Step 5.1: Add work items section if any exist
WORK_ITEMS_FILE="$work_items_path"
if [ -n "$WORK_ITEMS_FILE" ] && [ -f "$WORK_ITEMS_FILE" ] && [ -s "$WORK_ITEMS_FILE" ]; then
  echo "Found work items file, adding to wiki..."
  WIKI_CONTENT+="### 🔗 Related Work Items"$'\n'
  WIKI_CONTENT+=$'\n'
  
  while IFS= read -r WI_ID; do
    if [ -n "$WI_ID" ]; then
      WI_URL="https://dev.azure.com/areebgroup/$ado_project/_workitems/edit/$WI_ID"
      WIKI_CONTENT+="- [Work Item #$WI_ID]($WI_URL)"$'\n'
    fi
  done < "$WORK_ITEMS_FILE"
  
  WIKI_CONTENT+=$'\n'
fi

# Group commits by type
declare -A COMMIT_GROUPS

if [ -n "$COMMIT_FILE" ] && [ -f "$COMMIT_FILE" ] && [ -s "$COMMIT_FILE" ]; then
  while IFS='|' read -r TYPE DESCRIPTION; do
    if [ -n "$TYPE" ] && [ -n "$DESCRIPTION" ]; then
      COMMIT_GROUPS["$TYPE"]+="- $DESCRIPTION"$'\n'
    fi
  done < "$COMMIT_FILE"
  
  # Add features
  if [ -n "${COMMIT_GROUPS[feat]}" ]; then
    WIKI_CONTENT+="### ✨ Features"$'\n'
    WIKI_CONTENT+="${COMMIT_GROUPS[feat]}"$'\n'
  fi
  
  # Add fixes
  if [ -n "${COMMIT_GROUPS[fix]}" ]; then
    WIKI_CONTENT+="### 🐛 Bug Fixes"$'\n'
    WIKI_CONTENT+="${COMMIT_GROUPS[fix]}"$'\n'
  fi
  
  # Add documentation
  if [ -n "${COMMIT_GROUPS[docs]}" ]; then
    WIKI_CONTENT+="### 📚 Documentation"$'\n'
    WIKI_CONTENT+="${COMMIT_GROUPS[docs]}"$'\n'
  fi
  
  # Add refactoring
  if [ -n "${COMMIT_GROUPS[refactor]}" ]; then
    WIKI_CONTENT+="### ♻️ Refactoring"$'\n'
    WIKI_CONTENT+="${COMMIT_GROUPS[refactor]}"$'\n'
  fi
  
  # Add performance
  if [ -n "${COMMIT_GROUPS[perf]}" ]; then
    WIKI_CONTENT+="### ⚡ Performance"$'\n'
    WIKI_CONTENT+="${COMMIT_GROUPS[perf]}"$'\n'
  fi
  
  # Add other types
  for TYPE in style test chore; do
    if [ -n "${COMMIT_GROUPS[$TYPE]}" ]; then
      WIKI_CONTENT+="### 🔧 ${TYPE^}"$'\n'
      WIKI_CONTENT+="${COMMIT_GROUPS[$TYPE]}"$'\n'
    fi
  done
else
  WIKI_CONTENT+="No conventional commits found in this release."$'\n'
fi

echo "Release notes preview:"
echo "$WIKI_CONTENT" | head -n 25
echo ""

# ============================================
# STEP 6: Create parent pages if they don't exist
# ============================================
echo "=========================================="
echo "STEP 6: Creating parent pages if needed"
echo "=========================================="
# Structure: releases/{Platform}/{branch_name}/{version}
# Capitalize platform name to match existing wiki structure
PLATFORM_CAP="$(echo "$platform" | sed 's/.*/\u&/')"
WIKI_PAGE_PATH="releases/$PLATFORM_CAP/$branch_name/$new_version"
echo "Target page path: $WIKI_PAGE_PATH"

# Split path and create each parent
IFS='/' read -ra PATH_PARTS <<< "$WIKI_PAGE_PATH"
CURRENT_PATH=""

for i in "${!PATH_PARTS[@]}"; do
  if [ $i -lt $((${#PATH_PARTS[@]} - 1)) ]; then
    if [ -z "$CURRENT_PATH" ]; then
      CURRENT_PATH="${PATH_PARTS[$i]}"
    else
      CURRENT_PATH="$CURRENT_PATH/${PATH_PARTS[$i]}"
    fi
    
    echo "Checking parent page: $CURRENT_PATH"
    
    # Check if page exists
    PAGE_CHECK_URL="https://dev.azure.com/areebgroup/$ado_project/_apis/wiki/wikis/$wiki_repo/pages?path=$CURRENT_PATH&api-version=7.1"
    HTTP_CODE=$(curl -s -o /tmp/page_check.json -w "%{http_code}" -X GET "$PAGE_CHECK_URL" \
      -H "Authorization: Bearer $ado_token")
    
    if [ "$HTTP_CODE" == "404" ]; then
      echo "  → Page doesn't exist, creating..."
      
      # Create parent page
      PARENT_CONTENT="# ${PATH_PARTS[$i]^}

This page was automatically created for organizing releases.
"
      
      CREATE_PARENT_URL="https://dev.azure.com/areebgroup/$ado_project/_apis/wiki/wikis/$wiki_repo/pages?path=$CURRENT_PATH&api-version=7.1"
      
      PARENT_HTTP_CODE=$(curl -s -X PUT "$CREATE_PARENT_URL" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $ado_token" \
        -d "{
          \"content\": $(echo "$PARENT_CONTENT" | jq -Rs .)
        }" \
        -o /tmp/parent_create_response.json \
        -w "%{http_code}")
      
      echo "  HTTP Status: $PARENT_HTTP_CODE"
      
      if [ "$PARENT_HTTP_CODE" == "201" ] || [ "$PARENT_HTTP_CODE" == "200" ]; then
        echo "  ✓ Parent page created successfully"
      else
        echo "  ⚠️  Warning: Could not create parent page (will try to continue)"
        cat /tmp/parent_create_response.json | jq -r '.message' 2>/dev/null || cat /tmp/parent_create_response.json
      fi
    else
      echo "  → Page already exists (HTTP $HTTP_CODE)"
    fi
  fi
done
echo ""

# ============================================
# STEP 7: Create the release page with complete content
# ============================================
echo "=========================================="
echo "STEP 7: Creating release page"
echo "=========================================="

# Create wiki page using Azure DevOps REST API
API_URL="https://dev.azure.com/areebgroup/$ado_project/_apis/wiki/wikis/$wiki_repo/pages?path=$WIKI_PAGE_PATH&api-version=7.1"

echo "Creating page at: $WIKI_PAGE_PATH"
echo "API URL: $API_URL"
echo ""

HTTP_CODE=$(curl -s -X PUT "$API_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ado_token" \
  -d "{
    \"content\": $(echo "$WIKI_CONTENT" | jq -Rs .)
  }" \
  -o /tmp/wiki_response.json \
  -w "%{http_code}")

echo "HTTP Status: $HTTP_CODE"
echo "Response:"
cat /tmp/wiki_response.json | jq '.' 2>/dev/null || cat /tmp/wiki_response.json
echo ""

if [ "$HTTP_CODE" == "201" ] || [ "$HTTP_CODE" == "200" ]; then
  echo "✅ Wiki page created successfully with complete release notes!"
elif [ "$HTTP_CODE" == "404" ]; then
  # Ancestor page issue - try creating with simpler path structure
  echo "⚠️  Ancestor page issue detected. Trying alternative approach..."
  
  # Try creating missing parent pages one at a time with wikiIdentifier
  WIKI_ID=$(cat /tmp/wikis_list.json | jq -r --arg wiki "$wiki_repo" '.value[] | select(.name == $wiki) | .id' 2>/dev/null)
  
  if [ -n "$WIKI_ID" ]; then
    echo "Using Wiki ID: $WIKI_ID"
    
    # Create each missing parent page using wiki ID instead of name
    CURRENT_PATH=""
    for i in "${!PATH_PARTS[@]}"; do
      if [ $i -lt $((${#PATH_PARTS[@]} - 1)) ]; then
        if [ -z "$CURRENT_PATH" ]; then
          CURRENT_PATH="${PATH_PARTS[$i]}"
        else
          CURRENT_PATH="$CURRENT_PATH/${PATH_PARTS[$i]}"
        fi
        
        # Check and create using wiki ID
        PARENT_URL="https://dev.azure.com/areebgroup/$ado_project/_apis/wiki/wikis/$WIKI_ID/pages?path=$CURRENT_PATH&api-version=7.1"
        PARENT_CONTENT="# ${PATH_PARTS[$i]^}"$'\n\n'"This page was automatically created."
        
        curl -s -X PUT "$PARENT_URL" \
          -H "Content-Type: application/json" \
          -H "Authorization: Bearer $ado_token" \
          -d "{\"content\": $(echo "$PARENT_CONTENT" | jq -Rs .)}" \
          -o /dev/null 2>&1 || true
      fi
    done
    
    # Retry creating the final page
    echo "Retrying final page creation..."
    RETRY_URL="https://dev.azure.com/areebgroup/$ado_project/_apis/wiki/wikis/$WIKI_ID/pages?path=$WIKI_PAGE_PATH&api-version=7.1"
    
    HTTP_CODE=$(curl -s -X PUT "$RETRY_URL" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $ado_token" \
      -d "{\"content\": $(echo "$WIKI_CONTENT" | jq -Rs .)}" \
      -o /tmp/wiki_response.json \
      -w "%{http_code}")
    
    echo "Retry HTTP Status: $HTTP_CODE"
    
    if [ "$HTTP_CODE" == "201" ] || [ "$HTTP_CODE" == "200" ]; then
      echo "✅ Wiki page created successfully on retry!"
    else
      echo "❌ Failed to create wiki page after retry (HTTP $HTTP_CODE)"
      cat /tmp/wiki_response.json | jq '.' 2>/dev/null || cat /tmp/wiki_response.json
      exit 1
    fi
  else
    echo "❌ Could not find wiki ID"
    exit 1
  fi
else
  echo "❌ Failed to create wiki page (HTTP $HTTP_CODE)"
  exit 1
fi

# ============================================
# STEP 8: Export outputs
# ============================================
echo "=========================================="
echo "Exporting outputs"
echo "=========================================="

# Extract page ID from the API response and construct clean URL
WIKI_PAGE_ID=$(cat /tmp/wiki_response.json | jq -r '.id' 2>/dev/null || echo "")
if [ -n "$WIKI_PAGE_ID" ]; then
  WIKI_PAGE_URL="https://dev.azure.com/areebgroup/$ado_project/_wiki/wikis/$wiki_repo/${WIKI_PAGE_ID}/$new_version"
else
  # Fallback URL if we can't extract the ID
  WIKI_PAGE_URL="https://dev.azure.com/areebgroup/$ado_project/_wiki/wikis/$wiki_repo"
fi

echo "Wiki Page URL: $WIKI_PAGE_URL"
echo "Wiki Page Path: $WIKI_PAGE_PATH"

# Export environment variables for next steps
envman add --key WIKI_PAGE_URL --value "$WIKI_PAGE_URL"
envman add --key WIKI_PAGE_PATH --value "$WIKI_PAGE_PATH"

echo ""
echo "✅ Wiki page creation complete!"
