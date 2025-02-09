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

# Funcție pentru verificarea erorilor
check_error() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}Eroare: $1${NC}"
        exit 1
    fi
}

# Verifică conexiunea la internet
echo -e "\n${YELLOW}Verific conexiunea la internet...${NC}"
ping -c 1 google.com >/dev/null 2>&1
check_error "Nu există conexiune la internet. Verificați conexiunea și încercați din nou."

# Instalează dependențele necesare
echo -e "\n${YELLOW}Instalez dependențele...${NC}"
apt-get update
check_error "Nu s-a putut actualiza lista de pachete"

apt-get install -y openssh-server openvpn openssl curl wget sudo
check_error "Nu s-au putut instala dependențele necesare"

# Creează directoarele necesare
echo -e "\n${YELLOW}Creez directoarele necesare...${NC}"
mkdir -p /usr/local/vpnmanager
check_error "Nu s-au putut crea directoarele necesare"

# Descarcă și instalează scriptul principal
echo -e "\n${YELLOW}Instalez scriptul principal...${NC}"
GITHUB_USERNAME="arian222"  # Înlocuiește cu username-ul tău de GitHub
SCRIPT_URL="https://raw.githubusercontent.com/$GITHUB_USERNAME/vpnmanager/main/vpn_manager.sh"
wget -O /usr/local/vpnmanager/vpnmanager.sh "$SCRIPT_URL"
if [ $? -ne 0 ]; then
    echo -e "${RED}Nu s-a putut descărca scriptul principal.${NC}"
    echo -e "URL încercat: $SCRIPT_URL"
    echo -e "Verificați dacă URL-ul este corect și repository-ul este public."
    exit 1
fi

chmod +x /usr/local/vpnmanager/vpnmanager.sh
check_error "Nu s-au putut seta permisiunile pentru script"

# Creează link simbolic
ln -sf /usr/local/vpnmanager/vpnmanager.sh /usr/local/bin/vpnmanager
check_error "Nu s-a putut crea link-ul simbolic"

# Creează directorul pentru configurare
mkdir -p /etc/vpnmanager
check_error "Nu s-a putut crea directorul de configurare"

# Obține IP-ul curent
CURRENT_IP=$(curl -s ifconfig.me)
if [ -z "$CURRENT_IP" ]; then
    echo -e "${RED}Nu s-a putut obține IP-ul curent.${NC}"
    exit 1
fi

echo -e "\n${GREEN}Instalare completă!${NC}"
echo -e "IP-ul dvs. este: ${YELLOW}$CURRENT_IP${NC}"
echo -e "Furnizați acest IP administratorului pentru activare."
echo -e "După activare, puteți rula scriptul cu comanda: ${YELLOW}vpnmanager${NC}"
echo -e "\nÎn caz de probleme, verificați:"
echo -e "1. Dacă IP-ul de mai sus este corect"
echo -e "2. Dacă administratorul a adăugat IP-ul în lista de IP-uri autorizate"
echo -e "3. Dacă toate serviciile necesare sunt pornite:"
echo -e "   - sudo systemctl status ssh"
echo -e "   - sudo systemctl status openvpn" 