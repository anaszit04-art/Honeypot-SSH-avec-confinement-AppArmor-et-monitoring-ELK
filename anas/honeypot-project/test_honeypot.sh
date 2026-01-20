#!/bin/bash
echo "TEST DU HONEYPOT SSH"

# Verifier si le honeypot tourne
if ! pgrep -f "honeypot_ssh.py" > /dev/null; then
    echo "ERREUR: Honeypot non demarre! Lancez: ./start_honeypot.sh"
    exit 1
fi

echo "1. Test de connexions normales..."
for i in {1..3}; do
    echo "   Connexion $i"
    timeout 2 nc localhost 2222
    sleep 1
done

echo ""
echo "2. Test de detection brute-force..."
echo "   Simulation de 8 connexions rapides..."
for i in {1..8}; do
    timeout 1 nc localhost 2222 &
    sleep 0.3
done
wait

echo ""
echo "3. Verification des logs..."
echo "   Tentatives enregistrees:"
sudo tail -n 5 /var/log/honeypot/attempts.json | jq '.' 2>/dev/null || sudo tail -n 5 /var/log/honeypot/attempts.json

echo ""
echo "Tests termines avec succes!"
