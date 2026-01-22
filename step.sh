#!/bin/bash
set -e

echo "=========================================="
echo "Push New Git Tag"
echo "=========================================="

echo "Configuration:"
echo "  Branch: $branch_name"
echo "  New Version: $new_version"
echo "  Bump Type: $bump_type"
echo ""

# ============================================
# STEP 1: Check if we should skip
# ============================================
if [ "$bump_type" == "none" ]; then
  echo "ℹ️  Bump type is 'none', skipping tag creation"
  envman add --key NEW_TAG --value ""
  exit 0
fi

# ============================================
# STEP 2: Configure git user
# ============================================
echo "=========================================="
echo "Configuring git user"
echo "=========================================="

GIT_USER="${git_user_name:-${GIT_CLONE_COMMIT_AUTHOR_NAME:-Bitrise CI}}"
GIT_EMAIL="${git_user_email:-${GIT_CLONE_COMMIT_AUTHOR_EMAIL:-ci@bitrise.io}}"

echo "Git User: $GIT_USER"
echo "Git Email: $GIT_EMAIL"

git config user.name "$GIT_USER"
git config user.email "$GIT_EMAIL"
echo ""

# ============================================
# STEP 3: Create the tag
# ============================================
echo "=========================================="
echo "Creating tag"
echo "=========================================="

NEW_TAG="$branch_name/$new_version"
echo "Tag to create: $NEW_TAG"

# Check if tag already exists locally
if git rev-parse "$NEW_TAG" >/dev/null 2>&1; then
  echo "⚠️  Tag $NEW_TAG already exists locally"
  
  # Check if it exists on remote
  if git ls-remote --tags origin | grep -q "refs/tags/$NEW_TAG"; then
    echo "✅ Tag already exists on remote, skipping push"
    envman add --key NEW_TAG --value "$NEW_TAG"
    exit 0
  fi
else
  # Create annotated tag
  echo "Creating annotated tag..."
  git tag -a "$NEW_TAG" -m "Release version $new_version"
  echo "✅ Tag created locally"
fi
echo ""

# ============================================
# STEP 4: Push the tag
# ============================================
echo "=========================================="
echo "Pushing tag to remote"
echo "=========================================="

echo "Pushing $NEW_TAG to origin..."
git push origin "$NEW_TAG"

echo ""
echo "✅ Tag $NEW_TAG pushed successfully!"

# ============================================
# STEP 5: Export outputs
# ============================================
echo "=========================================="
echo "Exporting outputs"
echo "=========================================="

envman add --key NEW_TAG --value "$NEW_TAG"
echo "NEW_TAG=$NEW_TAG"

echo ""
echo "✅ Push tag step complete!"

