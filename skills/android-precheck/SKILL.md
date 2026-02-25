---
name: android-play-store-precheck
version: 3.0.0
description: Pre-submission validation for Flutter and Expo apps before Google Play submission
triggers:
  - play store
  - google play
  - android submission
  - android precheck
  - android review
  - android rejection
  - flutter deploy android
  - expo submit android
tools:
  - bash
---

# Google Play Store Pre-Check for Flutter & Expo

Automated pre-submission validation to catch common rejection issues **before** you submit to Google Play.

## Supported Frameworks

| Framework | Detection | Build Workflow |
|-----------|-----------|----------------|
| **Flutter** | `pubspec.yaml` | `flutter build appbundle` |
| **Expo** | `app.json` + expo | `npx expo prebuild` → `npx expo run:android` |
| **React Native** | `package.json` | Native builds |

## Quick Start

Run from your project root:

```bash
./precheck-android.sh
```

Or use Claude to analyze your project:

> "Run the Play Store precheck on my Flutter app"

### Expo Projects

For Expo, run prebuild first so native files exist:

```bash
npx expo prebuild --platform android
./precheck-android.sh
```

Without prebuild, the script checks `app.json` config only.

---

## What It Checks

### Build & Configuration

| Check | Requirement | Severity |
|-------|-------------|----------|
| targetSdk < 35 | Aug 2025 policy — new apps/updates must target API 35+ | ❌ Blocker |
| compileSdk < targetSdk | compileSdk must be ≥ targetSdk | ⚠️ Warning |
| Building APK instead of AAB | Google requires AAB for new apps | ❌ Blocker |
| Missing signing configuration | Release builds | ⚠️ Warning |
| key.properties not in .gitignore | Security | ⚠️ Warning |
| R8/ProGuard not enabled for release | App quality & size | ⚠️ Warning |

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
| `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO` without core use | Should use Android Photo Picker instead | ⚠️ Warning |
| `SYSTEM_ALERT_WINDOW` | Draw over other apps — needs justification | ⚠️ Warning |
| `CAMERA` without core use | Must be essential to app functionality | ⚠️ Warning |
| `RECORD_AUDIO` without core use | Must be essential to app functionality | ⚠️ Warning |
| `READ_CONTACTS` without core use | Must be essential — not for data harvesting | ⚠️ Warning |

#### Legacy / Deprecated Permissions

| Check | Requirement | Severity |
|-------|-------------|----------|
| `READ_EXTERNAL_STORAGE` without `maxSdkVersion` on API 35 target | Legacy — must migrate to Scoped Storage | ❌ Blocker |
| `WRITE_EXTERNAL_STORAGE` without `maxSdkVersion` on API 35 target | Legacy — deprecated since API 30 | ❌ Blocker |
| `READ_EXTERNAL_STORAGE` on API 33+ | Deprecated — use Scoped Storage, MediaStore, or Photo Picker | ⚠️ Warning |
| `WRITE_EXTERNAL_STORAGE` on API 33+ | Deprecated — use Scoped Storage or SAF | ⚠️ Warning |
| Unused permissions declared in manifest | Remove any permissions not actively used | ⚠️ Warning |

### Foreground Services

| Check | Requirement | Severity |
|-------|-------------|----------|
| `<service>` without `android:foregroundServiceType` | Required since API 34 — missing = crash or rejection | ❌ Blocker |
| `foregroundServiceType` uses invalid type | Must be a valid type (see list below) | ❌ Blocker |

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

### Storage Policy

| Check | Requirement | Severity |
|-------|-------------|----------|
| `READ_EXTERNAL_STORAGE` without `maxSdkVersion` on API 35 target | Must migrate to Scoped Storage | ❌ Blocker |
| `WRITE_EXTERNAL_STORAGE` without `maxSdkVersion` on API 35 target | Deprecated since API 30 | ❌ Blocker |
| No use of MediaStore / SAF / Photo Picker as replacement | Must use modern storage APIs | ⚠️ Warning |

### In-App Purchases

| Check | Requirement | Severity |
|-------|-------------|----------|
| Play Billing Library < v7 | Must use v7+ for new apps/updates | ❌ Blocker |
| IAP present but no restore mechanism | User must be able to restore purchases | ⚠️ Warning |

### Account & Privacy

| Check | Requirement | Severity |
|-------|-------------|----------|
| Login exists but no account deletion | Play Policy requires account deletion option | ❌ Blocker |
| No privacy policy in app | Must link privacy policy in-app and in listing | ⚠️ Warning |
| No data deletion URL/mechanism discoverable | Play Store requires accessible deletion path | ⚠️ Warning |

### SDK Data Safety Audit

| Check | Requirement | Severity |
|-------|-------------|----------|
| Firebase Analytics detected | Must declare: Device IDs, App activity, Diagnostics in Data Safety form | ℹ️ Data Safety |
| Firebase Crashlytics detected | Must declare: Crash logs, Device IDs in Data Safety form | ℹ️ Data Safety |
| Firebase Cloud Messaging detected | Must declare: Device IDs in Data Safety form | ℹ️ Data Safety |
| Firebase Auth detected | Must declare: Email, User IDs, Phone number in Data Safety form | ℹ️ Data Safety |
| Google Maps SDK detected | Must declare: Location data in Data Safety form | ℹ️ Data Safety |
| Google AdMob detected | Must declare: Device IDs, App interactions in Data Safety form | ℹ️ Data Safety |
| Sentry / Bugsnag detected | Must declare: Crash logs, Diagnostics, Device IDs in Data Safety form | ℹ️ Data Safety |
| Facebook SDK detected | Must declare: Device IDs in Data Safety form | ℹ️ Data Safety |
| OneSignal / Braze detected | Must declare: Device IDs, Personal info in Data Safety form | ℹ️ Data Safety |
| Microsoft App Center detected | Must declare: Crash logs, Diagnostics in Data Safety form | ℹ️ Data Safety |
| Amplitude / Mixpanel detected | Must declare: Device IDs, App activity in Data Safety form | ℹ️ Data Safety |
| Adjust / AppsFlyer detected | Must declare: Device IDs in Data Safety form | ℹ️ Data Safety |
| RevenueCat detected | Must declare: Purchase history, Device IDs in Data Safety form | ℹ️ Data Safety |
| Stripe SDK detected | Must declare: User payment info in Data Safety form | ℹ️ Data Safety |
| Microsoft Intune SDK detected | Must declare: Device IDs, App info in Data Safety form | ℹ️ Data Safety |

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
- `app.json` → `android.blockedPermissions` — verifies unwanted permissions are blocked

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

---

## Output Format

```
╔═══════════════════════════════════════════════════════════════════════════╗
║               GOOGLE PLAY STORE PRE-CHECK VALIDATOR v3.0                  ║
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
┃   PERMISSIONS AUDIT (AndroidManifest.xml)                                ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
▸ Restricted Permissions (SMS, Call Log — Declaration Form required)
▸ Background Location (Declaration Form required)
▸ All Files Access (MANAGE_EXTERNAL_STORAGE — review required)
▸ Install Packages (REQUEST_INSTALL_PACKAGES)
▸ Dangerous Permissions (Camera, Location, Microphone, etc.)
▸ Legacy Storage Permissions (deprecated API 33+)
▸ Unused Permission Detection

┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃   FOREGROUND SERVICES                                                    ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
▸ Missing foregroundServiceType on <service> tags
▸ Invalid foregroundServiceType values

┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃   NETWORK SECURITY                                                       ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
▸ Cleartext Traffic (must be disabled)
▸ Network Security Config (should exist)
▸ HTTPS Enforcement

┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃   STORAGE POLICY                                                         ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
▸ Scoped Storage Migration
▸ Legacy Storage API Usage

┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃   IN-APP PURCHASES                                                       ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
▸ Play Billing Library Version (must be v7+)
▸ Restore Purchases Mechanism

┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃   ACCOUNT & PRIVACY                                                      ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
▸ Account Deletion Mechanism
▸ Privacy Policy (in-app link)
▸ Data Deletion URL / Mechanism

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
❌ BLOCKERS / ⚠️ WARNINGS / ✅ PASSED

📊 DATA SAFETY FORM REQUIREMENTS
┌─────────────────────────────────────────────────────────────┐
│  Based on detected SDKs, you must declare:                  │
│  • Device or other IDs (Firebase, push tokens)              │
│  • Crash logs (Crashlytics)                                 │
│  • Diagnostics (Analytics)                                  │
│  • App interactions (Analytics)                             │
│  • [additional based on detected SDKs]                      │
└─────────────────────────────────────────────────────────────┘

📋 PLAY CONSOLE MANUAL CHECKLIST
□ Data Safety form completed in Play Console
□ Privacy policy URL added in Play Console
□ Data deletion URL added in Play Console
□ Content rating questionnaire completed
□ Target audience declaration completed
□ Ads declaration completed
□ Financial features declaration completed (even if none)
□ Permissions Declaration Form submitted (if restricted permissions used)
□ Developer account verified (required 2026)
□ Screenshots meet requirements (min 2, 9:16, no frames, no transparency)
□ Store listing complete (title, short description, full description)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                              FINAL VERDICT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Build & Config:      X blockers   X warnings   X passed
  Permissions:         X blockers   X warnings   X passed
  Foreground Svc:      X blockers   X warnings   X passed
  Network Security:    X blockers   X warnings   X passed
  Storage Policy:      X blockers   X warnings   X passed
  In-App Purchases:    X blockers   X warnings   X passed
  Account & Privacy:   X blockers   X warnings   X passed
  Data Safety:         X SDKs detected requiring declarations
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

### Foreground Service Type

```xml
<!-- BAD — missing type, will crash on API 34+ -->
<service android:name=".MyService" />

<!-- GOOD — type declared -->
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

## SDK Data Safety Mapping Reference

Use this table to fill out your Google Play Data Safety form based on SDKs detected in your project:

| SDK | Data Types to Declare | Purpose |
|-----|----------------------|---------|
| **Firebase Analytics** | Device IDs, App interactions, Diagnostics | Analytics |
| **Firebase Crashlytics** | Crash logs, Device IDs | App functionality, Analytics |
| **Firebase Cloud Messaging** | Device IDs | App functionality, Developer communications |
| **Firebase Auth** | Email, User IDs, Phone number | Account management, App functionality |
| **Firebase Remote Config** | Device IDs | App functionality |
| **Google Maps SDK** | Approximate/Precise location | App functionality |
| **Google AdMob** | Device IDs, App interactions | Advertising |
| **Sentry** | Crash logs, Diagnostics, Device IDs | Analytics, App functionality |
| **Bugsnag** | Crash logs, Diagnostics, Device IDs | Analytics, App functionality |
| **Microsoft App Center** | Crash logs, Diagnostics | Analytics |
| **OneSignal** | Device IDs, Personal info | Developer communications |
| **Braze** | Device IDs, Personal info, App interactions | Developer communications, Personalization |
| **Facebook SDK** | Device IDs | Advertising, Analytics |
| **Amplitude** | Device IDs, App interactions | Analytics |
| **Mixpanel** | Device IDs, App interactions | Analytics |
| **Adjust** | Device IDs | Advertising, Analytics |
| **AppsFlyer** | Device IDs | Advertising, Analytics |
| **RevenueCat** | Purchase history, Device IDs | App functionality, Analytics |
| **Stripe SDK** | User payment info | App functionality |
| **Microsoft Intune SDK** | Device IDs, App info | App functionality, Security |

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
| News & Magazines declaration | App content → News | ✅ If news/magazine app |
| Store listing | Store presence → Main store listing | ✅ All apps |
| Developer account verification | Account details | ✅ All apps (enforced 2026) |

---

## References

- [Google Play Developer Program Policy](https://support.google.com/googleplay/android-developer/answer/16810878)
- [Google Play Data Safety Requirements](https://support.google.com/googleplay/android-developer/answer/10787469)
- [Prepare Your App for Review (Play Console)](https://support.google.com/googleplay/android-developer/answer/9859455)
- [Target API Level Requirements](https://support.google.com/googleplay/android-developer/answer/11926878)
- [Permissions and Sensitive APIs Policy](https://support.google.com/googleplay/android-developer/answer/16558241)
- [Play Store Screenshot Requirements](https://support.google.com/googleplay/android-developer/answer/9866151)
- [Google Play SDK Index](https://developer.android.com/distribute/sdk-index)
- [Play Policy Insights (Android Studio)](https://developer.android.com/studio/releases#policy-insights)
- [Developer Policy Center](https://play.google/developer-content-policy/)
