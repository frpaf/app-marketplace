# app-marketplace

Mobile app lifecycle toolkit for Claude Code -- validate store submissions, generate marketing assets, and deploy to App Store and Google Play.

## Install

```bash
claude plugin add frpaf/app-marketplace
```

## Architecture

```
app-marketplace/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   ├── validate/
│   │   ├── android-precheck/
│   │   │   ├── SKILL.md
│   │   │   ├── scripts/
│   │   │   │   └── precheck.sh
│   │   │   └── evals/
│   │   │       └── evals.json
│   │   └── ios-precheck/
│   │       ├── SKILL.md
│   │       ├── scripts/
│   │       │   └── precheck.sh
│   │       └── evals/
│   │           └── evals.json
│   ├── assets/
│   │   ├── screenshots/
│   │   │   ├── SKILL.md
│   │   │   ├── scripts/
│   │   │   │   ├── screenshot_styler.py
│   │   │   │   └── organize_output.py
│   │   │   └── references/
│   │   │       ├── agent-device-commands.md
│   │   │       └── store-listing-specs.md
│   │   └── icon/
│   │       ├── SKILL.md
│   │       └── scripts/
│   │           └── generate_icon.py
│   └── deploy/
│       ├── deploy/
│       │   └── SKILL.md
│       ├── assistant/
│       │   └── SKILL.md
│       └── changelog/
│           └── SKILL.md
├── packages/
│   └── screenshot-styler/
│       ├── __init__.py
│       ├── __main__.py
│       ├── cli.py
│       ├── compositor.py
│       ├── config.py
│       ├── textgen.py
│       └── tests/
│           ├── test_compositor.py
│           ├── test_config.py
│           ├── test_fastlane.py
│           └── test_textgen.py
├── requirements.txt
└── LICENSE
```

## Skills

| Skill | Trigger | What it does |
|-------|---------|--------------|
| `android-precheck` | "android precheck", "play store" | Validates Android apps against Google Play policies (targetSdk, permissions, data safety, billing) |
| `ios-precheck` | "ios precheck", "app store" | Validates iOS apps against App Store Review Guidelines (background modes, privacy strings, ATS) |
| `screenshots` | "app store screenshots", "marketing screenshots" | Explores a running app via agent-device, captures screens, generates captions, and produces styled store-ready images |
| `icon` | "play store icon", "512x512 icon" | Generates Google Play compliant 512x512 PNG icons with automatic background detection and replacement |
| `deploy` | "deploy ios", "deploy android" | Deploys builds to TestFlight or Google Play Store tracks via the `store-deploy` CLI |
| `assistant` | "deploy", "release", "testflight" | Conversational deployment assistant handling setup, versioning, store queries, and deployment in one flow |
| `changelog` | "changelog", "release notes" | Generates release notes from git history in bullet, markdown, or conventional commit format |

## Validate

**android-precheck** -- Runs a shell script against your Flutter, Expo, or React Native project to catch Google Play rejection issues before submission. Checks targetSdk level, restricted permissions, foreground service types, network security, Play Billing version, account deletion, and audits SDKs for Data Safety form requirements.

**ios-precheck** -- Scans Info.plist, build configuration, and source code for common App Store rejection triggers. Validates UIBackgroundModes, privacy purpose strings (must be specific, not generic), ATS configuration, location permission consistency, Flutter version blockers (3.24.3/3.24.4), and account/IAP requirements.

## Assets

**screenshots** -- End-to-end workflow: opens the app in a simulator/emulator using `agent-device`, navigates and captures 5-8 unique screens, generates marketing captions (auto-detecting the UI language), validates caption lengths, then produces styled store-ready images with phone frames and text overlays. Supports presets for iPhone 6.9", iPad 13", and Play Store phone dimensions.

**icon** -- Takes a source image and produces a Play Store compliant 512x512 PNG. Auto-detects and replaces the background color by sampling edge pixels. Handles transparent, solid, and full-bleed artwork. Optimizes output to stay under the 1MB limit.

## Deploy

**deploy** -- Executes `store-deploy` CLI commands to push builds to TestFlight (iOS) or specific Play Store tracks (internal, alpha, beta, production). Installs/updates the CLI, runs setup for credential verification, and reports results with a step tracker.

**assistant** -- Interactive deployment companion that manages the full flow: CLI installation, credential setup via HashiCorp Vault, version comparison against store versions, version bumping, changelog generation, deployment, and post-deploy verification.

**changelog** -- Extracts commits since the last git tag and formats them as user-facing release notes. Supports bullet, markdown, and conventional commit formats. Output can be piped directly into the deploy command's `--changelog` flag.

## screenshot-styler package

The `packages/screenshot-styler/` directory contains a standalone Python package for compositing store-ready screenshots. It can be used independently of the Claude Code skill.

```bash
python -m screenshot_styler --input screenshots/ --output styled/ --lang en
```

Modules:
- `compositor.py` -- Image composition engine using Pillow. Draws a colored background, phone frame with rounded corners and drop shadow, places the screenshot inside the frame, and renders centered marketing text above it.
- `textgen.py` -- Sends screenshots to Claude's vision API to generate marketing captions in multiple languages. Falls back to filename-derived text if the API is unavailable.
- `config.py` -- Loads JSON config files for per-screenshot text overrides, enabling repeatable builds without API calls.
- `cli.py` -- Full CLI with support for presets, Fastlane metadata directory output, multi-language processing, dry-run mode, and config file generation.

## Requirements

- **Python 3.10+** and **Pillow** (for screenshot-styler, icon generation, and screenshot styling scripts)
- `anthropic` Python SDK (optional, only for AI-generated captions when no config/captions JSON is provided)
- `agent-device` CLI (for the screenshots skill -- `npm install -g agent-device`)
- `store-deploy` CLI (for deploy skills -- installed automatically during deployment)

Install Python dependencies:

```bash
pip install -r requirements.txt
```

## License

MIT
