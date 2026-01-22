# Update File Version - Bitrise Step

This Bitrise step updates a version value in a file by searching for a specific key and replacing its value with a new version.

## Features

- ✅ Updates version in files with key=value format (e.g., `appVersion=1.1.0`)
- ✅ Supports custom file paths and version keys
- ✅ Prints file content before and after update for verification
- ✅ Creates backup of original file
- ✅ Works with any text file containing version information
- ✅ Supports multiple formats: `key = "value"`, `key="value"`, `key=value`

## Inputs

### `file_path` (required)
- **Title**: File Path
- **Description**: The path to the file containing the version to update
- **Default**: `android/buildSrc/src/main/java/Versions.kt`

### `version_key` (required)
- **Title**: Version Key
- **Description**: The key name to search for in the file
- **Default**: `version`

### `new_version` (required)
- **Title**: New Version
- **Description**: The new version to set in the file (typically from `$NEW_VERSION` output of get-version-step)

## Outputs

### `UPDATED_FILE_PATH`
The path to the file that was updated

### `UPDATED_VERSION`
The version that was set in the file

## Usage Example

```yaml
workflows:
  version_update:
    steps:
    - git::https://github.com/areebgroup/versioning.git@main:
        title: Calculate New Version
        inputs:
        - branch: $BITRISE_GIT_BRANCH
        - platform: android
    - git::https://github.com/areebgroup/versioning.git@main:
        title: Update Version in File
        inputs:
        - file_path: android/buildSrc/src/main/java/Versions.kt
        - version_key: version
        - new_version: $NEW_VERSION
```

## How It Works

1. **Validates inputs**: Ensures all required inputs are provided and the file exists
2. **Creates backup**: Saves a backup of the original file (`.backup` extension)
3. **Displays original content**: Shows the file content before modification
4. **Updates version**: Uses `sed` to find and replace the version value
5. **Displays updated content**: Shows the file content after modification
6. **Verifies change**: Confirms the new version appears in the file
7. **Exports outputs**: Makes the updated file path and version available to subsequent steps

## Supported File Formats

The step can handle various version declaration formats:

### Kotlin (Versions.kt)
```kotlin
const val version = "1.0.0"
```

### Properties Files
```properties
appVersion=1.1.0
version=2.0.0
```

### Configuration Files
```
version = "1.2.3"
app_version="3.0.0"
```

## Error Handling

The step will fail with a clear error message if:
- Required inputs are missing
- The specified file doesn't exist
- The file cannot be read or written

## Notes

- The original file is backed up with a `.backup` extension before modification
- The step prints both the original and updated file content for easy verification
- The version update is verified by checking if the new version appears in the file
