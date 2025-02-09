# VPN Manager

Manager pentru conexiuni VPN SSH SSL cu sistem de licențiere prin IP.

## Instalare Administrator

```bash
wget https://raw.githubusercontent.com/YOUR_USERNAME/vpnmanager/main/install.sh
chmod +x install.sh
sudo ./install.sh
```

## Instalare Client

```bash
wget https://raw.githubusercontent.com/YOUR_USERNAME/vpnmanager/main/client_install.sh
chmod +x client_install.sh
sudo ./client_install.sh
```

## Funcționalități

- Management conturi SSH
- Creare tuneluri VPN
- Verificare porturi
- Sistem de licențiere prin IP
- Management utilizatori
- Monitorizare conexiuni

## Cerințe

- Sistem bazat pe Debian/Ubuntu
- Root access
- OpenSSH Server
- OpenVPN

## Configurare

Porturile implicite verificate sunt:
- SSH: 22
- SSL: 443
- OpenVPN: 1194

Pentru a modifica porturile implicite, editați array-ul asociativ `REQUIRED_PORTS` din script.

## Note de Securitate

- Asigurați-vă că folosiți conexiuni criptate
- Nu stocați parole în script
- Verificați întotdeauna certificatele SSL
- Folosiți chei SSH în loc de parole când este posibil
- Rulați scriptul doar pe sisteme de încredere

## Contribuții

Contribuțiile sunt binevenite! Vă rugăm să creați un issue sau pull request pentru orice îmbunătățiri. 