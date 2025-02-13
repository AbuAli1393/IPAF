#!/bin/bash
# IPAF Installation Script
# Created by Abdo.Mohammed
# Version: 2.1.0

set -e

# Configuration
IPAF_ROOT="/opt/IPAF"
VENV_DIR="${IPAF_ROOT}/venv"
CONFIG_DIR="/etc/ipaf"
LOG_DIR="/var/log/ipaf"
MODULES_DIR="${IPAF_ROOT}/modules"
REPORTS_DIR="${IPAF_ROOT}/reports"
GOPATH="/root/go"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Error handling
trap 'echo -e "${RED}[-] Error at line $LINENO${NC}"; exit 1' ERR

# Check root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[-] Please run as root${NC}"
  exit 1
fi

# Header
echo -e "${GREEN}"
cat << "EOF"
 ██▓ ██████ ▄▄▄█████▓ ▄████▄  
▓██▒██    ▒ ▓  ██▒ ▓▒▒██▀ ▀█  
▒██░ ▓██▄   ▒ ▓██░ ▒░▒▓█    ▄ 
░██░ ▒   ██▒░ ▓██▓ ░ ▒▓▓▄ ▄██▒
░██▒▒██████▒▒  ▒██▒ ░ ▒ ▓███▀ 
░▓ ▒▒ ▒▓▒ ▒ ░  ▒ ░░   ░ ░▒ ▒  ░
 ▒ ░░ ░▒  ░ ░    ░      ░  ▒   
 ▒ ░░  ░  ░    ░      ░        
 ░        ░            ░ ░      
                       ░       
EOF
echo -e "${NC}"

# Create directory structure
echo -e "${YELLOW}[+] Creating directory structure...${NC}"
dirs=(
  "${IPAF_ROOT}" "${VENV_DIR}" "${CONFIG_DIR}"
  "${LOG_DIR}" "${MODULES_DIR}" "${REPORTS_DIR}"
  "${MODULES_DIR}/recon" "${MODULES_DIR}/enumeration"
  "${MODULES_DIR}/exploitation" "${MODULES_DIR}/post_exploit"
  "${MODULES_DIR}/reporting" "${IPAF_ROOT}/core"
  "${IPAF_ROOT}/lib" "${IPAF_ROOT}/scripts"
)

for dir in "${dirs[@]}"; do
  [ ! -d "$dir" ] && mkdir -p "$dir"
done

# System setup
echo -e "${YELLOW}[+] Updating system packages...${NC}"
apt update -qq && apt full-upgrade -y -qq

echo -e "${YELLOW}[+] Installing dependencies...${NC}"
apt install -y -qq \
  git curl wget python3.11 python3.11-venv python3-pip golang-go \
  ruby-full perl docker.io docker-compose nmap masscan wireshark \
  openjdk-17-jdk libssl-dev libffi-dev build-essential zlib1g-dev \
  libxml2-dev libxslt1-dev libfreetype6-dev procps redis-server

# Python environment
echo -e "${YELLOW}[+] Setting up Python virtual environment...${NC}"
python3.11 -m venv "${VENV_DIR}"
source "${VENV_DIR}/bin/activate"

echo -e "${YELLOW}[+] Installing Python requirements...${NC}"
pip install -q --upgrade pip
pip install -q \
  pycryptodome requests beautifulsoup4 paramiko colorama \
  python-nmap pandas openpyxl cryptography xmltodict

# Core framework
echo -e "${YELLOW}[+] Installing IPAF core...${NC}"
git clone -q https://github.com/Abdo.Mohammed/IPAF-core.git "${IPAF_ROOT}/core"
cp "${IPAF_ROOT}/core/ipaf.sh" /usr/local/bin/ipaf
chmod +x /usr/local/bin/ipaf

# Module installer function
install_module() {
  local repo=$1
  local category=$2
  local name=$(basename "${repo}" .git)
  
  echo -e "${YELLOW}[+] Installing ${name}...${NC}"
  git clone -q --depth 1 "${repo}" "${MODULES_DIR}/${category}/${name}"
  
  if [ -f "${MODULES_DIR}/${category}/${name}/requirements.txt" ]; then
    pip install -q -r "${MODULES_DIR}/${category}/${name}/requirements.txt"
  fi
  
  if [ -f "${MODULES_DIR}/${category}/${name}/setup.sh" ]; then
    bash "${MODULES_DIR}/${category}/${name}/setup.sh" >/dev/null 2>&1
  fi
}

# Install modules
echo -e "${YELLOW}[+] Installing recon modules...${NC}"
install_module "https://github.com/aboul3la/Sublist3r.git" "recon"
install_module "https://github.com/projectdiscovery/subfinder.git" "recon"
install_module "https://github.com/OWASP/Amass.git" "recon"

echo -e "${YELLOW}[+] Installing enumeration modules...${NC}"
install_module "https://github.com/sqlmapproject/sqlmap.git" "enumeration"
install_module "https://github.com/rastating/dnmasscan.git" "enumeration"
install_module "https://github.com/darkoperator/dnsrecon.git" "enumeration"

echo -e "${YELLOW}[+] Installing exploitation modules...${NC}"
install_module "https://github.com/rapid7/metasploit-framework.git" "exploitation"
install_module "https://github.com/vanhauser-thc/thc-hydra.git" "exploitation"
install_module "https://github.com/lanmaster53/recon-ng.git" "exploitation"

echo -e "${YELLOW}[+] Installing post-exploit modules...${NC}"
install_module "https://github.com/EmpireProject/Empire.git" "post_exploit"
install_module "https://github.com/BloodHoundAD/BloodHound.git" "post_exploit"

echo -e "${YELLOW}[+] Installing reporting modules...${NC}"
install_module "https://github.com/AeonDave/doReport.git" "reporting"

# Go tools setup
echo -e "${YELLOW}[+] Configuring Go environment...${NC}"
export GOPATH="${GOPATH}"
export PATH="${PATH}:${GOPATH}/bin"
echo "export GOPATH=${GOPATH}" >> /etc/profile
echo 'export PATH=$PATH:$GOPATH/bin' >> /etc/profile

echo -e "${YELLOW}[+] Installing Go tools...${NC}"
go install -v github.com/projectdiscovery/nuclei/v2/cmd/nuclei@latest >/dev/null 2>&1
go install -v github.com/projectdiscovery/naabu/v2/cmd/naabu@latest >/dev/null 2>&1
go install -v github.com/ffuf/ffuf@latest >/dev/null 2>&1

# Docker setup
echo -e "${YELLOW}[+] Configuring Docker...${NC}"
systemctl enable docker --now >/dev/null 2>&1
docker-compose -f "${IPAF_ROOT}/core/docker/docker-compose.yml" up -d >/dev/null 2>&1

# Database setup
echo -e "${YELLOW}[+] Initializing databases...${NC}"
msfdb init --quiet
redis-server --daemonize yes

# Permissions
echo -e "${YELLOW}[+] Setting permissions...${NC}"
chmod -R 755 "${IPAF_ROOT}"
chown -R root:root "${IPAF_ROOT}"
chmod 600 "${CONFIG_DIR}"/*.conf

# Systemd service
echo -e "${YELLOW}[+] Creating IPAF service...${NC}"
cat << EOF > /etc/systemd/system/ipaf.service
[Unit]
Description=IPAF Framework Service
After=network.target docker.service

[Service]
Type=simple
User=root
WorkingDirectory=${IPAF_ROOT}
Environment="PATH=${VENV_DIR}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=${VENV_DIR}/bin/python ${IPAF_ROOT}/core/ipafd.py
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ipaf.service >/dev/null 2>&1

# Completion
echo -e "${GREEN}"
cat << "EOF"
 ___ _   _  ___ ___ ___  ___ ___ 
|_ _| | | |/ __/ _ \  \/  / __|
 | || |_| | (_| (_) \    /\__ \
|___|\__,_|\___\___/ \/\/ |___/
EOF
echo -e "${NC}"

echo -e "${GREEN}[+] Installation complete!${NC}"
echo -e "\n${YELLOW}Usage:${NC}"
echo -e "  Start framework: ${GREEN}systemctl start ipaf${NC}"
echo -e "  Command-line interface: ${GREEN}ipaf --help${NC}"
echo -e "  Web interface: ${GREEN}https://localhost:8443${NC}"
echo -e "\n${YELLOW}Credentials:${NC} admin / ipaf@2024"
echo -e "\n${RED}⚠️ Warning: Use only on authorized systems!${NC}"
