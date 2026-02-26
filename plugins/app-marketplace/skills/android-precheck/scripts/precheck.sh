#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# GOOGLE PLAY STORE PRE-CHECK v3.0 - Flutter & Expo Edition
# Pre-submission validation for Google Play (Android)
# ═══════════════════════════════════════════════════════════════════════════════

set -e

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'
BOLD='\033[1m'; NC='\033[0m'

BLOCKERS=0; WARNINGS=0; PASSED=0
declare -a BLOCKER_MSGS WARNING_MSGS DATA_SAFETY_MSGS
PROJECT_TYPE=""; PROJECT_NAME=""

echo ""
echo "╔═══════════════════════════════════════════════════════════════════════════╗"
echo "║               GOOGLE PLAY STORE PRE-CHECK VALIDATOR v3.0                  ║"
echo "╚═══════════════════════════════════════════════════════════════════════════╝"
echo ""

# ─── Project Detection ────────────────────────────────────────────────────────
if [ -f "pubspec.yaml" ]; then
    PROJECT_TYPE="flutter"; PKG_FILE="pubspec.yaml"; SRC_DIR="lib"
    PROJECT_NAME=$(grep "^name:" pubspec.yaml | sed 's/name: //' | tr -d ' ')
    echo -e "${MAGENTA}┌─────────────────────────────────────────────┐${NC}"
    echo -e "${MAGENTA}│${NC}  ${BOLD}Flutter Project${NC}: $PROJECT_NAME"
    echo -e "${MAGENTA}└─────────────────────────────────────────────┘${NC}"
elif [ -f "app.json" ] && grep -q "expo" app.json 2>/dev/null; then
    PROJECT_TYPE="expo"; PKG_FILE="package.json"; SRC_DIR="src"
    [ ! -d "$SRC_DIR" ] && SRC_DIR="app"; [ ! -d "$SRC_DIR" ] && SRC_DIR="."
    PROJECT_NAME=$(grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' app.json 2>/dev/null | head -1 | sed 's/.*: *"//' | sed 's/"//')
    HAS_PREBUILD=false; [ -d "android" ] && HAS_PREBUILD=true
    echo -e "${BLUE}┌─────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${NC}  ${BOLD}Expo Project${NC}: $PROJECT_NAME"
    if [ "$HAS_PREBUILD" = true ]; then
        echo -e "${BLUE}│${NC}  Prebuild: ${GREEN}✓ android/ exists${NC}"
    else
        echo -e "${BLUE}│${NC}  Prebuild: ${YELLOW}✗ Run 'npx expo prebuild --platform android'${NC}"
    fi
    echo -e "${BLUE}└─────────────────────────────────────────────┘${NC}"
elif [ -f "package.json" ] && grep -q "react-native" package.json 2>/dev/null; then
    PROJECT_TYPE="react-native"; PKG_FILE="package.json"; SRC_DIR="src"
    [ ! -d "$SRC_DIR" ] && SRC_DIR="app"; [ ! -d "$SRC_DIR" ] && SRC_DIR="."
    PROJECT_NAME=$(grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' package.json | head -1 | sed 's/.*: *"//' | sed 's/"//')
    echo -e "${CYAN}┌─────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}  ${BOLD}React Native Project${NC}: $PROJECT_NAME"
    echo -e "${CYAN}└─────────────────────────────────────────────┘${NC}"
else
    echo -e "${RED}❌ Could not detect project. Run from project root.${NC}"; exit 1
fi
echo ""

# ─── Find build files ─────────────────────────────────────────────────────────
GRADLE=""
[ -f "android/app/build.gradle.kts" ] && GRADLE="android/app/build.gradle.kts"
[ -f "android/app/build.gradle" ] && GRADLE="android/app/build.gradle"
MANIFEST=""
[ -f "android/app/src/main/AndroidManifest.xml" ] && MANIFEST="android/app/src/main/AndroidManifest.xml"

# ═══════════════════════════════════════════════════════════════════════════════
#                          BUILD & CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════
echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃   BUILD & CONFIGURATION                                                  ┃"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
echo ""

if [ -z "$GRADLE" ]; then
    if [ "$PROJECT_TYPE" = "expo" ]; then
        echo -e "${YELLOW}⚠️  No android/ directory — run npx expo prebuild --platform android${NC}"
        echo ""
        ANDROID_PACKAGE=$(grep -o '"package"[[:space:]]*:[[:space:]]*"[^"]*"' app.json 2>/dev/null | head -1 | sed 's/.*: *"//' | sed 's/"//')
        if [ -n "$ANDROID_PACKAGE" ]; then
            echo -e "  ${GREEN}✅${NC} Package: ${CYAN}$ANDROID_PACKAGE${NC}"; ((PASSED++))
        else
            echo -e "  ${RED}❌ BLOCKER: No android.package in app.json${NC}"
            BLOCKER_MSGS+=("Missing android.package in app.json"); ((BLOCKERS++))
        fi
    else
        echo -e "${YELLOW}⚠️  No build.gradle found${NC}"
        WARNING_MSGS+=("No build.gradle found"); ((WARNINGS++))
    fi
else
    echo -e "${BLUE}Found:${NC} $GRADLE"
    echo ""

    # Target SDK
    echo "▸ Target SDK Level (must be 35+ since Aug 2025)"
    TARGET_SDK=$(grep -oP "targetSdk\s*[=:]\s*\K\d+" "$GRADLE" 2>/dev/null | head -1)
    [ -z "$TARGET_SDK" ] && TARGET_SDK=$(grep -oP "targetSdkVersion\s*[=:]\s*\K\d+" "$GRADLE" 2>/dev/null | head -1)
    COMPILE_SDK=$(grep -oP "compileSdk\s*[=:]\s*\K\d+" "$GRADLE" 2>/dev/null | head -1)
    [ -z "$COMPILE_SDK" ] && COMPILE_SDK=$(grep -oP "compileSdkVersion\s*[=:]\s*\K\d+" "$GRADLE" 2>/dev/null | head -1)
    MIN_SDK=$(grep -oP "minSdk\s*[=:]\s*\K\d+" "$GRADLE" 2>/dev/null | head -1)
    [ -z "$MIN_SDK" ] && MIN_SDK=$(grep -oP "minSdkVersion\s*[=:]\s*\K\d+" "$GRADLE" 2>/dev/null | head -1)

    if [ -n "$TARGET_SDK" ]; then
        if [ "$TARGET_SDK" -lt 35 ]; then
            echo -e "  ${RED}❌ BLOCKER: targetSdk $TARGET_SDK — must be 35+${NC}"
            BLOCKER_MSGS+=("targetSdk $TARGET_SDK — must be 35+"); ((BLOCKERS++))
        else
            echo -e "  ${GREEN}✅${NC} targetSdk $TARGET_SDK"; ((PASSED++))
        fi
    else
        echo -e "  ${YELLOW}⚠️${NC}  Could not determine targetSdk"
        WARNING_MSGS+=("Could not determine targetSdk"); ((WARNINGS++))
    fi

    if [ -n "$COMPILE_SDK" ] && [ -n "$TARGET_SDK" ] && [ "$COMPILE_SDK" -lt "$TARGET_SDK" ]; then
        echo -e "  ${YELLOW}⚠️  compileSdk $COMPILE_SDK < targetSdk $TARGET_SDK${NC}"
        WARNING_MSGS+=("compileSdk < targetSdk"); ((WARNINGS++))
    fi
    [ -n "$MIN_SDK" ] && echo -e "  minSdk: ${CYAN}$MIN_SDK${NC}"
    echo ""

    # AAB Format
    echo "▸ Build Format (AAB Required)"
    AAB_ISSUE=false
    for ci_file in .github/workflows/*.yml .github/workflows/*.yaml fastlane/Fastfile; do
        if [ -f "$ci_file" ] 2>/dev/null; then
            if grep -qE "flutter build apk|task.*assemble" "$ci_file" 2>/dev/null; then
                if ! grep -qE "flutter build appbundle|task.*bundle" "$ci_file" 2>/dev/null; then
                    echo -e "  ${RED}❌ BLOCKER: APK-only build in $ci_file${NC}"
                    BLOCKER_MSGS+=("APK-only build in $ci_file — use AAB"); ((BLOCKERS++))
                    AAB_ISSUE=true
                fi
            fi
        fi
    done
    [ "$AAB_ISSUE" = false ] && echo -e "  ${GREEN}✅${NC} No APK-only builds detected" && ((PASSED++))
    echo ""

    # Signing
    echo "▸ Release Signing Configuration"
    if grep -q "signingConfigs" "$GRADLE" 2>/dev/null; then
        echo -e "  ${GREEN}✅${NC} signingConfigs found"; ((PASSED++))
    else
        echo -e "  ${YELLOW}⚠️${NC}  No signingConfigs — ensure Play App Signing enrolled"
        WARNING_MSGS+=("No signingConfigs"); ((WARNINGS++))
    fi
    if [ -f "android/key.properties" ]; then
        if [ -f ".gitignore" ] && grep -q "key.properties" .gitignore 2>/dev/null; then
            echo -e "  ${GREEN}✅${NC} key.properties in .gitignore"; ((PASSED++))
        else
            echo -e "  ${YELLOW}⚠️${NC}  key.properties NOT in .gitignore!"
            WARNING_MSGS+=("key.properties not in .gitignore"); ((WARNINGS++))
        fi
    fi
    echo ""

    # R8/ProGuard
    echo "▸ Code Shrinking (R8/ProGuard)"
    if grep -qE "minifyEnabled\s*[=:]\s*true" "$GRADLE" 2>/dev/null; then
        echo -e "  ${GREEN}✅${NC} minifyEnabled true"; ((PASSED++))
        grep -qE "shrinkResources\s*[=:]\s*true" "$GRADLE" 2>/dev/null && echo -e "  ${GREEN}✅${NC} shrinkResources enabled" && ((PASSED++))
    else
        echo -e "  ${YELLOW}⚠️${NC}  R8/ProGuard not enabled for release"
        WARNING_MSGS+=("R8/ProGuard not enabled"); ((WARNINGS++))
    fi
    echo ""

    # Version Info
    echo "▸ App Version Info"
    APP_ID=$(grep -oP "(applicationId|namespace)\s*[=:]\s*[\"']\K[^\"']+" "$GRADLE" 2>/dev/null | head -1)
    VERSION_NAME=$(grep -oP "versionName\s*[=:]\s*[\"']\K[^\"']+" "$GRADLE" 2>/dev/null | head -1)
    VERSION_CODE=$(grep -oP "versionCode\s*[=:]\s*\K\d+" "$GRADLE" 2>/dev/null | head -1)
    [ -n "$APP_ID" ] && echo -e "  Application ID: ${CYAN}$APP_ID${NC}"
    [ -n "$VERSION_NAME" ] && echo -e "  Version: ${CYAN}$VERSION_NAME${NC} (${CYAN}$VERSION_CODE${NC})"
    echo ""
fi

# ═══════════════════════════════════════════════════════════════════════════════
#                        PERMISSIONS AUDIT
# ═══════════════════════════════════════════════════════════════════════════════
if [ -n "$MANIFEST" ]; then
    echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
    echo "┃   PERMISSIONS AUDIT (AndroidManifest.xml)                                ┃"
    echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
    echo ""

    # Restricted
    echo "▸ Restricted Permissions (require Declaration Form)"
    RESTRICTED_FOUND=false
    for perm in READ_SMS SEND_SMS RECEIVE_SMS READ_CALL_LOG WRITE_CALL_LOG; do
        if grep -q "android.permission.$perm" "$MANIFEST" 2>/dev/null; then
            echo -e "  ${RED}❌ BLOCKER: $perm — only for default handler apps${NC}"
            BLOCKER_MSGS+=("$perm — restricted, requires Declaration Form"); ((BLOCKERS++))
            RESTRICTED_FOUND=true
        fi
    done
    if grep -q "android.permission.ACCESS_BACKGROUND_LOCATION" "$MANIFEST" 2>/dev/null; then
        echo -e "  ${RED}❌ BLOCKER: ACCESS_BACKGROUND_LOCATION — requires Declaration Form${NC}"
        BLOCKER_MSGS+=("ACCESS_BACKGROUND_LOCATION — requires Declaration Form"); ((BLOCKERS++))
        RESTRICTED_FOUND=true
    fi
    if grep -q "android.permission.MANAGE_EXTERNAL_STORAGE" "$MANIFEST" 2>/dev/null; then
        echo -e "  ${RED}❌ BLOCKER: MANAGE_EXTERNAL_STORAGE — requires access review${NC}"
        BLOCKER_MSGS+=("MANAGE_EXTERNAL_STORAGE — requires access review"); ((BLOCKERS++))
        RESTRICTED_FOUND=true
    fi
    if grep -q "android.permission.REQUEST_INSTALL_PACKAGES" "$MANIFEST" 2>/dev/null; then
        echo -e "  ${RED}❌ BLOCKER: REQUEST_INSTALL_PACKAGES — must justify${NC}"
        BLOCKER_MSGS+=("REQUEST_INSTALL_PACKAGES — must justify"); ((BLOCKERS++))
        RESTRICTED_FOUND=true
    fi
    [ "$RESTRICTED_FOUND" = false ] && echo -e "  ${GREEN}✅${NC} No restricted permissions" && ((PASSED++))
    echo ""

    # Dangerous
    echo "▸ Dangerous Permissions"
    DANGEROUS_FOUND=false
    if grep -q "android.permission.ACCESS_FINE_LOCATION" "$MANIFEST" 2>/dev/null; then
        echo -e "  ${YELLOW}⚠️  ACCESS_FINE_LOCATION — consider coarse location${NC}"
        WARNING_MSGS+=("ACCESS_FINE_LOCATION — verify precise is needed"); ((WARNINGS++)); DANGEROUS_FOUND=true
    fi
    if grep -q "android.permission.QUERY_ALL_PACKAGES" "$MANIFEST" 2>/dev/null; then
        echo -e "  ${YELLOW}⚠️  QUERY_ALL_PACKAGES — must justify${NC}"
        WARNING_MSGS+=("QUERY_ALL_PACKAGES — must justify"); ((WARNINGS++)); DANGEROUS_FOUND=true
    fi
    if grep -q "android.permission.SYSTEM_ALERT_WINDOW" "$MANIFEST" 2>/dev/null; then
        echo -e "  ${YELLOW}⚠️  SYSTEM_ALERT_WINDOW — must justify${NC}"
        WARNING_MSGS+=("SYSTEM_ALERT_WINDOW — must justify"); ((WARNINGS++)); DANGEROUS_FOUND=true
    fi
    [ "$DANGEROUS_FOUND" = false ] && echo -e "  ${GREEN}✅${NC} No dangerous permission concerns" && ((PASSED++))
    echo ""

    # Photo & Video Permissions (require Play Console declaration)
    echo "▸ Photo & Video Permissions"
    PHOTO_VIDEO_FOUND=false
    for perm in READ_MEDIA_IMAGES READ_MEDIA_VIDEO READ_MEDIA_VISUAL_USER_SELECTED; do
        if grep -q "android.permission.$perm" "$MANIFEST" 2>/dev/null; then
            echo -e "  ${RED}❌ BLOCKER: $perm — requires Photo & Video Permissions declaration in Play Console${NC}"
            echo "     Go to Play Console → App content → Photo and video permissions"
            BLOCKER_MSGS+=("$perm — complete Photo & Video Permissions declaration in Play Console"); ((BLOCKERS++))
            PHOTO_VIDEO_FOUND=true
        fi
    done
    [ "$PHOTO_VIDEO_FOUND" = false ] && echo -e "  ${GREEN}✅${NC} No photo/video permission concerns" && ((PASSED++))
    echo ""

    # Legacy Storage
    echo "▸ Legacy Storage Permissions"
    STORAGE_ISSUE=false
    for perm in READ_EXTERNAL_STORAGE WRITE_EXTERNAL_STORAGE; do
        if grep -q "android.permission.$perm" "$MANIFEST" 2>/dev/null; then
            if grep -q "android.permission.$perm.*maxSdkVersion" "$MANIFEST" 2>/dev/null; then
                echo -e "  ${GREEN}✅${NC} $perm has maxSdkVersion"; ((PASSED++))
            else
                echo -e "  ${RED}❌ BLOCKER: $perm without maxSdkVersion${NC}"
                BLOCKER_MSGS+=("$perm without maxSdkVersion — use Scoped Storage"); ((BLOCKERS++))
                STORAGE_ISSUE=true
            fi
        fi
    done
    if [ "$STORAGE_ISSUE" = false ] && ! grep -q "EXTERNAL_STORAGE" "$MANIFEST" 2>/dev/null; then
        echo -e "  ${GREEN}✅${NC} No legacy storage permissions"; ((PASSED++))
    fi
    echo ""
fi

# Photo & Video Permissions — Flutter pre-build check (no android/ directory)
if [ "$PROJECT_TYPE" = "flutter" ] && [ -z "$MANIFEST" ]; then
    echo "▸ Photo & Video Permissions (pubspec.yaml scan)"
    PHOTO_VIDEO_FOUND=false
    for pkg in image_picker photo_manager file_picker wechat_assets_picker; do
        if grep -q "$pkg" pubspec.yaml 2>/dev/null; then
            echo -e "  ${RED}❌ BLOCKER: $pkg in pubspec.yaml — will add READ_MEDIA_* permissions${NC}"
            echo "     Requires Photo & Video Permissions declaration in Play Console"
            BLOCKER_MSGS+=("$pkg — complete Photo & Video Permissions declaration in Play Console"); ((BLOCKERS++))
            PHOTO_VIDEO_FOUND=true
        fi
    done
    [ "$PHOTO_VIDEO_FOUND" = false ] && echo -e "  ${GREEN}✅${NC} No photo/video packages detected" && ((PASSED++))
    echo ""
fi

# Photo & Video Permissions — Expo pre-prebuild check (no android/ directory)
if [ "$PROJECT_TYPE" = "expo" ] && [ -z "$MANIFEST" ]; then
    echo "▸ Photo & Video Permissions (app.json scan)"
    PHOTO_VIDEO_FOUND=false
    if grep -qE "expo-media-library|expo-image-picker" app.json 2>/dev/null; then
        echo -e "  ${RED}❌ BLOCKER: expo-media-library/expo-image-picker plugin — will add READ_MEDIA_* permissions${NC}"
        echo "     Requires Photo & Video Permissions declaration in Play Console"
        BLOCKER_MSGS+=("Photo/video plugin — complete Photo & Video Permissions declaration in Play Console"); ((BLOCKERS++))
        PHOTO_VIDEO_FOUND=true
    fi
    [ "$PHOTO_VIDEO_FOUND" = false ] && echo -e "  ${GREEN}✅${NC} No photo/video plugins detected" && ((PASSED++))
    echo ""
fi

# ═══════════════════════════════════════════════════════════════════════════════
#                         FOREGROUND SERVICES
# ═══════════════════════════════════════════════════════════════════════════════
if [ -n "$MANIFEST" ] && grep -q "<service" "$MANIFEST" 2>/dev/null; then
    echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
    echo "┃   FOREGROUND SERVICES                                                    ┃"
    echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
    echo ""
    echo "▸ Foreground Service Type (required since API 34)"

    while IFS= read -r line; do
        svc_name=$(echo "$line" | grep -oP 'android:name="\K[^"]+')
        if echo "$line" | grep -q "foregroundServiceType"; then
            echo -e "  ${GREEN}✅${NC} $svc_name has foregroundServiceType"; ((PASSED++))
        else
            echo -e "  ${RED}❌ BLOCKER: $svc_name — missing foregroundServiceType${NC}"
            echo "     Will crash on Android 14+. Valid types: location, dataSync, camera, etc."
            BLOCKER_MSGS+=("Service $svc_name missing foregroundServiceType"); ((BLOCKERS++))
        fi
    done < <(grep "<service" "$MANIFEST" 2>/dev/null)
    echo ""
fi

# ═══════════════════════════════════════════════════════════════════════════════
#                         NETWORK SECURITY
# ═══════════════════════════════════════════════════════════════════════════════
if [ -n "$MANIFEST" ]; then
    echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
    echo "┃   NETWORK SECURITY                                                       ┃"
    echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
    echo ""
    echo "▸ Cleartext Traffic & HTTPS Enforcement"

    if grep -q 'usesCleartextTraffic="true"' "$MANIFEST" 2>/dev/null; then
        echo -e "  ${YELLOW}⚠️  usesCleartextTraffic=true — allows HTTP, set to false${NC}"
        WARNING_MSGS+=("usesCleartextTraffic=true"); ((WARNINGS++))
    else
        echo -e "  ${GREEN}✅${NC} Cleartext traffic not enabled"; ((PASSED++))
    fi

    NET_SEC="android/app/src/main/res/xml/network_security_config.xml"
    if [ -f "$NET_SEC" ]; then
        if grep -q '<base-config.*cleartextTrafficPermitted="true"' "$NET_SEC" 2>/dev/null; then
            echo -e "  ${YELLOW}⚠️  Global cleartext in network_security_config.xml${NC}"
            WARNING_MSGS+=("network_security_config allows cleartext"); ((WARNINGS++))
        else
            echo -e "  ${GREEN}✅${NC} network_security_config blocks cleartext"; ((PASSED++))
        fi
    else
        echo -e "  ${CYAN}ℹ️${NC}  No network_security_config.xml (optional but recommended)"
    fi
    echo ""
fi

# ═══════════════════════════════════════════════════════════════════════════════
#                         IN-APP PURCHASES
# ═══════════════════════════════════════════════════════════════════════════════
echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃   IN-APP PURCHASES                                                       ┃"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
echo ""
echo "▸ Play Billing Library (must be v7+)"

if [ -n "$GRADLE" ]; then
    BILLING_VER=$(grep -oP "com.android.billingclient:billing:\K[0-9.]+" "$GRADLE" 2>/dev/null | head -1)
    if [ -n "$BILLING_VER" ]; then
        BILLING_MAJOR=$(echo "$BILLING_VER" | cut -d. -f1)
        if [ "$BILLING_MAJOR" -lt 7 ]; then
            echo -e "  ${RED}❌ BLOCKER: Billing v$BILLING_VER — must be v7+${NC}"
            BLOCKER_MSGS+=("Billing Library v$BILLING_VER — must be v7+"); ((BLOCKERS++))
        else
            echo -e "  ${GREEN}✅${NC} Billing Library v$BILLING_VER"; ((PASSED++))
        fi
    else
        echo -e "  ${CYAN}ℹ️${NC}  No billing library detected"
    fi
fi
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
#                        ACCOUNT & PRIVACY
# ═══════════════════════════════════════════════════════════════════════════════
echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃   ACCOUNT & PRIVACY                                                      ┃"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
echo ""

echo "▸ Account Deletion (Google Play Policy)"
HAS_LOGIN=false; HAS_DELETE=false
if [ -d "$SRC_DIR" ]; then
    grep -rqE "signIn|login|authenticate|FirebaseAuth|createUser|signUp|register|supabase.*auth|Auth0|useAuth|AuthContext" "$SRC_DIR" 2>/dev/null && HAS_LOGIN=true
    grep -rqE "deleteUser|deleteAccount|delete.*account|account.*delet|removeAccount|closeAccount|accountDeletion" "$SRC_DIR" 2>/dev/null && HAS_DELETE=true
fi
if [ "$HAS_LOGIN" = true ]; then
    if [ "$HAS_DELETE" = true ]; then
        echo -e "  ${GREEN}✅${NC} Account deletion found"; ((PASSED++))
    else
        echo -e "  ${RED}❌ BLOCKER: Login exists but no account deletion${NC}"
        BLOCKER_MSGS+=("No account deletion found"); ((BLOCKERS++))
    fi
else
    echo -e "  ${CYAN}ℹ️${NC}  No login features detected"
fi
echo ""

echo "▸ Privacy Policy"
FOUND_PRIVACY=false
[ -d "$SRC_DIR" ] && grep -rqE "privacy.*policy|privacyPolicy|privacy_policy|PrivacyPolicy|privacyPolicyUrl" "$SRC_DIR" 2>/dev/null && FOUND_PRIVACY=true
if [ "$FOUND_PRIVACY" = true ]; then
    echo -e "  ${GREEN}✅${NC} Privacy policy reference found"; ((PASSED++))
else
    echo -e "  ${YELLOW}⚠️${NC}  No privacy policy link in code"
    WARNING_MSGS+=("Add privacy policy link in app"); ((WARNINGS++))
fi
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
#                       SDK DATA SAFETY AUDIT
# ═══════════════════════════════════════════════════════════════════════════════
echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃   SDK DATA SAFETY AUDIT                                                  ┃"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
echo ""

check_sdk() {
    local name="$1" pattern="$2" data="$3" purpose="$4"
    if grep -rqiE "$pattern" "$PKG_FILE" ${GRADLE:+"$GRADLE"} 2>/dev/null; then
        echo -e "  ${CYAN}ℹ️${NC}  ${BOLD}$name${NC} → Declare: ${YELLOW}$data${NC} ($purpose)"
        DATA_SAFETY_MSGS+=("$name → $data")
    fi
}

check_sdk "Firebase Analytics" "firebase_analytics|firebase-analytics" "Device IDs, App activity, Diagnostics" "Analytics"
check_sdk "Firebase Crashlytics" "firebase_crashlytics|firebase-crashlytics" "Crash logs, Device IDs" "Analytics"
check_sdk "Firebase Messaging" "firebase_messaging|firebase-messaging" "Device IDs" "Communications"
check_sdk "Firebase Auth" "firebase_auth|firebase-auth" "Email, User IDs, Phone number" "Account mgmt"
check_sdk "Google Maps" "google_maps_flutter|play-services-maps" "Location data" "App functionality"
check_sdk "AdMob" "google_mobile_ads|admob" "Device IDs, App interactions" "Advertising"
check_sdk "Sentry" "sentry_flutter|sentry-android" "Crash logs, Diagnostics, Device IDs" "Analytics"
check_sdk "Bugsnag" "bugsnag_flutter|bugsnag-android" "Crash logs, Diagnostics, Device IDs" "Analytics"
check_sdk "Facebook SDK" "facebook_sdk|flutter_facebook|facebook-android" "Device IDs" "Advertising"
check_sdk "OneSignal" "onesignal_flutter|onesignal" "Device IDs, Personal info" "Communications"
check_sdk "Braze" "braze_plugin|braze-android" "Device IDs, Personal info" "Personalization"
check_sdk "App Center" "appcenter|app_center" "Crash logs, Diagnostics" "Analytics"
check_sdk "Amplitude" "amplitude_flutter|amplitude" "Device IDs, App interactions" "Analytics"
check_sdk "Mixpanel" "mixpanel_flutter|mixpanel" "Device IDs, App interactions" "Analytics"
check_sdk "Adjust" "adjust_sdk|adjust-android" "Device IDs" "Advertising"
check_sdk "AppsFlyer" "appsflyer_sdk|appsflyer" "Device IDs" "Advertising"
check_sdk "RevenueCat" "purchases_flutter|revenuecat" "Purchase history, Device IDs" "Analytics"
check_sdk "Stripe" "flutter_stripe|stripe-android" "User payment info" "App functionality"

[ ${#DATA_SAFETY_MSGS[@]} -eq 0 ] && echo -e "  ${CYAN}ℹ️${NC}  No common SDKs detected — check manually"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
#                              SUMMARY
# ═══════════════════════════════════════════════════════════════════════════════
echo "╔═══════════════════════════════════════════════════════════════════════════╗"
echo "║                        ANDROID SUMMARY                                    ║"
echo "╚═══════════════════════════════════════════════════════════════════════════╝"
echo ""

[ ${#BLOCKER_MSGS[@]} -gt 0 ] && echo -e "${RED}❌ BLOCKERS (${#BLOCKER_MSGS[@]}):${NC}" && for m in "${BLOCKER_MSGS[@]}"; do echo "   • $m"; done && echo ""
[ ${#WARNING_MSGS[@]} -gt 0 ] && echo -e "${YELLOW}⚠️  WARNINGS (${#WARNING_MSGS[@]}):${NC}" && for m in "${WARNING_MSGS[@]}"; do echo "   • $m"; done && echo ""
echo -e "${GREEN}✅ PASSED: $PASSED checks${NC}"
echo ""

if [ ${#DATA_SAFETY_MSGS[@]} -gt 0 ]; then
    echo "📊 DATA SAFETY FORM — declare these in Play Console:"
    for m in "${DATA_SAFETY_MSGS[@]}"; do echo "   • $m"; done
    echo ""
fi

echo "📋 PLAY CONSOLE MANUAL CHECKLIST:"
echo "   [ ] Data Safety form completed"
echo "   [ ] Privacy policy URL added"
echo "   [ ] Data deletion URL added"
echo "   [ ] Content rating questionnaire"
echo "   [ ] Target audience declaration"
echo "   [ ] Ads + Financial features declarations"
echo "   [ ] Permissions Declaration Form (if restricted perms)"
echo "   [ ] Photo & video permissions declaration (if READ_MEDIA_* used)"
echo "   [ ] Developer account verified (2026)"
echo "   [ ] Screenshots: min 2, 9:16, no frames"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf "  TOTAL:  %2d blockers   %2d warnings   %2d passed   %2d SDK declarations\n" "$BLOCKERS" "$WARNINGS" "$PASSED" "${#DATA_SAFETY_MSGS[@]}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ $BLOCKERS -gt 0 ]; then
    echo -e "${RED}🚫 NOT READY — fix $BLOCKERS blocker(s)${NC}"; exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}⚠️  REVIEW $WARNINGS WARNING(S) BEFORE SUBMISSION${NC}"; exit 0
else
    echo -e "${GREEN}✅ AUTOMATED CHECKS PASSED — complete manual checklist${NC}"; exit 0
fi
