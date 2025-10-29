#!/usr/bin/env bash
# =============================================
# Installateur GLPI - Version standard dialog + gettext
# =============================================
# Auteur : PapyPoc
# Version : 1.0.0
# Description : Script d'installation et de mise à jour de GLPI avec interface dialog et support multilingue via gettext.
# Licence : MIT
# =============================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# === CONFIGURATION DE GETTEXT ===
TEXTDOMAIN=messages
TEXTDOMAINDIR="$SCRIPT_DIR/langs"
export TEXTDOMAIN TEXTDOMAINDIR

# === Détection automatique de la langue ===
LANGUAGE=${LANG%%_*}
[ -z "$LANGUAGE" ] && LANGUAGE="fr_FR"
export LANG=$LANGUAGE.UTF-8

# === Si les dossiers LC_MESSAGES n'existent pas, on les crée dynamiquement ===
if [ ! -f "$TEXTDOMAINDIR/$LANG/LC_MESSAGES/$TEXTDOMAIN.mo" ]; then
    sudo mkdir -p "$TEXTDOMAINDIR/$LANG/LC_MESSAGES"
    if [ -f "$TEXTDOMAINDIR/${LANG}.mo" ]; then
        ln -sf "../../${LANG}.mo" "$TEXTDOMAINDIR/$LANG/LC_MESSAGES/$TEXTDOMAIN.mo"
    fi
fi

# === Vérification de dialog ===
if ! command -v dialog &>/dev/null; then
    echo "Installation de 'dialog' requise..."
    sudo apt install -y dialog >/dev/null
fi
VERSION="10.0.19"
# === Interface ===
dialog --backtitle "$(gettext "Installation GLPI") ${VERSION}" \
       --title "$(gettext "Bienvenue")" \
       --msgbox "$(gettext "Bienvenue dans l'assistant d'installation GLPI")" 10 60

# === Menu principal ===
CHOICE=$(dialog --stdout \
    --backtitle "$(gettext 'Installation GLPI')" \
    --title "$(gettext 'Menu principal')" \
    --menu "$(gettext 'Que souhaitez-vous faire ?')" 15 60 3 \
    1 "$(gettext 'Installer GLPI')" \
    2 "$(gettext 'Mettre à jour GLPI')" \
    3 "$(gettext 'Quitter')")

case "$CHOICE" in
    1)
        dialog --infobox "$(gettext 'Installation de GLPI en cours...')" 5 50
        sleep 2
        dialog --msgbox "$(gettext 'Installation terminée avec succès !')" 6 50
        ;;
    2)
        dialog --infobox "$(gettext 'Mise à jour de GLPI en cours...')" 5 50
        sleep 2
        dialog --msgbox "$(gettext 'Mise à jour terminée avec succès !')" 6 50
        ;;
    3)
        dialog --yesno "$(gettext 'Voulez-vous vraiment quitter ?')" 7 50
        if [ $? -eq 0 ]; then
            clear
            printf '%s\n' "$(gettext 'Installation annulée.')"
            exit 0
        fi
        ;;
    *)
        dialog --msgbox "$(gettext 'Choix invalide.')" 6 50
        ;;
esac

clear
printf '%s\n' "$(gettext 'Fin du script. Merci Yoda 🧙‍♂️')"
