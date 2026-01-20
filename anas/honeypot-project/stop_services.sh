#!/bin/bash
echo "Arret des services Honeypot..."

# Arreter le honeypot
echo "Arret du honeypot SSH..."
sudo pkill -f "honeypot_ssh.py"

# Arreter ELK si running
echo "Arret de la stack ELK..."
docker-compose down 2>/dev/null

# Verifier l'arret
if pgrep -f "honeypot_ssh.py" > /dev/null; then
    echo "Honeypot toujours en cours, kill force..."
    sudo pkill -9 -f "honeypot_ssh.py"
fi

echo "Tous les services sont arretes"
