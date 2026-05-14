#!/usr/bin/env bash
# =============================================================================
# macOS Workstation Setup Script
# Target: Apple Silicon (arm64)
# Repo: https://github.com/l0s3rc0d3/workstation_setup/macos_config
#
# Usage (single command install):
#   bash <(curl -fsSL https://raw.githubusercontent.com/l0s3rc0d3/workstation_setup/main/macos_config/setup.sh)
# =============================================================================

set -euo pipefail

# =============================================================================
# ── VARIABLES ─────────────────────────────────────────────────────────────────
# Change these to update versions / paths without touching the rest of the script
# =============================================================================

GOLANG_VERSION="go1.26.3"
GOLANG_ARCH="darwin-arm64"
GOLANG_PKG="${GOLANG_VERSION}.${GOLANG_ARCH}.tar.gz"
GOLANG_URL="https://go.dev/dl/${GOLANG_PKG}"
GOLANG_INSTALL_DIR="/usr/local/go"

NERD_FONT="font-meslo-lg-nerd-font"   # brew cask name

ZSH_USER_FILE="${HOME}/.zsh_user"
ZSHRC_FILE="${HOME}/.zshrc"

OH_MY_ZSH_DIR="${HOME}/.oh-my-zsh"
ZSH_CUSTOM="${OH_MY_ZSH_DIR}/custom"

P10K_DIR="${ZSH_CUSTOM}/themes/powerlevel10k"
ZSH_AUTOSUGGESTIONS_DIR="${ZSH_CUSTOM}/plugins/zsh-autosuggestions"
ZSH_SYNTAX_DIR="${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting"
ZSH_HISTORY_SEARCH_DIR="${ZSH_CUSTOM}/plugins/zsh-history-substring-search"

PODMAN_CPUS=4
PODMAN_MEMORY=8192   # MB
PODMAN_DISK=60       # GB

DOCK_SIZE=36         # Dock icon size in pixels

# =============================================================================
# ── HELPERS ───────────────────────────────────────────────────────────────────
# =============================================================================

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
BOLD="\033[1m"
NC="\033[0m"

info()    { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
section() {
  echo -e "\n${GREEN}════════════════════════════════════════${NC}"
  echo -e "${GREEN} $*${NC}"
  echo -e "${GREEN}════════════════════════════════════════${NC}"
}

require_macos() {
  if [[ "$(uname)" != "Darwin" ]]; then
    echo -e "${RED}[ERROR]${NC} This script is for macOS only."
    exit 1
  fi
}

require_arm64() {
  if [[ "$(uname -m)" != "arm64" ]]; then
    echo -e "${RED}[ERROR]${NC} This script targets Apple Silicon (arm64). Detected: $(uname -m)"
    exit 1
  fi
}

step_done() {
  echo ""
  echo -e "${GREEN}✔  Step complete.${NC} Press Enter to return to the menu…"
  read -r
}

# =============================================================================
# ── PRE-FLIGHT ────────────────────────────────────────────────────────────────
# =============================================================================

require_macos
require_arm64

# =============================================================================
# ── STEP FUNCTIONS ────────────────────────────────────────────────────────────
# =============================================================================

step_homebrew() {
  section "1/10 · Homebrew"
  if ! command -v brew &>/dev/null; then
    info "Installing Homebrew…"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    info "Homebrew already installed — updating…"
    brew update
  fi
}

step_cask_apps() {
  section "2/10 · Cask Applications"
  CASK_APPS=(
    ghostty
    visual-studio-code
    podman-desktop
    obsidian
    notion
    bitwarden
    vivaldi
    aldente
    rectangle
    stats
    appcleaner
  )
  set +e
  for app in "${CASK_APPS[@]}"; do
    if brew list --cask "${app}" &>/dev/null 2>&1; then
      info "${app} already installed — skipping."
    else
      info "Installing ${app}…"
      brew install --cask "${app}"
      if [[ $? -ne 0 ]]; then
        warn "Failed to install cask: ${app} — continuing."
      fi
    fi
  done
  set -e
}

step_nerd_font() {
  section "3/10 · Nerd Font (${NERD_FONT})"
  # Note: homebrew/cask-fonts tap was merged into homebrew/cask in 2024;
  # fonts are now installed directly without tapping.
  set +e
  if brew list --cask "${NERD_FONT}" &>/dev/null 2>&1; then
    info "${NERD_FONT} already installed — skipping."
  else
    info "Installing ${NERD_FONT}…"
    brew install --cask "${NERD_FONT}"
  fi
  set -e
}

step_cli_tools() {
  section "4/10 · CLI Tools"

  # ── tfenv + Terraform ────────────────────────────────────────────────────
  if ! command -v tfenv &>/dev/null; then
    info "Installing tfenv…"
    brew install tfenv
  fi
  # tfenv list exits 0 but prints "No versions installed." when terraform is absent;
  # use command -v terraform as the reliable check instead.
  if ! command -v terraform &>/dev/null; then
    info "Installing latest Terraform via tfenv…"
    tfenv install latest
    tfenv use latest
  else
    info "Terraform already managed by tfenv — skipping."
  fi

  # ── kubectl ──────────────────────────────────────────────────────────────
  # kubectl does NOT conflict with Podman Desktop on macOS; install separately.
  if ! command -v kubectl &>/dev/null; then
    info "Installing kubectl…"
    brew install kubectl
  else
    info "kubectl already installed — skipping."
  fi

  # ── helm ─────────────────────────────────────────────────────────────────
  if ! command -v helm &>/dev/null; then
    info "Installing helm…"
    brew install helm
  else
    info "helm already installed — skipping."
  fi

  # ── kind ─────────────────────────────────────────────────────────────────
  if ! command -v kind &>/dev/null; then
    info "Installing kind…"
    brew install kind
  else
    info "kind already installed — skipping."
  fi

  # ── eza ──────────────────────────────────────────────────────────────────
  if ! command -v eza &>/dev/null; then
    info "Installing eza…"
    brew install eza
  else
    info "eza already installed — skipping."
  fi

  # ── fzf ──────────────────────────────────────────────────────────────────
  if ! command -v fzf &>/dev/null; then
    info "Installing fzf…"
    brew install fzf
    "$(brew --prefix fzf)/install" --key-bindings --completion --no-update-rc
  else
    info "fzf already installed — skipping."
  fi

  # ── AWS CLI ──────────────────────────────────────────────────────────────
  if ! command -v aws &>/dev/null; then
    info "Installing AWS CLI…"
    brew install awscli
  else
    info "AWS CLI already installed — skipping."
  fi
}

step_golang() {
  section "5/10 · Go (${GOLANG_VERSION})"
  if [[ -d "${GOLANG_INSTALL_DIR}" ]]; then
    CURRENT_GO="$(${GOLANG_INSTALL_DIR}/bin/go version 2>/dev/null || echo 'none')"
    info "Go already installed: ${CURRENT_GO} — skipping download."
  else
    info "Downloading ${GOLANG_PKG}…"
    curl -fSL "${GOLANG_URL}" -o "/tmp/${GOLANG_PKG}"

    info "Installing Go to ${GOLANG_INSTALL_DIR}…"
    sudo rm -rf "${GOLANG_INSTALL_DIR}"
    sudo tar -C /usr/local -xzf "/tmp/${GOLANG_PKG}"

    info "Cleaning up Go archive…"
    rm -f "/tmp/${GOLANG_PKG}"

    info "Go installed: $(/usr/local/go/bin/go version)"
  fi
}

step_rust() {
  section "6/10 · Rust (rustup)"
  if command -v rustup &>/dev/null; then
    info "Rust already installed — updating…"
    rustup update stable
  else
    info "Installing Rust via rustup…"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
  fi
  # Rust env is sourced at shell startup via ~/.cargo/env in .zshrc
}

step_python() {
  section "7/10 · Python virtualenv support"
  # macOS ships Python 3; ensure pip and venv are available.
  if ! python3 -m venv --help &>/dev/null; then
    warn "python3 venv module not available. Installing python3 via brew…"
    brew install python3
  else
    info "python3 venv already available — skipping."
  fi

  # pipx for isolated CLI tools
  if ! command -v pipx &>/dev/null; then
    info "Installing pipx…"
    brew install pipx
    pipx ensurepath
  else
    info "pipx already installed — skipping."
  fi
}

step_podman() {
  section "8/10 · Podman machine (Apple Hypervisor)"

  # podman-desktop is a GUI-only cask — the CLI must be installed separately.
  if ! command -v podman &>/dev/null; then
    info "Installing Podman CLI…"
    brew install podman
  else
    info "Podman CLI already installed — skipping."
  fi

  # Set Apple Hypervisor as default to avoid QEMU issues on Apple Silicon
  CONTAINERS_CONF_DIR="${HOME}/.config/containers"
  CONTAINERS_CONF="${CONTAINERS_CONF_DIR}/containers.conf"
  mkdir -p "${CONTAINERS_CONF_DIR}"

  if ! grep -q 'provider="applehv"' "${CONTAINERS_CONF}" 2>/dev/null; then
    info "Configuring Podman to use Apple Hypervisor (applehv)…"
    cat >> "${CONTAINERS_CONF}" <<'EOF'

[machine]
provider="applehv"
EOF
  else
    info "Podman applehv already configured — skipping."
  fi

  # Initialise the default Podman machine if it doesn't exist
  set +e
  podman machine list 2>/dev/null | grep -q "podman-machine-default"
  PODMAN_MACHINE_EXISTS=$?
  set -e

  if [[ "${PODMAN_MACHINE_EXISTS}" -ne 0 ]]; then
    info "Initialising Podman machine (${PODMAN_CPUS} CPUs, ${PODMAN_MEMORY}MB RAM, ${PODMAN_DISK}GB disk)…"
    podman machine init \
      --cpus="${PODMAN_CPUS}" \
      --memory="${PODMAN_MEMORY}" \
      --disk-size="${PODMAN_DISK}"
    podman machine start
  else
    info "Podman machine already exists — skipping init."
  fi
}

step_zsh() {
  section "9/10 · Zsh + Oh My Zsh + Powerlevel10k"

  # ── Oh My Zsh ──────────────────────────────────────────────────────────
  if [[ ! -d "${OH_MY_ZSH_DIR}" ]]; then
    info "Installing Oh My Zsh…"
    RUNZSH=no CHSH=no \
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  else
    info "Oh My Zsh already installed — skipping."
  fi

  # ── Powerlevel10k ──────────────────────────────────────────────────────
  if [[ ! -d "${P10K_DIR}" ]]; then
    info "Installing Powerlevel10k theme…"
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${P10K_DIR}"
  else
    info "Powerlevel10k already installed — skipping."
  fi

  # ── Plugins ────────────────────────────────────────────────────────────
  install_zsh_plugin() {
    local name="$1" url="$2" dest="$3"
    if [[ ! -d "${dest}" ]]; then
      info "Installing zsh plugin: ${name}…"
      git clone --depth=1 "${url}" "${dest}"
    else
      info "Plugin ${name} already installed — skipping."
    fi
  }

  install_zsh_plugin "zsh-autosuggestions" \
    "https://github.com/zsh-users/zsh-autosuggestions" \
    "${ZSH_AUTOSUGGESTIONS_DIR}"

  install_zsh_plugin "zsh-syntax-highlighting" \
    "https://github.com/zsh-users/zsh-syntax-highlighting" \
    "${ZSH_SYNTAX_DIR}"

  install_zsh_plugin "zsh-history-substring-search" \
    "https://github.com/zsh-users/zsh-history-substring-search" \
    "${ZSH_HISTORY_SEARCH_DIR}"

  # ── .zshrc ─────────────────────────────────────────────────────────────
  info "Writing ${ZSHRC_FILE}…"
  if [[ -f "${ZSHRC_FILE}" && ! -f "${ZSHRC_FILE}.bak" ]]; then
    cp "${ZSHRC_FILE}" "${ZSHRC_FILE}.bak"
    warn "Existing .zshrc backed up to ${ZSHRC_FILE}.bak"
  fi

  cat > "${ZSHRC_FILE}" <<'ZSHRC'
# =============================================================================
# .zshrc — generated by workstation setup script
# =============================================================================

# ── Powerlevel10k instant prompt ─────────────────────────────────────────────
# Must stay near the top; code requiring console input goes above this block.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ── Oh My Zsh ────────────────────────────────────────────────────────────────
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="powerlevel10k/powerlevel10k"

DISABLE_MAGIC_FUNCTIONS="true"
ENABLE_CORRECTION="true"
COMPLETION_WAITING_DOTS="true"

plugins=(
  git
  fzf
  extract
  kubectl
  zsh-autosuggestions
  zsh-syntax-highlighting
  zsh-history-substring-search
)

source "$ZSH/oh-my-zsh.sh"

# ── Homebrew (Apple Silicon) ─────────────────────────────────────────────────
eval "$(/opt/homebrew/bin/brew shellenv)"

# ── Go ───────────────────────────────────────────────────────────────────────
export GOPATH="$HOME/go"
export PATH="$PATH:/usr/local/go/bin:$GOPATH/bin"

# ── Rust / Cargo ─────────────────────────────────────────────────────────────
[[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"

# ── pipx ─────────────────────────────────────────────────────────────────────
export PATH="$PATH:$HOME/.local/bin"

# ── fzf ──────────────────────────────────────────────────────────────────────
export FZF_BASE="$(brew --prefix fzf)"
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# ── Podman / Kind socket ─────────────────────────────────────────────────────
# Required for kind to work with Podman as the container runtime
export DOCKER_HOST="unix://$HOME/.local/share/containers/podman/machine/podman.sock"

# ── History ──────────────────────────────────────────────────────────────────
# zsh uses setopts, not bash's HISTCONTROL
setopt HIST_IGNORE_SPACE    # ignore commands starting with a space
setopt HIST_IGNORE_DUPS     # ignore consecutive duplicate commands
setopt HIST_IGNORE_ALL_DUPS # remove older duplicate entries from history
setopt SHARE_HISTORY        # share history across all open shells
export HISTORY_IGNORE="(\&|[bf]g|c|clear|history|exit|q|pwd|* --help)"

# ── man page colours ─────────────────────────────────────────────────────────
export LESS_TERMCAP_md="$(tput bold 2>/dev/null; tput setaf 2 2>/dev/null)"
export LESS_TERMCAP_me="$(tput sgr0 2>/dev/null)"

# ── eza (modern ls) ──────────────────────────────────────────────────────────
if command -v eza &>/dev/null; then
  alias ls='eza -al --color=always --group-directories-first --icons'
  alias la='eza -a  --color=always --group-directories-first --icons'
  alias ll='eza -l  --color=always --group-directories-first --icons'
  alias lt='eza -aT --color=always --group-directories-first --icons'
  alias l.="eza -a  --color=always | grep -e '^\.'"
fi

# ── User customisations ───────────────────────────────────────────────────────
[[ -f ~/.zsh_user ]] && source ~/.zsh_user

# ── Powerlevel10k config ──────────────────────────────────────────────────────
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
ZSHRC

  # ── .zsh_user ──────────────────────────────────────────────────────────
  info "Writing ${ZSH_USER_FILE}…"
  if [[ ! -f "${ZSH_USER_FILE}" ]]; then
    cat > "${ZSH_USER_FILE}" <<'ZSH_USER'
# =============================================================================
# .zsh_user — personal additions (aliases, exports, overrides)
# This file is sourced at the end of .zshrc — add everything personal here.
# =============================================================================

# ── Kubernetes ───────────────────────────────────────────────────────────────
alias k='kubectl'
# kubectl shell completion
[[ $commands[kubectl] ]] && source <(kubectl completion zsh)
# Make the 'k' alias also benefit from completion
complete -o default -F __start_kubectl k

# ── Go workspace ─────────────────────────────────────────────────────────────
# GOPATH is set in .zshrc; override here only if you need a custom path.
# export GOPATH="$HOME/go"

# ── AWS CLI ──────────────────────────────────────────────────────────────────
# Shell completion (requires awscli installed via brew)
[[ $commands[aws] ]] && complete -C aws_completer aws

# ── Add your own aliases / exports below ─────────────────────────────────────
ZSH_USER
  else
    warn "${ZSH_USER_FILE} already exists — skipping creation to preserve your changes."
  fi
}

step_macos_settings() {
  section "10/10 · macOS System Settings"

  # ── Dock ─────────────────────────────────────────────────────────────────
  info "Setting Dock icon size to ${DOCK_SIZE}px…"
  defaults write com.apple.dock tilesize -int "${DOCK_SIZE}"

  info "Enabling Dock magnification…"
  defaults write com.apple.dock magnification -bool true
  defaults write com.apple.dock largesize -int 64

  info "Minimising windows into their application icon…"
  defaults write com.apple.dock minimize-to-application -bool true

  info "Disabling 'Show recent applications in Dock'…"
  defaults write com.apple.dock show-recents -bool false

  info "Setting Dock auto-hide…"
  defaults write com.apple.dock autohide -bool true
  defaults write com.apple.dock autohide-delay -float 0.1
  defaults write com.apple.dock autohide-time-modifier -float 0.3

  # ── Finder ───────────────────────────────────────────────────────────────
  info "Showing filename extensions in Finder…"
  defaults write NSGlobalDomain AppleShowAllExtensions -bool true

  info "Showing hidden files in Finder…"
  defaults write com.apple.finder AppleShowAllFiles -bool true

  info "Showing path bar in Finder…"
  defaults write com.apple.finder ShowPathbar -bool true

  info "Showing status bar in Finder…"
  defaults write com.apple.finder ShowStatusBar -bool true

  info "Setting Finder default view to list…"
  defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

  info "Disabling the warning when changing a file extension…"
  defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

  # ── Screenshots ──────────────────────────────────────────────────────────
  info "Saving screenshots to ~/Documents/Screenshots…"
  mkdir -p "${HOME}/Documents/Screenshots"
  defaults write com.apple.screencapture location -string "${HOME}/Documents/Screenshots"

  info "Saving screenshots in PNG format…"
  defaults write com.apple.screencapture type -string "png"

  info "Disabling screenshot shadow…"
  defaults write com.apple.screencapture disable-shadow -bool true

  # ── Keyboard & Input ─────────────────────────────────────────────────────
  info "Disabling automatic capitalisation…"
  defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false

  info "Disabling smart dashes…"
  defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

  info "Disabling automatic period substitution…"
  defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false

  info "Disabling smart quotes…"
  defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false

  info "Disabling auto-correct…"
  defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

  # ── General ──────────────────────────────────────────────────────────────
  info "Disabling 'Reopen windows when logging back in'…"
  defaults write com.apple.loginwindow TALLogoutSavesState -bool false

  info "Expanding save panel by default…"
  defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
  defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

  # ── Apply changes ─────────────────────────────────────────────────────────
  info "Restarting Dock and Finder to apply changes…"
  killall Dock
  killall Finder

  warn "Some settings may require a logout/reboot to fully take effect."
}

# =============================================================================
# ── FULL INSTALL ──────────────────────────────────────────────────────────────
# =============================================================================

run_all() {
  section "macOS Workstation Setup — Full Install"
  info "Running all steps. This may take a while…"
  step_homebrew
  step_cask_apps
  step_nerd_font
  step_cli_tools
  step_golang
  step_rust
  step_python
  step_podman
  step_zsh
  step_macos_settings

  section "✅  Full setup complete!"
  echo ""
  echo -e "  ${YELLOW}Next steps:${NC}"
  echo -e "  1. Open ${GREEN}Ghostty${NC} → set font to ${GREEN}MesloLGS NF${NC} in its config file"
  echo -e "  2. Run ${GREEN}p10k configure${NC} to generate your prompt layout"
  echo -e "  3. Restart your shell: ${GREEN}exec zsh${NC}"
  echo -e "  4. Browse Terraform versions: ${GREEN}tfenv list-remote${NC}"
  echo -e "  5. Start Podman when needed: ${GREEN}podman machine start${NC}"
  echo ""
  echo -e "  Your previous .zshrc was backed up to ${GREEN}~/.zshrc.bak${NC} (if it existed)."
  echo ""
}

# =============================================================================
# ── INTERACTIVE MENU ──────────────────────────────────────────────────────────
# =============================================================================

show_menu() {
  clear
  echo -e "${BOLD}${CYAN}"
  echo "  ╔══════════════════════════════════════════════╗"
  echo "  ║     macOS Workstation Setup — Apple Silicon  ║"
  echo "  ╚══════════════════════════════════════════════╝"
  echo -e "${NC}"
  echo -e "  ${BOLD}Select a step to run:${NC}"
  echo ""
  echo -e "   ${CYAN}0${NC}  →  Run everything (full install)"
  echo -e "   ${CYAN}1${NC}  →  Homebrew"
  echo -e "   ${CYAN}2${NC}  →  Cask Applications"
  echo -e "   ${CYAN}3${NC}  →  Nerd Font (MesloLGS NF)"
  echo -e "   ${CYAN}4${NC}  →  CLI Tools (terraform, kubectl, helm, kind, eza, fzf, aws)"
  echo -e "   ${CYAN}5${NC}  →  Go"
  echo -e "   ${CYAN}6${NC}  →  Rust"
  echo -e "   ${CYAN}7${NC}  →  Python (venv + pipx)"
  echo -e "   ${CYAN}8${NC}  →  Podman Machine"
  echo -e "   ${CYAN}9${NC}  →  Zsh Configuration (Oh My Zsh, p10k, plugins)"
  echo -e "   ${CYAN}10${NC} →  macOS System Settings (Dock, Finder, keyboard…)"
  echo ""
  echo -e "   ${RED}q${NC}  →  Quit"
  echo ""
  echo -ne "  ${BOLD}Choice:${NC} "
}

main() {
  while true; do
    show_menu
    read -r choice
    case "${choice}" in
      0)  run_all;              step_done ;;
      1)  step_homebrew;        step_done ;;
      2)  step_cask_apps;       step_done ;;
      3)  step_nerd_font;       step_done ;;
      4)  step_cli_tools;       step_done ;;
      5)  step_golang;          step_done ;;
      6)  step_rust;            step_done ;;
      7)  step_python;          step_done ;;
      8)  step_podman;          step_done ;;
      9)  step_zsh;             step_done ;;
      10) step_macos_settings;  step_done ;;
      q|Q)
        echo ""
        echo -e "  ${GREEN}Bye!${NC}"
        echo ""
        exit 0
        ;;
      *)
        echo ""
        echo -e "  ${RED}Invalid choice '${choice}'.${NC} Please enter a number from 0 to 10, or q to quit."
        sleep 1.5
        ;;
    esac
  done
}

main