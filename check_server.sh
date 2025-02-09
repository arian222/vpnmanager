#!/bin/bash

# Culori pentru output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "\n${YELLOW}=== Verificare Configurare Server ===${NC}"

# Verifică fișierele și directoarele necesare
echo -e "\n${YELLOW}Verificare structură fișiere:${NC}"
FILES_TO_CHECK=(
    "/etc/vpnmanager/authorized_ips.conf"
    "/usr/local/vpnmanager/vpnmanager.sh"
    "/usr/local/vpnmanager/add_ip.sh"
    "/usr/local/vpnmanager/cleanup_expired.sh"
)

for file in "${FILES_TO_CHECK[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓ $file există${NC}"
        echo -e "  Permisiuni: $(ls -l "$file")"
    else
        echo -e "${RED}✗ $file lipsește${NC}"
    fi
done

# Verifică serviciile
echo -e "\n${YELLOW}Verificare servicii:${NC}"
services=("ssh" "openvpn")
for service in "${services[@]}"; do
    if systemctl is-active --quiet "$service"; then
        echo -e "${GREEN}✓ Serviciul $service rulează${NC}"
    else
        echo -e "${RED}✗ Serviciul $service nu rulează${NC}"
    fi
done

# Verifică IP-urile autorizate
echo -e "\n${YELLOW}IP-uri autorizate:${NC}"
if [ -f "/etc/vpnmanager/authorized_ips.conf" ]; then
    echo "Lista IP-uri autorizate:"
    cat "/etc/vpnmanager/authorized_ips.conf"
else
    echo -e "${RED}Fișierul cu IP-uri autorizate nu există!${NC}"
fi

# Verifică permisiunile
echo -e "\n${YELLOW}Verificare permisiuni:${NC}"
directories=(
    "/etc/vpnmanager"
    "/usr/local/vpnmanager"
    "/etc/ssh/users"
)

for dir in "${directories[@]}"; do
    if [ -d "$dir" ]; then
        echo -e "${GREEN}✓ Directorul $dir există${NC}"
        echo -e "  Permisiuni: $(ls -ld "$dir")"
    else
        echo -e "${RED}✗ Directorul $dir lipsește${NC}"
    fi
done

# Verifică hostname
echo -e "\n${YELLOW}Verificare hostname:${NC}"
if grep -q "127.0.0.1.*$(hostname)" /etc/hosts; then
    echo -e "${GREEN}✓ Hostname configurat corect în /etc/hosts${NC}"
else
    echo -e "${RED}✗ Hostname nu este configurat în /etc/hosts${NC}"
    echo -e "Adăugați următoarea linie în /etc/hosts:"
    echo -e "127.0.0.1 $(hostname)"
fi

# Verifică conectivitate
echo -e "\n${YELLOW}Verificare conectivitate:${NC}"
if ping -c 1 google.com >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Conexiune la internet funcțională${NC}"
else
    echo -e "${RED}✗ Nu există conexiune la internet${NC}"
fi

echo -e "\n${YELLOW}=== Verificare completă ===${NC}" 