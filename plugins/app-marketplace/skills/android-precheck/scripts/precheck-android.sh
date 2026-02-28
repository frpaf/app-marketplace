#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# GOOGLE PLAY STORE PRE-CHECK v4.0 - Flutter, Expo & React Native
# Pre-submission validation for Google Play (Android)
#
# Usage:
#   ./precheck-android.sh              # Terminal output (default)
#   ./precheck-android.sh --json       # JSON output for CI/CD
#   ./precheck-android.sh --json-pretty # JSON output, formatted
# ═══════════════════════════════════════════════════════════════════════════════

# Note: not using set -e — the script handles errors explicitly with if/else blocks

# ─── Globals ─────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'
BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

OUTPUT_MODE="terminal"
[[ "${1:-}" == "--json" ]] && OUTPUT_MODE="json"
[[ "${1:-}" == "--json-pretty" ]] && OUTPUT_MODE="json-pretty"

PROJECT_TYPE=""; PROJECT_NAME=""; PKG_FILE=""; SRC_DIR=""
GRADLE=""; MANIFEST=""

# ─── Structured Issue Tracking ───────────────────────────────────────────────
# Each issue is stored as a delimited string:
#   severity|category|file|match|message|fix
# This enables grouping, filtering, JSON export, and per-category summaries.

declare -a ISSUES=()
declare -a DATA_SAFETY=()
declare -a PASSED_CHECKS=()

# Category counters
declare -A CAT_BLOCKERS CAT_WARNINGS CAT_PASSED
for cat in target-sdk compile-sdk permissions foreground-service network-security \
           build-config signing billing account-deletion data-safety 16kb-alignment \
           build-format expo-config photo-video; do
    CAT_BLOCKERS[$cat]=0; CAT_WARNINGS[$cat]=0; CAT_PASSED[$cat]=0
done

add_issue() {
    local severity="$1" category="$2" file="$3" match="$4" message="$5" fix="${6:-}"
    ISSUES+=("${severity}|${category}|${file}|${match}|${message}|${fix}")
    if [ "$severity" = "BLOCKER" ]; then
        CAT_BLOCKERS[$category]=$(( ${CAT_BLOCKERS[$category]} + 1 ))
    else
        CAT_WARNINGS[$category]=$(( ${CAT_WARNINGS[$category]} + 1 ))
    fi
}

add_pass() {
    local category="$1" message="$2"
    PASSED_CHECKS+=("${category}|${message}")
    CAT_PASSED[$category]=$(( ${CAT_PASSED[$category]} + 1 ))
}

add_data_safety() {
    local sdk="$1" file="$2" match="$3" declares="$4" purpose="$5"
    DATA_SAFETY+=("${sdk}|${file}|${match}|${declares}|${purpose}")
}

# Total counters (computed at summary time)
total_blockers() {
    local n=0
    for i in "${ISSUES[@]}"; do [[ "$i" == BLOCKER* ]] && ((n++)); done
    echo "$n"
}
total_warnings() {
    local n=0
    for i in "${ISSUES[@]}"; do [[ "$i" == WARNING* ]] && ((n++)); done
    echo "$n"
}

# ─── Output helpers ──────────────────────────────────────────────────────────
# In JSON mode, all terminal output is suppressed. Results are collected and
# emitted as JSON at the end.

tprint() {
    [[ "$OUTPUT_MODE" != "terminal" ]] && return 0
    echo -e "$@"
}

tprintf() {
    [[ "$OUTPUT_MODE" != "terminal" ]] && return 0
    printf "$@"
}

print_issue() {
    local severity="$1" file="$2" match="$3" message="$4" fix="$5"
    if [ "$severity" = "BLOCKER" ]; then
        tprint "  ${RED}❌ BLOCKER${NC} ${DIM}[$file]${NC} ${BOLD}$match${NC}"
        tprint "     $message"
    else
        tprint "  ${YELLOW}⚠️  WARNING${NC} ${DIM}[$file]${NC} ${BOLD}$match${NC}"
        tprint "     $message"
    fi
    [ -n "$fix" ] && tprint "     ${CYAN}Fix:${NC} $fix"
}

print_pass() {
    local message="$1"
    tprint "  ${GREEN}✅${NC} $message"
}

# ═══════════════════════════════════════════════════════════════════════════════
#                           HEADER & PROJECT DETECTION
# ═══════════════════════════════════════════════════════════════════════════════

tprint ""
tprint "╔═══════════════════════════════════════════════════════════════════════════╗"
tprint "║               GOOGLE PLAY STORE PRE-CHECK VALIDATOR v4.0                  ║"
tprint "╚═══════════════════════════════════════════════════════════════════════════╝"
tprint ""

if [ -f "pubspec.yaml" ]; then
    PROJECT_TYPE="flutter"; PKG_FILE="pubspec.yaml"; SRC_DIR="lib"
    PROJECT_NAME=$(grep "^name:" pubspec.yaml | sed 's/name: //' | tr -d ' ')
    tprint "${MAGENTA}┌─────────────────────────────────────────────┐${NC}"
    tprint "${MAGENTA}│${NC}  ${BOLD}Flutter Project${NC}: $PROJECT_NAME"
    tprint "${MAGENTA}└─────────────────────────────────────────────┘${NC}"
elif [ -f "app.json" ] && grep -q "expo" app.json 2>/dev/null; then
    PROJECT_TYPE="expo"; PKG_FILE="package.json"; SRC_DIR="src"
    [ ! -d "$SRC_DIR" ] && SRC_DIR="app"; [ ! -d "$SRC_DIR" ] && SRC_DIR="."
    PROJECT_NAME=$(grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' app.json 2>/dev/null | head -1 | sed 's/.*: *"//' | sed 's/"//')
    HAS_PREBUILD=false; [ -d "android" ] && HAS_PREBUILD=true
    tprint "${BLUE}┌─────────────────────────────────────────────┐${NC}"
    tprint "${BLUE}│${NC}  ${BOLD}Expo Project${NC}: $PROJECT_NAME"
    if [ "$HAS_PREBUILD" = true ]; then
        tprint "${BLUE}│${NC}  Prebuild: ${GREEN}✓ android/ exists${NC}"
    else
        tprint "${BLUE}│${NC}  Prebuild: ${YELLOW}✗ Run 'npx expo prebuild --platform android'${NC}"
    fi
    tprint "${BLUE}└─────────────────────────────────────────────┘${NC}"
elif [ -f "package.json" ] && grep -q "react-native" package.json 2>/dev/null; then
    PROJECT_TYPE="react-native"; PKG_FILE="package.json"; SRC_DIR="src"
    [ ! -d "$SRC_DIR" ] && SRC_DIR="app"; [ ! -d "$SRC_DIR" ] && SRC_DIR="."
    PROJECT_NAME=$(grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' package.json | head -1 | sed 's/.*: *"//' | sed 's/"//')
    tprint "${CYAN}┌─────────────────────────────────────────────┐${NC}"
    tprint "${CYAN}│${NC}  ${BOLD}React Native Project${NC}: $PROJECT_NAME"
    tprint "${CYAN}└─────────────────────────────────────────────┘${NC}"
else
    if [ "$OUTPUT_MODE" != "terminal" ]; then
        echo '{"error":"Could not detect project. Run from project root."}'
    else
        echo -e "${RED}❌ Could not detect project. Run from project root.${NC}"
    fi
    exit 1
fi
tprint ""

# ─── Find build files ─────────────────────────────────────────────────────────
[ -f "android/app/build.gradle.kts" ] && GRADLE="android/app/build.gradle.kts"
[ -f "android/app/build.gradle" ] && GRADLE="android/app/build.gradle"
[ -f "android/app/src/main/AndroidManifest.xml" ] && MANIFEST="android/app/src/main/AndroidManifest.xml"

# ═══════════════════════════════════════════════════════════════════════════════
#                          BUILD & CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════
tprint "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
tprint "┃   BUILD & CONFIGURATION                                                  ┃"
tprint "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
tprint ""

if [ -z "$GRADLE" ]; then
    if [ "$PROJECT_TYPE" = "expo" ]; then
        tprint "${YELLOW}⚠️  No android/ directory — run npx expo prebuild --platform android${NC}"
        tprint ""
        ANDROID_PACKAGE=$(grep -o '"package"[[:space:]]*:[[:space:]]*"[^"]*"' app.json 2>/dev/null | head -1 | sed 's/.*: *"//' | sed 's/"//')
        if [ -n "$ANDROID_PACKAGE" ]; then
            print_pass "Package: $ANDROID_PACKAGE"
            add_pass "expo-config" "android.package set: $ANDROID_PACKAGE"
        else
            add_issue "BLOCKER" "expo-config" "app.json" "android.package missing" \
                "No android.package in app.json — required for Play Store" \
                "Add \"package\": \"com.yourcompany.yourapp\" under expo.android in app.json"
            print_issue "BLOCKER" "app.json" "android.package missing" \
                "No android.package in app.json — required for Play Store" \
                "Add \"package\": \"com.yourcompany.yourapp\" under expo.android in app.json"
        fi
    else
        add_issue "WARNING" "build-config" "android/app/build.gradle" "file not found" \
            "No build.gradle found — cannot check build configuration" ""
        print_issue "WARNING" "android/app/build.gradle" "file not found" \
            "No build.gradle found — cannot check build configuration" ""
    fi
else
    tprint "${BLUE}Found:${NC} $GRADLE"
    tprint ""

    # ── Target SDK ──
    tprint "▸ Target SDK Level (must be 35+ since Aug 2025)"
    TARGET_SDK=$(grep -oP "targetSdk\s*[=: ]\s*\K\d+" "$GRADLE" 2>/dev/null | head -1 || true)
    [ -z "$TARGET_SDK" ] && TARGET_SDK=$(grep -oP "targetSdkVersion\s*[=: ]\s*\K\d+" "$GRADLE" 2>/dev/null | head -1 || true)
    COMPILE_SDK=$(grep -oP "compileSdk\s*[=: ]\s*\K\d+" "$GRADLE" 2>/dev/null | head -1 || true)
    [ -z "$COMPILE_SDK" ] && COMPILE_SDK=$(grep -oP "compileSdkVersion\s*[=: ]\s*\K\d+" "$GRADLE" 2>/dev/null | head -1 || true)
    MIN_SDK=$(grep -oP "minSdk\s*[=: ]\s*\K\d+" "$GRADLE" 2>/dev/null | head -1 || true)
    [ -z "$MIN_SDK" ] && MIN_SDK=$(grep -oP "minSdkVersion\s*[=: ]\s*\K\d+" "$GRADLE" 2>/dev/null | head -1 || true)

    if [ -n "$TARGET_SDK" ]; then
        if [ "$TARGET_SDK" -lt 35 ]; then
            add_issue "BLOCKER" "target-sdk" "$GRADLE" "targetSdk $TARGET_SDK" \
                "targetSdk $TARGET_SDK is below the required 35 for new apps and updates (since Aug 2025)" \
                "Update targetSdk to 35 in $GRADLE"
            print_issue "BLOCKER" "$GRADLE" "targetSdk $TARGET_SDK" \
                "targetSdk $TARGET_SDK is below the required 35 for new apps and updates (since Aug 2025)" \
                "Update targetSdk to 35 in $GRADLE"
        else
            add_pass "target-sdk" "targetSdk $TARGET_SDK"
            print_pass "targetSdk $TARGET_SDK"
        fi
    else
        add_issue "WARNING" "target-sdk" "$GRADLE" "targetSdk not found" \
            "Could not determine targetSdk from build.gradle" \
            "Ensure targetSdk is set to 35 in $GRADLE"
        print_issue "WARNING" "$GRADLE" "targetSdk not found" \
            "Could not determine targetSdk from build.gradle" \
            "Ensure targetSdk is set to 35 in $GRADLE"
    fi

    # ── Compile SDK ──
    if [ -n "$COMPILE_SDK" ] && [ -n "$TARGET_SDK" ] && [ "$COMPILE_SDK" -lt "$TARGET_SDK" ]; then
        add_issue "WARNING" "compile-sdk" "$GRADLE" "compileSdk $COMPILE_SDK" \
            "compileSdk $COMPILE_SDK is lower than targetSdk $TARGET_SDK — may cause build failures" \
            "Update compileSdk to $TARGET_SDK or higher in $GRADLE"
        print_issue "WARNING" "$GRADLE" "compileSdk $COMPILE_SDK" \
            "compileSdk $COMPILE_SDK is lower than targetSdk $TARGET_SDK — may cause build failures" \
            "Update compileSdk to $TARGET_SDK or higher in $GRADLE"
    fi
    [ -n "$MIN_SDK" ] && tprint "  minSdk: ${CYAN}$MIN_SDK${NC}"
    tprint ""

    # ── AAB Format ──
    tprint "▸ Build Format (AAB Required)"
    AAB_ISSUE=false
    for ci_file in .github/workflows/*.yml .github/workflows/*.yaml fastlane/Fastfile; do
        if [ -f "$ci_file" ] 2>/dev/null; then
            if grep -qE "flutter build apk|task.*assemble" "$ci_file" 2>/dev/null; then
                if ! grep -qE "flutter build appbundle|task.*bundle" "$ci_file" 2>/dev/null; then
                    # Find the specific offending command
                    APK_CMD=$(grep -oE "flutter build apk[^\"']*|task.*assemble[^\"']*" "$ci_file" 2>/dev/null | head -1)
                    add_issue "BLOCKER" "build-format" "$ci_file" "${APK_CMD:-APK build}" \
                        "Building APK instead of AAB — Google Play requires Android App Bundle (AAB) for new apps" \
                        "Replace with 'flutter build appbundle --release' and use '--aab' in Fastlane"
                    print_issue "BLOCKER" "$ci_file" "${APK_CMD:-APK build}" \
                        "Building APK instead of AAB — Google Play requires AAB for new apps" \
                        "Replace with 'flutter build appbundle --release' and use '--aab' in Fastlane"
                    AAB_ISSUE=true
                fi
            fi
            # Also check for --apk in fastlane supply
            if grep -qE "supply.*--apk|--apk.*supply" "$ci_file" 2>/dev/null; then
                SUPPLY_CMD=$(grep -oE "fastlane supply[^\"'\n]*--apk[^\"'\n]*|--apk[^\"'\n]*" "$ci_file" 2>/dev/null | head -1)
                add_issue "BLOCKER" "build-format" "$ci_file" "${SUPPLY_CMD:-fastlane --apk}" \
                    "Fastlane configured to upload APK instead of AAB" \
                    "Replace '--apk ...app-release.apk' with '--aab ...app-release.aab'"
                print_issue "BLOCKER" "$ci_file" "${SUPPLY_CMD:-fastlane --apk}" \
                    "Fastlane configured to upload APK instead of AAB" \
                    "Replace '--apk ...app-release.apk' with '--aab ...app-release.aab'"
                AAB_ISSUE=true
            fi
        fi
    done
    if [ "$AAB_ISSUE" = false ]; then
        add_pass "build-format" "No APK-only builds detected"
        print_pass "No APK-only builds detected"
    fi
    tprint ""

    # ── Signing ──
    tprint "▸ Release Signing Configuration"
    if grep -q "signingConfigs" "$GRADLE" 2>/dev/null; then
        add_pass "signing" "signingConfigs found"
        print_pass "signingConfigs found"
    else
        add_issue "WARNING" "signing" "$GRADLE" "signingConfigs missing" \
            "No signingConfigs block found — release builds may not be signed correctly" \
            "Add signingConfigs.release with keyAlias, keyPassword, storeFile, storePassword"
        print_issue "WARNING" "$GRADLE" "signingConfigs missing" \
            "No signingConfigs block found — release builds may not be signed correctly" \
            "Add signingConfigs.release with keyAlias, keyPassword, storeFile, storePassword"
    fi
    if [ -f "android/key.properties" ]; then
        if [ -f ".gitignore" ] && grep -q "key.properties" .gitignore 2>/dev/null; then
            add_pass "signing" "key.properties in .gitignore"
            print_pass "key.properties in .gitignore"
        else
            add_issue "WARNING" "signing" ".gitignore" "key.properties not listed" \
                "key.properties is not in .gitignore — keystore passwords would be exposed in source control" \
                "Add 'key.properties' and '*.jks' to .gitignore"
            print_issue "WARNING" ".gitignore" "key.properties not listed" \
                "key.properties is not in .gitignore — keystore passwords exposed" \
                "Add 'key.properties' and '*.jks' to .gitignore"
        fi
    fi
    tprint ""

    # ── R8/ProGuard ──
    tprint "▸ Code Shrinking (R8/ProGuard)"
    if grep -qE "minifyEnabled\s*[=: ]\s*true" "$GRADLE" 2>/dev/null; then
        add_pass "build-config" "minifyEnabled true"
        print_pass "minifyEnabled true"
        if grep -qE "shrinkResources\s*[=: ]\s*true" "$GRADLE" 2>/dev/null; then
            add_pass "build-config" "shrinkResources true"
            print_pass "shrinkResources true"
        else
            add_issue "WARNING" "build-config" "$GRADLE" "shrinkResources false" \
                "Resource shrinking disabled for release — unused resources included in bundle" \
                "Set shrinkResources true in release buildType"
            print_issue "WARNING" "$GRADLE" "shrinkResources false" \
                "Resource shrinking disabled" \
                "Set shrinkResources true in release buildType"
        fi
    else
        add_issue "WARNING" "build-config" "$GRADLE" "minifyEnabled false" \
            "R8 code shrinking disabled for release — larger APK/AAB size" \
            "Set minifyEnabled true in release buildType"
        print_issue "WARNING" "$GRADLE" "minifyEnabled false" \
            "R8 code shrinking disabled for release — larger APK/AAB size" \
            "Set minifyEnabled true in release buildType"
    fi
    tprint ""

    # ── Version Info ──
    tprint "▸ App Version Info"
    APP_ID=$(grep -oP "(applicationId|namespace)\s*[=: ]\s*[\"']\K[^\"']+" "$GRADLE" 2>/dev/null | head -1 || true)
    VERSION_NAME=$(grep -oP "versionName\s*[=: ]\s*[\"']\K[^\"']+" "$GRADLE" 2>/dev/null | head -1 || true)
    VERSION_CODE=$(grep -oP "versionCode\s*[=: ]\s*\K\d+" "$GRADLE" 2>/dev/null | head -1 || true)
    [ -n "$APP_ID" ] && tprint "  Application ID: ${CYAN}$APP_ID${NC}"
    [ -n "$VERSION_NAME" ] && tprint "  Version: ${CYAN}$VERSION_NAME${NC} (${CYAN}$VERSION_CODE${NC})"
    tprint ""
fi

# ═══════════════════════════════════════════════════════════════════════════════
#                     16 KB MEMORY PAGE SIZE (Android 15+)
# ═══════════════════════════════════════════════════════════════════════════════
tprint "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
tprint "┃   16 KB MEMORY PAGE SIZE (required since Nov 2025)                        ┃"
tprint "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
tprint ""

# ── Check 1: gradle.properties config ──
tprint "▸ gradle.properties — android.config.pageSize"
GRADLE_PROPS="android/gradle.properties"
if [ -d "android" ]; then
    if [ -f "$GRADLE_PROPS" ]; then
        if grep -qE "android\.config\.pageSize\s*=\s*16384" "$GRADLE_PROPS" 2>/dev/null; then
            add_pass "16kb-alignment" "android.config.pageSize=16384 set"
            print_pass "android.config.pageSize=16384 set"
        else
            add_issue "BLOCKER" "16kb-alignment" "$GRADLE_PROPS" "android.config.pageSize=16384 missing" \
                "Missing 16 KB page size configuration — required for Android 15+ devices since Nov 2025" \
                "Add android.config.pageSize=16384 to $GRADLE_PROPS"
            print_issue "BLOCKER" "$GRADLE_PROPS" "android.config.pageSize=16384 missing" \
                "Missing 16 KB page size configuration — required for Android 15+" \
                "Add android.config.pageSize=16384 to $GRADLE_PROPS"
        fi
    else
        add_issue "BLOCKER" "16kb-alignment" "$GRADLE_PROPS" "file not found" \
            "gradle.properties file missing — cannot set 16 KB page size configuration" \
            "Create $GRADLE_PROPS with android.config.pageSize=16384"
        print_issue "BLOCKER" "$GRADLE_PROPS" "file not found" \
            "gradle.properties file missing — cannot set 16 KB page size" \
            "Create $GRADLE_PROPS with android.config.pageSize=16384"
    fi
else
    case "$PROJECT_TYPE" in
        expo)         tprint "  ${YELLOW}⚠️  No android/ — run ${CYAN}npx expo prebuild --platform android${NC}${YELLOW}, then add pageSize=16384${NC}" ;;
        react-native) tprint "  ${YELLOW}⚠️  No android/ — generate it, then add android.config.pageSize=16384${NC}" ;;
        flutter)      tprint "  ${YELLOW}⚠️  No android/ — run ${CYAN}flutter create . --platforms android${NC}${YELLOW}, then add pageSize=16384${NC}" ;;
    esac
    add_issue "WARNING" "16kb-alignment" "$GRADLE_PROPS" "no android/ directory" \
        "No android/ directory — add android.config.pageSize=16384 after generating native files" ""
fi
tprint ""

# ── Check 2: Native .so alignment via readelf with package tracing ──
tprint "▸ Native Library (.so) Page Alignment"

SO_FILES=()
for so_dir in android .gradle build .dart_tool node_modules; do
    [ -d "$so_dir" ] || continue
    while IFS= read -r f; do SO_FILES+=("$f"); done < <(find "$so_dir" -name "*.so" -type f 2>/dev/null)
done

# ── Helper: trace .so file path back to owning package ──
trace_package() {
    local so_path="$1"

    # node_modules/@scope/package/... → @scope/package
    if [[ "$so_path" == node_modules/@* ]]; then
        echo "$so_path" | sed -E 's|^node_modules/(@[^/]+/[^/]+)/.*|\1|'
        return
    fi
    # node_modules/package/... → package
    if [[ "$so_path" == node_modules/* ]]; then
        echo "$so_path" | sed -E 's|^node_modules/([^/]+)/.*|\1|'
        return
    fi
    # android/.gradle/transforms/.../com.example/... or build/...
    # Try to extract from path segments
    if [[ "$so_path" == *"/.gradle/"* ]] || [[ "$so_path" == *"/build/"* ]]; then
        # Look for recognizable lib names
        local libname
        libname=$(basename "$so_path" .so | sed 's/^lib//')
        echo "$libname (native)"
        return
    fi
    # .dart_tool/flutter_build/.../lib*.so
    if [[ "$so_path" == *".dart_tool"* ]]; then
        local libname
        libname=$(basename "$so_path" .so | sed 's/^lib//')
        echo "$libname (flutter)"
        return
    fi
    # Fallback: just the filename
    basename "$so_path"
}

if [ ${#SO_FILES[@]} -eq 0 ]; then
    add_pass "16kb-alignment" "No native .so libraries found"
    print_pass "No native .so libraries found"
else
    tprint "  ${CYAN}ℹ️${NC}  ${#SO_FILES[@]} native .so file(s) found"

    READELF=""
    command -v readelf &>/dev/null && READELF="readelf"
    [ -z "$READELF" ] && command -v greadelf &>/dev/null && READELF="greadelf"

    if [ -z "$READELF" ]; then
        add_issue "WARNING" "16kb-alignment" "system" "readelf not available" \
            "readelf not available — install binutils to verify .so alignment" \
            "macOS: brew install binutils | Linux: sudo apt install binutils"
        print_issue "WARNING" "system" "readelf not available" \
            "Cannot verify .so alignment without readelf" \
            "macOS: brew install binutils | Linux: sudo apt install binutils"
    else
        # Collect results grouped by package
        declare -A PKG_STATUS   # package -> "pass" or "fail"
        declare -A PKG_DETAILS  # package -> "file1 (align)|file2 (align)|..."
        CHECKED=0
        MAX_CHECK=500

        for so_file in "${SO_FILES[@]}"; do
            [ $CHECKED -ge $MAX_CHECK ] && tprint "  ${CYAN}ℹ️${NC}  Checked $MAX_CHECK of ${#SO_FILES[@]} — run readelf manually for the rest" && break
            LOAD_ALIGN=$($READELF -l "$so_file" 2>/dev/null | grep -m1 "LOAD" | awk '{print $NF}')
            PKG_NAME=$(trace_package "$so_file")
            SO_BASENAME=$(basename "$so_file")

            if [ -n "$LOAD_ALIGN" ]; then
                ALIGN_DEC=$((LOAD_ALIGN)) 2>/dev/null || ALIGN_DEC=0
                if [ "$ALIGN_DEC" -lt 16384 ]; then
                    PKG_STATUS["$PKG_NAME"]="fail"
                    PKG_DETAILS["$PKG_NAME"]+="$SO_BASENAME ($LOAD_ALIGN)|"
                else
                    # Only set pass if not already failed
                    [ "${PKG_STATUS[$PKG_NAME]:-}" != "fail" ] && PKG_STATUS["$PKG_NAME"]="pass"
                    PKG_DETAILS["$PKG_NAME"]+="$SO_BASENAME ($LOAD_ALIGN)|"
                fi
            fi
            ((CHECKED++))
        done

        # Count failures
        FAIL_COUNT=0
        for pkg in "${!PKG_STATUS[@]}"; do
            [ "${PKG_STATUS[$pkg]}" = "fail" ] && ((FAIL_COUNT++))
        done

        if [ "$FAIL_COUNT" -gt 0 ]; then
            tprint ""
            tprint "  ${RED}❌ BLOCKER: $FAIL_COUNT package(s) with misaligned .so files${NC}"
            tprint "  ┌──────────────────────────────────────────────────────────────────┐"
            for pkg in $(echo "${!PKG_STATUS[@]}" | tr ' ' '\n' | sort); do
                if [ "${PKG_STATUS[$pkg]}" = "fail" ]; then
                    tprint "  │  ${RED}✗${NC} ${BOLD}$pkg${NC}"
                    IFS='|' read -ra FILES <<< "${PKG_DETAILS[$pkg]}"
                    for detail in "${FILES[@]}"; do
                        [ -n "$detail" ] && tprint "  │      $detail"
                    done
                fi
            done
            tprint "  └──────────────────────────────────────────────────────────────────┘"
            tprint ""
            tprint "  All packages with native libraries:"
            for pkg in $(echo "${!PKG_STATUS[@]}" | tr ' ' '\n' | sort); do
                if [ "${PKG_STATUS[$pkg]}" = "fail" ]; then
                    tprint "     ${RED}✗${NC} $pkg"
                else
                    tprint "     ${GREEN}✓${NC} $pkg"
                fi
            done

            # Build a summary of failed packages for the issue message
            FAIL_PKGS=""
            for pkg in "${!PKG_STATUS[@]}"; do
                [ "${PKG_STATUS[$pkg]}" = "fail" ] && FAIL_PKGS+="$pkg, "
            done
            FAIL_PKGS="${FAIL_PKGS%, }"

            add_issue "BLOCKER" "16kb-alignment" "native .so files" "$FAIL_PKGS" \
                "$FAIL_COUNT package(s) with native .so files not aligned to 16 KB" \
                "Update the owning packages, rebuild. For libs you own: recompile with -Wl,-z,max-page-size=16384"
        else
            add_pass "16kb-alignment" "All $CHECKED checked .so files have 16 KB page alignment"
            print_pass "All $CHECKED checked .so files have 16 KB page alignment"
        fi
    fi
fi

# ── Check 3: Known native packages from dependencies (no build needed) ──
tprint ""
tprint "▸ Known Native Packages (dependency scan)"
NATIVE_PKGS_FOUND=false
check_native_pkg() {
    local name="$1" pattern="$2"
    if grep -rqiE "$pattern" "$PKG_FILE" ${GRADLE:+"$GRADLE"} 2>/dev/null; then
        tprint "  ${CYAN}ℹ️${NC}  ${BOLD}$name${NC} — contains native .so libraries (verify 16 KB alignment after build)"
        NATIVE_PKGS_FOUND=true
    fi
}
check_native_pkg "camera" "camera:|\"react-native-camera\"|\"expo-camera\""
check_native_pkg "video_player" "video_player:|\"react-native-video\"|\"expo-av\""
check_native_pkg "webview" "webview_flutter:|\"react-native-webview\""
check_native_pkg "maps" "google_maps_flutter:|\"react-native-maps\""
check_native_pkg "reanimated" "\"react-native-reanimated\""
check_native_pkg "hermes" "\"hermes-engine\"|hermesEnabled"
check_native_pkg "fast-image" "\"react-native-fast-image\"|cached_network_image:"
[ "$NATIVE_PKGS_FOUND" = false ] && print_pass "No known native packages detected"
tprint ""

# ═══════════════════════════════════════════════════════════════════════════════
#                        PERMISSIONS AUDIT
# ═══════════════════════════════════════════════════════════════════════════════
if [ -n "$MANIFEST" ]; then
    tprint "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
    tprint "┃   PERMISSIONS AUDIT (AndroidManifest.xml)                                ┃"
    tprint "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
    tprint ""

    # ── Restricted Permissions ──
    tprint "▸ Restricted Permissions (require Declaration Form)"
    RESTRICTED_FOUND=false
    for perm in READ_SMS SEND_SMS RECEIVE_SMS READ_CALL_LOG WRITE_CALL_LOG; do
        if grep -q "android.permission.$perm" "$MANIFEST" 2>/dev/null; then
            add_issue "BLOCKER" "permissions" "$MANIFEST" "android.permission.$perm" \
                "$perm is restricted — only allowed for default handler apps" \
                "Remove unless app is the default handler; submit Permissions Declaration Form if required"
            print_issue "BLOCKER" "$MANIFEST" "android.permission.$perm" \
                "$perm is restricted — only allowed for default handler apps" \
                "Remove unless app is the default handler"
            RESTRICTED_FOUND=true
        fi
    done
    if grep -q "android.permission.ACCESS_BACKGROUND_LOCATION" "$MANIFEST" 2>/dev/null; then
        add_issue "BLOCKER" "permissions" "$MANIFEST" "android.permission.ACCESS_BACKGROUND_LOCATION" \
            "ACCESS_BACKGROUND_LOCATION requires Permissions Declaration Form approval before publishing" \
            "Remove and use foreground service with location type, or submit Permissions Declaration Form"
        print_issue "BLOCKER" "$MANIFEST" "android.permission.ACCESS_BACKGROUND_LOCATION" \
            "Requires Permissions Declaration Form approval before publishing" \
            "Remove and use foreground service with location type, or submit declaration form"
        RESTRICTED_FOUND=true
    fi
    if grep -q "android.permission.MANAGE_EXTERNAL_STORAGE" "$MANIFEST" 2>/dev/null; then
        add_issue "BLOCKER" "permissions" "$MANIFEST" "android.permission.MANAGE_EXTERNAL_STORAGE" \
            "MANAGE_EXTERNAL_STORAGE requires All Files Access review before publishing" \
            "Remove and use Scoped Storage, MediaStore, or Storage Access Framework (SAF) instead"
        print_issue "BLOCKER" "$MANIFEST" "android.permission.MANAGE_EXTERNAL_STORAGE" \
            "Requires All Files Access review before publishing" \
            "Use Scoped Storage, MediaStore, or SAF instead"
        RESTRICTED_FOUND=true
    fi
    if grep -q "android.permission.REQUEST_INSTALL_PACKAGES" "$MANIFEST" 2>/dev/null; then
        add_issue "BLOCKER" "permissions" "$MANIFEST" "android.permission.REQUEST_INSTALL_PACKAGES" \
            "REQUEST_INSTALL_PACKAGES allows sideloading APKs — highly scrutinized by Google Play review" \
            "Remove unless app is a legitimate app store or package installer"
        print_issue "BLOCKER" "$MANIFEST" "android.permission.REQUEST_INSTALL_PACKAGES" \
            "Allows sideloading APKs — highly scrutinized by Play review" \
            "Remove unless app is a legitimate app store or package installer"
        RESTRICTED_FOUND=true
    fi
    if [ "$RESTRICTED_FOUND" = false ]; then
        add_pass "permissions" "No restricted permissions"
        print_pass "No restricted permissions"
    fi
    tprint ""

    # ── Dangerous Permissions ──
    tprint "▸ Dangerous Permissions"
    DANGEROUS_FOUND=false
    if grep -q "android.permission.ACCESS_FINE_LOCATION" "$MANIFEST" 2>/dev/null; then
        add_issue "WARNING" "permissions" "$MANIFEST" "android.permission.ACCESS_FINE_LOCATION" \
            "ACCESS_FINE_LOCATION declared — consider if ACCESS_COARSE_LOCATION is sufficient" \
            "Replace with ACCESS_COARSE_LOCATION if precise location is not required"
        print_issue "WARNING" "$MANIFEST" "android.permission.ACCESS_FINE_LOCATION" \
            "Consider if ACCESS_COARSE_LOCATION is sufficient" \
            "Replace with ACCESS_COARSE_LOCATION if precise location is not required"
        DANGEROUS_FOUND=true
    fi
    if grep -q "android.permission.QUERY_ALL_PACKAGES" "$MANIFEST" 2>/dev/null; then
        add_issue "WARNING" "permissions" "$MANIFEST" "android.permission.QUERY_ALL_PACKAGES" \
            "QUERY_ALL_PACKAGES — must justify visibility into installed apps" \
            "Remove unless required; use targeted <queries> in manifest instead"
        print_issue "WARNING" "$MANIFEST" "android.permission.QUERY_ALL_PACKAGES" \
            "Must justify visibility into installed apps" \
            "Remove unless required; use targeted <queries> in manifest instead"
        DANGEROUS_FOUND=true
    fi
    if grep -q "android.permission.SYSTEM_ALERT_WINDOW" "$MANIFEST" 2>/dev/null; then
        add_issue "WARNING" "permissions" "$MANIFEST" "android.permission.SYSTEM_ALERT_WINDOW" \
            "SYSTEM_ALERT_WINDOW — draw over other apps needs justification" \
            "Remove unless essential to core app functionality"
        print_issue "WARNING" "$MANIFEST" "android.permission.SYSTEM_ALERT_WINDOW" \
            "Draw over other apps needs justification" \
            "Remove unless essential to core app functionality"
        DANGEROUS_FOUND=true
    fi
    if [ "$DANGEROUS_FOUND" = false ]; then
        add_pass "permissions" "No dangerous permission concerns"
        print_pass "No dangerous permission concerns"
    fi
    tprint ""

    # ── Photo & Video Permissions ──
    tprint "▸ Photo & Video Permissions"
    PHOTO_VIDEO_FOUND=false
    for perm in READ_MEDIA_IMAGES READ_MEDIA_VIDEO READ_MEDIA_VISUAL_USER_SELECTED; do
        if grep -q "android.permission.$perm" "$MANIFEST" 2>/dev/null; then
            add_issue "BLOCKER" "photo-video" "$MANIFEST" "android.permission.$perm" \
                "$perm requires Photo & Video Permissions declaration in Play Console — rejected unless core photo/video app" \
                "Remove and use Android Photo Picker (no permission needed), or complete declaration in Play Console → App content"
            print_issue "BLOCKER" "$MANIFEST" "android.permission.$perm" \
                "Requires Photo & Video Permissions declaration — rejected unless core photo/video app" \
                "Remove and use Android Photo Picker, or complete declaration in Play Console → App content"
            PHOTO_VIDEO_FOUND=true
        fi
    done
    if [ "$PHOTO_VIDEO_FOUND" = true ]; then
        tprint ""
        case "$PROJECT_TYPE" in
            flutter)       tprint "     Use image_picker v1.0.7+ which defaults to Android Photo Picker" ;;
            expo)          tprint "     Use expo-image-picker v15+ which defaults to Photo Picker" ;;
            react-native)  tprint "     Use react-native-image-picker v7+ which supports Photo Picker" ;;
        esac
        tprint "     Only keep these permissions if your app IS a gallery, photo editor, or file manager"
    else
        add_pass "photo-video" "No photo/video permission concerns"
        print_pass "No photo/video permission concerns"
    fi
    tprint ""

    # ── Legacy Storage ──
    tprint "▸ Legacy Storage Permissions"
    STORAGE_ISSUE=false
    for perm in READ_EXTERNAL_STORAGE WRITE_EXTERNAL_STORAGE; do
        if grep -q "android.permission.$perm" "$MANIFEST" 2>/dev/null; then
            if grep -q "android.permission.$perm.*maxSdkVersion" "$MANIFEST" 2>/dev/null; then
                add_pass "permissions" "$perm has maxSdkVersion"
                print_pass "$perm has maxSdkVersion"
            else
                local_fix="Add android:maxSdkVersion=\"32\""
                [ "$perm" = "WRITE_EXTERNAL_STORAGE" ] && local_fix="Add android:maxSdkVersion=\"29\""
                add_issue "BLOCKER" "permissions" "$MANIFEST" "android.permission.$perm" \
                    "$perm without maxSdkVersion is blocked on API 35" \
                    "$local_fix or migrate to Scoped Storage / MediaStore / SAF"
                print_issue "BLOCKER" "$MANIFEST" "android.permission.$perm" \
                    "$perm without maxSdkVersion is blocked on API 35" \
                    "$local_fix or migrate to Scoped Storage / MediaStore / SAF"
                STORAGE_ISSUE=true
            fi
        fi
    done
    if [ "$STORAGE_ISSUE" = false ] && ! grep -q "EXTERNAL_STORAGE" "$MANIFEST" 2>/dev/null; then
        add_pass "permissions" "No legacy storage permissions"
        print_pass "No legacy storage permissions"
    fi
    tprint ""
fi

# ── Photo & Video: Flutter pre-build check (no android/ directory) ──
if [ "$PROJECT_TYPE" = "flutter" ] && [ -z "$MANIFEST" ]; then
    tprint "▸ Photo & Video Permissions (pubspec.yaml scan)"
    PHOTO_VIDEO_FOUND=false
    for pkg in image_picker photo_manager file_picker wechat_assets_picker; do
        if grep -q "$pkg" pubspec.yaml 2>/dev/null; then
            add_issue "BLOCKER" "photo-video" "pubspec.yaml" "$pkg" \
                "$pkg adds READ_MEDIA_* permissions at build time — requires Photo & Video Permissions declaration in Play Console" \
                "Complete Photo & Video Permissions declaration in Play Console → App content, or use Photo Picker"
            print_issue "BLOCKER" "pubspec.yaml" "$pkg" \
                "Adds READ_MEDIA_* permissions at build time — requires declaration in Play Console" \
                "Complete Photo & Video Permissions declaration in Play Console → App content"
            PHOTO_VIDEO_FOUND=true
        fi
    done
    if [ "$PHOTO_VIDEO_FOUND" = true ]; then
        tprint "     Use image_picker v1.0.7+ which defaults to Android Photo Picker (no permission needed)"
        tprint "     After prebuild, verify AndroidManifest.xml does NOT contain READ_MEDIA_IMAGES/VIDEO"
        tprint "     Only keep these permissions if your app IS a gallery, photo editor, or file manager"
    else
        add_pass "photo-video" "No photo/video packages detected"
        print_pass "No photo/video packages detected"
    fi
    tprint ""
fi

# ── Photo & Video: Expo pre-prebuild check (no android/ directory) ──
if [ "$PROJECT_TYPE" = "expo" ] && [ -z "$MANIFEST" ]; then
    tprint "▸ Photo & Video Permissions (app.json + package.json scan)"
    PHOTO_VIDEO_FOUND=false
    for pkg in expo-media-library expo-image-picker; do
        if grep -qE "$pkg" app.json ${PKG_FILE:+"$PKG_FILE"} 2>/dev/null; then
            # Determine source file
            local_file="app.json"
            grep -q "$pkg" "$PKG_FILE" 2>/dev/null && local_file="$PKG_FILE"
            add_issue "BLOCKER" "photo-video" "$local_file" "$pkg" \
                "$pkg adds READ_MEDIA_* permissions — requires Photo & Video Permissions declaration in Play Console" \
                "Complete Photo & Video Permissions declaration in Play Console → App content"
            print_issue "BLOCKER" "$local_file" "$pkg" \
                "Adds READ_MEDIA_* permissions — requires declaration in Play Console" \
                "Complete Photo & Video Permissions declaration in Play Console → App content"
            PHOTO_VIDEO_FOUND=true
        fi
    done
    if [ "$PHOTO_VIDEO_FOUND" = true ]; then
        tprint "     Use expo-image-picker v15+ which defaults to Photo Picker (no permission needed)"
        tprint "     Remove READ_MEDIA_* from app.json android.permissions if present"
        tprint "     Only keep these permissions if your app IS a gallery, photo editor, or file manager"
    else
        add_pass "photo-video" "No photo/video plugins detected"
        print_pass "No photo/video plugins detected"
    fi
    tprint ""
fi

# ═══════════════════════════════════════════════════════════════════════════════
#                         FOREGROUND SERVICES
# ═══════════════════════════════════════════════════════════════════════════════
# FIX: Multi-line XML parsing — join service blocks before checking for
# foregroundServiceType. Previous version read line-by-line and missed
# attributes on subsequent lines.

if [ -n "$MANIFEST" ] && grep -q "<service" "$MANIFEST" 2>/dev/null; then
    tprint "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
    tprint "┃   FOREGROUND SERVICES                                                    ┃"
    tprint "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
    tprint ""
    tprint "▸ Foreground Service Type (required since API 34)"

    # Collapse multi-line XML into single-line service blocks
    # This handles <service\n  android:name="..."\n  android:foregroundServiceType="..."\n/>
    MANIFEST_FLAT=$(tr '\n' ' ' < "$MANIFEST" | sed 's/> */>\n/g')

    while IFS= read -r line; do
        [[ "$line" != *"<service"* ]] && continue
        svc_name=$(echo "$line" | grep -oP 'android:name="\K[^"]+' || echo "unknown")
        if echo "$line" | grep -q "foregroundServiceType"; then
            svc_type=$(echo "$line" | grep -oP 'android:foregroundServiceType="\K[^"]+' || echo "")
            add_pass "foreground-service" "$svc_name has foregroundServiceType=\"$svc_type\""
            print_pass "$svc_name — foregroundServiceType=\"$svc_type\""
        else
            add_issue "BLOCKER" "foreground-service" "$MANIFEST" "$svc_name" \
                "Service missing android:foregroundServiceType — required since API 34, causes crash on Android 14+" \
                "Add android:foregroundServiceType (e.g. location, dataSync, camera) and matching FOREGROUND_SERVICE_* permission"
            print_issue "BLOCKER" "$MANIFEST" "$svc_name" \
                "Missing foregroundServiceType — crashes on Android 14+" \
                "Add android:foregroundServiceType and matching FOREGROUND_SERVICE_* permission"
        fi
    done <<< "$MANIFEST_FLAT"
    tprint ""
fi

# ═══════════════════════════════════════════════════════════════════════════════
#                         NETWORK SECURITY
# ═══════════════════════════════════════════════════════════════════════════════
if [ -n "$MANIFEST" ]; then
    tprint "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
    tprint "┃   NETWORK SECURITY                                                       ┃"
    tprint "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
    tprint ""
    tprint "▸ Cleartext Traffic & HTTPS Enforcement"

    if grep -q 'usesCleartextTraffic="true"' "$MANIFEST" 2>/dev/null; then
        add_issue "WARNING" "network-security" "$MANIFEST" "usesCleartextTraffic=\"true\"" \
            "Cleartext traffic enabled — Data Safety mismatch risk if encryption in transit is declared" \
            "Set android:usesCleartextTraffic=\"false\" and use HTTPS for all connections"
        print_issue "WARNING" "$MANIFEST" "usesCleartextTraffic=\"true\"" \
            "Cleartext traffic enabled — Data Safety mismatch risk" \
            "Set android:usesCleartextTraffic=\"false\" and use HTTPS"
    else
        add_pass "network-security" "Cleartext traffic not enabled"
        print_pass "Cleartext traffic not enabled"
    fi

    NET_SEC="android/app/src/main/res/xml/network_security_config.xml"
    if [ -f "$NET_SEC" ]; then
        if grep -q '<base-config.*cleartextTrafficPermitted="true"' "$NET_SEC" 2>/dev/null; then
            add_issue "WARNING" "network-security" "$NET_SEC" "cleartextTrafficPermitted=\"true\"" \
                "Cleartext traffic permitted in network security config — Data Safety mismatch risk" \
                "Set cleartextTrafficPermitted=\"false\" in base-config"
            print_issue "WARNING" "$NET_SEC" "cleartextTrafficPermitted=\"true\"" \
                "Cleartext traffic permitted in network security config" \
                "Set cleartextTrafficPermitted=\"false\" in base-config"
        else
            add_pass "network-security" "network_security_config blocks cleartext"
            print_pass "network_security_config blocks cleartext"
        fi
    else
        tprint "  ${CYAN}ℹ️${NC}  No network_security_config.xml (optional but recommended)"
    fi
    tprint ""
fi

# ═══════════════════════════════════════════════════════════════════════════════
#                         IN-APP PURCHASES
# ═══════════════════════════════════════════════════════════════════════════════
tprint "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
tprint "┃   IN-APP PURCHASES                                                       ┃"
tprint "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
tprint ""
tprint "▸ Play Billing Library (must be v7+)"

if [ -n "$GRADLE" ]; then
    BILLING_VER=$(grep -oP "com.android.billingclient:billing:\K[0-9.]+" "$GRADLE" 2>/dev/null | head -1 || true)
    if [ -n "$BILLING_VER" ]; then
        BILLING_MAJOR=$(echo "$BILLING_VER" | cut -d. -f1)
        if [ "$BILLING_MAJOR" -lt 7 ]; then
            add_issue "BLOCKER" "billing" "$GRADLE" "billing:$BILLING_VER" \
                "Play Billing Library v$BILLING_VER is below the required v7+ (enforced since Aug 2025)" \
                "Update to com.android.billingclient:billing:7.x.x or latest"
            print_issue "BLOCKER" "$GRADLE" "billing:$BILLING_VER" \
                "Play Billing Library v$BILLING_VER is below required v7+" \
                "Update to com.android.billingclient:billing:7.x.x or latest"
        else
            add_pass "billing" "Billing Library v$BILLING_VER"
            print_pass "Billing Library v$BILLING_VER"
        fi
    else
        tprint "  ${CYAN}ℹ️${NC}  No billing library detected"
    fi
fi
tprint ""

# ═══════════════════════════════════════════════════════════════════════════════
#                        ACCOUNT & PRIVACY
# ═══════════════════════════════════════════════════════════════════════════════
tprint "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
tprint "┃   ACCOUNT & PRIVACY                                                      ┃"
tprint "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
tprint ""

tprint "▸ Account Deletion (Google Play Policy)"
HAS_LOGIN=false; HAS_DELETE=false; LOGIN_FILE=""; LOGIN_MATCH=""
if [ -d "$SRC_DIR" ]; then
    LOGIN_FILE=$(grep -rlE "signIn|login|authenticate|FirebaseAuth|createUser|signUp|register|supabase.*auth|Auth0|useAuth|AuthContext|signInWithCredential|signInAnonymously" "$SRC_DIR" 2>/dev/null | head -1)
    if [ -n "$LOGIN_FILE" ]; then
        HAS_LOGIN=true
        LOGIN_MATCH=$(grep -oE "signIn|login|authenticate|FirebaseAuth|createUser|signUp|register|supabase.*auth|Auth0|useAuth|AuthContext|signInWithCredential|signInAnonymously" "$LOGIN_FILE" 2>/dev/null | head -1)
    fi
    grep -rqE "deleteUser|deleteAccount|delete.*account|account.*delet|removeAccount|closeAccount|accountDeletion" "$SRC_DIR" 2>/dev/null && HAS_DELETE=true
fi
if [ "$HAS_LOGIN" = true ]; then
    if [ "$HAS_DELETE" = true ]; then
        add_pass "account-deletion" "Account deletion found"
        print_pass "Account deletion found"
    else
        add_issue "BLOCKER" "account-deletion" "${LOGIN_FILE:-$SRC_DIR}" "${LOGIN_MATCH:-login detected}" \
            "Account creation/login found but no account deletion flow detected — Google Play requires in-app account deletion" \
            "Implement account deletion (e.g. FirebaseAuth.instance.currentUser.delete()) and provide UI access"
        print_issue "BLOCKER" "${LOGIN_FILE:-$SRC_DIR}" "${LOGIN_MATCH:-login detected}" \
            "Login found but no account deletion flow detected" \
            "Implement account deletion and provide UI access"
    fi
else
    tprint "  ${CYAN}ℹ️${NC}  No login features detected"
fi
tprint ""

tprint "▸ Privacy Policy"
FOUND_PRIVACY=false; PRIVACY_FILE=""
if [ -d "$SRC_DIR" ]; then
    PRIVACY_FILE=$(grep -rlE "privacy.*policy|privacyPolicy|privacy_policy|PrivacyPolicy|privacyPolicyUrl" "$SRC_DIR" 2>/dev/null | head -1)
    [ -n "$PRIVACY_FILE" ] && FOUND_PRIVACY=true
fi
if [ "$FOUND_PRIVACY" = true ]; then
    add_pass "account-deletion" "Privacy policy reference found in $PRIVACY_FILE"
    print_pass "Privacy policy reference found ${DIM}[$PRIVACY_FILE]${NC}"
else
    add_issue "WARNING" "account-deletion" "$SRC_DIR" "privacy policy not found" \
        "No privacy policy link found in code — required in-app and in Play Store listing" \
        "Add a privacy policy URL in your app settings and Play Console"
    print_issue "WARNING" "$SRC_DIR" "privacy policy not found" \
        "No privacy policy link in code" \
        "Add a privacy policy URL in your app settings and Play Console"
fi
tprint ""

# ═══════════════════════════════════════════════════════════════════════════════
#                       SDK DATA SAFETY AUDIT
# ═══════════════════════════════════════════════════════════════════════════════
tprint "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
tprint "┃   SDK DATA SAFETY AUDIT                                                  ┃"
tprint "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
tprint ""

check_sdk() {
    local name="$1" pattern="$2" data="$3" purpose="$4"
    local found_in=""
    if grep -rqiE "$pattern" "$PKG_FILE" 2>/dev/null; then
        found_in="$PKG_FILE"
    elif [ -n "$GRADLE" ] && grep -rqiE "$pattern" "$GRADLE" 2>/dev/null; then
        found_in="$GRADLE"
    fi
    if [ -n "$found_in" ]; then
        local match_str
        match_str=$(grep -oiE "$pattern" "$found_in" 2>/dev/null | head -1)
        add_data_safety "$name" "$found_in" "${match_str:-$pattern}" "$data" "$purpose"
        tprint "  ${CYAN}ℹ️${NC}  ${BOLD}$name${NC} ${DIM}[$found_in]${NC}"
        tprint "     Declare: ${YELLOW}$data${NC} ($purpose)"
    fi
}

check_sdk "Firebase Analytics"    "firebase_analytics|firebase-analytics"      "Device IDs, App activity, Diagnostics" "Analytics"
check_sdk "Firebase Crashlytics"  "firebase_crashlytics|firebase-crashlytics"  "Crash logs, Device IDs"               "Analytics"
check_sdk "Firebase Messaging"    "firebase_messaging|firebase-messaging"      "Device IDs"                           "Communications"
check_sdk "Firebase Auth"         "firebase_auth|firebase-auth"                "Email, User IDs, Phone number"        "Account mgmt"
check_sdk "Google Maps"           "google_maps_flutter|play-services-maps|react-native-maps" "Location data"          "App functionality"
check_sdk "AdMob"                 "google_mobile_ads|admob"                    "Device IDs, App interactions"          "Advertising"
check_sdk "Sentry"                "sentry_flutter|sentry-android|@sentry/react-native" "Crash logs, Diagnostics, Device IDs" "Analytics"
check_sdk "Bugsnag"               "bugsnag_flutter|bugsnag-android|@bugsnag/react-native" "Crash logs, Diagnostics, Device IDs" "Analytics"
check_sdk "Facebook SDK"          "facebook_sdk|flutter_facebook|facebook-android|react-native-fbsdk" "Device IDs"    "Advertising"
check_sdk "OneSignal"             "onesignal_flutter|onesignal|react-native-onesignal" "Device IDs, Personal info"    "Communications"
check_sdk "Braze"                 "braze_plugin|braze-android|@braze/react-native" "Device IDs, Personal info"        "Personalization"
check_sdk "App Center"            "appcenter|app_center"                       "Crash logs, Diagnostics"              "Analytics"
check_sdk "Amplitude"             "amplitude_flutter|amplitude|@amplitude/react-native" "Device IDs, App interactions" "Analytics"
check_sdk "Mixpanel"              "mixpanel_flutter|mixpanel"                  "Device IDs, App interactions"          "Analytics"
check_sdk "Adjust"                "adjust_sdk|adjust-android|react-native-adjust" "Device IDs"                        "Advertising"
check_sdk "AppsFlyer"             "appsflyer_sdk|appsflyer|react-native-appsflyer" "Device IDs"                       "Advertising"
check_sdk "RevenueCat"            "purchases_flutter|revenuecat|react-native-purchases" "Purchase history, Device IDs" "Analytics"
check_sdk "Stripe"                "flutter_stripe|stripe-android|@stripe/stripe-react-native" "User payment info"     "App functionality"
check_sdk "Microsoft Intune"      "intune|msal_flutter|react-native-intune"    "Device IDs, App info"                 "Security"

[ ${#DATA_SAFETY[@]} -eq 0 ] && tprint "  ${CYAN}ℹ️${NC}  No common SDKs detected — check manually"
tprint ""

# ═══════════════════════════════════════════════════════════════════════════════
#                              SUMMARY
# ═══════════════════════════════════════════════════════════════════════════════

TOTAL_BLOCKERS=$(total_blockers)
TOTAL_WARNINGS=$(total_warnings)
TOTAL_PASSED=${#PASSED_CHECKS[@]}

# ─── JSON Output Mode ────────────────────────────────────────────────────────
if [ "$OUTPUT_MODE" != "terminal" ]; then
    # Build JSON output
    JSON="{"
    JSON+="\"project\":{\"name\":\"$PROJECT_NAME\",\"type\":\"$PROJECT_TYPE\"},"
    JSON+="\"summary\":{\"blockers\":$TOTAL_BLOCKERS,\"warnings\":$TOTAL_WARNINGS,\"passed\":$TOTAL_PASSED,\"data_safety\":${#DATA_SAFETY[@]}},"

    # Issues array
    JSON+="\"issues\":["
    first=true
    for issue in "${ISSUES[@]}"; do
        IFS='|' read -r sev cat file match msg fix <<< "$issue"
        [ "$first" = true ] && first=false || JSON+=","
        # Escape double quotes in strings
        msg="${msg//\"/\\\"}"
        fix="${fix//\"/\\\"}"
        match="${match//\"/\\\"}"
        JSON+="{\"severity\":\"$sev\",\"category\":\"$cat\",\"file\":\"$file\",\"match\":\"$match\",\"message\":\"$msg\",\"fix\":\"$fix\"}"
    done
    JSON+="],"

    # Data safety array
    JSON+="\"data_safety\":["
    first=true
    for ds in "${DATA_SAFETY[@]}"; do
        IFS='|' read -r sdk file match declares purpose <<< "$ds"
        [ "$first" = true ] && first=false || JSON+=","
        JSON+="{\"sdk\":\"$sdk\",\"file\":\"$file\",\"match\":\"$match\",\"declares\":\"$declares\",\"purpose\":\"$purpose\"}"
    done
    JSON+="],"

    # Per-category breakdown
    JSON+="\"categories\":{"
    first=true
    for cat in target-sdk compile-sdk permissions foreground-service network-security \
               build-config signing billing account-deletion 16kb-alignment \
               build-format expo-config photo-video; do
        b=${CAT_BLOCKERS[$cat]}; w=${CAT_WARNINGS[$cat]}; p=${CAT_PASSED[$cat]}
        [ "$b" -eq 0 ] && [ "$w" -eq 0 ] && [ "$p" -eq 0 ] && continue
        [ "$first" = true ] && first=false || JSON+=","
        JSON+="\"$cat\":{\"blockers\":$b,\"warnings\":$w,\"passed\":$p}"
    done
    JSON+="},"

    # Verdict
    if [ "$TOTAL_BLOCKERS" -gt 0 ]; then
        JSON+="\"verdict\":\"NOT_READY\""
    elif [ "$TOTAL_WARNINGS" -gt 0 ]; then
        JSON+="\"verdict\":\"REVIEW_WARNINGS\""
    else
        JSON+="\"verdict\":\"PASSED\""
    fi
    JSON+="}"

    if [ "$OUTPUT_MODE" = "json-pretty" ]; then
        echo "$JSON" | python3 -m json.tool 2>/dev/null || echo "$JSON"
    else
        echo "$JSON"
    fi
    [ "$TOTAL_BLOCKERS" -gt 0 ] && exit 1 || exit 0
fi

# ─── Terminal Summary ─────────────────────────────────────────────────────────
echo ""
echo "╔═══════════════════════════════════════════════════════════════════════════╗"
echo "║                        ANDROID SUMMARY                                    ║"
echo "╚═══════════════════════════════════════════════════════════════════════════╝"
echo ""

# List all blockers with file references
if [ "$TOTAL_BLOCKERS" -gt 0 ]; then
    echo -e "${RED}❌ BLOCKERS ($TOTAL_BLOCKERS):${NC}"
    for issue in "${ISSUES[@]}"; do
        IFS='|' read -r sev cat file match msg fix <<< "$issue"
        [ "$sev" = "BLOCKER" ] && echo -e "   ${RED}•${NC} ${DIM}[$cat]${NC} ${BOLD}$match${NC} ${DIM}($file)${NC}"
    done
    echo ""
fi

# List all warnings with file references
if [ "$TOTAL_WARNINGS" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  WARNINGS ($TOTAL_WARNINGS):${NC}"
    for issue in "${ISSUES[@]}"; do
        IFS='|' read -r sev cat file match msg fix <<< "$issue"
        [ "$sev" = "WARNING" ] && echo -e "   ${YELLOW}•${NC} ${DIM}[$cat]${NC} $match ${DIM}($file)${NC}"
    done
    echo ""
fi

echo -e "${GREEN}✅ PASSED: $TOTAL_PASSED checks${NC}"
echo ""

# Data Safety summary
if [ ${#DATA_SAFETY[@]} -gt 0 ]; then
    echo "📊 DATA SAFETY FORM — declare these in Play Console:"
    for ds in "${DATA_SAFETY[@]}"; do
        IFS='|' read -r sdk file match declares purpose <<< "$ds"
        echo -e "   • ${BOLD}$sdk${NC} → $declares"
    done
    echo ""
fi

# Manual checklist
echo "📋 PLAY CONSOLE MANUAL CHECKLIST:"
echo "   [ ] Data Safety form completed"
echo "   [ ] Privacy policy URL added"
echo "   [ ] Data deletion URL added"
echo "   [ ] Content rating questionnaire"
echo "   [ ] Target audience declaration"
echo "   [ ] Ads + Financial features declarations"
echo "   [ ] Permissions Declaration Form (if restricted perms)"
echo "   [ ] Photo & video: use Android Photo Picker (or declare if core photo app)"
echo "   [ ] Developer account verified (2026)"
echo "   [ ] Screenshots: min 2, 9:16, no frames"
echo ""

# Per-category breakdown
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "                              FINAL VERDICT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Category display names
declare -A CAT_NAMES=(
    [target-sdk]="Target SDK"
    [compile-sdk]="Compile SDK"
    [permissions]="Permissions"
    [foreground-service]="Foreground Svc"
    [network-security]="Network Security"
    [build-config]="Build Config"
    [signing]="Signing"
    [billing]="Billing"
    [account-deletion]="Account & Privacy"
    [16kb-alignment]="16 KB Page Size"
    [build-format]="Build Format"
    [expo-config]="Expo Config"
    [photo-video]="Photo & Video"
)

for cat in target-sdk compile-sdk build-format build-config signing 16kb-alignment \
           permissions photo-video foreground-service network-security billing \
           account-deletion expo-config; do
    b=${CAT_BLOCKERS[$cat]}; w=${CAT_WARNINGS[$cat]}; p=${CAT_PASSED[$cat]}
    [ "$b" -eq 0 ] && [ "$w" -eq 0 ] && [ "$p" -eq 0 ] && continue
    name="${CAT_NAMES[$cat]:-$cat}"
    printf "  %-20s" "$name:"
    [ "$b" -gt 0 ] && printf "${RED}%d blocker(s)${NC}  " "$b" || printf "             "
    [ "$w" -gt 0 ] && printf "${YELLOW}%d warning(s)${NC}  " "$w" || printf "              "
    printf "${GREEN}%d passed${NC}\n" "$p"
done

echo "  ─────────────────────────────────────────────────────────"
printf "  %-20s" "TOTAL:"
printf "${RED}%d blocker(s)${NC}  ${YELLOW}%d warning(s)${NC}  ${GREEN}%d passed${NC}  ${CYAN}%d SDK declarations${NC}\n" \
    "$TOTAL_BLOCKERS" "$TOTAL_WARNINGS" "$TOTAL_PASSED" "${#DATA_SAFETY[@]}"
echo ""

if [ "$TOTAL_BLOCKERS" -gt 0 ]; then
    echo -e "${RED}🚫 NOT READY — fix $TOTAL_BLOCKERS blocker(s) before submission${NC}"
    exit 1
elif [ "$TOTAL_WARNINGS" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  REVIEW $TOTAL_WARNINGS WARNING(S) BEFORE SUBMISSION${NC}"
    exit 0
else
    echo -e "${GREEN}✅ AUTOMATED CHECKS PASSED — complete manual checklist above${NC}"
    exit 0
fi