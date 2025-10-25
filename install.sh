#!/usr/bin/env bash
#
# GLPI install script
# Author: PapyPoc
# Version: 1.9.0
# Install file
# Langage pris en compte français et anglais
#
#set -Eeuo pipefail
clear
# Langue du systeme
LANGUE="${LANG%%_*}"
# Variables d'environnement
REP_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORIG_USER="${SUDO_USER:-$(logname 2>/dev/null || echo "${USER:-unknown}")}"
DEPENDENCIES="curl jq openssl sudo dialog git"
GIT="https://github.com/PapyPoc/glpi_install.git"
BRANCHE="dev"
ERRORFILE="${REP_SCRIPT}/error.log"
DEBUGFILE="${REP_SCRIPT}/debug.log"
UPDATEFILE="${REP_SCRIPT}/update.log"
# Traduction des messages
if [ "$LANGUE" == "fr" ]; then
    # Messages pour la détection de la distribution et les privilèges
    MSG_INSTALL_SH_DETECT_DISTRO="Distribution détectée : "
    MSG_INSTALL_SH_DETECT_DISTRO_NONOK="Distribution non détectée ou non prise en charge."
    MSG_INSTALL_SH_CHECK_GROUP_1="Groupe non reconnu. Utilisation de '"
    MSG_INSTALL_SH_CHECK_GROUP_2="' par défaut."
    MSG_INSTALL_SH_USER_GROUP_1="L'utilisateur '${ORIG_USER}' appartient au groupe '"
    MSG_INSTALL_SH_USER_GROUP_2="'."
    MSG_INSTALL_SH_USER_GROUP_3="L'utilisateur '${ORIG_USER}' n'appartient pas au groupe '"
    MSG_INSTALL_SH_RESTART_SESSION="Relancez votre session."
    MSG_INSTALL_SH_RESTART_SCRIPT_SUDO="Relance du script avec privilèges administrateur via sudo..."
    MSG_INSTALL_SH_RESTART_SCRIPT_SU="Relance du script avec privilèges administrateur via su..."
    MSG_INSTALL_SH_RESTART_ERROR="Aucune commande disponible pour élever les privilèges (sudo/su)."
    # Messages pour la gestion des dépendances
    MSG_INSTALL_SH_DEPENDENCIES_MISSING_01="Dépendances manquantes: "
    MSG_INSTALL_SH_DEPENDENCIES_MISSING_02=". Tentative d'installation..."
    MSG_INSTALL_SH_DEPENDENCIES_SATISFIED="Toutes les dépendances sont satisfaites."
    MSG_INSTALL_SH_DEPENDENCIES_FAILED="Échec de la vérification ou installation des dépendances."
    MSG_INSTALL_SH_PACKAGE_MANAGER_NOT_FOUND="Aucun gestionnaire de paquets pris en charge trouvé pour installer :"
    MSG_INSTALL_SH_DEPENDENCIES_INSTALL_FAILED="Échec de l'installation des dépendances :"
    MSG_INSTALL_SH_DEPENDENCIES_MISSING_AFTER_INSTALL="Commandes toujours manquantes après l'installation :"
    MSG_INSTALL_SH_DEPENDENCIES_INSTALLED="Dépendances installées. Redémarrage du script..."
    # Messages pour Github
    MSG_INSTALL_SH_GITHUB_CLONE="Clonage du dépôt git ${GIT} (branche: ${BRANCHE})"
    MSG_INSTALL_SH_GITHUB_CLONE="Clonage du dépôt git ${GIT} (branche: ${BRANCHE})"
    MSG_INSTALL_SH_GITHUB_UPDATE="Mise à jour du dépôt git ${GIT} (branche: ${BRANCHE})"
    MSG_INSTALL_SH_GITHUB_CLONE_FAILED="Échec du clonage du dépôt git ${GIT}."
    # Messages dépôt git
    MSG_INSTALL_SH_GITHUB_SCRIPT_NOT_FOUND="Le script '${REP_SCRIPT}/glpi_install/glpi-install' est introuvable."
    # Messages execution script
    MSG_INSTALL_SH_GITHUB_SCRIPT_EXECUTED="Exécution réussie de ${REP_SCRIPT}/glpi_install/glpi-install"
    MSG_INSTALL_SH_GITHUB_SCRIPT_EXECUTION_FAILED="Échec de l'exécution de ${REP_SCRIPT}/glpi_install/glpi-install"
elif [ "$LANGUE" == "en" ]; then
    # Messages for distro detection and privileges
    MSG_INSTALL_SH_DETECT_DISTRO="Detected distribution: "
    MSG_INSTALL_SH_DETECT_DISTRO_NONOK="Distribution not detected or not supported."
    MSG_INSTALL_SH_CHECK_GROUP_1="Unrecognized group. Using "
    MSG_INSTALL_SH_CHECK_GROUP_2=" by default."
    MSG_INSTALL_SH_USER_GROUP_1="User ${ORIG_USER} belongs to group "
    MSG_INSTALL_SH_USER_GROUP_2="."
    MSG_INSTALL_SH_RESTART_SESSION="Please restart your session."
    MSG_INSTALL_SH_RESTART_SCRIPT_SUDO="Restarting script with administrator privileges via sudo..."
    MSG_INSTALL_SH_RESTART_SCRIPT_SU="Restarting script with administrator privileges via su..."
    MSG_INSTALL_SH_RESTART_ERROR="No command available to elevate privileges (sudo/su)."
    # Messages for dependency management
    MSG_INSTALL_SH_DEPENDENCIES_MISSING_01="Missing dependencies: "
    MSG_INSTALL_SH_DEPENDENCIES_MISSING_02=". Attempting to install..."
    MSG_INSTALL_SH_DEPENDENCIES_SATISFIED="All dependencies are satisfied."
    MSG_INSTALL_SH_DEPENDENCIES_FAILED="Failed to verify or install dependencies."
    MSG_INSTALL_SH_PACKAGE_MANAGER_NOT_FOUND="No supported package manager found to install:"
    MSG_INSTALL_SH_DEPENDENCIES_INSTALL_FAILED="Failed to install dependencies:"
    MSG_INSTALL_SH_DEPENDENCIES_MISSING_AFTER_INSTALL="Commands still missing after installation:"
    MSG_INSTALL_SH_DEPENDENCIES_INSTALLED="Dependencies installed. Restarting script..."
    # Messages for Github
    MSG_INSTALL_SH_GITHUB_CLONE="Cloning git repository ${GIT} (branch: ${BRANCHE})"
    MSG_INSTALL_SH_GITHUB_UPDATE="Updating git repository ${GIT} (branch: ${BRANCHE})"
    MSG_INSTALL_SH_GITHUB_CLONE_FAILED="Failed to clone git repository ${GIT}."
    MSG_INSTALL_SH_GITHUB_SCRIPT_NOT_FOUND="The script ${REP_SCRIPT}/glpi_install/glpi-install is not found."
    MSG_INSTALL_SH_GITHUB_SCRIPT_EXECUTED="Successful execution of ${REP_SCRIPT}/glpi_install/glpi-install"
    MSG_INSTALL_SH_GITHUB_SCRIPT_EXECUTION_FAILED="Failed to execute ${REP_SCRIPT}/glpi_install/glpi-install"   
fi
: > "${ERRORFILE}"
: > "${DEBUGFILE}"
: > "${UPDATEFILE}"
function warn(){ 
    echo -e "\033[0;31m[ERREUR]\033[0m $1";
}
function info(){
    echo -e "\033[0;36m[INFO]\033[0m $1";
}
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
    info "${MSG_INSTALL_SH_DEPENDENCIES_MISSING_01}${missing}${MSG_INSTALL_SH_DEPENDENCIES_MISSING_02}"
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
        warn "${MSG_INSTALL_SH_PACKAGE_MANAGER_NOT_FOUND}"
        return 1
    fi
    info "Installation via ${pkgmgr} : ${pkgs}"
    if ! bash -c "$install_cmd 1>>${UPDATEFILE} 2>>${ERRORFILE}"; then
        warn "${MSG_INSTALL_SH_DEPENDENCIES_INSTALL_FAILED} ${pkgs}"
        return 1
    fi
    local still_missing=""
    for cmd in $list; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            still_missing="${still_missing:+$still_missing }$cmd"
        fi
    done
    if [ -n "$still_missing" ]; then
        warn "${MSG_INSTALL_SH_DEPENDENCIES_MISSING_AFTER_INSTALL} ${still_missing}"
        sleep 3
        return 1
    fi
    NEED_RESTART=1
    export NEED_RESTART
    return 0
}
# Détection de la distribution
if . /etc/os-release 2>/dev/null; then
    DISTRO_ID=$(echo "$ID" | tr '[:upper:]' '[:lower:]')
    info "${MSG_INSTALL_SH_DETECT_DISTRO}${DISTRO_ID^} ${VERSION_ID:-}"
else
    warn "${MSG_INSTALL_SH_DETECT_DISTRO_NONOK}"
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
        info "${MSG_INSTALL_SH_CHECK_GROUP_1}${ADMIN_GROUP}${MSG_INSTALL_SH_CHECK_GROUP_2}"
        ;;
esac
# Vérification des privilèges administrateur
if [ "$EUID" -ne 0 ]; then
    # Vérification si l'utilisateur fait partie du groupe administrateur
    if id -nG "${ORIG_USER}" | grep -qw "${ADMIN_GROUP}"; then
        info "${MSG_INSTALL_SH_USER_GROUP_1}${ADMIN_GROUP}${MSG_INSTALL_SH_USER_GROUP_2}"
    else
        warn "${MSG_INSTALL_SH_USER_GROUP_3}${ADMIN_GROUP}'.\n${MSG_INSTALL_SH_RESTART_SESSION}"
        exit 0 
    fi
    if command -v sudo >/dev/null 2>&1; then
        info "${MSG_INSTALL_SH_RESTART_SCRIPT_SUDO}"
        exec sudo -E bash "$0" "$@"
    fi
    if command -v su >/dev/null 2>&1; then
        info "${MSG_INSTALL_SH_RESTART_SCRIPT_SU}"
        exec su -c "bash '$0' $*"
    else
        warn "${MSG_INSTALL_SH_RESTART_ERROR}"
        exit 1
    fi
fi
# Vérification et installation des dépendances
if ensure_dependencies "${DEPENDENCIES}"; then
    info "${MSG_INSTALL_SH_DEPENDENCIES_SATISFIED}"
else
    warn "${MSG_INSTALL_SH_DEPENDENCIES_FAILED}"
    exit 1
fi
# Redémarrer le script si des dépendances ont été installées
if [ "${NEED_RESTART:-0}" -eq 1 ]; then
    info "${MSG_INSTALL_SH_DEPENDENCIES_INSTALLED}"
    sleep 3
    exec bash "${REP_SCRIPT}/$(basename "$0")" "$@"
fi
# Clonage ou mise à jour du dépôt git
if [ -d "${REP_SCRIPT}/glpi_install" ]; then
    info "${MSG_INSTALL_SH_GITHUB_UPDATE}"
    cd "${REP_SCRIPT}/glpi_install" && git pull origin "${BRANCHE}" && cd ..
else
    info "${MSG_INSTALL_SH_GITHUB_CLONE}"
    git clone "${GIT}" -b "${BRANCHE}" "${REP_SCRIPT}/glpi_install" || {
        warn "${MSG_INSTALL_SH_GITHUB_CLONE_FAILED}"
        exit 1
    }
fi
# Vérification d’existence
if [  -f "${REP_SCRIPT}/glpi_install/glpi-install" ]; then
    sudo chmod +x "${REP_SCRIPT}/glpi_install/glpi-install" 2>/dev/null
else
    warn "${MSG_INSTALL_SH_GITHUB_SCRIPT_NOT_FOUND}" | tee -a "${ERRORFILE}"
    dialog --title "❌" \
           --msgbox "${MSG_INSTALL_SH_GITHUB_SCRIPT_NOT_FOUND}" 7 70
    exit 1
fi
# Exécution sécurisée
if bash "${REP_SCRIPT}/glpi_install/glpi-install"; then
    info "${MSG_INSTALL_SH_GITHUB_SCRIPT_EXECUTED}" | tee -a "${DEBUGFILE}"
else
    warn "${MSG_INSTALL_SH_GITHUB_SCRIPT_EXECUTION_FAILED}" | tee -a "${ERRORFILE}"
    dialog --title "❌" \
           --msgbox "Erreur : l'exécution du script '${REP_SCRIPT}/glpi_install/glpi-install' a échoué. Consultez le log." 8 70
    exit 1
fi