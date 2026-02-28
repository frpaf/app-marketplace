---
name: android-play-store-precheck
version: 4.0.0
description: Pre-submission validation for Flutter, Expo, and React Native apps before Google Play submission
triggers:
  - play store
  - google play
  - android submission
  - android precheck
  - android review
  - android rejection
  - flutter deploy android
  - expo submit android
  - react native play store
tools:
  - bash
---

# Google Play Store Pre-Check for Flutter, Expo & React Native

Automated pre-submission validation to catch common rejection issues **before** you submit to Google Play.

## Supported Frameworks

| Framework | Detection | Build Workflow |
|-----------|-----------|----------------|
| **Flutter** | `pubspec.yaml` | `flutter build appbundle` |
| **Expo** | `app.json` + expo | `npx expo prebuild` → `npx expo run:android` |
| **React Native** | `package.json` + react-native | Native builds |

## Step 0 — Check & Install Dependencies (run every time)

Before doing anything else, run the automated setup script. It detects the OS, checks each dependency, and installs whatever is missing:

```bash
bash scripts/setup.sh
```

This checks: Bash, readelf (binutils), and the precheck script (ensures it exists and is executable).

Do NOT proceed until the setup script reports all dependencies are ready.

## Quick Start

Run from your project root:

```bash
./precheck-android.sh              # Terminal output (default)
./precheck-android.sh --json       # JSON output for CI/CD
./precheck-android.sh --json-pretty # JSON output, formatted
```

Or use Claude to analyze your project:

> "Run the Play Store precheck on my Flutter app"

### Expo Projects

For Expo, run prebuild first so native files exist:

```bash
npx expo prebuild --platform android
./precheck-android.sh
```

Without prebuild, the script checks `app.json` and `package.json` config — including photo/video plugins (`expo-media-library`, `expo-image-picker`) which are flagged as blockers even without native files.

---

## Issue Categories

Every issue detected by the script includes:

| Field | Description |
|-------|-------------|
| **Severity** | `BLOCKER` (must fix) or `WARNING` (review before submission) |
| **Category** | One of the categories below |
| **File** | The file where the issue was found |
| **Match** | The specific line, permission, library, or config causing the issue |
| **Message** | Human-readable explanation |
| **Fix** | Actionable recommendation |

Categories: `target-sdk`, `compile-sdk`, `permissions`, `photo-video`, `foreground-service`, `network-security`, `build-config`, `signing`, `billing`, `account-deletion`, `16kb-alignment`, `build-format`, `expo-config`

---

## What It Checks

### Build & Configuration

| Check | Requirement | Severity |
|-------|-------------|----------|
| targetSdk < 35 | Aug 2025 policy — new apps/updates must target API 35+ | ❌ Blocker |
| compileSdk < targetSdk | compileSdk must be ≥ targetSdk | ⚠️ Warning |
| Building APK instead of AAB | Google requires AAB for new apps | ❌ Blocker |
| Fastlane `--apk` upload | Must use `--aab` for Play Store | ❌ Blocker |
| Missing signing configuration | Release builds | ⚠️ Warning |
| key.properties not in .gitignore | Security | ⚠️ Warning |
| R8/ProGuard not enabled for release | App quality & size | ⚠️ Warning |
| shrinkResources not enabled | Unused resources in bundle | ⚠️ Warning |
| Missing `android.config.pageSize=16384` | Required for Android 15+ (16 KB page sizes) since Nov 2025 | ❌ Blocker |
| Missing `gradle.properties` file entirely | Cannot set 16 KB page size | ❌ Blocker |
| Native `.so` libraries without 16 KB alignment | Scans `android/`, `node_modules/`, build dirs; uses `readelf` to verify and **traces each failure back to its owning 3rd-party package** | ❌ Blocker |

### Permissions (AndroidManifest.xml)

#### Restricted Permissions (Require Permissions Declaration Form)

| Check | Requirement | Severity |
|-------|-------------|----------|
| `READ_SMS` / `SEND_SMS` / `RECEIVE_SMS` | Only allowed for default SMS handler apps | ❌ Blocker |
| `READ_CALL_LOG` / `WRITE_CALL_LOG` | Only allowed for default Phone handler apps | ❌ Blocker |
| `ACCESS_BACKGROUND_LOCATION` | Requires Permissions Declaration Form approval from Google | ❌ Blocker |
| `MANAGE_EXTERNAL_STORAGE` | Requires "All files access" review before publishing | ❌ Blocker |
| `REQUEST_INSTALL_PACKAGES` | Highly scrutinized — must justify sideloading | ❌ Blocker |

#### Dangerous Permissions (Require Justification)

| Check | Requirement | Severity |
|-------|-------------|----------|
| `QUERY_ALL_PACKAGES` | Must justify visibility into installed apps | ⚠️ Warning |
| `ACCESS_FINE_LOCATION` without justification | Consider if `ACCESS_COARSE_LOCATION` is sufficient | ⚠️ Warning |
| `SYSTEM_ALERT_WINDOW` | Draw over other apps — needs justification | ⚠️ Warning |

#### Photo & Video Permissions

| Check | Requirement | Severity |
|-------|-------------|----------|
| `READ_MEDIA_IMAGES` in manifest | Requires Photo & Video Permissions declaration in Play Console | ❌ Blocker |
| `READ_MEDIA_VIDEO` in manifest | Requires Photo & Video Permissions declaration in Play Console | ❌ Blocker |
| `READ_MEDIA_VISUAL_USER_SELECTED` in manifest | Requires Photo & Video Permissions declaration in Play Console | ❌ Blocker |
| `image_picker` / `photo_manager` in pubspec.yaml (no android/ dir) | Adds READ_MEDIA_* at build time — requires declaration | ❌ Blocker |
| `expo-media-library` / `expo-image-picker` in package.json (no android/ dir) | Adds READ_MEDIA_* at build time — requires declaration | ❌ Blocker |

> **Note:** These are blockers because Google will reject apps using READ_MEDIA_* permissions unless the app's core purpose is photo/video management. Use the Android Photo Picker instead (no permission needed).

#### Legacy / Deprecated Permissions

| Check | Requirement | Severity |
|-------|-------------|----------|
| `READ_EXTERNAL_STORAGE` without `maxSdkVersion` on API 35 target | Legacy — must migrate to Scoped Storage | ❌ Blocker |
| `WRITE_EXTERNAL_STORAGE` without `maxSdkVersion` on API 35 target | Legacy — deprecated since API 30 | ❌ Blocker |

### Foreground Services

| Check | Requirement | Severity |
|-------|-------------|----------|
| `<service>` without `android:foregroundServiceType` | Required since API 34 — missing = crash on Android 14+ | ❌ Blocker |

> **Note (v4.0):** The script now correctly handles multi-line `<service>` XML declarations. Previous versions could false-positive on services where `foregroundServiceType` was on a separate line from `<service`.

Valid foreground service types (API 34+):
- `camera` — Camera access in foreground
- `connectedDevice` — Interaction with external devices (Bluetooth, USB)
- `dataSync` — Data transfer/sync operations
- `health` — Health/fitness tracking
- `location` — GPS / location tracking
- `mediaPlayback` — Audio/video playback
- `mediaProjection` — Screen capture/casting
- `microphone` — Audio recording
- `phoneCall` — Ongoing phone calls
- `remoteMessaging` — Messaging transfer
- `shortService` — Quick tasks (< 3 min)
- `specialUse` — Other use cases (requires justification)
- `systemExempted` — System-level only

### Network Security

| Check | Requirement | Severity |
|-------|-------------|----------|
| `android:usesCleartextTraffic="true"` in manifest | Must be false — must enforce HTTPS | ⚠️ Warning |
| `cleartextTrafficPermitted="true"` in network_security_config.xml | Allows plain HTTP traffic — Data Safety mismatch risk | ⚠️ Warning |
| Missing network_security_config.xml entirely | Should explicitly configure network security | ℹ️ Info |

### In-App Purchases

| Check | Requirement | Severity |
|-------|-------------|----------|
| Play Billing Library < v7 | Must use v7+ for new apps/updates | ❌ Blocker |

### Account & Privacy

| Check | Requirement | Severity |
|-------|-------------|----------|
| Login exists but no account deletion | Play Policy requires account deletion option | ❌ Blocker |
| No privacy policy in app | Must link privacy policy in-app and in listing | ⚠️ Warning |

> **Note (v4.0):** Login detection now also matches `signInWithCredential`, `signInAnonymously`, `Auth0`, `supabase.*auth`, `useAuth`, and `AuthContext` patterns.

### SDK Data Safety Audit

| SDK | Data Types to Declare | Purpose |
|-----|----------------------|---------|
| **Firebase Analytics** | Device IDs, App interactions, Diagnostics | Analytics |
| **Firebase Crashlytics** | Crash logs, Device IDs | Analytics |
| **Firebase Cloud Messaging** | Device IDs | Communications |
| **Firebase Auth** | Email, User IDs, Phone number | Account mgmt |
| **Google Maps SDK** | Location data | App functionality |
| **Google AdMob** | Device IDs, App interactions | Advertising |
| **Sentry** | Crash logs, Diagnostics, Device IDs | Analytics |
| **Bugsnag** | Crash logs, Diagnostics, Device IDs | Analytics |
| **Microsoft App Center** | Crash logs, Diagnostics | Analytics |
| **OneSignal** | Device IDs, Personal info | Communications |
| **Braze** | Device IDs, Personal info | Personalization |
| **Facebook SDK** | Device IDs | Advertising |
| **Amplitude** | Device IDs, App interactions | Analytics |
| **Mixpanel** | Device IDs, App interactions | Analytics |
| **Adjust** | Device IDs | Advertising |
| **AppsFlyer** | Device IDs | Advertising |
| **RevenueCat** | Purchase history, Device IDs | Analytics |
| **Stripe SDK** | User payment info | App functionality |
| **Microsoft Intune SDK** | Device IDs, App info | Security |

> **Note (v4.0):** SDK detection now also matches React Native package names (e.g. `@react-native-firebase/analytics`, `@sentry/react-native`, `react-native-purchases`, `@stripe/stripe-react-native`). Each detection shows the source file where the SDK was found.

---

## Screenshot Requirements (2025)

| Device | Dimensions | Required? |
|--------|------------|-----------|
| **Phone** | 1080 × 1920 (or 9:16) | ✅ Min 2 total |
| 7" Tablet | 1200 × 1920 | If supported |
| 10" Tablet | 1600 × 2560 | If supported |

- Max 8 screenshots per device type
- Aspect ratio must not exceed 2:1
- Format: JPEG or PNG, **no transparency**, max 8MB
- **No device frames**

---

## Expo-Specific Notes

### With Prebuild (Recommended)

After running `npx expo prebuild --platform android`, the script checks:
- `android/app/build.gradle` — Full native checks
- `android/app/src/main/AndroidManifest.xml` — Permissions, services, network config

### Without Prebuild

If no `android/` directory exists, the script checks:
- `app.json` → `android.package`
- `app.json` → `android.permissions` — checks for restricted permissions
- `app.json` + `package.json` → `expo-media-library` / `expo-image-picker` — flagged as **BLOCKER** for photo/video permissions
- `package.json` → SDK dependencies for Data Safety audit

The script will suggest running `npx expo prebuild` for complete checks.

### app.json Configuration

```json
{
  "expo": {
    "android": {
      "package": "com.yourcompany.yourapp",
      "permissions": [
        "CAMERA",
        "ACCESS_FINE_LOCATION"
      ],
      "blockedPermissions": [
        "READ_SMS",
        "READ_CALL_LOG"
      ]
    }
  }
}
```

---

## Flutter-Specific Notes

### Common Flutter Android Issues

1. **Legacy storage permissions** — Some older plugins still request `WRITE_EXTERNAL_STORAGE`
2. **Missing foreground service types** — Plugins that use foreground services may not declare the type
3. **Release mode crashes** — Always test `flutter build appbundle` not just `flutter run`
4. **Gradle/AGP version mismatches** — Ensure `android/settings.gradle` uses compatible versions
5. **ProGuard rules missing** — Some plugins need custom ProGuard rules to avoid R8 stripping
6. **Photo/video plugins** — `image_picker`, `photo_manager`, `file_picker` may inject `READ_MEDIA_*` permissions; the script flags these as blockers even without `android/` directory

---

## Output Format

### Terminal Output (default)

Each issue is displayed inline with severity, file, and the offending value:

```
  ❌ BLOCKER [android/app/build.gradle] targetSdk 33
     targetSdk 33 is below the required 35 for new apps and updates (since Aug 2025)
     Fix: Update targetSdk to 35 in android/app/build.gradle

  ⚠️  WARNING [android/app/build.gradle] minifyEnabled false
     R8 code shrinking disabled for release — larger APK/AAB size
     Fix: Set minifyEnabled true in release buildType
```

### Full Terminal Layout

```
╔═══════════════════════════════════════════════════════════════════════════╗
║               GOOGLE PLAY STORE PRE-CHECK VALIDATOR v4.0                  ║
╚═══════════════════════════════════════════════════════════════════════════╝

┌─────────────────────────────────────────────┐
│  Project: my-app                            │
│  Framework: Flutter 3.27.1                  │
│  Prebuild: ✓ Native directories exist       │
└─────────────────────────────────────────────┘

┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃   BUILD & CONFIGURATION                                                  ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
▸ Target SDK Level (must be 35+)
▸ Compile SDK Level (must be ≥ targetSdk)
▸ Build Format (AAB required, not APK)
▸ Release Signing Configuration
▸ Code Shrinking (R8/ProGuard)
▸ App Version Info

┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃   16 KB MEMORY PAGE SIZE (required since Nov 2025)                       ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
▸ gradle.properties — android.config.pageSize
▸ Native Library (.so) Page Alignment
  ┌──────────────────────────────────────────────────────────────────┐
  │  ✗ react-native-fast-image                                     │
  │      libRNFastImage.so (0x1000)                                │
  │  ✗ @react-native-firebase/app                                  │
  │      libfirebase.so (0x1000)                                   │
  └──────────────────────────────────────────────────────────────────┘
  All packages with native libraries:
     ✗ react-native-fast-image
     ✗ @react-native-firebase/app
     ✓ react-native-reanimated
     ✓ hermes-engine
▸ Known Native Packages (dependency scan)

┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃   PERMISSIONS AUDIT (AndroidManifest.xml)                                ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
▸ Restricted Permissions (SMS, Call Log — Declaration Form required)
▸ Background Location (Declaration Form required)
▸ All Files Access (MANAGE_EXTERNAL_STORAGE — review required)
▸ Install Packages (REQUEST_INSTALL_PACKAGES)
▸ Dangerous Permissions (Location, QUERY_ALL_PACKAGES, etc.)
▸ Photo & Video Permissions
▸ Legacy Storage Permissions (deprecated API 33+)

┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃   FOREGROUND SERVICES                                                    ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
▸ Missing foregroundServiceType on <service> tags

┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃   NETWORK SECURITY                                                       ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
▸ Cleartext Traffic (must be disabled)
▸ Network Security Config (should exist)

┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃   IN-APP PURCHASES                                                       ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
▸ Play Billing Library Version (must be v7+)

┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃   ACCOUNT & PRIVACY                                                      ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
▸ Account Deletion Mechanism
▸ Privacy Policy (in-app link)

┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃   SDK DATA SAFETY AUDIT                                                  ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
▸ Firebase (Analytics, Crashlytics, FCM, Auth)
▸ Analytics (Amplitude, Mixpanel, etc.)
▸ Crash Reporting (Sentry, Bugsnag, App Center)
▸ Push Notifications (OneSignal, Braze)
▸ Maps (Google Maps SDK)
▸ Attribution (Adjust, AppsFlyer)
▸ Advertising (Facebook SDK, AdMob)
▸ Payments (Stripe, RevenueCat)
▸ MDM (Microsoft Intune)

╔═══════════════════════════════════════════════════════════════════════════╗
║                        ANDROID SUMMARY                                    ║
╚═══════════════════════════════════════════════════════════════════════════╝

❌ BLOCKERS (N):
   • [category] match (file)
   • [category] match (file)

⚠️  WARNINGS (N):
   • [category] match (file)

✅ PASSED: N checks

📊 DATA SAFETY FORM — declare these in Play Console:
   • Firebase Analytics → Device IDs, App activity, Diagnostics
   • Firebase Crashlytics → Crash logs, Device IDs

📋 PLAY CONSOLE MANUAL CHECKLIST:
   [ ] Data Safety form completed
   [ ] Privacy policy URL added
   [ ] Data deletion URL added
   [ ] Content rating questionnaire
   [ ] Target audience declaration
   [ ] Ads + Financial features declarations
   [ ] Permissions Declaration Form (if restricted perms)
   [ ] Photo & video: use Android Photo Picker (or declare if core photo app)
   [ ] Developer account verified (2026)
   [ ] Screenshots: min 2, 9:16, no frames

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                              FINAL VERDICT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Target SDK:         X blocker(s)   X warning(s)   X passed
  Build Format:       X blocker(s)   X warning(s)   X passed
  Build Config:       X blocker(s)   X warning(s)   X passed
  Signing:            X blocker(s)   X warning(s)   X passed
  16 KB Page Size:    X blocker(s)   X warning(s)   X passed
  Permissions:        X blocker(s)   X warning(s)   X passed
  Photo & Video:      X blocker(s)   X warning(s)   X passed
  Foreground Svc:     X blocker(s)   X warning(s)   X passed
  Network Security:   X blocker(s)   X warning(s)   X passed
  Billing:            X blocker(s)   X warning(s)   X passed
  Account & Privacy:  X blocker(s)   X warning(s)   X passed
  ─────────────────────────────────────────────────────────
  TOTAL:              X blocker(s)   X warning(s)   X passed   X SDK declarations

🚫 NOT READY / ⚠️ REVIEW WARNINGS / ✅ AUTOMATED CHECKS PASSED
```

### JSON Output (`--json`)

```json
{
  "project": { "name": "my-app", "type": "flutter" },
  "summary": { "blockers": 3, "warnings": 2, "passed": 10, "data_safety": 2 },
  "issues": [
    {
      "severity": "BLOCKER",
      "category": "target-sdk",
      "file": "android/app/build.gradle",
      "match": "targetSdk 33",
      "message": "targetSdk 33 is below the required 35 for new apps and updates (since Aug 2025)",
      "fix": "Update targetSdk to 35 in android/app/build.gradle"
    }
  ],
  "data_safety": [
    {
      "sdk": "Firebase Analytics",
      "file": "pubspec.yaml",
      "match": "firebase_analytics",
      "declares": "Device IDs, App activity, Diagnostics",
      "purpose": "Analytics"
    }
  ],
  "categories": {
    "target-sdk": { "blockers": 1, "warnings": 0, "passed": 0 },
    "permissions": { "blockers": 2, "warnings": 0, "passed": 1 }
  },
  "verdict": "NOT_READY"
}
```

Use `--json` in CI/CD pipelines:

```yaml
# GitHub Actions example
- name: Play Store precheck
  run: |
    result=$(./precheck-android.sh --json)
    blockers=$(echo "$result" | jq '.summary.blockers')
    if [ "$blockers" -gt 0 ]; then
      echo "::error::$blockers Play Store blocker(s) found"
      echo "$result" | jq '.issues[] | select(.severity == "BLOCKER")'
      exit 1
    fi
```

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All checks passed (or warnings only) |
| 1 | Blockers found — do not submit |

---

## Common Fixes

### targetSdk Too Low

```gradle
// android/app/build.gradle
android {
    compileSdk 35
    defaultConfig {
        targetSdk 35
        minSdk 21
    }
}
```

For Flutter, ensure your `android/app/build.gradle` and `android/settings.gradle` reference the latest Gradle and AGP versions.

### 16 KB Memory Page Size (Android 15+)

Since Nov 2025, Google Play requires all apps targeting Android 15+ to support 16 KB memory page sizes.

```properties
# android/gradle.properties — add this line (requires AGP 8.5.1+)
android.config.pageSize=16384
```

If your app includes native `.so` libraries (NDK, C/C++), ensure they are compiled with 16 KB page alignment:

```bash
# Verify alignment of a .so file (LOAD segment alignment should be 0x4000)
readelf -l path/to/lib.so | grep LOAD

# Recompile with 16 KB alignment (CMakeLists.txt)
# Add to your CMakeLists.txt:
# target_link_options(your_lib PRIVATE "-Wl,-z,max-page-size=16384")
```

The script traces misaligned `.so` files back to their owning package:

```
  ❌ BLOCKER [native .so files] react-native-fast-image, @react-native-firebase/app
     2 package(s) with native .so files not aligned to 16 KB
     Fix: Update the owning packages, rebuild. For libs you own: recompile with -Wl,-z,max-page-size=16384

  ┌──────────────────────────────────────────────────────────────────┐
  │  ✗ react-native-fast-image                                     │
  │      libRNFastImage.so (0x1000)                                │
  │  ✗ @react-native-firebase/app                                  │
  │      libfirebase.so (0x1000)                                   │
  └──────────────────────────────────────────────────────────────────┘
  All packages with native libraries:
     ✗ react-native-fast-image
     ✗ @react-native-firebase/app
     ✓ react-native-reanimated
     ✓ hermes-engine
```

### Build AAB Instead of APK

```bash
# Flutter — always use appbundle for Play Store
flutter build appbundle --release

# NOT: flutter build apk --release
```

For Fastlane:
```ruby
# Fastfile
lane :release do
  gradle(
    task: "bundle",          # NOT "assemble"
    build_type: "Release"
  )
end
```

### Restricted Permissions — SMS/Call Log

If your app is **not** the default SMS or Phone handler, **remove these entirely**:

```xml
<!-- AndroidManifest.xml — REMOVE these unless you are the default handler app -->
<uses-permission android:name="android.permission.READ_SMS" />         <!-- REMOVE -->
<uses-permission android:name="android.permission.SEND_SMS" />         <!-- REMOVE -->
<uses-permission android:name="android.permission.RECEIVE_SMS" />      <!-- REMOVE -->
<uses-permission android:name="android.permission.READ_CALL_LOG" />    <!-- REMOVE -->
<uses-permission android:name="android.permission.WRITE_CALL_LOG" />   <!-- REMOVE -->
```

If your app legitimately needs these, you must submit the **Permissions Declaration Form** in Play Console and be approved.

### Background Location

```xml
<!-- Only add if absolutely needed — requires Declaration Form approval -->
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
```

Before adding, ask: Can the feature work with foreground location only? If yes, remove background location and use a foreground service with `location` type instead.

### Legacy Storage Permissions

```xml
<!-- BAD — deprecated on API 33+ -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />

<!-- OK — scoped with maxSdkVersion for backward compat -->
<uses-permission
    android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32" />
<uses-permission
    android:name="android.permission.WRITE_EXTERNAL_STORAGE"
    android:maxSdkVersion="29" />
```

Replace with modern alternatives:
```kotlin
// Use Photo Picker (no permission needed)
val pickMedia = registerForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri -> }

// Use MediaStore for media files
val cursor = contentResolver.query(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, ...)

// Use SAF for user-selected files
val openDocument = registerForActivityResult(ActivityResultContracts.OpenDocument()) { uri -> }
```

For Flutter:
```dart
// Use image_picker (handles Photo Picker internally)
final image = await ImagePicker().pickImage(source: ImageSource.gallery);

// Use file_picker with SAF
final result = await FilePicker.platform.pickFiles();
```

### Photo & Video Permissions

```xml
<!-- BAD — Google will reject unless core photo/video app -->
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
<uses-permission android:name="android.permission.READ_MEDIA_VISUAL_USER_SELECTED" />
```

**Remove these permissions** and use the Android Photo Picker instead (no permission needed). Only keep them if your app IS a gallery, photo editor, or file manager — and complete the Photo & Video Permissions declaration in Play Console → App content.

| Framework | Fix |
|-----------|-----|
| Flutter | Use `image_picker` v1.0.7+ which defaults to Android Photo Picker |
| Expo | Use `expo-image-picker` v15+ which defaults to Photo Picker |
| React Native | Use `react-native-image-picker` v7+ which supports Photo Picker |

### Foreground Service Type

```xml
<!-- BAD — missing type, will crash on API 34+ -->
<service android:name=".MyService" />

<!-- GOOD — type declared (can span multiple lines) -->
<service
    android:name=".LocationTrackingService"
    android:foregroundServiceType="location"
    android:exported="false" />

<service
    android:name=".UploadService"
    android:foregroundServiceType="dataSync"
    android:exported="false" />
```

### Network Security Config

```xml
<!-- android/app/src/main/res/xml/network_security_config.xml -->
<network-security-config>
    <!-- Block all cleartext (HTTP) traffic -->
    <base-config cleartextTrafficPermitted="false">
        <trust-anchors>
            <certificates src="system" />
        </trust-anchors>
    </base-config>

    <!-- OPTIONAL: Allow cleartext for local dev only -->
    <!-- Remove this block before release -->
    <!--
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="true">10.0.2.2</domain>
        <domain includeSubdomains="true">localhost</domain>
    </domain-config>
    -->
</network-security-config>
```

```xml
<!-- AndroidManifest.xml -->
<application
    android:networkSecurityConfig="@xml/network_security_config"
    android:usesCleartextTraffic="false">
```

### Enable R8/ProGuard

```gradle
// android/app/build.gradle
android {
    buildTypes {
        release {
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
}
```

### Play Billing Library

```gradle
// android/app/build.gradle — must be v7+
dependencies {
    implementation 'com.android.billingclient:billing:7.1.1'
}
```

For Flutter (`in_app_purchase`), ensure you use the latest version:
```yaml
# pubspec.yaml
dependencies:
  in_app_purchase: ^3.2.0  # Check for latest — must bundle billing v7+
```

For Expo/React Native:
```json
// package.json — react-native-iap must be recent enough to bundle billing v7+
{
  "dependencies": {
    "react-native-iap": "^12.15.0"
  }
}
```

### Account Deletion

Add a "Delete Account" option in Settings or Profile screen that:
1. Clearly explains what will be deleted
2. Requires confirmation
3. Actually deletes the account and data
4. Provides a web URL fallback for Play Console data deletion field

---

## Play Console Manual Checklist

These items cannot be validated automatically from code and must be completed in the Google Play Console:

| Item | Where in Console | Required? |
|------|-----------------|-----------|
| Data Safety form | App content → Data safety | ✅ All apps |
| Privacy policy URL | App content → Privacy policy | ✅ All apps |
| Data deletion URL / instructions | App content → Data safety | ✅ If collecting data |
| Content rating questionnaire | App content → Content ratings | ✅ All apps |
| Target audience declaration | App content → Target audience | ✅ All apps |
| Ads declaration | App content → Ads | ✅ All apps |
| Financial features declaration | App content → Financial features | ✅ All apps (even if none) |
| Permissions Declaration Form | App content → App access | ✅ If restricted permissions |
| Photo & Video Permissions | App content → Photo and video permissions | ✅ If READ_MEDIA_* used |
| News & Magazines declaration | App content → News | ✅ If news/magazine app |
| Store listing | Store presence → Main store listing | ✅ All apps |
| Developer account verification | Account details | ✅ All apps (enforced 2026) |

---

## Changelog

### v4.0.0

- **Structured issue tracking** — every issue now includes severity, category, file, match, message, and fix
- **`--json` / `--json-pretty` output** — machine-readable output for CI/CD pipelines
- **Per-category summary** — final verdict shows blocker/warning/pass counts per category
- **Multi-line XML parsing** — foreground service detection now handles `<service>` tags spanning multiple lines
- **Photo/video permissions upgraded to BLOCKER** — `image_picker` in pubspec.yaml and `expo-media-library` in package.json are now blockers (previously warnings)
- **`.so` package tracing** — misaligned native libraries are grouped by owning package name (npm/pub), not raw file paths
- **Broader login detection** — now matches `signInWithCredential`, `signInAnonymously`, `Auth0`, Supabase, `useAuth`, `AuthContext`
- **React Native SDK patterns** — Data Safety audit now matches `@react-native-firebase/*`, `@sentry/react-native`, `@stripe/stripe-react-native`, etc.
- **Fastlane `--apk` detection** — catches `fastlane supply --apk` in CI configs
- **File references on every issue** — summary shows `[category] match (file)` for quick navigation
- **gradle.properties missing** — distinguished from "file exists but missing pageSize" with different messages

### v3.0.0

- Initial release with Flutter, Expo, and React Native support
- 16 KB page size checks
- SDK Data Safety audit
- Foreground service type validation
- Permissions audit with restricted/dangerous/legacy categories

---

## References

- [Google Play Developer Program Policy](https://support.google.com/googleplay/android-developer/answer/16810878)
- [Google Play Data Safety Requirements](https://support.google.com/googleplay/android-developer/answer/10787469)
- [Prepare Your App for Review (Play Console)](https://support.google.com/googleplay/android-developer/answer/9859455)
- [Target API Level Requirements](https://support.google.com/googleplay/android-developer/answer/11926878)
- [Permissions and Sensitive APIs Policy](https://support.google.com/googleplay/android-developer/answer/16558241)
- [Photo & Video Permissions Policy](https://support.google.com/googleplay/android-developer/answer/14115180)
- [Play Store Screenshot Requirements](https://support.google.com/googleplay/android-developer/answer/9866151)
- [Google Play SDK Index](https://developer.android.com/distribute/sdk-index)
- [16 KB Page Size Support](https://developer.android.com/guide/practices/page-sizes)
- [Play Policy Insights (Android Studio)](https://developer.android.com/studio/releases#policy-insights)
- [Developer Policy Center](https://play.google/developer-content-policy/)