#!/bin/bash
echo "=== INSTALLATION DES DÉPENDANCES KALI ==="

# Mettre à jour Kali
echo "[+] Mise à jour du système..."
sudo apt update && sudo apt upgrade -y

# Installer Docker
echo "[+] Installation de Docker..."
sudo apt install docker.io docker-compose -y
sudo systemctl enable docker
sudo systemctl start docker

# Ajouter l'utilisateur au groupe docker
sudo usermod -aG docker $USER

# Installer les packages Python
echo "[+] Installation des packages Python..."
pip3 install paramiko python-seccomp python-logstash

# Créer le dossier de logs
echo "[+] Création des dossiers..."
sudo mkdir -p /var/log/honeypot
sudo chmod 755 /var/log/honeypot

echo "[+] Installation terminée !"
echo "[!] Redémarrez votre session: sudo reboot"
