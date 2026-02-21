#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="/opt/agent-grid-os"
REPO="https://github.com/Quantum-Fire-Labs/agent-grid-os.git"

RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

header()  { echo -e "\n${BOLD}==> $*${RESET}"; }
success() { echo -e "${GREEN}$*${RESET}"; }
error()   { echo -e "${RED}ERROR: $*${RESET}" >&2; exit 1; }
dim()     { echo -e "${DIM}$*${RESET}"; }

# --- Preflight ---

[[ $EUID -eq 0 ]] || error "Please run as root (sudo bash)"

header "AgentGridOS — Installer"
echo ""

# --- Install Docker if needed ---

if ! command -v docker &>/dev/null; then
  header "Installing Docker"
  curl -fsSL https://get.docker.com | sh
  systemctl enable --now docker
  success "Docker installed."
else
  dim "Docker already installed."
fi

if ! docker compose version &>/dev/null; then
  error "Docker Compose plugin not found. Please install it: https://docs.docker.com/compose/install/"
fi

# Detect Docker socket GID (used during setup for container access)
if [[ -S /var/run/docker.sock ]]; then
  DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)
  dim "Docker socket GID: ${DOCKER_GID}"
fi

# --- Clone or update repo ---

if [[ -d "${INSTALL_DIR}" ]]; then
  header "Updating AgentGridOS"
  git -C "${INSTALL_DIR}" pull --ff-only
else
  header "Downloading AgentGridOS"
  git clone "${REPO}" "${INSTALL_DIR}"
fi

# --- Symlink CLI ---

header "Installing CLI"
chmod +x "${INSTALL_DIR}/bin/agentgridos"
ln -sf "${INSTALL_DIR}/bin/agentgridos" /usr/local/bin/agentgridos
success "Installed 'agentgridos' command."

# --- Done ---

echo ""
success "AgentGridOS is installed!"
echo ""
echo "  Next step:"
echo ""
echo "    agentgridos setup"
echo ""
dim "This will configure your domain, admin account, and start the services."
