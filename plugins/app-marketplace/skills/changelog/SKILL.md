---
name: changelog
description: Generate changelog from git history. Use when user needs release notes for deployment or wants to see recent changes.
argument-hint: "[--since TAG] [--format bullet|markdown|conventional]"
user-invocable: true
disable-model-invocation: false
allowed-tools: Bash, Read
---

# Changelog Generation

Generate release notes from git commit history for app store deployments.

## Step 0 — Check & Install Dependencies (run every time)

Before doing anything else, run the automated setup script. It detects the OS, checks each dependency, and installs whatever is missing:

```bash
bash scripts/setup.sh
```

This checks and auto-installs: Node.js, npm, git, and the store-deploy CLI.

Do NOT proceed until the setup script reports all dependencies are ready.

## Pre-flight: MANDATORY — Install or Update CLI

**You MUST run this exact command first before any other command.** This ensures the CLI is installed and up-to-date. Do NOT simplify or skip this step.

```bash
npm config set @egdw:registry https://artifactory.eg.dk/artifactory/api/npm/egdw-store-deploy-npm-local/ && npm install -g @egdw/store-deploy
```

This will install the CLI if missing, or update it to the latest version if outdated. npm handles both cases.

## Pre-flight: Setup & Credential Verification

```bash
store-deploy setup
store-deploy version get --json
```

If version get fails after setup, surface the error and stop.

## Find Last Tag

```bash
git describe --tags --abbrev=0 2>/dev/null || echo "No tags found"
```

## Get Commits Since Tag

```bash
# Since specific tag
git log v1.2.0..HEAD --oneline --no-merges

# Since last tag
git log $(git describe --tags --abbrev=0)..HEAD --oneline --no-merges

# If no tags, last 10 commits
git log -10 --oneline --no-merges
```

## Commit Details

For more context:

```bash
git log $(git describe --tags --abbrev=0)..HEAD --pretty=format:"%h %s" --no-merges
```

## Output Formats

### Bullet Format (default)
```
- Fix login bug
- Add dark mode support
- Update dependencies
```

### Markdown Format
```markdown
## What's New

### Features
- Add dark mode support

### Bug Fixes
- Fix login bug

### Maintenance
- Update dependencies
```

### Conventional Format
```
feat: Add dark mode support
fix: Fix login bug
chore: Update dependencies
```

## Parsing Conventional Commits

If commits follow conventional format (feat:, fix:, etc.):

```bash
git log $(git describe --tags --abbrev=0)..HEAD --pretty=format:"%s" --no-merges | grep -E "^(feat|fix|docs|style|refactor|test|chore):"
```

## Arguments

$ARGUMENTS

If no arguments, generate bullet-format changelog since last tag.

## Usage with Deploy

After generating changelog, user can deploy with:

```bash
# iOS (TestFlight)
store-deploy ios --changelog "GENERATED_CHANGELOG"

# Android (Play Store tracks)
store-deploy android --changelog "GENERATED_CHANGELOG"
store-deploy internal --changelog "GENERATED_CHANGELOG"
store-deploy alpha --changelog "GENERATED_CHANGELOG"
store-deploy beta --changelog "GENERATED_CHANGELOG"
store-deploy production --changelog "GENERATED_CHANGELOG"
```

## Changelog Best Practices

1. **User-facing language** - Write for app store users, not developers
2. **Highlight benefits** - Focus on what users gain
3. **Keep it concise** - App stores have character limits
4. **Group by category** - Features, fixes, improvements
5. **No internal jargon** - Avoid technical implementation details

## Output Formatting

You have two output modes: **clean** (default) and **verbose**.

### Detecting Mode

- **Default: clean mode**
- Switch to **verbose** if the user passes `--verbose`, `-v`, or says "verbose", "show logs", "debug"

### Clean Mode (default)

**Suppress raw command output.** Run git commands silently, parse the results, then present the changelog directly.

**Show a header line** with commit count and range:
```
  ✓ Changelog: 6 commits since v1.2.3
```

**Then render the changelog** in the requested format (bullet, markdown, or conventional) — clean, no git hashes, no raw output.

If the user plans to deploy, present the changelog and ask for confirmation before passing it to the deploy command.

### Verbose Mode

Show each git command with `$` prefix and full raw output in code blocks. Then render the formatted changelog below.
