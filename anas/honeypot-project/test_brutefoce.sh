#!/bin/bash
echo "TEST DETECTION BRUTE-FORCE"

if ! pgrep -f "honeypot_ssh.py" > /dev/null; then
    echo "ERREUR: Honeypot non demarre!"
    exit 1
fi

echo "Simulation de 8 connexions rapides..."
for i in {1..8}; do
    echo "   Tentative $i/8"
    timeout 1 nc localhost 2222 &
    sleep 0.2
done

wait
echo ""
echo "Verifiez les logs: sudo tail -n 10 /var/log/honeypot/attempts.json"
