#!/usr/bin/env bash
set -Eeuo pipefail
clear
REP_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORIG_USER="${SUDO_USER:-$(logname 2>/dev/null || echo "${USER:-unknown}")}"
DEPENDENCIES="curl jq openssl sudo dialog git shellcheck"
GIT="https://github.com/PapyPoc/glpi_install.git"
BRANCHE="dev"
ERRORFILE="${REP_SCRIPT}/error.log"
LOGFILE="${REP_SCRIPT}/debug.log"
export ORIG_USER REP_SCRIPT GIT BRANCHE
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
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing="${missing:+$missing }$cmd"
        fi
    done
    if [ -z "$missing" ]; then
        return 0
    fi
    echo "Dépendances manquantes : ${missing}. Tentative d'installation..."
    local pkgmgr install_cmd
    local pkgs="$missing"
    if command -v apt-get >/dev/null 2>&1; then
        pkgmgr="apt-get"
        install_cmd="${pkgmgr} update -qq && ${pkgmgr} install -y -qq ${pkgs}"
    elif command -v dnf >/dev/null 2>&1; then
        pkgmgr="dnf"
        install_cmd="${pkgmgr} install -y -q ${pkgs}"
    elif command -v yum >/dev/null 2>&1; then
        pkgmgr="yum"
        install_cmd="${pkgmgr} install -y -q ${pkgs}"
    elif command -v apk >/dev/null 2>&1; then
        pkgmgr="apk"
        install_cmd="${pkgmgr} add --no-cache ${pkgs}"
    elif command -v pacman >/dev/null 2>&1; then
        pkgmgr="pacman"
        install_cmd="${pkgmgr} -Syu --noconfirm ${pkgs}"
    elif command -v zypper >/dev/null 2>&1; then
        pkgmgr="zypper"
        install_cmd="${pkgmgr} install -y ${pkgs}"
    else
        warn "Aucun gestionnaire de paquets pris en charge trouvé pour installer : ${pkgs}"
        return 1
    fi
    info "Installation via ${pkgmgr} : ${pkgs}"
    if ! bash -c "$install_cmd"; then
        warn "Échec de l'installation des dépendances : ${pkgs}"
        return 1
    fi
    local still_missing=""
    for cmd in $list; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            still_missing="${still_missing:+$still_missing }$cmd"
        fi
    done
    if [ -n "$still_missing" ]; then
        warn "Commandes toujours manquantes après l'installation : ${still_missing}"
        sleep 3
        return 1
    fi
    NEED_RESTART=1
    export NEED_RESTART
    return 0
}
function on_error_install() {
    local rc=$?
    local cmd=$BASH_COMMAND
    local line=${BASH_LINENO[0]}

    echo "Erreur détectée : '${cmd}' (code=$rc) à la ligne $line" | tee -a "$ERRORFILE" >&2
    echo "Pile d’appels :" >> "$ERRORFILE"
    for ((i=${#FUNCNAME[@]}-1; i>=0; i--)); do
        echo "  ↳ ${FUNCNAME[$i]}() depuis ${BASH_SOURCE[$i]}:${BASH_LINENO[$((i-1))]}" >> "$ERRORFILE"
    done
    echo "──────────────────────────────" >> "$ERRORFILE"

    dialog --msgbox "Une erreur est survenue.\n\nCommande : ${cmd}\nCode : ${rc}\n\nConsultez $ERRORFILE pour plus d’informations." 40 90 || true
    exit "$rc"
}
trap 'on_error_install' ERR
if source /etc/os-release 2>/dev/null; then
    DISTRO_ID=$(echo "$ID" | tr '[:upper:]' '[:lower:]')
    info "Distribution détectée : ${DISTRO_ID^} ${VERSION_ID:-}"
else
    warn "Distribution non détectée ou non prise en charge."
    exit 1
fi
case "${DISTRO_ID}" in
    debian|ubuntu)
        ADMIN_GROUP="sudo"
        ;;
    centos|rhel|rocky|almalinux|fedora)
        ADMIN_GROUP="wheel"
        ;;
    *)
        ADMIN_GROUP="sudo"
        info "Distribution non reconnue. Utilisation de '${ADMIN_GROUP}' par défaut."
        ;;
esac
if [ "$EUID" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
        info "Relance du script avec privilèges administrateur via sudo..."
        exec sudo -E bash "$0" "$@"
    elif command -v su >/dev/null 2>&1; then
        info "Relance du script avec privilèges administrateur via su..."
        exec su -c "bash '$0' $*"
    else
        warn "Aucune commande disponible pour élever les privilèges (sudo/su)."
        exit 1
    fi
fi
if ensure_dependencies "${DEPENDENCIES}"; then
    info "Toutes les dépendances sont satisfaites."
else
    warn "Échec de la vérification ou installation des dépendances."
    exit 1
fi
if [ "${NEED_RESTART:-0}" -eq 1 ]; then
    info "Dépendances installées. Redémarrage du script..."
    sleep 3
    exec bash "${REP_SCRIPT}/$(basename "$0")" "$@"
fi
if [ -d "${REP_SCRIPT}/glpi_install" ]; then
    cd "${REP_SCRIPT}/glpi_install" && git pull origin "${BRANCHE}" && cd ..
else
    git clone "${GIT}" -b "${BRANCHE}" "${REP_SCRIPT}/glpi_install" || {
        warn "Échec du clonage du dépôt git ${GIT}."
        exit 1
    }
fi
# Vérification d’existence 
if [ ! -f "${REP_SCRIPT}/glpi_install/glpi-install" ]; then
    warn "Le script '${REP_SCRIPT}/glpi_install/glpi-install' est introuvable." | tee -a "${ERRORFILE}"
    dialog --title "Attention" \
           --msgbox "Erreur : le fichier '${REP_SCRIPT}/glpi_install/glpi-install' est introuvable." 7 70
    exit 1
fi 
# Vérification des permissions
if [ ! -x "${REP_SCRIPT}/glpi_install/glpi-install" ]; then
    sudo chmod +x "${REP_SCRIPT}/glpi_install/glpi-install" 2>/dev/null
else 
        warn "Impossible de rendre '${REP_SCRIPT}/glpi_install/glpi-install' exécutable (droits insuffisants)." | tee -a "${ERRORFILE}"
        dialog --title "Attention" \
               --msgbox "Erreur : impossible d'exécuter '${REP_SCRIPT}/glpi_install/glpi-install'. Vérifiez vos droits." 7 70
        exit 1
fi
# Exécution sécurisée
if bash "${REP_SCRIPT}/glpi_install/glpi-install" >> "${LOGFILE}" 2>&1; then
    info "Exécution réussie de ${REP_SCRIPT}/glpi_install/glpi-install" | tee -a "${LOGFILE}"
else
    warn "Échec de l'exécution de ${REP_SCRIPT}/glpi_install/glpi-install" | tee -a "${ERRORFILE}"
    dialog --title "Attention" \
           --msgbox "Erreur : l'exécution du script '${REP_SCRIPT}/glpi_install/glpi-install' a échoué. Consultez le log." 8 70
    exit 1
fi