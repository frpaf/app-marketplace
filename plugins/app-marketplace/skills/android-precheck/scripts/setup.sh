#!/usr/bin/env bash
# Android Precheck Skill v4.0 — Automated Setup
# Detects OS, checks dependencies, installs what's missing.
# Usage: bash scripts/setup.sh

# Not using set -e — we handle errors explicitly with check_or_install

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

passed=0
installed=0
skipped=0
failed=0
failures=()

echo ""
echo -e "${BOLD}Android Precheck Skill v4.0 — Dependency Setup${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ─── Detect OS ───────────────────────────────────────────────────────────────
OS="unknown"
case "$(uname -s)" in
    Darwin*)  OS="mac" ;;
    Linux*)   OS="linux" ;;
    MINGW*|MSYS*|CYGWIN*) OS="windows" ;;
esac

LINUX_PKG=""
if [ "$OS" = "linux" ]; then
    if command -v apt-get &>/dev/null; then LINUX_PKG="apt"
    elif command -v dnf &>/dev/null; then LINUX_PKG="dnf"
    elif command -v yum &>/dev/null; then LINUX_PKG="yum"
    elif command -v pacman &>/dev/null; then LINUX_PKG="pacman"
    fi
fi

echo -e "${BOLD}Platform:${NC} $OS"
[ "$OS" = "linux" ] && [ -n "$LINUX_PKG" ] && echo -e "${BOLD}Package manager:${NC} $LINUX_PKG"
echo ""

# ─── Helpers ─────────────────────────────────────────────────────────────────

check_or_install() {
    local name="$1"
    local check_cmd="$2"
    local install_fn="$3"
    local required="${4:-required}"  # "required" or "optional"

    printf "  Checking %-25s" "$name..."
    if eval "$check_cmd" &>/dev/null; then
        local version
        version=$(eval "$check_cmd" 2>/dev/null | head -1)
        echo -e "${GREEN}✓${NC} $version"
        ((passed++))
        return 0
    fi

    if [ "$required" = "optional" ]; then
        echo -e "${YELLOW}not found (optional)${NC}"
        ((skipped++))
        return 0
    fi

    echo -e "${YELLOW}not found${NC}"

    if [ -n "$install_fn" ]; then
        echo -e "    Installing $name..."
        if $install_fn 2>/dev/null; then
            if eval "$check_cmd" &>/dev/null; then
                local version
                version=$(eval "$check_cmd" 2>/dev/null | head -1)
                echo -e "    ${GREEN}✓ Installed${NC} $version"
                ((installed++))
                return 0
            fi
        fi
    fi

    echo -e "    ${RED}✗ $name is not available${NC}"
    ((failed++))
    failures+=("$name")
    return 1
}

# ─── Install functions ───────────────────────────────────────────────────────

install_bash() {
    case "$OS" in
        linux)
            case "$LINUX_PKG" in
                apt)    sudo apt-get update -qq && sudo apt-get install -y -qq bash ;;
                dnf)    sudo dnf install -y bash ;;
                yum)    sudo yum install -y bash ;;
                pacman) sudo pacman -S --noconfirm bash ;;
                *)      return 1 ;;
            esac ;;
        *) return 1 ;;
    esac
}

install_binutils() {
    case "$OS" in
        mac)    brew install binutils ;;
        linux)
            case "$LINUX_PKG" in
                apt)    sudo apt-get update -qq && sudo apt-get install -y -qq binutils ;;
                dnf)    sudo dnf install -y binutils ;;
                yum)    sudo yum install -y binutils ;;
                pacman) sudo pacman -S --noconfirm binutils ;;
                *)      return 1 ;;
            esac ;;
        *) return 1 ;;
    esac
}

install_python3() {
    case "$OS" in
        mac)    brew install python3 ;;
        linux)
            case "$LINUX_PKG" in
                apt)    sudo apt-get update -qq && sudo apt-get install -y -qq python3 ;;
                dnf)    sudo dnf install -y python3 ;;
                yum)    sudo yum install -y python3 ;;
                pacman) sudo pacman -S --noconfirm python ;;
                *)      return 1 ;;
            esac ;;
        *) return 1 ;;
    esac
}

install_jq() {
    case "$OS" in
        mac)    brew install jq ;;
        linux)
            case "$LINUX_PKG" in
                apt)    sudo apt-get update -qq && sudo apt-get install -y -qq jq ;;
                dnf)    sudo dnf install -y jq ;;
                yum)    sudo yum install -y jq ;;
                pacman) sudo pacman -S --noconfirm jq ;;
                *)      return 1 ;;
            esac ;;
        *) return 1 ;;
    esac
}

check_readelf() {
    command -v readelf &>/dev/null || command -v greadelf &>/dev/null
}

# ─── Required dependencies ───────────────────────────────────────────────────

echo -e "${BOLD}Required:${NC}"

check_or_install "Bash" "bash --version" install_bash || true
check_or_install "readelf (binutils)" check_readelf install_binutils || true

echo ""

# ─── Optional dependencies ───────────────────────────────────────────────────

echo -e "${BOLD}Optional:${NC}"

check_or_install "python3 (--json-pretty)" "python3 --version" install_python3 "optional" || true
check_or_install "jq (CI/CD JSON parsing)" "jq --version" install_jq "optional" || true

echo ""

# ─── Locate precheck script ─────────────────────────────────────────────────

echo -e "${BOLD}Precheck script:${NC}"

# Determine the skill root directory. The setup script can live at:
#   <skill>/scripts/setup.sh  → SCRIPT_DIR is <skill>
#   <project>/scripts/setup.sh → look for precheck-android.sh in known locations
SCRIPT_DIR="$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)"

PRECHECK_SCRIPT=""
PRECHECK_LOCATIONS=(
    "$SCRIPT_DIR/scripts/precheck-android.sh"
    "$SCRIPT_DIR/precheck-android.sh"
    "./precheck-android.sh"
    "./scripts/precheck-android.sh"
)

printf "  Checking %-25s" "precheck-android.sh..."
for loc in "${PRECHECK_LOCATIONS[@]}"; do
    if [ -f "$loc" ]; then
        PRECHECK_SCRIPT="$loc"
        break
    fi
done

if [ -n "$PRECHECK_SCRIPT" ]; then
    echo -e "${GREEN}✓${NC} found at $PRECHECK_SCRIPT"
    ((passed++))

    # Ensure executable
    if [ ! -x "$PRECHECK_SCRIPT" ]; then
        chmod +x "$PRECHECK_SCRIPT"
        echo -e "    Made executable"
    fi

    # Check version
    SCRIPT_VERSION=$(grep -oP "PRE-CHECK.*v\K[0-9.]+" "$PRECHECK_SCRIPT" 2>/dev/null | head -1)
    if [ -n "$SCRIPT_VERSION" ]; then
        echo -e "    Version: ${CYAN}v$SCRIPT_VERSION${NC}"
        case "$SCRIPT_VERSION" in
            4.*)
                echo -e "    ${GREEN}✓${NC} v4.x — structured issues, --json output, per-category summary"
                ;;
            3.*)
                echo -e "    ${YELLOW}⚠️  v3.x detected — consider updating to v4.0 for:${NC}"
                echo "       • Structured issue tracking (severity, category, file, match)"
                echo "       • --json / --json-pretty output for CI/CD"
                echo "       • Per-category summary in final verdict"
                echo "       • Multi-line XML service tag parsing fix"
                echo "       • Photo/video permissions as blockers (not warnings)"
                echo "       • .so package tracing for 16 KB alignment"
                ;;
            *)
                echo -e "    ${YELLOW}⚠️  Unknown version — consider updating to v4.0${NC}"
                ;;
        esac
    fi

    # Check --json support
    if grep -q "\-\-json" "$PRECHECK_SCRIPT" 2>/dev/null; then
        echo -e "    ${GREEN}✓${NC} --json output supported"
    else
        echo -e "    ${DIM}ℹ️  --json output not available (v4.0+ feature)${NC}"
    fi
else
    echo -e "${RED}✗ not found${NC}"
    echo -e "    Searched:"
    for loc in "${PRECHECK_LOCATIONS[@]}"; do
        echo "      $loc"
    done
    ((failed++))
    failures+=("precheck-android.sh")
fi

# ─── Summary ─────────────────────────────────────────────────────────────────

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$failed" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}All dependencies ready!${NC}"
    echo -e "  ✓ Already installed: $passed"
    [ "$installed" -gt 0 ] && echo -e "  ✓ Newly installed:  $installed"
    [ "$skipped" -gt 0 ] && echo -e "  ○ Optional skipped:  $skipped"
    echo ""
    if [ -n "$PRECHECK_SCRIPT" ]; then
        echo -e "Run the precheck from your project root:"
        echo -e "  ${CYAN}$PRECHECK_SCRIPT${NC}              # terminal output"
        echo -e "  ${CYAN}$PRECHECK_SCRIPT --json${NC}       # JSON for CI/CD"
    else
        echo "You can now run the android precheck skill."
    fi
else
    echo -e "${RED}${BOLD}Some dependencies are missing:${NC}"
    for f in "${failures[@]}"; do echo -e "  ${RED}✗${NC} $f"; done
    echo ""
    echo "Fix the issues above, then re-run this script."
fi

echo ""