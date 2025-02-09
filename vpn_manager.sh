#!/bin/bash

# Verifică dacă scriptul rulează ca root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Acest script trebuie rulat ca root${NC}"
   exit 1
fi

# Verifică IP-ul curent
CURRENT_IP=$(curl -s ifconfig.me)
if ! grep -q "^$CURRENT_IP$" /etc/vpnmanager/authorized_ips.conf; then
    echo -e "${RED}Acces neautorizat! IP-ul $CURRENT_IP nu este autorizat.${NC}"
    echo -e "Contactați administratorul pentru a autoriza acest IP."
    exit 1
fi

# Culori pentru output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Porturi necesare
declare -A REQUIRED_PORTS
REQUIRED_PORTS["SSH"]=22
REQUIRED_PORTS["SSL"]=443
REQUIRED_PORTS["OpenVPN"]=1194

# Configurări SSH
SSH_USERS_DIR="/etc/ssh/users"
SSH_CONFIG="/etc/ssh/sshd_config"
TRIAL_DURATION=1 # durată trial în zile

# Funcție pentru verificarea unui port
check_port() {
    local host=$1
    local port=$2
    timeout 2 bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null
    if [ $? -eq 0 ]; then
        return 0 # Port deschis
    else
        return 1 # Port închis
    fi
}

# Funcție pentru verificarea tuturor porturilor
verify_required_ports() {
    local host=$1
    echo -e "\nVerificare porturi pentru $host..."
    
    for service in "${!REQUIRED_PORTS[@]}"; do
        port=${REQUIRED_PORTS[$service]}
        if check_port "$host" "$port"; then
            echo -e "${GREEN}Port $port ($service): Deschis${NC}"
        else
            echo -e "${RED}Port $port ($service): Închis${NC}"
        fi
    done
}

# Funcție pentru crearea unui tunel SSH
start_ssh_tunnel() {
    local remote_host=$1
    local remote_port=$2
    local local_port=$3
    local username=$4

    echo -e "\nCreare tunel SSH..."
    ssh -N -L "$local_port:localhost:$remote_port" "$username@$remote_host" &
    
    # Verifică dacă tunelul s-a creat cu succes
    sleep 2
    if ps aux | grep -v grep | grep "ssh -N -L $local_port:localhost:$remote_port" > /dev/null; then
        echo -e "${GREEN}Tunel SSH creat cu succes!${NC}"
        return 0
    else
        echo -e "${RED}Eroare la crearea tunelului SSH${NC}"
        return 1
    fi
}

# Funcție pentru pornirea OpenVPN
start_openvpn() {
    local config_file=$1
    
    echo -e "\nPornire OpenVPN..."
    if [ ! -f "$config_file" ]; then
        echo -e "${RED}Fișierul de configurare $config_file nu există!${NC}"
        return 1
    fi
    
    sudo openvpn --config "$config_file" --daemon
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}OpenVPN pornit cu succes!${NC}"
        return 0
    else
        echo -e "${RED}Eroare la pornirea OpenVPN${NC}"
        return 1
    fi
}

# Funcție pentru oprirea serviciilor
stop_services() {
    echo -e "\nOprire servicii..."
    
    # Oprește tunelurile SSH
    pkill -f "ssh -N -L"
    
    # Oprește OpenVPN
    sudo killall openvpn 2>/dev/null
    
    echo -e "${GREEN}Servicii oprite cu succes${NC}"
}

# Funcții pentru gestionarea conturilor SSH

create_ssh_user() {
    echo -e "\n=== Creare cont SSH nou ==="
    echo -n "Introduceți numele utilizatorului: "
    read -r username
    
    if id "$username" >/dev/null 2>&1; then
        echo -e "${RED}Utilizatorul există deja!${NC}"
        return 1
    fi
    
    password=$(openssl rand -base64 12)
    sudo useradd -m -s /bin/bash "$username"
    echo "$username:$password" | sudo chpasswd
    
    sudo mkdir -p "/home/$username/.ssh"
    sudo touch "/home/$username/.ssh/authorized_keys"
    sudo chown -R "$username:$username" "/home/$username/.ssh"
    sudo chmod 700 "/home/$username/.ssh"
    sudo chmod 600 "/home/$username/.ssh/authorized_keys"
    
    echo -e "${GREEN}Cont creat cu succes!${NC}"
    echo -e "Utilizator: ${YELLOW}$username${NC}"
    echo -e "Parolă: ${YELLOW}$password${NC}"
    
    echo "$(date +%Y-%m-%d) - Created user: $username" | sudo tee -a "$SSH_USERS_DIR/users.log"
}

create_trial_account() {
    echo -e "\n=== Generare cont trial SSH ==="
    username="trial$(date +%s)"
    password=$(openssl rand -base64 12)
    
    sudo useradd -m -s /bin/bash -e $(date -d "+$TRIAL_DURATION days" +%Y-%m-%d) "$username"
    echo "$username:$password" | sudo chpasswd
    
    echo -e "${GREEN}Cont trial creat cu succes!${NC}"
    echo -e "Utilizator: ${YELLOW}$username${NC}"
    echo -e "Parolă: ${YELLOW}$password${NC}"
    echo -e "Expiră în: ${YELLOW}$TRIAL_DURATION zile${NC}"
    
    echo "$(date +%Y-%m-%d) - Created trial user: $username" | sudo tee -a "$SSH_USERS_DIR/trials.log"
}

renew_account() {
    echo -e "\n=== Reînnoire cont SSH ==="
    echo -n "Introduceți numele utilizatorului: "
    read -r username
    
    if ! id "$username" >/dev/null 2>&1; then
        echo -e "${RED}Utilizatorul nu există!${NC}"
        return 1
    fi
    
    echo -n "Număr de zile pentru prelungire: "
    read -r days
    
    sudo chage -E $(date -d "+$days days" +%Y-%m-%d) "$username"
    echo -e "${GREEN}Cont reînnoit cu succes!${NC}"
    echo "$(date +%Y-%m-%d) - Renewed user: $username" | sudo tee -a "$SSH_USERS_DIR/renewals.log"
}

delete_account() {
    echo -e "\n=== Ștergere cont SSH ==="
    echo -n "Introduceți numele utilizatorului: "
    read -r username
    
    if ! id "$username" >/dev/null 2>&1; then
        echo -e "${RED}Utilizatorul nu există!${NC}"
        return 1
    fi
    
    if who | grep -q "^$username "; then
        echo -e "${RED}Utilizatorul este conectat! Deconectați-l mai întâi.${NC}"
        return 1
    fi
    
    sudo userdel -r "$username"
    echo -e "${GREEN}Cont șters cu succes!${NC}"
    echo "$(date +%Y-%m-%d) - Deleted user: $username" | sudo tee -a "$SSH_USERS_DIR/deletions.log"
}

check_connected_users() {
    echo -e "\n=== Utilizatori SSH conectați ==="
    who | grep -i pts
    echo -e "\nConexiuni active detaliate:"
    ss | grep -i ssh
}

list_all_accounts() {
    echo -e "\n=== Lista toate conturile SSH ==="
    echo -e "${YELLOW}Conturi active:${NC}"
    awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd
    
    echo -e "\n${YELLOW}Detalii conturi:${NC}"
    for user in $(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd); do
        expiry=$(sudo chage -l "$user" | grep "Account expires" | cut -d: -f2-)
        echo -e "Utilizator: ${GREEN}$user${NC}"
        echo -e "Data expirării: $expiry"
        echo "------------------------"
    done
}

# Funcție pentru meniul SSH
show_ssh_menu() {
    echo -e "\n=== Gestionare SSH ==="
    echo "1) Creare cont nou"
    echo "2) Generare cont trial"
    echo "3) Reînnoire cont"
    echo "4) Ștergere cont"
    echo "5) Verificare utilizatori conectați"
    echo "6) Lista toate conturile SSH"
    echo "7) Înapoi la meniul principal"
    echo -n "Alegeți opțiunea: "
}

# Procesare meniu SSH
process_ssh_menu() {
    while true; do
        show_ssh_menu
        read -r choice
        case $choice in
            1) create_ssh_user ;;
            2) create_trial_account ;;
            3) renew_account ;;
            4) delete_account ;;
            5) check_connected_users ;;
            6) list_all_accounts ;;
            7) return 0 ;;
            *) echo -e "${RED}Opțiune invalidă!${NC}" ;;
        esac
    done
}

# Meniu principal
show_menu() {
    echo -e "\n=== Manager VPN SSH SSL ==="
    echo "1. Gestionare SSH"
    echo "2. Verificare porturi"
    echo "3. Pornire/Oprire servicii"
    echo "4. Ieșire"
    echo -n "Alegerea ta: "
}

# Main loop
while true; do
    show_menu
    read -r choice
    case $choice in
        1) process_ssh_menu ;;
        2)
            echo -n "Introduceți host-ul: "
            read -r host
            verify_required_ports "$host"
            ;;
        3)
            echo -e "\n1. Pornire servicii"
            echo "2. Oprire servicii"
            echo -n "Alegerea ta: "
            read -r service_choice
            case $service_choice in
                1) start_services ;;
                2) stop_services ;;
                *) echo -e "${RED}Opțiune invalidă!${NC}" ;;
            esac
            ;;
        4)
            echo -e "\nLa revedere!"
            exit 0
            ;;
        *)
            echo -e "${RED}Opțiune invalidă!${NC}"
            ;;
    esac
done 