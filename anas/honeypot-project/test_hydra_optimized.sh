#!/bin/bash
echo "TEST HYDRA OPTIMISE - Brute Force SSH"

# Configuration
HONEYPOT_HOST="localhost"
HONEYPOT_PORT="2222"
LOG_FILE="/var/log/honeypot/hydra_test.log"
TIMEOUT=300  # 5 minutes max

# Recherche des wordlists
echo "VERIFICATIONS INITIALES..."

if ! command -v hydra &> /dev/null; then
    echo "Hydra non installe, installation..."
    sudo apt update && sudo apt install -y hydra
fi

if ! pgrep -f "honeypot_ssh.py" > /dev/null; then
    echo "Honeypot non demarre!"
    echo "Lancez: sudo python3 honeypot_ssh.py"
    exit 1
fi

# Trouver les wordlists disponibles
echo "RECHERCHE DES WORDLISTS..."

USER_LIST=""
PASS_LIST=""

# Wordlists par defaut Kali Linux
POSSIBLE_USER_LISTS=(
    "/usr/share/wordlists/metasploit/unix_users.txt"
    "/usr/share/wordlists/seclists/Usernames/top-usernames-shortlist.txt"
    "/usr/share/wordlists/seclists/Usernames/xato-net-10-million-usernames.txt"
    "/usr/share/wordlists/common_users.txt"
    "/usr/share/wordlists/fasttrack.txt"
)

POSSIBLE_PASS_LISTS=(
    "/usr/share/wordlists/metasploit/unix_passwords.txt"
    "/usr/share/wordlists/seclists/Passwords/Common-Credentials/top-20-common-SSH-passwords.txt"
    "/usr/share/wordlists/seclists/Passwords/Common-Credentials/10-million-password-list-top-100.txt"
    "/usr/share/wordlists/seclists/Passwords/Common-Credentials/10-million-password-list-top-1000.txt"
    "/usr/share/wordlists/rockyou.txt"
    "/usr/share/wordlists/fasttrack.txt"
)

# Trouver une userlist valide
for user_list in "${POSSIBLE_USER_LISTS[@]}"; do
    if [ -f "$user_list" ]; then
        USER_LIST="$user_list"
        echo "Userlist trouvee: $USER_LIST"
        break
    fi
done

# Trouver une passlist valide
for pass_list in "${POSSIBLE_PASS_LISTS[@]}"; do
    if [ -f "$pass_list" ]; then
        PASS_LIST="$pass_list"
        echo "Passlist trouvee: $PASS_LIST"
        break
    fi
done

# Si pas de wordlists trouvees, creer des listes minimales
if [ -z "$USER_LIST" ]; then
    echo "CREATION USERLIST MINIMALE..."
    USER_LIST="/tmp/honeypot_users.txt"
    echo -e "root\nadmin\nuser\ntest\nssh\nubuntu\ndebian\nkali" > "$USER_LIST"
    echo "Userlist creee: $USER_LIST"
fi

if [ -z "$PASS_LIST" ]; then
    echo "CREATION PASSLIST MINIMALE..."
    PASS_LIST="/tmp/honeypot_passwords.txt"
    echo -e "password\n123456\nadmin\nroot\npass123\nssh\ntest\npassword123" > "$PASS_LIST"
    echo "Passlist creee: $PASS_LIST"
fi

# Nettoyer l'ancien log
sudo touch "$LOG_FILE"
sudo chmod 644 "$LOG_FILE"

echo "CIBLE: $HONEYPOT_HOST:$HONEYPOT_PORT"
echo "USERLIST: $USER_LIST"
echo "PASSLIST: $PASS_LIST"
echo "TIMEOUT: $TIMEOUT secondes"
echo "LOG: $LOG_FILE"
echo ""

# Lancer Hydra avec parametres optimises
echo "LANCEMENT DE HYDRA..."
timeout $TIMEOUT hydra \
    -L "$USER_LIST" \
    -P "$PASS_LIST" \
    -e nsr \
    -t 4 \
    -W 2 \
    -f \
    -I \
    -V \
    -s $HONEYPOT_PORT \
    -o "$LOG_FILE" \
    ssh://$HONEYPOT_HOST

HYDRA_EXIT=$?

echo ""
echo "ANALYSE DES RESULTATS:"

# Analyse des resultats
if [ $HYDRA_EXIT -eq 0 ]; then
    echo "Hydra termine normalement"
elif [ $HYDRA_EXIT -eq 124 ]; then
    echo "Hydra arrete (timeout apres ${TIMEOUT}s)"
else
    echo "Hydra arrete avec code: $HYDRA_EXIT"
fi

# Statistiques des logs honeypot
echo ""
echo "STATISTIQUES HONEYPOT:"
if [ -f "/var/log/honeypot/attempts.json" ]; then
    TOTAL_ATTEMPTS=$(wc -l < /var/log/honeypot/attempts.json 2>/dev/null || echo "0")
    BRUTE_FORCE_COUNT=$(grep -c "BRUTE_FORCE_BLOCKED" /var/log/honeypot/attempts.json 2>/dev/null || echo "0")
    UNIQUE_IPS=$(jq -r '.ip' /var/log/honeypot/attempts.json 2>/dev/null | sort -u | wc -l 2>/dev/null || echo "0")
    
    echo "   Tentatives totales: $TOTAL_ATTEMPTS"
    echo "   Blocages brute-force: $BRUTE_FORCE_COUNT"
    echo "   IPs uniques: $UNIQUE_IPS"
    
    # Dernieres alertes
    echo ""
    echo "DERNIERES ALERTES:"
    grep -o '"alert":"[^"]*"' /var/log/honeypot/attempts.json 2>/dev/null | tail -5 | uniq || echo "   Aucune alerte"
fi

# Resume Hydra
echo ""
echo "RESUME HYDRA:"
if [ -f "$LOG_FILE" ]; then
    HYDRA_ATTEMPTS=$(grep -c "login:" "$LOG_FILE" 2>/dev/null || echo "0")
    echo "   Tentatives Hydra: $HYDRA_ATTEMPTS"
    echo "   Dernieres lignes du log:"
    tail -5 "$LOG_FILE" 2>/dev/null || echo "   Log vide"
    
    # Afficher les resultats si trouves
    if grep -q "host:" "$LOG_FILE" 2>/dev/null; then
        echo ""
        echo "RESULTATS HYDRA:"
        grep "host:" "$LOG_FILE"
    fi
fi

echo ""
echo "Test Hydra termine!"
