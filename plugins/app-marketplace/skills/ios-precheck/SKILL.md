---
name: ios-app-store-precheck
version: 3.0.0
description: Pre-submission validation for Flutter and Expo apps before Apple App Store submission
triggers:
  - app store
  - apple
  - ios submission
  - ios precheck
  - ios review
  - ios rejection
  - flutter deploy ios
  - expo submit ios
  - testflight
tools:
  - bash
---

# Apple App Store Pre-Check for Flutter & Expo

Automated pre-submission validation to catch common rejection issues **before** you submit to the App Store.

## Supported Frameworks

| Framework | Detection | Build Workflow |
|-----------|-----------|----------------|
| **Flutter** | `pubspec.yaml` | `flutter build ios` |
| **Expo** | `app.json` + expo | `npx expo prebuild` → `npx expo run:ios` |
| **React Native** | `package.json` | Native builds |

## Step 0 — Check & Install Dependencies (run every time)

Before doing anything else, run the automated setup script. It detects the OS, checks each dependency, and installs whatever is missing:

```bash
bash scripts/setup.sh
```

This checks: Bash and the precheck script (ensures it exists and is executable).

Do NOT proceed until the setup script reports all dependencies are ready.

## Quick Start

Run from your project root:

```bash
./precheck-ios.sh
```

Or use Claude to analyze your project:

> "Run the App Store precheck on my Flutter app"

### Expo Projects

For Expo, run prebuild first so native files exist:

```bash
npx expo prebuild --platform ios
./precheck-ios.sh
```

Without prebuild, the script checks `app.json` config only.

---

## What It Checks

### Background Modes (Guideline 2.5.4)

| Check | Guideline | Severity |
|-------|-----------|----------|
| `UIBackgroundModes` contains `audio` without audio playback feature | 2.5.4 | ❌ Blocker |
| `UIBackgroundModes` contains `audio` injected by dependency (e.g. expo-video) | 2.5.4 | ❌ Blocker |
| `UIBackgroundModes` contains `voip` without VoIP feature | 2.5.4 | ❌ Blocker |
| `UIBackgroundModes` contains `location` but no background location code found | 2.5.4 | ❌ Blocker |
| `UIBackgroundModes` contains `location` with background location code | 2.5.4 | ⚠️ Warning |
| `UIBackgroundModes` contains `bluetooth-central` without BLE feature | 2.5.4 | ⚠️ Warning |

### Privacy Purpose Strings (Guideline 5.1.1)

| Check | Guideline | Severity |
|-------|-----------|----------|
| Privacy purpose string contains placeholder text (e.g. "TODO", "PLACEHOLDER") | 5.1.1 | ❌ Blocker |
| Privacy purpose string too short (< 20 characters) | 5.1.1 | ⚠️ Warning |
| Privacy purpose string too generic (e.g. "Camera access needed") | 5.1.1 | ⚠️ Warning |
| Missing purpose string for declared permission | 5.1.1 | ❌ Blocker |

Privacy keys checked:
- `NSCameraUsageDescription`
- `NSPhotoLibraryUsageDescription`
- `NSPhotoLibraryAddUsageDescription`
- `NSMicrophoneUsageDescription`
- `NSLocationWhenInUseUsageDescription`
- `NSLocationAlwaysUsageDescription`
- `NSLocationAlwaysAndWhenInUseUsageDescription`
- `NSContactsUsageDescription`
- `NSCalendarsUsageDescription`
- `NSFaceIDUsageDescription`
- `NSMotionUsageDescription`
- `NSBluetoothAlwaysUsageDescription`
- `NSBluetoothPeripheralUsageDescription`
- `NSSpeechRecognitionUsageDescription`
- `NSHealthShareUsageDescription`
- `NSHealthUpdateUsageDescription`

### Generic Template / Wrong-Context Strings in Built Info.plist (Guideline 5.1.1)

| Check | Guideline | Severity |
|-------|-----------|----------|
| Permission string contains `$(PRODUCT_NAME)` or "Allow X to access/use" template | 5.1.1 | ❌ Blocker |
| Permission string has wrong-context text (e.g. "share with friends" in a safety app) | 5.1.1 | ❌ Blocker |

These checks run on the **generated Info.plist** in `ios/` — the actual file Apple reviews. This catches generic strings regardless of whether they came from Expo plugin configs, Flutter plugin defaults, or manual edits.

**Expo without prebuild:** When no `ios/` directory exists, the script falls back to checking `app.json` plugin configs (`cameraPermission`, `photosPermission`, etc.) as a preview, since plugin configs override `infoPlist` values at build time.

### Location Permission Consistency (Guideline 2.5.4 / 5.1.1)

| Check | Guideline | Severity |
|-------|-----------|----------|
| Foreground-only location code but declares `NSLocationAlwaysUsageDescription` | 2.5.4 | ❌ Blocker |
| Foreground-only location code but expo-location uses `locationAlwaysAndWhenInUsePermission` | 2.5.4 | ❌ Blocker |
| Unnecessary `NSLocationAlways*` keys in infoPlist for foreground-only app | 5.1.1 | ⚠️ Warning |

### Business Distribution Signals (Guideline 3.2)

| Check | Guideline | Severity |
|-------|-----------|----------|
| App has B2B/enterprise patterns (org login, invite-only, admin panels) | 3.2 | ⚠️ Warning |

Apple may reject apps that appear to be for internal business use only. The check detects patterns like enterprise login, invite codes, admin panels, and multi-tenant architecture. If flagged, prepare responses to Apple's 5 questions about distribution scope.

### App Transport Security (ATS)

| Check | Guideline | Severity |
|-------|-----------|----------|
| `NSAllowsArbitraryLoads` set to `true` | - | ⚠️ Warning |
| `NSExceptionDomains` with `NSExceptionAllowsInsecureHTTPLoads` | - | ⚠️ Warning |

### Build Configuration

| Check | Guideline | Severity |
|-------|-----------|----------|
| Bundle ID not set or uses placeholder | - | ❌ Blocker |
| Version string missing or invalid | - | ⚠️ Warning |
| Build number missing or invalid | - | ⚠️ Warning |
| Minimum deployment target too low | - | ⚠️ Warning |

### Account & Privacy

| Check | Guideline | Severity |
|-------|-----------|----------|
| Login exists but no account deletion | 5.1.1(v) | ❌ Blocker |
| IAP exists but no restore purchases button | 3.1.1 | ❌ Blocker |
| No privacy policy in app | 5.1.1 | ⚠️ Warning |

### Flutter Version

| Check | Guideline | Severity |
|-------|-----------|----------|
| Flutter 3.24.3 detected (uses non-public iOS APIs) | 2.5.1 | ❌ Blocker |
| Flutter 3.24.4 detected (uses non-public iOS APIs) | 2.5.1 | ❌ Blocker |

---

## Screenshot Requirements (2025)

| Device | Dimensions | Required? |
|--------|------------|-----------|
| **iPhone 6.9"** (16 Pro Max) | 1320 × 2868 px | ✅ Required |
| iPhone 6.7" (15 Pro Max) | 1290 × 2796 px | Auto-scaled |
| iPhone 6.5" (15 Plus) | 1284 × 2778 px | Auto-scaled |
| iPhone 5.5" (8 Plus) | 1242 × 2208 px | Auto-scaled |
| **iPad 13"** | 2064 × 2752 px | ✅ If iPad app |
| iPad 12.9" | 2048 × 2732 px | Auto-scaled |

- Max 10 screenshots per device
- First 3 shown in search results (most important!)
- Format: JPEG or PNG, no transparency, max 8MB

---

## Expo-Specific Notes

### With Prebuild (Recommended)

After running `npx expo prebuild --platform ios`, the script checks:
- `ios/<ProjectName>/Info.plist` — Full native checks (background modes, privacy strings, ATS)

### Without Prebuild

If no `ios/` directory exists, the script checks:
- `app.json` → `ios.bundleIdentifier`
- `app.json` → `ios.infoPlist` — Privacy strings, background modes overrides

The script will suggest running `npx expo prebuild` for complete checks.

### app.json Configuration

```json
{
  "expo": {
    "ios": {
      "bundleIdentifier": "com.yourcompany.yourapp",
      "infoPlist": {
        "NSCameraUsageDescription": "Take photos of documents to upload",
        "NSPhotoLibraryUsageDescription": "Select photos to attach to reports",
        "UIBackgroundModes": ["remote-notification"]
      }
    }
  }
}
```

---

## Flutter-Specific Notes

### Known Problematic Versions

| Version | Issue | Solution |
|---------|-------|----------|
| 3.24.3 | Uses non-public iOS APIs | Upgrade to 3.24.5+ |
| 3.24.4 | Uses non-public iOS APIs | Upgrade to 3.24.5+ |

### Common Flutter iOS Issues

1. **UIBackgroundModes audio** — Often added by Firebase plugins but not needed for push notifications
2. **Generic privacy strings** — Flutter templates have placeholder text
3. **Release mode crashes** — Always test `flutter build ios` not just `flutter run`
4. **Xcode version mismatch** — Ensure Xcode matches Flutter's requirements
5. **CocoaPods version** — Outdated pods can cause build failures with newer Xcode

---

## Output Format

```
╔═══════════════════════════════════════════════════════════════════════════╗
║                APPLE APP STORE PRE-CHECK VALIDATOR v3.0                   ║
╚═══════════════════════════════════════════════════════════════════════════╝

┌─────────────────────────────────────────────┐
│  Project: my-app                            │
│  Framework: Flutter 3.27.1                  │
│  Prebuild: ✓ Native directories exist       │
└─────────────────────────────────────────────┘

┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃   BACKGROUND MODES (Guideline 2.5.4)                                     ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
▸ UIBackgroundModes audit (audio, voip, location, bluetooth)

┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃   PRIVACY PURPOSE STRINGS (Guideline 5.1.1)                              ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
▸ Camera (NSCameraUsageDescription)
▸ Photo Library (NSPhotoLibraryUsageDescription)
▸ Microphone (NSMicrophoneUsageDescription)
▸ Location (NSLocationWhenInUseUsageDescription)
▸ Contacts (NSContactsUsageDescription)
▸ [all declared privacy keys]

┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃   APP TRANSPORT SECURITY                                                 ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
▸ NSAllowsArbitraryLoads
▸ Exception Domains

┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃   BUILD CONFIGURATION                                                    ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
▸ Bundle ID
▸ Version String
▸ Build Number
▸ Minimum Deployment Target

┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃   ACCOUNT & PRIVACY                                                      ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
▸ Account Deletion (Guideline 5.1.1(v))
▸ Restore Purchases (Guideline 3.1.1)
▸ Privacy Policy

┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃   FLUTTER VERSION                                                        ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
▸ Known problematic versions (3.24.3, 3.24.4)

╔═══════════════════════════════════════════════════════════════════════════╗
║                          iOS SUMMARY                                      ║
╚═══════════════════════════════════════════════════════════════════════════╝
❌ BLOCKERS / ⚠️ WARNINGS / ✅ PASSED

📋 APP STORE CONNECT MANUAL CHECKLIST
□ App Store screenshots uploaded (6.9" iPhone required)
□ iPad screenshots uploaded (if Universal app)
□ App description, keywords, and promotional text set
□ Privacy nutrition labels completed (App Privacy section)
□ App category selected
□ Age rating questionnaire completed
□ Review notes provided (login credentials if needed)
□ Contact information for App Review team
□ IDFA declaration completed (if using advertising identifier)
□ Export compliance (uses encryption?) answered
□ In-app purchases configured and submitted for review

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                              FINAL VERDICT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Background Modes:    X blockers   X warnings   X passed
  Privacy Strings:     X blockers   X warnings   X passed
  ATS:                 X blockers   X warnings   X passed
  Build Config:        X blockers   X warnings   X passed
  Account & Privacy:   X blockers   X warnings   X passed
  Flutter Version:     X blockers   X warnings   X passed
  ─────────────────────────────────────────────────────────
  TOTAL:               X blockers   X warnings   X passed

🚫 NOT READY / ⚠️ REVIEW WARNINGS / ✅ AUTOMATED CHECKS PASSED
```

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All checks passed (or warnings only) |
| 1 | Blockers found - do not submit |

---

## Common Fixes

### UIBackgroundModes "audio" (Guideline 2.5.4)

```xml
<!-- ios/Runner/Info.plist or ios/<AppName>/Info.plist -->
<!-- REMOVE 'audio' if not a streaming app -->
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>  <!-- DELETE THIS LINE -->
    <string>remote-notification</string>  <!-- This one is OK -->
</array>
```

For Expo, remove from `app.json`:
```json
{
  "expo": {
    "ios": {
      "infoPlist": {
        "UIBackgroundModes": ["remote-notification"]
      }
    }
  }
}
```

### Expo Plugin Permission Overrides (Guideline 5.1.1)

Plugin configs override `infoPlist` values. Update the plugin configs directly:

```json
// app.json — expo-camera plugin
["expo-camera", {
  "cameraPermission": "This app uses the camera to take photos for incident reports and QR code scanning.",
  "microphonePermission": "This app uses the microphone to record audio notes and capture videos for documentation."
}]

// app.json — expo-image-picker plugin
["expo-image-picker", {
  "photosPermission": "This app accesses your photo library to attach existing images to reports."
}]

// app.json — expo-media-library plugin
["expo-media-library", {
  "photosPermission": "This app accesses your photo library to attach images to reports.",
  "savePhotosPermission": "This app saves captured photos to your photo library for your records."
}]

// app.json — expo-location plugin (foreground-only)
["expo-location", {
  "locationWhenInUsePermission": "This app uses your location to tag reports with where events occur."
}]
```

After changes, run `npx expo prebuild --clean` to regenerate `Info.plist`.

### Location Permission Consistency (Guideline 2.5.4)

If your app only uses foreground location (`requestForegroundPermissionsAsync`, `getCurrentPositionAsync`):

1. Remove `"location"` from `UIBackgroundModes`
2. Remove `NSLocationAlwaysUsageDescription` from `infoPlist`
3. Remove `NSLocationAlwaysAndWhenInUseUsageDescription` from `infoPlist`
4. Use `locationWhenInUsePermission` (not `locationAlwaysAndWhenInUsePermission`) in expo-location plugin
5. Keep only `NSLocationWhenInUseUsageDescription`

### Business Distribution (Guideline 3.2)

If Apple flags your app as internal/enterprise-only, respond in App Store Connect with:

1. **Not restricted to one company** — explain multi-tenant/multi-client model
2. **Serves multiple organizations** — list industries or use cases
3. **General public features** — describe any publicly accessible features
4. **Account creation** — how users get accounts (employer signup, self-registration, etc.)
5. **Payment model** — B2B subscription, individual purchase, freemium, etc.

Add this information in **App Review Notes** in App Store Connect before resubmitting.

### Generic Privacy Strings (Guideline 5.1.1)

```xml
<!-- BAD — will be flagged -->
<key>NSCameraUsageDescription</key>
<string>Camera access needed</string>

<!-- BAD — placeholder text -->
<key>NSCameraUsageDescription</key>
<string>TODO: Add camera description</string>

<!-- GOOD — specific and descriptive -->
<key>NSCameraUsageDescription</key>
<string>Take photos of receipts to attach to your expense reports</string>
```

For Expo in `app.json`:
```json
{
  "expo": {
    "ios": {
      "infoPlist": {
        "NSCameraUsageDescription": "Take photos of receipts to attach to your expense reports",
        "NSPhotoLibraryUsageDescription": "Select existing photos to attach to your expense reports",
        "NSLocationWhenInUseUsageDescription": "Show nearby offices on the map to help you find the closest location"
      }
    }
  }
}
```

### App Transport Security

```xml
<!-- BAD — disables all HTTPS enforcement -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>

<!-- BETTER — exception only for specific domains that need HTTP -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>legacy-api.example.com</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
        </dict>
    </dict>
</dict>

<!-- BEST — no exceptions, all HTTPS -->
<!-- Simply don't include NSAppTransportSecurity at all -->
```

### Account Deletion (Guideline 5.1.1(v))

Add a "Delete Account" option in Settings or Profile screen that:
1. Clearly explains what will be deleted
2. Requires confirmation
3. Actually deletes the account and data
4. Must be discoverable without contacting support

### Restore Purchases (Guideline 3.1.1)

Add a visible "Restore Purchases" button on your paywall or in Settings that calls:

```dart
// Flutter (in_app_purchase)
await InAppPurchase.instance.restorePurchases();
```

```javascript
// Expo/React Native (react-native-iap)
await RNIap.getAvailablePurchases();
```

### Flutter Version Fix

```bash
# Check current version
flutter --version

# Upgrade past problematic versions
flutter upgrade

# Or pin to a specific safe version
flutter downgrade 3.24.5
```

---

## App Store Connect Manual Checklist

These items cannot be validated automatically from code and must be completed in App Store Connect:

| Item | Where in ASC | Required? |
|------|-------------|-----------|
| Screenshots (6.9" iPhone) | App Store → Screenshots | ✅ All apps |
| Screenshots (iPad 13") | App Store → Screenshots | ✅ If Universal app |
| App description | App Store → Description | ✅ All apps |
| Keywords | App Store → Keywords | ✅ All apps |
| Privacy nutrition labels | App Privacy | ✅ All apps |
| Age rating questionnaire | App Information → Age Rating | ✅ All apps |
| App category | App Information → Category | ✅ All apps |
| Review notes / login credentials | App Review Information | ✅ If login required |
| Contact info for review team | App Review Information | ✅ All apps |
| IDFA declaration | App Privacy → Tracking | ✅ If using IDFA |
| Export compliance (encryption) | App Information → Export Compliance | ✅ All apps |
| In-app purchases submitted | Features → In-App Purchases | ✅ If IAP exists |

---

## References

- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [App Store Screenshot Specifications](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/)
- [Required Privacy Manifest Reasons API](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files/describing_use_of_required_reason_api)
- [App Store Review Guidelines History](https://developer.apple.com/app-store/review/guidelines/updates/)
- [App Privacy Details on the App Store](https://developer.apple.com/app-store/app-privacy-details/)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
