# Semantic Version Calculator - Bitrise Step

A Bitrise step that calculates semantic versions based on conventional commit messages.

## Features

- **Conventional Commit Analysis**: Automatically determines version bumps based on commit types
- **Platform Support**: Handles web, iOS, Android, and backend platforms
- **Special iOS UAT Mode**: Increments build number (4th component) for iOS UAT builds
- **Git Tag Integration**: Reads current version from git tags in `branch/version` format

## Version Bump Rules

| Commit Type | Version Bump | Example |
|-------------|--------------|---------|
| `feat:` or `feat(scope):` | Minor | 1.0.0 → 1.1.0 |
| `fix:` or `fix(scope):` | Patch | 1.0.0 → 1.0.1 |
| `type!:` or `BREAKING CHANGE:` | Major | 1.0.0 → 2.0.0 |
| `docs:`, `style:`, `refactor:`, etc. | None | 1.0.0 → 1.0.0 |
| iOS + UAT branch | Build | 1.0.0.5 → 1.0.0.6 |

## Inputs

### `branch` (required)
The branch name to use for version tagging. This is used to find existing tags in the format: `branch/version`

**Example**: `develop`, `main`, `uat`

### `platform` (required)
The platform for which to calculate the version.

**Options**: `web`, `ios`, `android`, `backend`

**Special behavior**: When `platform=ios` and `branch=uat`, only the build number (4th component) is incremented.

## Outputs

### `NEW_VERSION`
The calculated new semantic version.

**Examples**: 
- `1.2.3` (standard)
- `1.2.3.4` (iOS UAT with build number)

### `BUMP_TYPE`
The type of version bump performed.

**Values**: `major`, `minor`, `patch`, `build`, `none`

### `CURRENT_VERSION`
The current version before the bump (extracted from latest git tag).

## Usage

### Basic Usage

```yaml
workflows:
  version:
    steps:
      - git-clone:
          inputs:
            - fetch_tags: "yes"
            
      - path::./getVersionStep:
          inputs:
            - branch: "develop"
            - platform: "web"
            
      - script:
          inputs:
            - content: |
                echo "New version: $NEW_VERSION"
                echo "Bump type: $BUMP_TYPE"
```

### iOS UAT Build

```yaml
workflows:
  ios_uat:
    steps:
      - git-clone:
          inputs:
            - fetch_tags: "yes"
            
      - path::./getVersionStep:
          inputs:
            - branch: "uat"
            - platform: "ios"
            
      - script:
          inputs:
            - content: |
                echo "New iOS UAT version: $NEW_VERSION"
                # Will output something like: 1.2.3.45
```

## Testing

Run the included test workflows:

```bash
# Test standard versioning
bitrise run test

# Test iOS UAT build number increment
bitrise run test_ios_uat
```

## How It Works

1. **Fetch Current Version**: Reads git tags matching `branch/*` pattern and extracts the latest version
2. **Parse Version**: Splits version into MAJOR.MINOR.PATCH[.BUILD] components
3. **Special Case Check**: If iOS + UAT, skip commit analysis and increment build number
4. **Analyze Commits**: Scans commit messages since last tag for conventional commit types
5. **Determine Bump Type**: Identifies the highest priority bump (major > minor > patch)
6. **Calculate New Version**: Applies the bump and resets lower components
7. **Export Outputs**: Makes NEW_VERSION, BUMP_TYPE, and CURRENT_VERSION available to subsequent steps

## Conventional Commit Format

This step expects commits to follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>[optional scope][optional !]: <description>

[optional body]

[optional footer(s)]
```

### Examples

**Minor bump (feature)**:
```
feat: add user authentication
```

**Patch bump (bugfix)**:
```
fix(auth): resolve login timeout issue
```

**Major bump (breaking change)**:
```
feat!: redesign API endpoints

BREAKING CHANGE: API endpoints now use /v2/ prefix
```

**No bump**:
```
docs: update README
style: format code
refactor: simplify validation logic
```

## Tag Format

The step expects git tags in the format: `branch/version`

**Examples**:
- `develop/1.2.3`
- `main/2.0.0`
- `uat/1.5.0.42`

If no tags exist for the branch, it defaults to `1.0.0`.

## Requirements

- Git repository with tags enabled
- Conventional commit message format
- Bitrise CLI or Bitrise.io platform

## License

MIT
