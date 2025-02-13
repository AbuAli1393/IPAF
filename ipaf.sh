#!/bin/bash
# IPAF - Integrated Pentest Automation Framework
# Created by Abdo.Mohammed
# Version: 1.0.0

# Configuration
IPAF_ROOT="/opt/IPAF"
VENV_DIR="$IPAF_ROOT/venv"
CONFIG_DIR="/etc/ipaf"
LOG_DIR="/var/log/ipaf"
MODULES_DIR="$IPAF_ROOT/modules"
REPORTS_DIR="$IPAF_ROOT/reports"

# Check root privileges
if [ "$EUID" -ne 0 ]; then
  echo "[-] Please run as root"
  exit 1
fi

# Create directory structure
echo "[+] Creating IPAF framework structure..."
mkdir -p {$IPAF_ROOT,$VENV_DIR,$CONFIG_DIR,$LOG_DIR,$MODULES_DIR,$REPORTS_DIR} \
  $MODULES_DIR/{recon,enumeration,exploitation,post_exploit,reporting} \
  $IPAF_ROOT/core $IPAF_ROOT/lib $IPAF_ROOT/scripts

# Install system dependencies
echo "[+] Installing system dependencies..."
apt update && apt full-upgrade -y
apt install -y \
  python3.11 python3.11-venv python3-pip golang-go ruby-full perl \
  docker.io docker-compose nmap masscan wireshark openjdk-17-jdk \
  libssl-dev libffi-dev build-essential zlib1g-dev

# Setup Python virtual environment
echo "[+] Configuring Python environment..."
python3.11 -m venv $VENV_DIR
source $VENV_DIR/bin/activate

# Install core Python dependencies
pip install --upgrade pip
pip install \
  pycryptodome requests beautifulsoup4 paramiko colorama \
  python-nmap pandas openpyxl cryptography

# Framework core components
echo "[+] Installing framework core..."
git clone https://github.com/IPAF/core.git $IPAF_ROOT/core
cp $IPAF_ROOT/core/ipaf.sh /usr/local/bin/ipaf
chmod +x /usr/local/bin/ipaf

# Install modules
install_module() {
  local repo=$1
  local category=$2
  local name=$(basename $repo .git)
  
  echo "[+] Installing $name module..."
  git clone --depth 1 $repo $MODULES_DIR/$category/$name
  [ -f "$MODULES_DIR/$category/$name/requirements.txt" ] && \
    pip install -r $MODULES_DIR/$category/$name/requirements.txt
  [ -f "$MODULES_DIR/$category/$name/setup.sh" ] && \
    bash $MODULES_DIR/$category/$name/setup.sh
}

# Reconnaissance modules
install_module "https://github.com/aboul3la/Sublist3r" recon
install_module "https://github.com/projectdiscovery/subfinder" recon
install_module "https://github.com/OWASP/Amass" recon

# Enumeration modules
install_module "https://github.com/sqlmapproject/sqlmap" enumeration
install_module "https://github.com/rastating/dnmasscan" enumeration
install_module "https://github.com/darkoperator/dnsrecon" enumeration

# Exploitation modules
install_module "https://github.com/rapid7/metasploit-framework" exploitation
install_module "https://github.com/vanhauser-thc/thc-hydra" exploitation
install_module "https://github.com/lanmaster53/recon-ng" exploitation

# Post-exploitation modules
install_module "https://github.com/EmpireProject/Empire" post_exploit
install_module "https://github.com/BloodHoundAD/BloodHound" post_exploit

# Reporting modules
install_module "https://github.com/AeonDave/doReport" reporting

# Install Go-based tools
echo "[+] Installing Go utilities..."
export GOPATH=/root/go
export PATH=$PATH:/root/go/bin

go install -v github.com/projectdiscovery/nuclei/v2/cmd/nuclei@latest
go install -v github.com/projectdiscovery/naabu/v2/cmd/naabu@latest
go install -v github.com/ffuf/ffuf@latest

# Configure framework services
echo "[+] Configuring framework services..."
cp $IPAF_ROOT/core/config/ipaf.conf $CONFIG_DIR/
cp $IPAF_ROOT/core/config/logging.conf $CONFIG_DIR/
cp $IPAF_ROOT/core/scripts/* $IPAF_ROOT/scripts/

# Database setup
echo "[+] Initializing databases..."
msfdb init
redis-server --daemonize yes

# Docker containers setup
echo "[+] Deploying Docker containers..."
docker-compose -f $IPAF_ROOT/core/docker/docker-compose.yml up -d

# Set permissions
echo "[+] Configuring permissions..."
chmod 755 $IPAF_ROOT
chown -R root:root $IPAF_ROOT
chmod 600 $CONFIG_DIR/*.conf

# Finalize installation
echo "[+] Finalizing setup..."
ldconfig
updatedb

# Create systemd service
echo "[+] Creating IPAF service..."
cat << EOF > /etc/systemd/system/ipaf.service
[Unit]
Description=IPAF Framework Service
After=network.target

[Service]
Type=simple
ExecStart=$VENV_DIR/bin/python $IPAF_ROOT/core/ipafd.py
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ipaf.service

echo -e "\n[+] IPAF installation complete!"
echo -e "\n[!] Framework Components:"
echo -e "  Core System: $IPAF_ROOT/core"
echo -e "  Modules: $MODULES_DIR"
echo -e "  Configuration: $CONFIG_DIR"
echo -e "  Reports: $REPORTS_DIR"
echo -e "\n[!] Usage:"
echo -e "  Start framework: systemctl start ipaf"
echo -e "  Command-line interface: ipaf"
echo -e "  Web interface: https://localhost:8443"
echo -e "\n[!] Documentation: https://github.com/AbuAli1393/IPAF/wiki"
