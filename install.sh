#!/bin/bash

# Culori pentru output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Verifică dacă scriptul rulează ca root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Acest script trebuie rulat ca root${NC}"
   exit 1
fi

# Funcție pentru așteptarea eliberării lock-ului
wait_for_dpkg() {
    while fuser /var/lib/dpkg/lock >/dev/null 2>&1 || fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
        echo -e "${YELLOW}Aștept finalizarea altor procese apt/dpkg...${NC}"
        sleep 1
    done
}

# Creează directoarele necesare
echo -e "\n${YELLOW}Creez directoarele necesare...${NC}"
mkdir -p /etc/ssh/users
mkdir -p /etc/vpnmanager
mkdir -p /usr/local/vpnmanager

# Instalează dependențele necesare
echo -e "\n${YELLOW}Instalez dependențele...${NC}"
wait_for_dpkg
apt-get update
wait_for_dpkg
apt-get install -y openssh-server openvpn openssl curl wget sudo

# Verifică dacă wget este instalat
if ! command -v wget &> /dev/null; then
    echo -e "${RED}wget nu este instalat. Încerc să-l instalez...${NC}"
    wait_for_dpkg
    apt-get install -y wget
fi

# Descarcă scripturile necesare
echo -e "\n${YELLOW}Descarc scripturile...${NC}"
GITHUB_USERNAME="arian222"  # Înlocuiește cu username-ul tău real de GitHub
BASE_URL="https://raw.githubusercontent.com/$GITHUB_USERNAME/vpnmanager/main"

# Descarcă scriptul principal cu verificare
wget -O /usr/local/vpnmanager/vpnmanager.sh "$BASE_URL/vpn_manager.sh"
if [ $? -ne 0 ]; then
    echo -e "${RED}Eroare la descărcarea scriptului principal.${NC}"
    echo -e "URL încercat: $BASE_URL/vpn_manager.sh"
    echo -e "Verificați dacă repository-ul și fișierele există și sunt publice."
    exit 1
fi
chmod +x /usr/local/vpnmanager/vpnmanager.sh

# Creează script pentru adăugare IP-uri
cat > /usr/local/vpnmanager/add_ip.sh << 'EOL'
#!/bin/bash
if [[ $# -ne 1 ]]; then
    echo "Utilizare: $0 <ip_address>"
    exit 1
fi
if [[ ! $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "IP invalid. Folosiți formatul: xxx.xxx.xxx.xxx"
    exit 1
fi
echo "$1" >> /etc/vpnmanager/authorized_ips.conf
sort -u -o /etc/vpnmanager/authorized_ips.conf /etc/vpnmanager/authorized_ips.conf
echo "IP $1 adăugat cu succes!"
EOL
chmod +x /usr/local/vpnmanager/add_ip.sh

# Creează link simbolic
ln -sf /usr/local/vpnmanager/vpnmanager.sh /usr/local/bin/vpnmanager

# Adaugă IP-ul curent în lista de IP-uri autorizate
CURRENT_IP=$(curl -s ifconfig.me)
if [ -n "$CURRENT_IP" ]; then
    echo "$CURRENT_IP" > /etc/vpnmanager/authorized_ips.conf
else
    echo -e "${RED}Nu s-a putut obține IP-ul curent!${NC}"
fi

# Configurează hostname dacă nu există deja
if ! grep -q "127.0.0.1.*$(hostname)" /etc/hosts; then
    echo "127.0.0.1 $(hostname)" >> /etc/hosts
fi

# Verifică instalarea
echo -e "\n${YELLOW}Verificare instalare:${NC}"
if [ -f "/usr/local/vpnmanager/vpnmanager.sh" ] && [ -x "/usr/local/vpnmanager/vpnmanager.sh" ]; then
    echo -e "${GREEN}✓ Script principal instalat corect${NC}"
else
    echo -e "${RED}✗ Probleme cu scriptul principal${NC}"
fi

if [ -f "/usr/local/vpnmanager/add_ip.sh" ] && [ -x "/usr/local/vpnmanager/add_ip.sh" ]; then
    echo -e "${GREEN}✓ Script add_ip instalat corect${NC}"
else
    echo -e "${RED}✗ Probleme cu scriptul add_ip${NC}"
fi

echo -e "\n${GREEN}Instalare completă!${NC}"
echo -e "Pentru a adăuga un IP nou autorizat, rulați: ${YELLOW}sudo /usr/local/vpnmanager/add_ip.sh <ip_address>${NC}"
echo -e "Pentru a porni managerul VPN, rulați: ${YELLOW}vpnmanager${NC}"
echo -e "\nIP-ul dvs. curent ($CURRENT_IP) a fost adăugat automat în lista de IP-uri autorizate." 