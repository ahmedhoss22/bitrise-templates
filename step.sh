#!/bin/bash
set -e

echo "=========================================="
echo "Semantic Version Calculator"
echo "=========================================="
echo "Branch: $branch"
echo "Platform: $platform"
echo ""

# ============================================
# STEP 1: Fetch Current Version from Tags
# ============================================
echo "Fetching current version from git tags..."

# Get all tags matching the branch pattern
LATEST_TAG=$(git tag -l "$branch/*" --sort=-v:refname | head -n 1)
echo "Latest tag found: $LATEST_TAG"

if [ -z "$LATEST_TAG" ]; then
  echo "No existing tags found for branch $branch"
  CURRENT_VERSION="1.0.0"
else
  echo "Latest tag found: $LATEST_TAG"
  # Extract version from tag (format: branch/version)
  CURRENT_VERSION=$(echo "$LATEST_TAG" | sed 's/.*\///')
fi

echo "Current version: $CURRENT_VERSION"
echo ""

# ============================================
# STEP 2: Parse Current Version
# ============================================
IFS='.' read -r MAJOR MINOR PATCH BUILD <<< "$CURRENT_VERSION"
BUILD=${BUILD:-}  # Build number is optional

echo "Parsed version components:"
echo "  MAJOR: $MAJOR"
echo "  MINOR: $MINOR"
echo "  PATCH: $PATCH"
if [ -n "$BUILD" ]; then
  echo "  BUILD: $BUILD"
fi
echo ""

# ============================================
# SPECIAL CASE: iOS + UAT = Just increment build number
# ============================================
if [ "$platform" == "ios" ] && [ "$branch" == "uat" ]; then
  echo "=========================================="
  echo "iOS UAT Mode: Skipping commit analysis"
  echo "Just incrementing build number (4th component)"
  echo "=========================================="
  
  BUILD=${BUILD:-0}  # Default to 0 if no build number exists
  BUILD=$((BUILD + 1))
  
  NEW_VERSION="$MAJOR.$MINOR.$PATCH.$BUILD"
  BUMP_TYPE="build"
  
  echo "New version: $NEW_VERSION"
  echo ""
  
  # Export outputs
  envman add --key NEW_VERSION --value "$NEW_VERSION"
  envman add --key BUMP_TYPE --value "$BUMP_TYPE"
  envman add --key CURRENT_VERSION --value "$CURRENT_VERSION"
  
  echo "✅ Version calculation complete!"
  exit 0
fi

# ============================================
# STEP 3: Get Commits Since Last Tag
# ============================================
echo "Analyzing commits..."

if [ -z "$LATEST_TAG" ]; then
  echo "No previous tag, analyzing all commits on current branch"
  COMMIT_SUBJECTS=$(git log --pretty=format:"%s" origin/$branch 2>/dev/null || git log --pretty=format:"%s" $branch)
  FULL_COMMITS=$(git log --pretty=format:"%B---COMMIT_SEPARATOR---" origin/$branch 2>/dev/null || git log --pretty=format:"%B---COMMIT_SEPARATOR---" $branch)
else
  echo "Analyzing commits since $LATEST_TAG"
  COMMIT_SUBJECTS=$(git log --pretty=format:"%s" $LATEST_TAG..HEAD)
  FULL_COMMITS=$(git log --pretty=format:"%B---COMMIT_SEPARATOR---" $LATEST_TAG..HEAD)
fi

# Count commits
COMMIT_COUNT=$(echo "$COMMIT_SUBJECTS" | grep -c . || echo "0")
echo "Found $COMMIT_COUNT commits to analyze"
echo  "$COMMIT_SUBJECTS "
echo ""

# ============================================
# STEP 4: Analyze Commits for Version Bump
# ============================================
BUMP_TYPE="none"

echo "Checking for version bump indicators..."

# Check for breaking changes (major bump)
# Pattern 1: type!: or type(scope)!: in subject line
# Pattern 2: BREAKING CHANGE: or BREAKING-CHANGE: in body/footer
if echo "$COMMIT_SUBJECTS" | grep -qE "^[a-z]+(\(.+\))?!:"; then
  echo "  ✓ Found BREAKING CHANGE (!) in subject - Major version bump"
  BUMP_TYPE="major"
elif echo "$FULL_COMMITS" | grep -qE "^BREAKING CHANGE:|^BREAKING-CHANGE:"; then
  echo "  ✓ Found BREAKING CHANGE in footer/body - Major version bump"
  BUMP_TYPE="major"
# Check for features (minor bump)
# Pattern: feat: or feat(scope):
elif echo "$COMMIT_SUBJECTS" | grep -qE "^feat(\(.+\))?:"; then
  echo "  ✓ Found feat commits - Minor version bump"
  BUMP_TYPE="minor"
# Check for fixes (patch bump)
# Pattern: fix: or fix(scope):
elif echo "$COMMIT_SUBJECTS" | grep -qE "^fix(\(.+\))?:"; then
  echo "  ✓ Found fix commits - Patch version bump"
  BUMP_TYPE="patch"
else
  echo "  ℹ No version bump needed (only docs/style/refactor/perf/test/chore commits)"
fi

echo ""

# ============================================
# STEP 5: Calculate New Version
# ============================================
echo "Calculating new version..."

case $BUMP_TYPE in
  major)
    MAJOR=$((MAJOR + 1))
    MINOR=0
    PATCH=0
    echo "  Major bump: $CURRENT_VERSION -> $MAJOR.$MINOR.$PATCH"
    ;;
  minor)
    MINOR=$((MINOR + 1))
    PATCH=0
    echo "  Minor bump: $CURRENT_VERSION -> $MAJOR.$MINOR.$PATCH"
    ;;
  patch)
    PATCH=$((PATCH + 1))
    echo "  Patch bump: $CURRENT_VERSION -> $MAJOR.$MINOR.$PATCH"
    ;;
  *)
    echo "  No bump: $CURRENT_VERSION (unchanged)"
    ;;
esac

NEW_VERSION="$MAJOR.$MINOR.$PATCH"
echo ""

# ============================================
# STEP 6: Export Outputs
# ============================================
echo "=========================================="
echo "Results:"
echo "=========================================="
echo "Current Version: $CURRENT_VERSION"
echo "New Version:     $NEW_VERSION"
echo "Bump Type:       $BUMP_TYPE"
echo "=========================================="

# Export environment variables for next steps
envman add --key NEW_VERSION --value "$NEW_VERSION"
envman add --key BUMP_TYPE --value "$BUMP_TYPE"
envman add --key CURRENT_VERSION --value "$CURRENT_VERSION"

echo ""
echo "✅ Version calculation complete!"
