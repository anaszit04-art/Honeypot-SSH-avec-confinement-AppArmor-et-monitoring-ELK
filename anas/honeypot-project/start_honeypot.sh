#!/bin/bash
echo "HONEYPOT COMPLET - DEMARRAGE OPTIMISE"

cd ~/honeypot-project

echo "[1] Nettoyage des processus precedents..."
sudo pkill -f "python3 honeypot_ssh.py" 2>/dev/null
sudo docker-compose down 2>/dev/null
sleep 2

echo "[2] Verification AppArmor..."
if ! sudo aa-status | grep -q "python_honeypot"; then
    echo "ATTENTION: Chargement du profil AppArmor..."
    sudo apparmor_parser -r /etc/apparmor.d/python_honeypot
else
    echo "OK: Profil AppArmor actif"
fi

echo "[3] Verification des dependances Python..."
# Verifier si les modules Python sont installés
if ! python3 -c "import seccomp" 2>/dev/null; then
    echo "INSTALLATION: python-seccomp..."
    pip3 install python-seccomp
fi

if ! python3 -c "import requests" 2>/dev/null; then
    echo "INSTALLATION: requests..."
    pip3 install requests
fi

echo "[4] Creation des repertoires de logs..."
sudo mkdir -p /var/log/honeypot
sudo chmod 755 /var/log/honeypot
sudo touch /var/log/honeypot/attempts.json
sudo chmod 644 /var/log/honeypot/attempts.json

echo "[5] Demarrage ELK..."
sudo docker-compose up -d

echo "[6] Attente demarrage Elasticsearch..."
for i in {1..15}; do
    if curl -s http://localhost:9200 > /dev/null 2>&1; then
        echo "OK: Elasticsearch pret!"
        break
    fi
    if [ $i -eq 15 ]; then
        echo "ERREUR: Timeout Elasticsearch - verifiez les logs Docker"
        docker-compose logs elasticsearch
        exit 1
    fi
    echo "Attente Elasticsearch... ($i/15)"
    sleep 5
done

echo "[7] Verification Kibana..."
for i in {1..10}; do
    if curl -s http://localhost:5601 > /dev/null 2>&1; then
        echo "OK: Kibana pret!"
        break
    fi
    echo "Attente Kibana... ($i/10)"
    sleep 10
done

echo "[8] Etat des services ELK:"
sudo docker-compose ps

echo "[9] Demarrage du Honeypot SSH..."
echo ""
echo "=== INSTRUCTIONS ==="
echo "TEST RAPIDE: Ouvrez un NOUVEAU terminal et executez:"
echo "  cd ~/honeypot-project && ./test_bruteforce.sh"
echo ""
echo "TEST COMPLET (Hydra):"
echo "  cd ~/honeypot-project && ./test_hydra_optimized.sh"
echo ""
echo "=== INTERFACES ==="
echo "Kibana (visualisation): http://localhost:5601"
echo "Elasticsearch (API): http://localhost:9200"
echo "Webhook (alertes): https://webhook.site/#!/view/ccee8b0c-1c0f-471d-9cdb-1dd4bfe1640d"
echo ""
echo "=== SURVEILLANCE ==="
echo "Logs honeypot:    sudo tail -f /var/log/honeypot/attempts.json"
echo "Logs application: surveillez ce terminal"
echo "Alertes:          verifiez webhook.site"
echo ""
echo "=== CONTROLES ==="
echo "Arret: Ctrl+C dans ce terminal"
echo "Redemarrage: ./start_honeypot.sh"
echo "Arret complet: ./stop_services.sh"
echo ""

echo "Lancement du honeypot principal dans 5 secondes..."
echo "=== DEBUT DES LOGS HONEYPOT ==="
sleep 5

# Lancer le honeypot principal
sudo python3 honeypot_ssh.py
