#!/usr/bin/env bash
# Screenshots Skill — Automated Setup
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
echo -e "${BOLD}Screenshots Skill — Dependency Setup${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# --- Detect OS ---
OS="unknown"
case "$(uname -s)" in
    Darwin*)  OS="mac" ;;
    Linux*)   OS="linux" ;;
    MINGW*|MSYS*|CYGWIN*) OS="windows" ;;
esac

# Detect package manager (Linux)
LINUX_PKG=""
if [ "$OS" = "linux" ]; then
    if command -v apt-get &>/dev/null; then
        LINUX_PKG="apt"
    elif command -v dnf &>/dev/null; then
        LINUX_PKG="dnf"
    elif command -v yum &>/dev/null; then
        LINUX_PKG="yum"
    elif command -v pacman &>/dev/null; then
        LINUX_PKG="pacman"
    fi
fi

# Detect Homebrew (Mac)
HAS_BREW=false
if [ "$OS" = "mac" ] && command -v brew &>/dev/null; then
    HAS_BREW=true
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
    echo -e "    Installing $name..."

    if $install_fn; then
        # Verify after install
        if eval "$check_cmd" &>/dev/null; then
            local version
            version=$(eval "$check_cmd" 2>/dev/null | head -1)
            echo -e "    ${GREEN}✓ Installed${NC} $version"
            ((installed++))
            return 0
        fi
    fi

    echo -e "    ${RED}✗ Failed to install $name${NC}"
    ((failed++))
    failures+=("$name")
    return 1
}

# --- Install functions ---

install_node() {
    case "$OS" in
        mac)
            if $HAS_BREW; then
                brew install node
            else
                echo -e "    ${RED}Homebrew not found. Install Node.js from https://nodejs.org/${NC}"
                return 1
            fi
            ;;
        linux)
            case "$LINUX_PKG" in
                apt)    sudo apt-get update -qq && sudo apt-get install -y -qq nodejs npm ;;
                dnf)    sudo dnf install -y nodejs npm ;;
                yum)    sudo yum install -y nodejs npm ;;
                pacman) sudo pacman -S --noconfirm nodejs npm ;;
                *)      echo -e "    ${RED}Unknown package manager. Install Node.js from https://nodejs.org/${NC}"; return 1 ;;
            esac
            ;;
        *)
            echo -e "    ${RED}Install Node.js manually from https://nodejs.org/${NC}"
            return 1
            ;;
    esac
}

install_python() {
    case "$OS" in
        mac)
            if $HAS_BREW; then
                brew install python
            else
                echo -e "    ${RED}Homebrew not found. Install Python from https://www.python.org/downloads/${NC}"
                return 1
            fi
            ;;
        linux)
            case "$LINUX_PKG" in
                apt)    sudo apt-get update -qq && sudo apt-get install -y -qq python3 python3-pip ;;
                dnf)    sudo dnf install -y python3 python3-pip ;;
                yum)    sudo yum install -y python3 python3-pip ;;
                pacman) sudo pacman -S --noconfirm python python-pip ;;
                *)      echo -e "    ${RED}Unknown package manager. Install Python from https://www.python.org/downloads/${NC}"; return 1 ;;
            esac
            ;;
        *)
            echo -e "    ${RED}Install Python manually from https://www.python.org/downloads/${NC}"
            return 1
            ;;
    esac
}

install_pillow() {
    if command -v pip3 &>/dev/null; then
        pip3 install --user Pillow
    elif command -v pip &>/dev/null; then
        pip install --user Pillow
    else
        echo -e "    ${RED}pip not found. Install Python first.${NC}"
        return 1
    fi
}

install_agent_device() {
    if command -v npm &>/dev/null; then
        npm install -g agent-device 2>/dev/null || sudo npm install -g agent-device
    else
        echo -e "    ${RED}npm not found. Install Node.js first.${NC}"
        return 1
    fi
}

install_anthropic() {
    if command -v pip3 &>/dev/null; then
        pip3 install --user anthropic
    elif command -v pip &>/dev/null; then
        pip install --user anthropic
    else
        echo -e "    ${RED}pip not found. Install Python first.${NC}"
        return 1
    fi
}

# --- Run checks and installs ---

echo -e "${BOLD}Platform:${NC} $OS"
[ "$OS" = "mac" ] && echo -e "${BOLD}Homebrew:${NC} $($HAS_BREW && echo 'yes' || echo 'no')"
[ "$OS" = "linux" ] && echo -e "${BOLD}Package manager:${NC} ${LINUX_PKG:-unknown}"
echo ""

# Node.js (install before agent-device)
check_or_install "Node.js" "node --version" install_node || true

# Python 3 (install before Pillow)
check_or_install "Python 3" "python3 --version" install_python || true

# Pillow
check_or_install "Pillow" "python3 -c \"from PIL import Image; print('Pillow ' + Image.__version__)\"" install_pillow || true

# agent-device
check_or_install "agent-device" "agent-device --version" install_agent_device || true

# anthropic SDK (optional)
echo ""
echo -e "${BOLD}Optional:${NC}"
check_or_install "anthropic SDK" "python3 -c \"import anthropic; print('anthropic ' + anthropic.__version__)\"" install_anthropic || true

# --- Summary ---

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$failed" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}All dependencies ready!${NC}"
    echo -e "  ✓ Already installed: $passed"
    [ "$installed" -gt 0 ] && echo -e "  ✓ Newly installed:  $installed"
    echo ""
    echo "You can now run the screenshots skill."
else
    echo -e "${RED}${BOLD}Some dependencies could not be installed:${NC}"
    for f in "${failures[@]}"; do
        echo -e "  ${RED}✗${NC} $f"
    done
    echo ""
    echo "Install the failed dependencies manually, then re-run this script."
fi

echo ""
