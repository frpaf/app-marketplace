#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# APPLE APP STORE PRE-CHECK v3.0 - Flutter & Expo Edition
# Pre-submission validation for Apple App Store (iOS)
# ═══════════════════════════════════════════════════════════════════════════════

set -e

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'
BOLD='\033[1m'; NC='\033[0m'

BLOCKERS=0; WARNINGS=0; PASSED=0
declare -a BLOCKER_MSGS WARNING_MSGS
PROJECT_TYPE=""; PROJECT_NAME=""

# Cross-framework code pattern constants
# Background location APIs: Expo, Flutter, React Native, native iOS
BG_LOCATION_PATTERN="startLocationUpdatesAsync|watchPositionAsync|LocationTaskService|startBackgroundLocationUpdatesAsync|TaskManager.*location|Location\.startLocationUpdatesAsync|startMonitoringSignificantLocationChanges|allowsBackgroundLocationUpdates|BackgroundLocator|background_locator|startUpdatingLocation|CLLocationManager.*startUpdating|getPositionStream.*distanceFilter|onLocationChanged|enableBackgroundMode"
# Foreground location APIs: Expo, Flutter, React Native, native iOS
FG_LOCATION_PATTERN="requestForegroundPermissionsAsync|getCurrentPositionAsync|getLastKnownPositionAsync|requestPermissionsAsync.*location|Location\.(getCurrentPosition|getLastKnown)|useLocation|Geolocation\.getCurrentPosition|Geolocator\.getCurrentPosition|Geolocator\.getLastKnownPosition|CLLocationManager.*requestWhenInUse|requestLocation"
# Audio playback APIs: Expo, Flutter, React Native, native iOS
AUDIO_PATTERN="expo-av|Audio\.Sound|Audio\.Recording|useAudioPlayer|AVAudioSession|AVAudioPlayer|expo-video.*backgroundPlayback|AudioSession|playbackAllowsExternalMedia|just_audio|audioplayers|audio_service|AudioPlayer|MediaPlayer|AVPlayer|backgroundPlayback|audio_session"

echo ""
echo "╔═══════════════════════════════════════════════════════════════════════════╗"
echo "║                APPLE APP STORE PRE-CHECK VALIDATOR v3.0                   ║"
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
    HAS_PREBUILD=false; [ -d "ios" ] && HAS_PREBUILD=true
    echo -e "${BLUE}┌─────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${NC}  ${BOLD}Expo Project${NC}: $PROJECT_NAME"
    if [ "$HAS_PREBUILD" = true ]; then
        echo -e "${BLUE}│${NC}  Prebuild: ${GREEN}✓ ios/ exists${NC}"
    else
        echo -e "${BLUE}│${NC}  Prebuild: ${YELLOW}✗ Run 'npx expo prebuild --platform ios'${NC}"
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

# ─── Find Info.plist ──────────────────────────────────────────────────────────
PLIST=""
if [ "$PROJECT_TYPE" = "flutter" ]; then
    [ -f "ios/Runner/Info.plist" ] && PLIST="ios/Runner/Info.plist"
elif [ "$PROJECT_TYPE" = "expo" ]; then
    [ -d "ios" ] && PLIST=$(find ios -name "Info.plist" -not -path "*/Pods/*" 2>/dev/null | head -1)
else
    PLIST=$(find ios -name "Info.plist" -not -path "*/Pods/*" 2>/dev/null | grep -v "Tests" | head -1)
fi

# ═══════════════════════════════════════════════════════════════════════════════
#                      BACKGROUND MODES (Guideline 2.5.4)
# ═══════════════════════════════════════════════════════════════════════════════
echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃   BACKGROUND MODES (Guideline 2.5.4)                                     ┃"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
echo ""

if [ -z "$PLIST" ]; then
    if [ "$PROJECT_TYPE" = "expo" ] && [ -f "app.json" ]; then
        echo "▸ Checking app.json infoPlist overrides"
        if grep -q '"UIBackgroundModes"' app.json 2>/dev/null; then
            if grep -A5 '"UIBackgroundModes"' app.json | grep -q '"audio"'; then
                echo -e "  ${RED}❌ BLOCKER: UIBackgroundModes 'audio' in app.json${NC}"
                echo "     Only valid for streaming/playback apps"
                BLOCKER_MSGS+=("UIBackgroundModes 'audio' in app.json"); ((BLOCKERS++))
            fi
            if grep -A5 '"UIBackgroundModes"' app.json | grep -q '"voip"'; then
                echo -e "  ${RED}❌ BLOCKER: UIBackgroundModes 'voip' in app.json${NC}"
                BLOCKER_MSGS+=("UIBackgroundModes 'voip' in app.json"); ((BLOCKERS++))
            fi
            # Check "location" in background modes vs actual background location usage
            if grep -A5 '"UIBackgroundModes"' app.json | grep -q '"location"'; then
                USES_BG_LOCATION=false
                [ -d "$SRC_DIR" ] && grep -rqE "$BG_LOCATION_PATTERN" "$SRC_DIR" 2>/dev/null && USES_BG_LOCATION=true
                if [ "$USES_BG_LOCATION" = false ]; then
                    echo -e "  ${RED}❌ BLOCKER: UIBackgroundModes 'location' but no background location code found${NC}"
                    echo "     If using foreground-only location, remove 'location' from UIBackgroundModes"
                    echo "     Fix: Change UIBackgroundModes to only [\"fetch\", \"remote-notification\"]"
                    BLOCKER_MSGS+=("UIBackgroundModes 'location' without background location usage"); ((BLOCKERS++))
                else
                    echo -e "  ${GREEN}✅${NC} UIBackgroundModes 'location' — background location code found"; ((PASSED++))
                fi
            fi
        else
            echo -e "  ${GREEN}✅${NC} No UIBackgroundModes in app.json"; ((PASSED++))
        fi
    else
        echo -e "${YELLOW}⚠️  No Info.plist found — skipping${NC}"
        WARNING_MSGS+=("No Info.plist found"); ((WARNINGS++))
    fi
else
    echo -e "${BLUE}Found:${NC} $PLIST"
    echo ""
    echo "▸ UIBackgroundModes"

    BG_MODES=$(plutil -extract UIBackgroundModes xml1 -o - "$PLIST" 2>/dev/null || echo "")
    if [ -n "$BG_MODES" ]; then
        BG_OK=true
        if echo "$BG_MODES" | grep -q ">audio<"; then
            # Check if any audio playback/streaming code exists
            USES_AUDIO=false
            [ -d "$SRC_DIR" ] && grep -rqE "$AUDIO_PATTERN" "$SRC_DIR" 2>/dev/null && USES_AUDIO=true
            if [ "$USES_AUDIO" = false ]; then
                echo -e "  ${RED}❌ BLOCKER: 'audio' — no audio playback/streaming code found${NC}"
                echo "     This may have been injected by a dependency during build."
                echo "     Push notification sounds work WITHOUT this."
                echo "     Fix: Remove 'audio' from UIBackgroundModes in Info.plist"
                if [ "$PROJECT_TYPE" = "expo" ]; then
                    echo "     For Expo: ensure expo-video has supportsBackgroundPlayback: false"
                    echo "     Then run: npx expo prebuild --clean"
                elif [ "$PROJECT_TYPE" = "flutter" ]; then
                    echo "     Check Flutter plugins (audio_service, just_audio) for background config"
                fi
            else
                echo -e "  ${RED}❌ BLOCKER: 'audio' — only for streaming/playback apps${NC}"
                echo "     Push notification sounds work WITHOUT this."
                echo "     Fix: Remove 'audio' from UIBackgroundModes"
            fi
            BLOCKER_MSGS+=("UIBackgroundModes 'audio'"); ((BLOCKERS++)); BG_OK=false
        fi
        if echo "$BG_MODES" | grep -q ">voip<"; then
            echo -e "  ${RED}❌ BLOCKER: 'voip' — only for VoIP calling apps${NC}"
            BLOCKER_MSGS+=("UIBackgroundModes 'voip'"); ((BLOCKERS++)); BG_OK=false
        fi
        if echo "$BG_MODES" | grep -q ">location<"; then
            # Check if app actually uses background location APIs
            USES_BG_LOCATION=false
            [ -d "$SRC_DIR" ] && grep -rqE "$BG_LOCATION_PATTERN" "$SRC_DIR" 2>/dev/null && USES_BG_LOCATION=true
            if [ "$USES_BG_LOCATION" = false ]; then
                echo -e "  ${RED}❌ BLOCKER: 'location' — no background location code found${NC}"
                echo "     App uses foreground-only location (e.g. getCurrentPositionAsync)"
                echo "     Fix: Remove 'location' from UIBackgroundModes"
                BLOCKER_MSGS+=("UIBackgroundModes 'location' without background location usage"); ((BLOCKERS++))
            else
                echo -e "  ${YELLOW}⚠️  'location' — requires user-facing justification${NC}"
                WARNING_MSGS+=("UIBackgroundModes 'location'"); ((WARNINGS++))
            fi
            BG_OK=false
        fi
        [ "$BG_OK" = true ] && echo -e "  ${GREEN}✅${NC} Background modes OK" && ((PASSED++))
    else
        echo -e "  ${GREEN}✅${NC} No UIBackgroundModes declared"; ((PASSED++))
    fi
fi
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
#                    PRIVACY PURPOSE STRINGS (Guideline 5.1.1)
# ═══════════════════════════════════════════════════════════════════════════════
echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃   PRIVACY PURPOSE STRINGS (Guideline 5.1.1)                              ┃"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
echo ""

if [ -n "$PLIST" ]; then
    declare -A USAGE_KEYS=(
        ["NSCameraUsageDescription"]="Camera"
        ["NSPhotoLibraryUsageDescription"]="Photo Library (read)"
        ["NSPhotoLibraryAddUsageDescription"]="Photo Library (write)"
        ["NSMicrophoneUsageDescription"]="Microphone"
        ["NSLocationWhenInUseUsageDescription"]="Location (in use)"
        ["NSLocationAlwaysUsageDescription"]="Location (always)"
        ["NSLocationAlwaysAndWhenInUseUsageDescription"]="Location (always+inuse)"
        ["NSContactsUsageDescription"]="Contacts"
        ["NSCalendarsUsageDescription"]="Calendars"
        ["NSFaceIDUsageDescription"]="Face ID"
        ["NSBluetoothAlwaysUsageDescription"]="Bluetooth"
        ["NSSpeechRecognitionUsageDescription"]="Speech Recognition"
        ["NSMotionUsageDescription"]="Motion"
        ["NSUserTrackingUsageDescription"]="App Tracking (ATT)"
    )

    echo -e "${BLUE}Checking:${NC} $PLIST"
    echo ""
    FOUND_KEYS=0
    for key in "${!USAGE_KEYS[@]}"; do
        friendly="${USAGE_KEYS[$key]}"
        value=$(plutil -extract "$key" raw -o - "$PLIST" 2>/dev/null || echo "")
        if [ -n "$value" ]; then
            ((FOUND_KEYS++))
            len=${#value}
            if echo "$value" | grep -qiE "(example|todo|fill this|placeholder|you should|CHANGEME|REPLACE)"; then
                echo -e "  ${RED}❌ BLOCKER: $friendly — placeholder text${NC}"
                echo "     \"$value\""
                BLOCKER_MSGS+=("$key contains placeholder text"); ((BLOCKERS++))
            elif echo "$value" | grep -qiE '(\$\(PRODUCT_NAME\)|Allow .* to access your|Allow .* to use your|Allow .* to save)'; then
                echo -e "  ${RED}❌ BLOCKER: $friendly — generic template string in built Info.plist${NC}"
                echo "     \"$value\""
                echo "     This is likely injected by a plugin/dependency with default text."
                if [ "$PROJECT_TYPE" = "expo" ]; then
                    echo "     Fix: Update the plugin config in app.json (plugin configs override infoPlist)"
                    echo "     Then run: npx expo prebuild --clean"
                elif [ "$PROJECT_TYPE" = "flutter" ]; then
                    echo "     Fix: Update ios/Runner/Info.plist directly or the plugin generating this"
                else
                    echo "     Fix: Update ios/*/Info.plist directly or the plugin generating this"
                fi
                BLOCKER_MSGS+=("$key has generic template string — likely from plugin default"); ((BLOCKERS++))
            elif echo "$value" | grep -qiE "(with your friends|share.*(friend|contact)|friend.*(share|send))"; then
                echo -e "  ${RED}❌ BLOCKER: $friendly — wrong context (mentions friends/sharing)${NC}"
                echo "     \"$value\""
                echo "     This default text doesn't match your app's actual usage."
                BLOCKER_MSGS+=("$key has wrong-context text (mentions friends/sharing)"); ((BLOCKERS++))
            elif [ $len -lt 20 ]; then
                echo -e "  ${YELLOW}⚠️  $friendly — too short ($len chars)${NC}"
                echo "     \"$value\""
                echo "     ${CYAN}Tip: Include specific usage example${NC}"
                WARNING_MSGS+=("$key too short"); ((WARNINGS++))
            elif echo "$value" | grep -qiE "^(this app needs|we need|required for|access to|needs access|used for|for |to )"; then
                echo -e "  ${YELLOW}⚠️  $friendly — may be too generic${NC}"
                echo "     \"$value\""
                WARNING_MSGS+=("$key too generic"); ((WARNINGS++))
            else
                echo -e "  ${GREEN}✅${NC} $friendly ($len chars)"; ((PASSED++))
            fi
        fi
    done
    [ $FOUND_KEYS -eq 0 ] && echo -e "  ${CYAN}ℹ️${NC}  No privacy permission strings found"
elif [ "$PROJECT_TYPE" = "expo" ] && [ -f "app.json" ]; then
    echo "▸ Checking app.json infoPlist privacy strings"
    for key in NSCameraUsageDescription NSPhotoLibraryUsageDescription NSLocationWhenInUseUsageDescription NSMicrophoneUsageDescription; do
        value=$(grep -oP "\"$key\"\s*:\s*\"\K[^\"]*" app.json 2>/dev/null)
        if [ -n "$value" ]; then
            len=${#value}
            if [ $len -lt 20 ]; then
                echo -e "  ${YELLOW}⚠️  $key — too short ($len chars)${NC}"
                WARNING_MSGS+=("$key too short in app.json"); ((WARNINGS++))
            else
                echo -e "  ${GREEN}✅${NC} $key ($len chars)"; ((PASSED++))
            fi
        fi
    done
fi
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
#    EXPO PLUGIN PERMISSION OVERRIDES — PRE-PREBUILD ONLY (Guideline 5.1.1)
# ═══════════════════════════════════════════════════════════════════════════════
# When ios/ exists, the generated Info.plist is already checked above.
# This section only runs when there's NO prebuild yet, to catch issues early.
if [ "$PROJECT_TYPE" = "expo" ] && [ -f "app.json" ] && [ "$HAS_PREBUILD" != true ]; then
    echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
    echo "┃   EXPO PLUGIN PERMISSION PREVIEW (Guideline 5.1.1)                        ┃"
    echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
    echo ""
    echo -e "  ${CYAN}ℹ️${NC}  No ios/ build found — checking app.json plugin configs as preview"
    echo -e "  ${CYAN}ℹ️${NC}  Plugin configs override infoPlist values at build time"
    echo ""

    PLUGIN_ISSUES=0
    # Check expo-camera plugin permission strings
    CAMERA_PERM=$(grep -oP '"cameraPermission"\s*:\s*"\K[^"]*' app.json 2>/dev/null || echo "")
    if [ -n "$CAMERA_PERM" ]; then
        if echo "$CAMERA_PERM" | grep -qiE '(\$\(PRODUCT_NAME\)|Allow .* to access|Allow .* to use)'; then
            echo -e "  ${RED}❌ BLOCKER: expo-camera cameraPermission is generic${NC}"
            echo "     \"$CAMERA_PERM\""
            echo "     Fix: Use app-specific description, e.g.:"
            echo "     \"This app uses the camera to take photos for reports and QR code scanning.\""
            BLOCKER_MSGS+=("expo-camera cameraPermission is generic — overrides infoPlist"); ((BLOCKERS++)); ((PLUGIN_ISSUES++))
        else
            echo -e "  ${GREEN}✅${NC} expo-camera cameraPermission is descriptive"; ((PASSED++))
        fi
    fi

    MIC_PERM=$(grep -oP '"microphonePermission"\s*:\s*"\K[^"]*' app.json 2>/dev/null || echo "")
    if [ -n "$MIC_PERM" ]; then
        if echo "$MIC_PERM" | grep -qiE '(\$\(PRODUCT_NAME\)|Allow .* to access|Allow .* to use)'; then
            echo -e "  ${RED}❌ BLOCKER: expo-camera microphonePermission is generic${NC}"
            echo "     \"$MIC_PERM\""
            echo "     Fix: Use app-specific description, e.g.:"
            echo "     \"This app uses the microphone to record audio notes for documentation.\""
            BLOCKER_MSGS+=("expo-camera microphonePermission is generic — overrides infoPlist"); ((BLOCKERS++)); ((PLUGIN_ISSUES++))
        else
            echo -e "  ${GREEN}✅${NC} expo-camera microphonePermission is descriptive"; ((PASSED++))
        fi
    fi

    # Check expo-image-picker plugin permission strings
    PHOTOS_PERM=$(grep -oP '"photosPermission"\s*:\s*"\K[^"]*' app.json 2>/dev/null || echo "")
    if [ -n "$PHOTOS_PERM" ]; then
        if echo "$PHOTOS_PERM" | grep -qiE '(\$\(PRODUCT_NAME\)|Allow .* to access|Allow .* to use|share them with your friends|with your friends)'; then
            echo -e "  ${RED}❌ BLOCKER: Plugin photosPermission is generic or wrong context${NC}"
            echo "     \"$PHOTOS_PERM\""
            echo "     Fix: Use app-specific description, e.g.:"
            echo "     \"This app accesses your photo library to attach images to reports.\""
            BLOCKER_MSGS+=("Plugin photosPermission is generic — overrides infoPlist"); ((BLOCKERS++)); ((PLUGIN_ISSUES++))
        else
            echo -e "  ${GREEN}✅${NC} Plugin photosPermission is descriptive"; ((PASSED++))
        fi
    fi

    # Check expo-media-library savePhotosPermission
    SAVE_PHOTOS_PERM=$(grep -oP '"savePhotosPermission"\s*:\s*"\K[^"]*' app.json 2>/dev/null || echo "")
    if [ -n "$SAVE_PHOTOS_PERM" ]; then
        if echo "$SAVE_PHOTOS_PERM" | grep -qiE '(\$\(PRODUCT_NAME\)|Allow .* to save|Allow .* to access)'; then
            echo -e "  ${RED}❌ BLOCKER: expo-media-library savePhotosPermission is generic${NC}"
            echo "     \"$SAVE_PHOTOS_PERM\""
            echo "     Fix: Use app-specific description, e.g.:"
            echo "     \"This app saves captured photos to your library for your records.\""
            BLOCKER_MSGS+=("expo-media-library savePhotosPermission is generic — overrides infoPlist"); ((BLOCKERS++)); ((PLUGIN_ISSUES++))
        else
            echo -e "  ${GREEN}✅${NC} expo-media-library savePhotosPermission is descriptive"; ((PASSED++))
        fi
    fi

    # Check expo-location plugin permission strings
    LOC_ALWAYS_PERM=$(grep -oP '"locationAlwaysAndWhenInUsePermission"\s*:\s*"\K[^"]*' app.json 2>/dev/null || echo "")
    LOC_WHENUSE_PERM=$(grep -oP '"locationWhenInUsePermission"\s*:\s*"\K[^"]*' app.json 2>/dev/null || echo "")
    for LOC_PERM_VAL in "$LOC_ALWAYS_PERM" "$LOC_WHENUSE_PERM"; do
        if [ -n "$LOC_PERM_VAL" ]; then
            if echo "$LOC_PERM_VAL" | grep -qiE '(\$\(PRODUCT_NAME\)|Allow .* to use your location|Allow .* to access)'; then
                echo -e "  ${RED}❌ BLOCKER: expo-location permission string is generic${NC}"
                echo "     \"$LOC_PERM_VAL\""
                echo "     Fix: Use app-specific description, e.g.:"
                echo "     \"This app uses your location to tag reports with where events occur.\""
                BLOCKER_MSGS+=("expo-location permission string is generic — overrides infoPlist"); ((BLOCKERS++)); ((PLUGIN_ISSUES++))
            else
                echo -e "  ${GREEN}✅${NC} expo-location permission string is descriptive"; ((PASSED++))
            fi
        fi
    done

    [ $PLUGIN_ISSUES -eq 0 ] && [ -z "$CAMERA_PERM$MIC_PERM$PHOTOS_PERM$SAVE_PHOTOS_PERM$LOC_ALWAYS_PERM$LOC_WHENUSE_PERM" ] && echo -e "  ${CYAN}ℹ️${NC}  No plugin permission overrides found in app.json"
    echo ""
fi

# ═══════════════════════════════════════════════════════════════════════════════
#       LOCATION PERMISSION CONSISTENCY (Guideline 2.5.4 / 5.1.1)
# ═══════════════════════════════════════════════════════════════════════════════
echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃   LOCATION PERMISSION CONSISTENCY (Guideline 2.5.4 / 5.1.1)              ┃"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
echo ""

USES_BG_LOCATION_CODE=false
USES_FG_LOCATION_CODE=false
if [ -d "$SRC_DIR" ]; then
    grep -rqE "$BG_LOCATION_PATTERN" "$SRC_DIR" 2>/dev/null && USES_BG_LOCATION_CODE=true
    grep -rqE "$FG_LOCATION_PATTERN" "$SRC_DIR" 2>/dev/null && USES_FG_LOCATION_CODE=true
fi

if [ "$USES_FG_LOCATION_CODE" = true ] && [ "$USES_BG_LOCATION_CODE" = false ]; then
    # Foreground-only location — check for unnecessary "Always" permissions
    if [ -n "$PLIST" ]; then
        HAS_ALWAYS=$(plutil -extract NSLocationAlwaysUsageDescription raw -o - "$PLIST" 2>/dev/null || echo "")
        HAS_ALWAYS_AND=$(plutil -extract NSLocationAlwaysAndWhenInUseUsageDescription raw -o - "$PLIST" 2>/dev/null || echo "")
        if [ -n "$HAS_ALWAYS" ] || [ -n "$HAS_ALWAYS_AND" ]; then
            echo -e "  ${RED}❌ BLOCKER: App uses foreground-only location but declares 'Always' location permissions${NC}"
            echo "     Code only uses foreground location APIs (no background location tracking found)"
            echo "     But Info.plist has NSLocationAlwaysUsageDescription or NSLocationAlwaysAndWhenInUseUsageDescription"
            echo "     Fix: Remove NSLocationAlwaysUsageDescription and NSLocationAlwaysAndWhenInUseUsageDescription"
            echo "     Keep only NSLocationWhenInUseUsageDescription"
            BLOCKER_MSGS+=("Foreground-only location but declares Always location permissions"); ((BLOCKERS++))
        else
            echo -e "  ${GREEN}✅${NC} Location permissions match foreground-only usage"; ((PASSED++))
        fi
    elif [ "$PROJECT_TYPE" = "expo" ] && [ -f "app.json" ]; then
        # Check if expo-location uses locationAlwaysAndWhenInUsePermission when only foreground is needed
        if grep -q '"locationAlwaysAndWhenInUsePermission"' app.json 2>/dev/null; then
            echo -e "  ${RED}❌ BLOCKER: App uses foreground-only location but expo-location declares 'Always' permission${NC}"
            echo "     Code only uses foreground location APIs (no background location tracking found)"
            echo "     But app.json has locationAlwaysAndWhenInUsePermission in expo-location plugin"
            echo "     Fix: Change to locationWhenInUsePermission instead:"
            echo "     [\"expo-location\", { \"locationWhenInUsePermission\": \"Your descriptive string here\" }]"
            BLOCKER_MSGS+=("Foreground-only location but expo-location declares Always permission"); ((BLOCKERS++))
        else
            echo -e "  ${GREEN}✅${NC} Location permissions match foreground-only usage"; ((PASSED++))
        fi
        # Check infoPlist for unnecessary Always keys
        if grep -q '"NSLocationAlwaysUsageDescription"' app.json 2>/dev/null || grep -q '"NSLocationAlwaysAndWhenInUseUsageDescription"' app.json 2>/dev/null; then
            echo -e "  ${YELLOW}⚠️  infoPlist has NSLocationAlways* keys but app only uses foreground location${NC}"
            echo "     Fix: Remove NSLocationAlwaysUsageDescription and NSLocationAlwaysAndWhenInUseUsageDescription from infoPlist"
            WARNING_MSGS+=("Unnecessary Always location keys in infoPlist"); ((WARNINGS++))
        fi
    fi
elif [ "$USES_BG_LOCATION_CODE" = true ]; then
    echo -e "  ${GREEN}✅${NC} Background location code found — Always permission is justified"; ((PASSED++))
else
    echo -e "  ${CYAN}ℹ️${NC}  No location code detected — skipping consistency check"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
#                      APP TRANSPORT SECURITY
# ═══════════════════════════════════════════════════════════════════════════════
echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃   APP TRANSPORT SECURITY                                                 ┃"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
echo ""

if [ -n "$PLIST" ]; then
    ATS=$(plutil -extract NSAppTransportSecurity xml1 -o - "$PLIST" 2>/dev/null || echo "")
    if [ -n "$ATS" ] && echo "$ATS" | grep -q "NSAllowsArbitraryLoads.*true"; then
        echo -e "  ${YELLOW}⚠️  NSAllowsArbitraryLoads enabled — disables HTTPS requirement${NC}"
        echo "     May require justification during review"
        WARNING_MSGS+=("NSAllowsArbitraryLoads enabled"); ((WARNINGS++))
    else
        echo -e "  ${GREEN}✅${NC} ATS secure (HTTPS required)"; ((PASSED++))
    fi
else
    echo -e "  ${CYAN}ℹ️${NC}  Skipped — no Info.plist"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
#                      BUILD CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════
echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃   BUILD CONFIGURATION                                                    ┃"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
echo ""

if [ -n "$PLIST" ]; then
    BUNDLE_ID=$(plutil -extract CFBundleIdentifier raw -o - "$PLIST" 2>/dev/null || echo "")
    VERSION=$(plutil -extract CFBundleShortVersionString raw -o - "$PLIST" 2>/dev/null || echo "")
    BUILD=$(plutil -extract CFBundleVersion raw -o - "$PLIST" 2>/dev/null || echo "")
    [ -n "$BUNDLE_ID" ] && echo -e "  Bundle ID: ${CYAN}$BUNDLE_ID${NC}"
    [ -n "$VERSION" ] && echo -e "  Version: ${CYAN}$VERSION${NC} (Build: ${CYAN}$BUILD${NC})"
elif [ "$PROJECT_TYPE" = "expo" ] && [ -f "app.json" ]; then
    IOS_BUNDLE=$(grep -o '"bundleIdentifier"[[:space:]]*:[[:space:]]*"[^"]*"' app.json 2>/dev/null | sed 's/.*: *"//' | sed 's/"//')
    if [ -n "$IOS_BUNDLE" ]; then
        echo -e "  ${GREEN}✅${NC} Bundle ID: ${CYAN}$IOS_BUNDLE${NC}"; ((PASSED++))
    else
        echo -e "  ${RED}❌ BLOCKER: No ios.bundleIdentifier in app.json${NC}"
        BLOCKER_MSGS+=("Missing ios.bundleIdentifier"); ((BLOCKERS++))
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

# Account Deletion (5.1.1(v))
echo "▸ Account Deletion (Guideline 5.1.1(v))"
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
        echo "     iOS requires in-app account deletion (Guideline 5.1.1(v))"
        BLOCKER_MSGS+=("No account deletion found"); ((BLOCKERS++))
    fi
else
    echo -e "  ${CYAN}ℹ️${NC}  No login features detected"
fi
echo ""

# Restore Purchases (3.1.1)
echo "▸ Restore Purchases (Guideline 3.1.1)"
HAS_IAP=false; HAS_RESTORE=false
if [ -f "$PKG_FILE" ]; then
    if [ "$PROJECT_TYPE" = "flutter" ]; then
        grep -qE "in_app_purchase|purchases_flutter|flutter_inapp_purchase|revenue_cat" "$PKG_FILE" 2>/dev/null && HAS_IAP=true
    else
        grep -qE "react-native-iap|expo-in-app-purchases|react-native-purchases|@revenuecat" "$PKG_FILE" 2>/dev/null && HAS_IAP=true
    fi
    [ -d "$SRC_DIR" ] && grep -rqE "restorePurchases|restore.*purchase|restoreTransactions|getPurchaseHistory" "$SRC_DIR" 2>/dev/null && HAS_RESTORE=true
fi
if [ "$HAS_IAP" = true ]; then
    if [ "$HAS_RESTORE" = true ]; then
        echo -e "  ${GREEN}✅${NC} Restore purchases found"; ((PASSED++))
    else
        echo -e "  ${RED}❌ BLOCKER: IAP exists but no restore purchases${NC}"
        echo "     Add visible 'Restore Purchases' button on paywall/settings"
        BLOCKER_MSGS+=("IAP without restore purchases"); ((BLOCKERS++))
    fi
else
    echo -e "  ${CYAN}ℹ️${NC}  No IAP packages detected"
fi
echo ""

# Privacy Policy
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
#              BUSINESS DISTRIBUTION SIGNALS (Guideline 3.2)
# ═══════════════════════════════════════════════════════════════════════════════
echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃   BUSINESS DISTRIBUTION SIGNALS (Guideline 3.2)                           ┃"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
echo ""

B2B_SIGNALS=0
if [ -d "$SRC_DIR" ]; then
    # Check for B2B / enterprise patterns
    grep -rqiE "(enterprise|organization|company|employer|corporate|tenant|workspace).*\b(login|auth|sign.?in|account|register|onboard)\b" "$SRC_DIR" 2>/dev/null && ((B2B_SIGNALS++))
    grep -rqiE "\b(login|auth|sign.?in|account|register|onboard)\b.*(enterprise|organization|company|employer|corporate|tenant|workspace)" "$SRC_DIR" 2>/dev/null && ((B2B_SIGNALS++))
    # No public signup / invite-only patterns
    grep -rqiE "(invite.?only|invitation.?code|org.?code|company.?code|access.?code|no.?public.?sign)" "$SRC_DIR" 2>/dev/null && ((B2B_SIGNALS++))
    # Admin / management portal patterns
    grep -rqiE "(admin.?panel|admin.?dashboard|manage.?users|user.?management|role.?based|rbac)" "$SRC_DIR" 2>/dev/null && ((B2B_SIGNALS++))
fi

if [ $B2B_SIGNALS -ge 2 ]; then
    echo -e "  ${YELLOW}⚠️  App appears to be B2B/enterprise — Apple may flag Guideline 3.2${NC}"
    echo "     Apple may ask: Is this app for general public or internal business use?"
    echo ""
    echo "     ${CYAN}Prepare responses for App Store Connect review notes:${NC}"
    echo "     1. Is the app restricted to one company? (Explain multi-tenant model)"
    echo "     2. What industries/companies does it serve?"
    echo "     3. Are there features for the general public?"
    echo "     4. How do users obtain accounts? (Through employer, self-signup, etc.)"
    echo "     5. What is the payment model? (B2B, individual, freemium, etc.)"
    echo ""
    echo "     ${CYAN}Tip: Add clear explanation in App Review Notes in App Store Connect${NC}"
    WARNING_MSGS+=("B2B/enterprise app — prepare Guideline 3.2 response for Apple"); ((WARNINGS++))
elif [ $B2B_SIGNALS -eq 1 ]; then
    echo -e "  ${CYAN}ℹ️${NC}  Some B2B patterns detected — consider preparing Guideline 3.2 justification"
else
    echo -e "  ${GREEN}✅${NC} No B2B/enterprise-only distribution signals"; ((PASSED++))
fi
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
#                      FLUTTER VERSION CHECK
# ═══════════════════════════════════════════════════════════════════════════════
if [ "$PROJECT_TYPE" = "flutter" ]; then
    echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
    echo "┃   FLUTTER VERSION                                                        ┃"
    echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
    echo ""

    if command -v flutter &> /dev/null; then
        FLUTTER_VER=$(flutter --version 2>/dev/null | head -1 | grep -oP "Flutter \K[0-9]+\.[0-9]+\.[0-9]+")
        if [ -n "$FLUTTER_VER" ]; then
            echo -e "  Version: ${CYAN}$FLUTTER_VER${NC}"
            if [[ "$FLUTTER_VER" == "3.24.3" ]] || [[ "$FLUTTER_VER" == "3.24.4" ]]; then
                echo -e "  ${RED}❌ BLOCKER: Flutter $FLUTTER_VER uses non-public iOS APIs (2.5.1)${NC}"
                echo "     Fix: Upgrade to 3.24.5+"
                BLOCKER_MSGS+=("Flutter $FLUTTER_VER — upgrade to 3.24.5+"); ((BLOCKERS++))
            else
                echo -e "  ${GREEN}✅${NC} Version OK"; ((PASSED++))
            fi
        fi
    else
        echo -e "  ${CYAN}ℹ️${NC}  Flutter CLI not available"
    fi
    echo ""
fi

# ═══════════════════════════════════════════════════════════════════════════════
#                              SUMMARY
# ═══════════════════════════════════════════════════════════════════════════════
echo "╔═══════════════════════════════════════════════════════════════════════════╗"
echo "║                          iOS SUMMARY                                      ║"
echo "╚═══════════════════════════════════════════════════════════════════════════╝"
echo ""

[ ${#BLOCKER_MSGS[@]} -gt 0 ] && echo -e "${RED}❌ BLOCKERS (${#BLOCKER_MSGS[@]}):${NC}" && for m in "${BLOCKER_MSGS[@]}"; do echo "   • $m"; done && echo ""
[ ${#WARNING_MSGS[@]} -gt 0 ] && echo -e "${YELLOW}⚠️  WARNINGS (${#WARNING_MSGS[@]}):${NC}" && for m in "${WARNING_MSGS[@]}"; do echo "   • $m"; done && echo ""
echo -e "${GREEN}✅ PASSED: $PASSED checks${NC}"
echo ""

echo "📋 APP STORE CONNECT MANUAL CHECKLIST:"
echo "   [ ] Screenshots: 6.9\" iPhone (1320×2868) — REQUIRED"
echo "   [ ] Screenshots: 13\" iPad (2064×2752) — if Universal app"
echo "   [ ] App description, keywords, promotional text"
echo "   [ ] Privacy nutrition labels completed"
echo "   [ ] Age rating questionnaire"
echo "   [ ] Review notes + demo credentials (if login required)"
echo "   [ ] Contact info for App Review team"
echo "   [ ] IDFA declaration (if using advertising identifier)"
echo "   [ ] Export compliance (encryption) answered"
echo "   [ ] In-app purchases submitted for review"
echo "   [ ] Guideline 3.2 response ready (if B2B/enterprise app)"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf "  TOTAL:  %2d blockers   %2d warnings   %2d passed\n" "$BLOCKERS" "$WARNINGS" "$PASSED"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ $BLOCKERS -gt 0 ]; then
    echo -e "${RED}🚫 NOT READY — fix $BLOCKERS blocker(s)${NC}"; exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}⚠️  REVIEW $WARNINGS WARNING(S) BEFORE SUBMISSION${NC}"; exit 0
else
    echo -e "${GREEN}✅ AUTOMATED CHECKS PASSED — complete manual checklist${NC}"; exit 0
fi
