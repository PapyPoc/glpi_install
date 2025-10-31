#!/usr/bin/env bash
#
# GLPI install script
# Author: PapyPoc
# Version: 2.0.0
# Install file
# Langage pris en compte français et anglais
#
set -Eeuo pipefail
clear # Nettoyer le terminal
# Variables d'environnement
REP_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORIG_USER="${SUDO_USER:-$(logname 2>/dev/null || echo "${USER:-unknown}")}"
DEPENDENCIES="curl jq openssl sudo dialog git gettext"
GIT="https://github.com/PapyPoc/glpi_install.git"
BRANCHE="dev"
ERRORFILE="${REP_SCRIPT}/error.log"
DEBUGFILE="${REP_SCRIPT}/debug.log"
UPDATEFILE="${REP_SCRIPT}/update.log"
: > "${ERRORFILE}"
: > "${DEBUGFILE}"
: > "${UPDATEFILE}"
# Détection automatique de la langue du système
LANGUAGE=${LANG%%.*}
[ -z "$LANGUAGE" ] && LANGUAGE="fr_FR"
export LANG="${LANGUAGE}.UTF-8"
export LANGUAGE
# --- Configuration gettext ---
TEXTDOMAIN="messages"
TEXTDOMAINDIR="${REP_SCRIPT}/glpi_install/lang"
export TEXTDOMAIN TEXTDOMAINDIR
# --- Vérifie la présence du .mo et crée le lien symbolique attendu ---
if [ ! -f "$TEXTDOMAINDIR/$LANGUAGE/LC_MESSAGES/$TEXTDOMAIN.mo" ]; then
    sudo mkdir -p "$TEXTDOMAINDIR/$LANGUAGE/LC_MESSAGES"
    if [ -f "$TEXTDOMAINDIR/${LANGUAGE}.mo" ]; then
        sudo ln -sf "../../${LANGUAGE}.mo" \
            "$TEXTDOMAINDIR/$LANGUAGE/LC_MESSAGES/$TEXTDOMAIN.mo"
    fi
fi
export DIALOGOPTS="--ascii-lines"  # option alternative en cas de TTY incompatible
# Fonctions d'affichage des messages WARN
function warn(){ 
    echo -e "⚠️ \033[0;31m$1\033[0m" | tee -a "${ERRORFILE}"
}
# Fonctions d'affichage des messages INFO
function info(){
    echo -e "ℹ️ \033[0;36m$1\033[0m" | tee -a "${DEBUGFILE}"
}
# Fonction d'installation des dépendances
function ensure_dependencies(){
    NEED_RESTART=0
    local missing=""
    local list
    if [ $# -ge 1 ] && [ -n "$1" ]; then
        list="$1"
    else
        list="$DEPENDENCIES"
    fi
    for cmd in $list; do
        if ! command -v "$cmd" >/dev/null; then
            missing="${missing:+$missing }$cmd"
        fi
    done
    if [ -z "$missing" ]; then
        return 0
    fi
    info "$(gt "Dépendances manquantes:") ${missing}. $(gt "Tentative d'installation...")"
    local pkgmgr install_cmd
    local pkgs="$missing"
    if command -v apt-get >/dev/null; then
        pkgmgr="apt-get"
        install_cmd="${pkgmgr} update -qq && ${pkgmgr} install -y -qq ${pkgs}"
    elif command -v dnf >/dev/null; then
        pkgmgr="dnf"
        install_cmd="${pkgmgr} install -y -q ${pkgs}"
    elif command -v yum >/dev/null; then
        pkgmgr="yum"
        install_cmd="${pkgmgr} install -y -q ${pkgs}"
    elif command -v apk >/dev/null; then
        pkgmgr="apk"
        install_cmd="${pkgmgr} add --no-cache ${pkgs}"
    elif command -v pacman >/dev/null; then
        pkgmgr="pacman"
        install_cmd="${pkgmgr} -Syu --noconfirm ${pkgs}"
    elif command -v zypper >/dev/null; then
        pkgmgr="zypper"
        install_cmd="${pkgmgr} install -y ${pkgs}"
    else
        warn "$(gt "Aucun gestionnaire de paquets pris en charge trouvé pour installer :") ${pkgs}"
        return 1
    fi
    info "Installation via ${pkgmgr} : ${pkgs}"
    if ! bash -c "$install_cmd 1>>${UPDATEFILE} 2>>${ERRORFILE}"; then
        warn "$(gt "Échec de l'installation des dépendances :") ${pkgs}"
        return 1
    fi
    local still_missing=""
    for cmd in $list; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            still_missing="${still_missing:+$still_missing }$cmd"
        fi
    done
    if [ -n "$still_missing" ]; then
        warn "$(gt "Dépendances manquantes après installation :") ${still_missing}"
        sleep 3
        return 1
    fi
    NEED_RESTART=1
    export NEED_RESTART
    return 0
}
# Fonction de traduction
function gt(){
    gettext "$1"
}
# Détection de la distribution
if source /etc/os-release 2>/dev/null; then
    DISTRO_ID=$(echo "$ID" | tr '[:upper:]' '[:lower:]')
    info "$(gt "Distribution détectée :") ${DISTRO_ID^} ${VERSION_ID:-}"
else
    warn "$(gt "Distribution non détectée ou non prise en charge.")"
    exit 1
fi
# Définir le groupe administrateur en fonction de la distribution
case "${DISTRO_ID}" in
    debian|ubuntu)
        ADMIN_GROUP="sudo"
        ;;
    centos|rhel|rocky|almalinux|fedora)
        ADMIN_GROUP="wheel"
        ;;
    *)
        ADMIN_GROUP="sudo"
        info "$(gt "Groupe administrateur par défaut : ${ADMIN_GROUP} non reconnu. Utilisation de '${ADMIN_GROUP}' par défaut.")"
        ;;
esac
# Vérification des privilèges administrateur
if [ "$EUID" -ne 0 ]; then
    # Vérification si l'utilisateur fait partie du groupe administrateur
    if id -nG "${ORIG_USER}" | grep -qw "${ADMIN_GROUP}"; then
        info "$(gt "L'utilisateur ${ORIG_USER} appartient au groupe ${ADMIN_GROUP}.")"
    else
        warn "$(gt "L'utilisateur ${ORIG_USER} n'appartient pas au groupe ${ADMIN_GROUP}.")\n$(gt "Veuillez ajouter l'utilisateur au groupe ${ADMIN_GROUP}.")"
        sleep 3
        exit 0
    fi
    if command -v sudo >/dev/null 2>&1; then
        info "$(gt "Relance du script avec privilèges administrateur via sudo...")"
        exec sudo -E bash "$0" "$@"
    fi
    if command -v su >/dev/null 2>&1; then
        info "$(gt "Relance du script avec privilèges administrateur via su...")"
        exec su -c "bash '$0' $*"
    else
        warn "$(gt "Aucune commande disponible pour élever les privilèges (sudo/su).")"
        exit 1
    fi
fi
# Vérification et installation des dépendances
if ensure_dependencies "${DEPENDENCIES}"; then
    info "$(gt "Toutes les dépendances sont satisfaites.")"
else
    warn "$(gt "Échec de l'installation des dépendances :") ${pkgs}"
    exit 1
fi
# Redémarrer le script si des dépendances ont été installées
if [ "${NEED_RESTART:-0}" -eq 1 ]; then
    info "$(gt "Redémarrage du script...")"
    sleep 3
    exec bash "${REP_SCRIPT}/$(basename "$0")" "$@"
fi
# Clonage ou mise à jour du dépôt git
if [ -d "${REP_SCRIPT}/glpi_install" ]; then
    info "$(gt "Mise à jour du dépôt git '${GIT}' (branche: ${BRANCHE})")"
    cd "${REP_SCRIPT}/glpi_install"
    sudo git pull origin "${BRANCHE}" && cd ..
else
    info "$(gt "Clonage du dépôt git '${GIT}' (branche: ${BRANCHE})")"
    sudo git clone "${GIT}" -b "${BRANCHE}" "${REP_SCRIPT}/glpi_install" || {
        warn "$(gt "Échec du clonage du dépôt git '${GIT}' (branche: ${BRANCHE})")"
        exit 1
    }
fi
# Vérification d’existence
if [  -f "${REP_SCRIPT}/glpi_install/glpi-install" ]; then
    sudo chmod +x "${REP_SCRIPT}/glpi_install/glpi-install" 2>/dev/null
else
    warn "$(gt "Script d'installation non trouvé : ${REP_SCRIPT}/glpi_install/glpi-install")"
    dialog --title "$(gt "Erreur")" \
        --msgbox "$(gt "Script d'installation non trouvé : ${REP_SCRIPT}/glpi_install/glpi-install")" 7 70
    exit 1
fi
# Exécution sécurisée
if bash "${REP_SCRIPT}/glpi_install/glpi-install" | tee -a "${DEBUGFILE}"; then
    info "$(gt "Exécution du script '${REP_SCRIPT}/glpi_install/glpi-install' réussie.")"
else
    warn "$(gt "Échec de l'exécution du script '${REP_SCRIPT}/glpi_install/glpi-install'.")"
    dialog --title "$(gt "Erreur")" \
        --msgbox "$(gt "L'exécution du script '${REP_SCRIPT}/glpi_install/glpi-install' a échoué. Consultez le log.")" 8 70
    exit 1
fi