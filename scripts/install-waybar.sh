#!/bin/bash
# SevenOS Waybar Installation Script
# Usage: ./scripts/install-waybar.sh

set -e

echo "🎨 SevenOS Waybar - Installation"

# Créer le dossier Waybar
mkdir -p ~/.config/waybar

# Copier les fichiers depuis le dépôt
echo "📁 Copie des fichiers de configuration..."
cp ~/Code/OS/SevenOS/waybar/config.jsonc ~/.config/waybar/
cp ~/Code/OS/SevenOS/waybar/style.css ~/.config/waybar/

# Vérifier les permissions
chmod 644 ~/.config/waybar/config.jsonc
chmod 644 ~/.config/waybar/style.css

# Relancer Waybar
echo "🔄 Redémarrage de Waybar..."
if pids="$(pgrep -x waybar || true)" && [ -n "$pids" ]; then
    kill $pids || true
fi
sleep 0.5
waybar -c ~/.config/waybar/config.jsonc -s ~/.config/waybar/style.css &

echo "✅ Waybar SevenOS installée avec succès !"
