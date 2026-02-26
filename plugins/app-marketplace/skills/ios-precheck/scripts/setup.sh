#!/usr/bin/env bash
# iOS Precheck Skill — Automated Setup
# Detects OS, checks dependencies, installs what's missing.
# Usage: bash scripts/setup.sh

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

passed=0
installed=0
failed=0
failures=()

echo ""
echo -e "${BOLD}iOS Precheck Skill — Dependency Setup${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# --- Detect OS ---
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

check_or_install() {
    local name="$1"
    local check_cmd="$2"
    local install_fn="$3"

    printf "  Checking %-20s" "$name..."
    if eval "$check_cmd" &>/dev/null; then
        local version
        version=$(eval "$check_cmd" 2>/dev/null | head -1)
        echo -e "${GREEN}✓${NC} $version"
        ((passed++))
        return 0
    fi

    echo -e "${YELLOW}not found${NC}"

    if [ -n "$install_fn" ]; then
        echo -e "    Installing $name..."
        if $install_fn; then
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

# --- Run checks ---

echo -e "${BOLD}Platform:${NC} $OS"
echo ""

check_or_install "Bash" "bash --version" install_bash || true

# Check precheck script
printf "  Checking %-20s" "precheck-ios.sh..."
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [ -f "$SCRIPT_DIR/scripts/precheck.sh" ]; then
    echo -e "${GREEN}✓${NC} found"
    ((passed++))

    # Ensure executable
    if [ ! -x "$SCRIPT_DIR/scripts/precheck.sh" ]; then
        chmod +x "$SCRIPT_DIR/scripts/precheck.sh"
        echo -e "    Made executable"
    fi
else
    echo -e "${RED}✗ not found${NC}"
    echo -e "    Expected at: $SCRIPT_DIR/scripts/precheck.sh"
    ((failed++))
    failures+=("precheck.sh")
fi

# --- Summary ---

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$failed" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}All dependencies ready!${NC}"
    echo -e "  ✓ Already installed: $passed"
    [ "$installed" -gt 0 ] && echo -e "  ✓ Newly installed:  $installed"
    echo ""
    echo "You can now run the ios precheck skill."
else
    echo -e "${RED}${BOLD}Some dependencies are missing:${NC}"
    for f in "${failures[@]}"; do echo -e "  ${RED}✗${NC} $f"; done
    echo ""
    echo "Fix the issues above, then re-run this script."
fi

echo ""
