# Azure DevOps Wiki Page Creator - Bitrise Step

A Bitrise step that creates structured release notes pages in Azure DevOps Wiki using the REST API.

## Features

- **Automated Wiki Page Creation**: Creates release notes pages in Azure DevOps Wiki
- **Parent Page Management**: Automatically creates parent pages if they don't exist
- **Commit Grouping**: Organizes commits by type (features, fixes, docs, etc.)
- **Work Item Linking**: Links to Azure DevOps work items mentioned in commits
- **Build Information**: Includes build number, author, and timestamp
- **Platform Organization**: Organizes pages by platform (web, ios, android, backend)

## Page Structure

Wiki pages are created with the following path structure:
```
releases/{platform}/{branch}/{version}
```

**Example**: `releases/android/develop/1.2.3`

## Inputs

### Required Inputs

| Input | Description | Example |
|-------|-------------|---------|
| `ado_project` | Azure DevOps project name | `MyProject` |
| `wiki_repo` | Wiki repository name | `MyProject.wiki` |
| `branch_name` | Branch name for organization | `develop` |
| `new_version` | New version number | `1.2.3` |
| `bump_type` | Version bump type | `minor` |
| `new_tag` | Full git tag name | `develop/1.2.3` |
| `platform` | Platform type | `android` |
| `ado_token` | Azure DevOps PAT (secret) | `***` |

### Optional Inputs

| Input | Description | Default |
|-------|-------------|---------|
| `commit_details_path` | Path to commit details file | - |
| `work_items_path` | Path to work items file | - |
| `build_number` | Build number | `$BITRISE_BUILD_NUMBER` |
| `build_url` | Build URL | `$BITRISE_BUILD_URL` |
| `author` | Author name | `$GIT_CLONE_COMMIT_AUTHOR_NAME` |

## Outputs

### `WIKI_PAGE_URL`
The full URL to the created wiki page.

**Example**: `https://dev.azure.com/areebgroup/MyProject/_wiki/wikis/MyProject.wiki/123/1.2.3`

### `WIKI_PAGE_PATH`
The path of the wiki page within the wiki.

**Example**: `releases/android/develop/1.2.3`

## Usage

### Basic Usage with Version Step

```yaml
workflows:
  release:
    steps:
      - git-clone:
          inputs:
            - fetch_tags: "yes"
            
      # Calculate version
      - path::./getVersionStep:
          inputs:
            - branch: "develop"
            - platform: "android"
            
      # Create wiki page
      - path::./createWiki:
          inputs:
            - ado_project: "MyProject"
            - wiki_repo: "MyProject.wiki"
            - branch_name: "develop"
            - new_version: "$NEW_VERSION"
            - bump_type: "$BUMP_TYPE"
            - new_tag: "develop/$NEW_VERSION"
            - platform: "android"
            - ado_token: "$ADO_PAT"
            
      - script:
          inputs:
            - content: |
                echo "Wiki page created: $WIKI_PAGE_URL"
```

### With Commit Details

To include commit details in the wiki page, you need to generate a commit details file in the format:
```
TYPE|DESCRIPTION
```

**Example**:
```
feat|Add user authentication
fix|Resolve login timeout issue
docs|Update README
```

Then pass the file path:

```yaml
- script:
    title: "Generate Commit Details"
    inputs:
      - content: |
          #!/bin/bash
          # Generate commit details (simplified example)
          git log --pretty=format:"%s" | while read line; do
            if [[ $line =~ ^([a-z]+).*:\ (.+)$ ]]; then
              echo "${BASH_REMATCH[1]}|${BASH_REMATCH[2]}" >> /tmp/commits.txt
            fi
          done

- path::./createWiki:
    inputs:
      - ado_project: "MyProject"
      - wiki_repo: "MyProject.wiki"
      - branch_name: "$BITRISE_GIT_BRANCH"
      - new_version: "$NEW_VERSION"
      - bump_type: "$BUMP_TYPE"
      - new_tag: "$BITRISE_GIT_BRANCH/$NEW_VERSION"
      - platform: "android"
      - ado_token: "$ADO_PAT"
      - commit_details_path: "/tmp/commits.txt"
```

### With Work Items

To include work item links, create a file with one work item ID per line:

```
12345
67890
```

Then pass the file path:

```yaml
- path::./createWiki:
    inputs:
      # ... other inputs ...
      - work_items_path: "/tmp/work_items.txt"
```

## Azure DevOps Setup

### 1. Create a Personal Access Token (PAT)

1. Go to Azure DevOps → User Settings → Personal Access Tokens
2. Create a new token with **Wiki (Read & Write)** permissions
3. Copy the token value

### 2. Add Token to Bitrise

1. Go to your Bitrise app → Workflow Editor → Secrets
2. Add a new secret:
   - Key: `ADO_PAT`
   - Value: Your PAT token
   - Mark as "Protected"

### 3. Verify Wiki Exists

Ensure the wiki repository exists in your Azure DevOps project. The step will verify this and fail if the wiki is not found.

## Generated Wiki Page Format

The step creates wiki pages with the following structure:

```markdown
# Release [1.2.3](link-to-tag)

**Date:** 2026-01-19 14:30:00 UTC  
**Author:** John Doe  
**Build:** [#123](link-to-build)  

## Release Notes

### 🔗 Related Work Items
- [Work Item #12345](link)
- [Work Item #67890](link)

### ✨ Features
- Add user authentication
- Implement dark mode

### 🐛 Bug Fixes
- Resolve login timeout issue
- Fix crash on startup

### 📚 Documentation
- Update README
```

## File Format Requirements

### Commit Details File
Format: `TYPE|DESCRIPTION` (one per line)

Supported types:
- `feat` - Features (✨)
- `fix` - Bug Fixes (🐛)
- `docs` - Documentation (📚)
- `refactor` - Refactoring (♻️)
- `perf` - Performance (⚡)
- `style`, `test`, `chore` - Other (🔧)

### Work Items File
Format: One work item ID per line (numbers only)

## Skipping Wiki Creation

If `bump_type` is set to `none`, the step will skip wiki page creation and exit successfully.

## Error Handling

The step will fail if:
- The specified wiki repository doesn't exist
- The Azure DevOps token doesn't have sufficient permissions
- The API request fails (network issues, invalid parameters, etc.)

## Requirements

- Azure DevOps account with wiki enabled
- Personal Access Token with Wiki read/write permissions
- Git repository with tags
- `jq` installed (usually available in Bitrise stacks)
- `curl` installed (usually available in Bitrise stacks)

## License

MIT
