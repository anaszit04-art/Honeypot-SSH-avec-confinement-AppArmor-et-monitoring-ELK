#!/usr/bin/env python3
import socket
import threading
import json
import time
import os
from datetime import datetime, timedelta
import seccomp
import requests
from collections import defaultdict

# Configuration Webhook
WEBHOOK_URLS = [
    "https://webhook.site/ccee8b0c-1c0f-471d-9cdb-1dd4bfe1640d",
]

# Configuration Brute-Force
BRUTE_FORCE_THRESHOLD = 5
BRUTE_FORCE_WINDOW = 60

# Stockage des tentatives par IP
connection_attempts = defaultdict(list)
attempts_lock = threading.Lock()

def send_webhook_alert(ip, attempt_count, reason="brute_force", data_sample=None):
    """Envoie une alerte via webhook"""
    
    # Message selon le type d'alerte
    if reason == "brute_force":
        alert_level = "HIGH"
        description = f"Brute-force detected from {ip} - {attempt_count} attempts in 1 minute"
    elif reason == "suspicious_data":
        alert_level = "MEDIUM" 
        description = f"Suspicious data from {ip}"
    else:
        alert_level = "LOW"
        description = f"New connection from {ip}"
    
    # Payload pour webhook
    payload = {
        "timestamp": datetime.now().isoformat(),
        "alert_level": alert_level,
        "source_ip": ip,
        "attempt_count": attempt_count,
        "reason": reason,
        "description": description,
        "honeypot_port": 2222,
        "system": "ssh_honeypot_kali"
    }
    
    # Ajouter un echantillon des donnees si disponible
    if data_sample:
        payload["data_sample"] = data_sample[:100]
    
    # Envoyer a tous les webhooks configures
    for webhook_url in WEBHOOK_URLS:
        if not webhook_url:
            continue
            
        threading.Thread(
            target=_send_single_webhook,
            args=(webhook_url, payload, ip),
            daemon=True
        ).start()

def _send_single_webhook(webhook_url, payload, ip):
    """Envoie a un webhook specifique avec gestion d'erreur"""
    max_retries = 2
    timeout = 10
    
    for attempt in range(max_retries):
        try:
            response = requests.post(
                webhook_url,
                json=payload,
                timeout=timeout,
                headers={'Content-Type': 'application/json', 'User-Agent': 'SSH-Honeypot/1.0'}
            )
            
            if response.status_code in [200, 201, 202, 204]:
                print(f"Webhook alert sent for {ip}")
                return True
            else:
                print(f"Webhook HTTP {response.status_code} for {ip}")
                
        except requests.exceptions.Timeout:
            print(f"Webhook timeout for {ip}")
        except requests.exceptions.ConnectionError:
            print(f"Webhook connection error for {ip}")
        except requests.exceptions.RequestException as e:
            print(f"Webhook error for {ip}: {e}")
        
        # Attendre avant retry
        if attempt < max_retries - 1:
            time.sleep(2)
    
    return False

def is_brute_force(ip):
    """Verifie si une IP depasse le seuil de brute-force"""
    with attempts_lock:
        now = datetime.now()
        
        # Nettoyer les anciennes tentatives
        connection_attempts[ip] = [
            attempt_time for attempt_time in connection_attempts[ip]
            if now - attempt_time < timedelta(seconds=BRUTE_FORCE_WINDOW)
        ]
        
        # Ajouter la tentative actuelle
        connection_attempts[ip].append(now)
        current_attempts = len(connection_attempts[ip])
        
        # Verifier le seuil
        if current_attempts >= BRUTE_FORCE_THRESHOLD:
            # Envoyer alerte seulement aux seuils importants
            alert_points = [BRUTE_FORCE_THRESHOLD, 10, 20, 50]
            if current_attempts in alert_points:
                print(f"BRUTE-FORCE DETECTED: {ip} - {current_attempts} attempts")
                send_webhook_alert(ip, current_attempts, "brute_force")
            return True
        return False

def setup_seccomp():
    """Configure le filtre SECCOMP pour restreindre les appels systeme"""
    filter = seccomp.SyscallFilter(defaction=seccomp.ALLOW)
    
    # Liste des appels systeme autorises (whitelist)
    allowed_syscalls = [
        'read', 'write', 'close', 'socket', 'accept', 'bind', 
        'listen', 'sendto', 'recvfrom', 'setsockopt', 'getsockname',
        'getpeername', 'select', 'poll', 'epoll_wait', 'nanosleep',
        'clock_gettime', 'gettimeofday', 'exit', 'exit_group',
        'futex', 'brk', 'mmap', 'munmap', 'mprotect', 'access',
        'arch_prctl', 'set_tid_address', 'set_robust_list'
    ]
    
    # Bloquer tous les appels systeme sauf ceux autorises
    for syscall in seccomp.get_syscall_names():
        if syscall not in allowed_syscalls:
            filter.add_rule(seccomp.KILL, syscall)
    
    filter.load()

def handle_connection(client_socket, client_address):
    """Gere chaque tentative de connexion"""
    client_ip = client_address[0]
    
    try:
        # Verifier le brute-force AVANT de traiter la connexion
        if is_brute_force(client_ip):
            log_entry = {
                'timestamp': datetime.now().isoformat(),
                'ip': client_ip,
                'port': client_address[1],
                'data': 'BRUTE_FORCE_BLOCKED',
                'type': 'ssh_honeypot',
                'alert': 'brute_force',
                'attempt_count': len(connection_attempts[client_ip])
            }
            
            with open('/var/log/honeypot/attempts.json', 'a') as f:
                f.write(json.dumps(log_entry) + '\n')
                f.flush()
            
            # Fermer immediatement sans reponse
            client_socket.close()
            return
        
        # Appliquer SECCOMP pour ce thread
        setup_seccomp()
        
        # Envoyer une banniere SSH immediatement
        banner = "SSH-2.0-OpenSSH_8.4p1 Debian-5\r\n"
        client_socket.send(banner.encode())
        
        # Attendre les donnees avec timeout
        client_socket.settimeout(3.0)
        try:
            data = client_socket.recv(1024).decode('utf-8', errors='ignore')
        except socket.timeout:
            data = None
        
        # Detection de donnees suspectes
        if data and any(keyword in data.lower() for keyword in ['root', 'admin', 'password', 'passwd', 'ssh']):
            send_webhook_alert(client_ip, len(connection_attempts[client_ip]), "suspicious_data", data)
        
        # Creer l'entree de log
        log_entry = {
            'timestamp': datetime.now().isoformat(),
            'ip': client_ip,
            'port': client_address[1],
            'data': data[:200] if data else 'CONNECTION_ONLY',
            'type': 'ssh_honeypot',
            'attempt_count': len(connection_attempts[client_ip])
        }
        
        print(f"[{datetime.now().strftime('%H:%M:%S')}] Attaque de {client_ip} (tentative {len(connection_attempts[client_ip])})")
        if data:
            print(f"   Donnees: {data[:100]}...")
        
        # Sauvegarder dans le fichier JSON
        with open('/var/log/honeypot/attempts.json', 'a') as f:
            f.write(json.dumps(log_entry) + '\n')
            f.flush()  # Force l'ecriture immediate
            
        # Garder la connexion un moment
        time.sleep(1)
        
    except Exception as e:
        print(f"Erreur avec {client_ip}: {e}")
    finally:
        try:
            client_socket.close()
        except:
            pass

def start_honeypot():
    """Démarre le honeypot SSH"""
    print("HONEYPOT SSH - KALI LINUX")
    print("Port: 2222")
    print("Logs: /var/log/honeypot/attempts.json")
    print(f"Brute-Force: {BRUTE_FORCE_THRESHOLD} tentatives / {BRUTE_FORCE_WINDOW}s")
    print("SECCOMP: Active")
    print("AppArmor: Active")
    print(f"Webhooks: {len(WEBHOOK_URLS)} configure(s)")
    print("Ctrl+C pour arreter")
    print("-" * 50)
    
    # Creer le socket
    server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server_socket.settimeout(1.0)  # Timeout pour accepter
    
    try:
        server_socket.bind(('0.0.0.0', 2222))
        server_socket.listen(5)
        
        print("Honeypot actif - En attente d'attaques...")
        
        while True:
            try:
                client_socket, client_address = server_socket.accept()
                print(f"Nouvelle connexion: {client_address[0]}:{client_address[1]}")
                
                # Demarrer un thread pour gerer la connexion
                thread = threading.Thread(
                    target=handle_connection, 
                    args=(client_socket, client_address),
                    daemon=True
                )
                thread.start()
                
            except socket.timeout:
                # Timeout normal pour accepter, continue
                continue
            except Exception as e:
                print(f"Erreur accept: {e}")
                continue
                
    except KeyboardInterrupt:
        print("\nArret du honeypot...")
    except Exception as e:
        print(f"ERREUR CRITIQUE: {e}")
    finally:
        server_socket.close()
        print("Honeypot arrete")

if __name__ == "__main__":
    # Creer le dossier de logs
    os.makedirs('/var/log/honeypot', mode=0o755, exist_ok=True)
    
    # Verifier les permissions
    if os.getuid() != 0:
        print("Conseil: Executez avec 'sudo' pour de meilleures permissions")
    
    start_honeypot()
