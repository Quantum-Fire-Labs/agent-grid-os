#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="/opt/thegrid"
REPO="https://github.com/Quantum-Fire-Labs/the-grid.git"

RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

header()  { echo -e "\n${BOLD}==> $*${RESET}"; }
success() { echo -e "${GREEN}$*${RESET}"; }
error()   { echo -e "${RED}ERROR: $*${RESET}" >&2; exit 1; }
dim()     { echo -e "${DIM}$*${RESET}"; }

# --- Preflight checks ---

[[ $EUID -eq 0 ]] || error "Please run as root (sudo bash)"

header "The Grid — Setup"
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

# --- Clone repo ---

if [[ -d "${INSTALL_DIR}" ]]; then
  header "Updating The Grid"
  git -C "${INSTALL_DIR}" pull --ff-only
else
  header "Downloading The Grid"
  git clone "${REPO}" "${INSTALL_DIR}"
fi

cd "${INSTALL_DIR}"

# --- Collect configuration ---

header "Configuration"
echo ""

read -rp "Domain name (e.g. grid.example.com): " domain
[[ -n "${domain}" ]] || error "Domain is required."

echo ""
read -rp "Admin email: " admin_email
[[ -n "${admin_email}" ]] || error "Admin email is required."

read -rsp "Admin password (min 8 chars): " admin_password
echo ""
[[ ${#admin_password} -ge 8 ]] || error "Password must be at least 8 characters."

echo ""
read -rp "Admin first name [Admin]: " admin_first_name
admin_first_name="${admin_first_name:-Admin}"

read -rp "Admin last name [User]: " admin_last_name
admin_last_name="${admin_last_name:-User}"

# --- Generate secrets ---

master_key=$(openssl rand -hex 16)

# --- Write .env ---

header "Writing configuration"

cat > "${INSTALL_DIR}/.env" <<EOF
DOMAIN=${domain}
RAILS_MASTER_KEY=${master_key}
ADMIN_EMAIL=${admin_email}
ADMIN_PASSWORD=${admin_password}
ADMIN_FIRST_NAME=${admin_first_name}
ADMIN_LAST_NAME=${admin_last_name}
EOF

chmod 600 "${INSTALL_DIR}/.env"
success "Configuration saved to ${INSTALL_DIR}/.env"

# --- Launch ---

header "Starting The Grid"

docker compose pull
docker compose up -d

echo ""
success "The Grid is running!"
echo ""
echo "  URL:   https://${domain}"
echo "  Login: ${admin_email}"
echo ""
dim "It may take a minute for SSL certificates to provision."
dim "Logs: docker compose -f ${INSTALL_DIR}/docker-compose.yml logs -f"
