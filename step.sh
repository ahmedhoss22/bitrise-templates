#!/bin/bash
set -e

echo "=========================================="
echo "Update File Version"
echo "=========================================="
echo "File Path: $file_path"
echo "Version Key: $version_key"
echo "New Version: $new_version"
echo ""

# ============================================
# STEP 1: Validate Inputs
# ============================================
echo "Validating inputs..."

if [ -z "$file_path" ]; then
  echo "❌ Error: file_path is required"
  exit 1
fi

if [ -z "$version_key" ]; then
  echo "❌ Error: version_key is required"
  exit 1
fi

if [ -z "$new_version" ]; then
  echo "❌ Error: new_version is required"
  exit 1
fi

# Check if file exists
if [ ! -f "$file_path" ]; then
  echo "❌ Error: File not found: $file_path"
  exit 1
fi

echo "✓ All inputs validated"
echo ""

# ============================================
# STEP 2: Backup Original File Content
# ============================================
echo "Creating backup of original file..."
BACKUP_FILE="${file_path}.backup"
cp "$file_path" "$BACKUP_FILE"
echo "✓ Backup created: $BACKUP_FILE"
echo ""

# ============================================
# STEP 3: Display Original Content
# ============================================
echo "=========================================="
echo "Original File Content:"
echo "=========================================="
cat "$file_path"
echo ""

# ============================================
# STEP 4: Update Version in File
# ============================================
echo "Updating version in file..."

# Try multiple patterns to match different formats:
# Pattern 1: const val version = "1.0.0"
# Pattern 2: version = "1.0.0"
# Pattern 3: version="1.0.0"
# Pattern 4: appVersion=1.1.0

# Use sed to replace the version value
# This pattern matches: key = "value" or key="value" or key=value
sed -i.tmp "s/\(${version_key}[[:space:]]*=[[:space:]]*\"\)[^\"]*\"/\1${new_version}\"/" "$file_path"

# Also handle case without quotes: key = value or key=value
sed -i.tmp "s/\(${version_key}[[:space:]]*=[[:space:]]*\)[0-9.]*\([^0-9.]\|$\)/\1${new_version}\2/" "$file_path"

# Remove temporary file created by sed
rm -f "${file_path}.tmp"

echo "✓ Version updated successfully"
echo ""

# ============================================
# STEP 5: Display Updated Content
# ============================================
echo "=========================================="
echo "Updated File Content:"
echo "=========================================="
cat "$file_path"
echo ""

# ============================================
# STEP 6: Verify the Change
# ============================================
echo "Verifying the change..."

# Check if the new version appears in the file
if grep -q "${version_key}.*${new_version}" "$file_path"; then
  echo "✓ Verification successful: Version ${new_version} found in file"
else
  echo "⚠ Warning: Could not verify version update"
  echo "  This might be normal if the version format is different than expected"
fi
echo ""

# ============================================
# STEP 7: Export Outputs
# ============================================
echo "=========================================="
echo "Results:"
echo "=========================================="
echo "File Updated:    $file_path"
echo "Version Key:     $version_key"
echo "New Version:     $new_version"
echo "=========================================="

# Export environment variables for next steps
envman add --key UPDATED_FILE_PATH --value "$file_path"
envman add --key UPDATED_VERSION --value "$new_version"

echo ""
echo "✅ File version update complete!"
