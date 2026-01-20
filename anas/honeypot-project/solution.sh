# Nettoyer les logs système
sudo journalctl --vacuum-time=1d

# Nettoyer le cache apt
sudo apt clean

# Nettoyer les packages inutiles
sudo apt autoremove --purge

# Vérifier les gros fichiers
sudo du -sh /* 2>/dev/null | sort -hr | head -20
