#!/usr/bin/env bash
# Deploy App Skill — Automated Setup
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
echo -e "${BOLD}Deploy App Skill — Dependency Setup${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
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

HAS_BREW=false
if [ "$OS" = "mac" ] && command -v brew &>/dev/null; then HAS_BREW=true; fi

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

install_node() {
    case "$OS" in
        mac)
            if $HAS_BREW; then brew install node
            else echo -e "    ${RED}Homebrew not found. Install Node.js from https://nodejs.org/${NC}"; return 1; fi ;;
        linux)
            case "$LINUX_PKG" in
                apt)    sudo apt-get update -qq && sudo apt-get install -y -qq nodejs npm ;;
                dnf)    sudo dnf install -y nodejs npm ;;
                yum)    sudo yum install -y nodejs npm ;;
                pacman) sudo pacman -S --noconfirm nodejs npm ;;
                *)      echo -e "    ${RED}Unknown package manager. Install Node.js from https://nodejs.org/${NC}"; return 1 ;;
            esac ;;
        *) echo -e "    ${RED}Install Node.js manually from https://nodejs.org/${NC}"; return 1 ;;
    esac
}

install_git() {
    case "$OS" in
        mac)
            if $HAS_BREW; then brew install git
            else echo -e "    ${RED}Install Xcode Command Line Tools: xcode-select --install${NC}"; return 1; fi ;;
        linux)
            case "$LINUX_PKG" in
                apt)    sudo apt-get update -qq && sudo apt-get install -y -qq git ;;
                dnf)    sudo dnf install -y git ;;
                yum)    sudo yum install -y git ;;
                pacman) sudo pacman -S --noconfirm git ;;
                *)      echo -e "    ${RED}Unknown package manager. Install git from https://git-scm.com/${NC}"; return 1 ;;
            esac ;;
        *) echo -e "    ${RED}Install git manually from https://git-scm.com/downloads${NC}"; return 1 ;;
    esac
}

install_ruby() {
    case "$OS" in
        mac)
            if $HAS_BREW; then brew install ruby
            else echo -e "    ${RED}Ruby should be pre-installed on macOS. Try: xcode-select --install${NC}"; return 1; fi ;;
        linux)
            case "$LINUX_PKG" in
                apt)    sudo apt-get update -qq && sudo apt-get install -y -qq ruby-full ;;
                dnf)    sudo dnf install -y ruby ;;
                yum)    sudo yum install -y ruby ;;
                pacman) sudo pacman -S --noconfirm ruby ;;
                *)      echo -e "    ${RED}Unknown package manager. Install Ruby from https://www.ruby-lang.org/${NC}"; return 1 ;;
            esac ;;
        *) echo -e "    ${RED}Install Ruby manually from https://rubyinstaller.org/${NC}"; return 1 ;;
    esac
}

install_bundler() {
    if command -v gem &>/dev/null; then
        gem install bundler 2>/dev/null || sudo gem install bundler
    else
        echo -e "    ${RED}gem not found. Install Ruby first.${NC}"; return 1
    fi
}

install_store_deploy() {
    if command -v npm &>/dev/null; then
        npm config set @egdw:registry https://artifactory.eg.dk/artifactory/api/npm/egdw-store-deploy-npm-local/ && npm install -g @egdw/store-deploy 2>/dev/null || sudo npm install -g @egdw/store-deploy
    else
        echo -e "    ${RED}npm not found. Install Node.js first.${NC}"; return 1
    fi
}

# --- Run checks ---

echo -e "${BOLD}Platform:${NC} $OS"
[ "$OS" = "mac" ] && echo -e "${BOLD}Homebrew:${NC} $($HAS_BREW && echo 'yes' || echo 'no')"
[ "$OS" = "linux" ] && echo -e "${BOLD}Package manager:${NC} ${LINUX_PKG:-unknown}"
echo ""

check_or_install "Node.js" "node --version" install_node || true
check_or_install "npm" "npm --version" install_node || true
check_or_install "git" "git --version" install_git || true
check_or_install "Ruby" "ruby --version" install_ruby || true
check_or_install "Bundler" "bundle --version" install_bundler || true
check_or_install "store-deploy CLI" "store-deploy --version" install_store_deploy || true

# --- Summary ---

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$failed" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}All dependencies ready!${NC}"
    echo -e "  ✓ Already installed: $passed"
    [ "$installed" -gt 0 ] && echo -e "  ✓ Newly installed:  $installed"
    echo ""
    echo "You can now run the deploy skill."
else
    echo -e "${RED}${BOLD}Some dependencies could not be installed:${NC}"
    for f in "${failures[@]}"; do echo -e "  ${RED}✗${NC} $f"; done
    echo ""
    echo "Install the failed dependencies manually, then re-run this script."
fi

echo ""
