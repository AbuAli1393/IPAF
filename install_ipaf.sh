#!/bin/bash

# Script Name: install_ipaf.sh
# Description: Installs and sets up the Integrated Pentest Automation Framework (IPAF).
# Author: Abdo.Mohammed
# Version: 1.0

# Define the main directory
MAIN_DIR="/opt/IPAF"
mkdir -p "$MAIN_DIR"

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Please use sudo or run as root user."
   exit 1
fi

echo "Welcome to the Integrated Pentest Automation Framework (IPAF) Installation!"

# Update and upgrade the system
echo "Updating and upgrading the system..."
apt update && apt upgrade -y

# Install common dependencies
echo "Installing common dependencies..."
apt install -y curl wget git build-essential libssl-dev libffi-dev python3 python3-pip python3-venv ruby-full snapd golang perl nmap hydra john sqlmap nikto wpscan crackmapexec bloodhound neo4j seclists

# Install GoLang-based tools
echo "Installing GoLang-based tools..."
GO111MODULE=on go get -u github.com/OWASP/Amass/v3/...
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
go install -v github.com/projectdiscovery/nuclei/v2/cmd/nuclei@latest

# Install Python-based tools
echo "Installing Python-based tools..."
pip3 install wfuzz crackmapexec reportlab flask

# Install Ruby-based tools
echo "Installing Ruby-based tools..."
gem install wpscan evil-winrm

# Install Metasploit Framework
echo "Installing Metasploit Framework..."
curl https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb > msfinstall && \
chmod 755 msfinstall && \
./msfinstall

# Install EyeWitness
echo "Installing EyeWitness..."
git clone https://github.com/FortyNorthSecurity/EyeWitness.git /opt/EyeWitness && \
cd /opt/EyeWitness/Python/setup && \
./setup.sh

# Install Responder
echo "Installing Responder..."
git clone https://github.com/lgandx/Responder.git /opt/Responder

# Install LinPEAS and WinPEAS
echo "Installing LinPEAS and WinPEAS..."
wget https://github.com/carlospolop/PEASS-ng/releases/latest/download/linpeas.sh -O /opt/linpeas.sh
wget https://github.com/carlospolop/PEASS-ng/releases/latest/download/winPEAS.bat -O /opt/winPEAS.bat

# Create directories for reports
REPORTS_DIR="$MAIN_DIR/reports"
mkdir -p "$REPORTS_DIR"

# Download the IPAF script
echo "Downloading the IPAF script..."
cat << 'EOF' > /usr/local/bin/ipaf
#!/bin/bash

# Script Name: ipaf
# Description: Integrated Pentest Automation Framework (IPAF)
# Author: Abdo.Mohammed
# Version: 1.0

# Define the main directory
MAIN_DIR="/opt/IPAF"
REPORTS_DIR="$MAIN_DIR/reports"

# Function to perform reconnaissance
recon() {
    echo "Starting reconnaissance..."
    read -p "Enter target domain/IP: " TARGET
    mkdir -p "$REPORTS_DIR/$TARGET"

    # Subdomain enumeration
    echo "Running Sublist3r..."
    sublist3r -d "$TARGET" -o "$REPORTS_DIR/$TARGET/subdomains.txt"

    # Amass for asset discovery
    echo "Running Amass..."
    amass enum -d "$TARGET" -o "$REPORTS_DIR/$TARGET/amass_subdomains.txt"

    # Nmap for port scanning
    echo "Running Nmap..."
    nmap -sV -T4 -oN "$REPORTS_DIR/$TARGET/nmap_scan.txt" "$TARGET"

    echo "Reconnaissance completed! Results saved in $REPORTS_DIR/$TARGET"
}

# Function to scan for vulnerabilities
vulnerability_scan() {
    echo "Starting vulnerability scanning..."
    read -p "Enter target domain/IP: " TARGET
    mkdir -p "$REPORTS_DIR/$TARGET"

    # Nikto for web server scanning
    echo "Running Nikto..."
    nikto -h "$TARGET" -o "$REPORTS_DIR/$TARGET/nikto_scan.html"

    # WPScan for WordPress scanning
    echo "Running WPScan..."
    wpscan --url "$TARGET" --enumerate u,vp,vt --output "$REPORTS_DIR/$TARGET/wpscan_results.txt"

    # Sqlmap for SQL injection testing
    echo "Running Sqlmap..."
    sqlmap -u "$TARGET" --batch --output-dir "$REPORTS_DIR/$TARGET/sqlmap_output"

    # Nuclei for vulnerability scanning
    echo "Running Nuclei..."
    nuclei -u "$TARGET" -o "$REPORTS_DIR/$TARGET/nuclei_results.txt"

    echo "Vulnerability scanning completed! Results saved in $REPORTS_DIR/$TARGET"
}

# Function to exploit vulnerabilities
exploit() {
    echo "Starting exploitation..."
    read -p "Enter target IP: " TARGET
    read -p "Enter service to exploit (e.g., ssh, smb): " SERVICE

    case $SERVICE in
        ssh)
            echo "Running Hydra on SSH..."
            if [[ -f /usr/share/wordlists/rockyou.txt ]]; then
                hydra -l admin -P /usr/share/wordlists/rockyou.txt "$TARGET" ssh -o "$REPORTS_DIR/$TARGET/hydra_ssh_results.txt"
            else
                echo "Wordlist not found at /usr/share/wordlists/rockyou.txt. Please install 'seclists' package."
            fi
            ;;
        smb)
            echo "Running CrackMapExec on SMB..."
            if [[ -f /usr/share/wordlists/rockyou.txt ]]; then
                crackmapexec smb "$TARGET" -u admin -p /usr/share/wordlists/rockyou.txt --shares -o "$REPORTS_DIR/$TARGET/crackmapexec_smb_results.txt"
            else
                echo "Wordlist not found at /usr/share/wordlists/rockyou.txt. Please install 'seclists' package."
            fi
            ;;
        *)
            echo "Service not supported yet!"
            ;;
    esac

    echo "Exploitation completed! Results saved in $REPORTS_DIR/$TARGET"
}

# Function to run EyeWitness
run_eyewitness() {
    echo "Running EyeWitness..."
    read -p "Enter target URL or IP: " TARGET
    mkdir -p "$REPORTS_DIR/$TARGET"
    python3 /opt/EyeWitness/EyeWitness.py --web -f "$TARGET" -d "$REPORTS_DIR/$TARGET/eyewitness_results"
    echo "EyeWitness completed! Results saved in $REPORTS_DIR/$TARGET/eyewitness_results"
}

# Function to run Responder
run_responder() {
    echo "Running Responder..."
    read -p "Enter network interface (e.g., eth0): " INTERFACE
    mkdir -p "$REPORTS_DIR/responder"
    python3 /opt/Responder/Responder.py -I "$INTERFACE" -wrf --output "$REPORTS_DIR/responder"
    echo "Responder completed! Results saved in $REPORTS_DIR/responder"
}

# Function to run BloodHound
run_bloodhound() {
    echo "Running BloodHound..."
    systemctl start neo4j
    bloodhound --no-sandbox &
    echo "BloodHound started! Access it via the browser at http://localhost:7474"
}

# Function to run LinPEAS
run_linpeas() {
    echo "Running LinPEAS..."
    bash /opt/linpeas.sh > "$REPORTS_DIR/linpeas_results.txt"
    echo "LinPEAS completed! Results saved in $REPORTS_DIR/linpeas_results.txt"
}

# Function to generate PDF report
generate_pdf_report() {
    echo "Generating PDF report..."
    read -p "Enter target name: " TARGET
    RESULTS=("Recon completed" "Vulnerability scan completed" "Exploitation completed")
    python3 <<END
from reportlab.lib.pagesizes import letter
from reportlab.pdfgen import canvas
pdf_file = f"$REPORTS_DIR/{TARGET}_report.pdf"
c = canvas.Canvas(pdf_file, pagesize=letter)
c.drawString(100, 750, f"Penetration Test Report for {TARGET}")
y = 700
for result in ["Recon completed", "Vulnerability scan completed", "Exploitation completed"]:
    c.drawString(100, y, result)
    y -= 20
c.save()
print(f"PDF report generated: {pdf_file}")
END
    echo "PDF report generated!"
}

# Main menu
while true; do
    echo "============================="
    echo "Integrated Pentest Automation Framework (IPAF)"
    echo "============================="
    echo "1. Reconnaissance"
    echo "2. Vulnerability Scanning"
    echo "3. Exploitation"
    echo "4. Run EyeWitness"
    echo "5. Run Responder"
    echo "6. Run BloodHound"
    echo "7. Run LinPEAS"
    echo "8. Generate PDF Report"
    echo "9. Exit"
    echo "============================="
    read -p "Select an option: " OPTION

    case $OPTION in
        1) recon ;;
        2) vulnerability_scan ;;
        3) exploit ;;
        4) run_eyewitness ;;
        5) run_responder ;;
        6) run_bloodhound ;;
        7) run_linpeas ;;
        8) generate_pdf_report ;;
        9) echo "Exiting the framework. Goodbye!"; exit 0 ;;
        *) echo "Invalid option. Please try again." ;;
    esac
done
EOF

# Make the IPAF script executable
chmod +x /usr/local/bin/ipaf

echo "Installation of IPAF completed successfully!"
echo "You can now run the framework by typing 'ipaf' in your terminal."
