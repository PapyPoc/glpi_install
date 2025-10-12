#!/usr/bin/env bash
#
# GLPI install script
# Author: PapyPoc
# Version: 1.8.0
# Script d'installation GLPI
# Langage pris en compte français et anglais
#
set -Eeuo pipefail
clear # Nettoyer le terminal
REP_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" # Répertoire du script
ORIG_USER="${SUDO_USER:-$(logname 2>/dev/null || echo "${USER:-unknown}")}" # Utilisateur d'origine
DEPENDENCIES="curl jq openssl sudo dialog git shellcheck" # Dépendances requises. Ajout de shellcheck
GIT="https://github.com/PapyPoc/glpi_install.git" # URL du dépôt git
BRANCHE="dev" # Branche git à utiliser
ERRORFILE="${REP_SCRIPT}/install_error.log" # Fichier de log des erreurs
SUCCESSFILE="${REP_SCRIPT}/install_success.log" # Fichier de log des succès
# Rediriger les erreurs vers le fichier de log
# exec 2>>"$ERRORFILE"
# Rediriger les sorties standard vers le fichier de log et vers le terminal
# exec >>"$SUCCESSFILE" 1>&1
export ORIG_USER REP_SCRIPT GIT BRANCHE
# Fonctions d'affichage
warn() {
    echo -e "\033[0;31m$1\033[0m"
}
info() {
    echo -e "\033[0;36m$1\033[0m"
}
# Vérifie et installe les dépendances manquantes
ensure_dependencies() {
    # Indique si une ré-exécution du script est nécessaire après installation
    NEED_RESTART=0
    local missing=""
    local list
    # Accepte soit une chaîne d'éléments séparés par des espaces, soit rien pour utiliser ${DEPENDENCIES}
    if [ $# -ge 1 ] && [ -n "$1" ]; then
        list="$1"
    else
        list="$DEPENDENCIES"
    fi
    # Boucle sur chaque mot de la liste (séparée par espaces)
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
    # Vérifie à nouveau si toutes les commandes sont présentes
    local still_missing=""
    for cmd in $list; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            still_missing="${still_missing:+$still_missing }$cmd"
        fi
    done
    if [ -n "$still_missing" ]; then
        warn "Commandes toujours manquantes après l'installation : ${still_missing}"
        sleep 5
        return 1
    fi
    NEED_RESTART=1
    export NEED_RESTART
    return 0
}
# Détection de la distribution
if source /etc/os-release 2>/dev/null; then
    DISTRO_ID=$(echo "$ID" | tr '[:upper:]' '[:lower:]')
    info "Distribution détectée : ${DISTRO_ID^} $(echo "${VERSION_ID}" | xargs)"
else
    warn "Distribution non détectée ou non prise en charge."
    exit 1
fi
# Détermination du groupe administrateur
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
# Vérification des droits root
if [ "$EUID" -ne 0 ]; then
    if id -nG "${ORIG_USER}" 2>/dev/null | grep -Eqw "sudo|wheel"; then
        info "Relance du script avec les droits administrateur..."
        sleep 2
        info "Utilisation de l'utilisateur ${ORIG_USER} avec les droits ${ADMIN_GROUP}."
        if command -v "${ADMIN_GROUP}" >/dev/null 2>&1; then
            exec "${ADMIN_GROUP}" -E "$0" "$@"
        else
            warn "Aucune commande disponible pour élever les privilèges (sudo/su)."
            goto finish
        fi
    else
        warn "L'utilisateur ${ORIG_USER} n'a pas les droits administrateur (${ADMIN_GROUP})."
        if command -v usermod >/dev/null 2>&1; then
            usermod -aG "$ADMIN_GROUP" "${ORIG_USER}" || true
        elif command -v adduser >/dev/null 2>&1; then
            # Cas Alpine ou BusyBox
            adduser "$ORIG_USER" "${ADMIN_GROUP}" || true
        else
            warn "Impossible d'ajouter ${ORIG_USER} au groupe ${ADMIN_GROUP} : aucune commande compatible trouvée."
            sleep 5
            goto finish
        fi
        warn "Ajout de ${ORIG_USER} au groupe ${ADMIN_GROUP}. Veuillez vous reconnecter et relancer le script."
        sleep 5
        goto finish
    fi
fi
# Vérification et installation des dépendances
if ensure_dependencies "${DEPENDENCIES}"; then
    info "Toutes les dépendances sont satisfaites."
    sleep 5
else
    warn "Échec de la vérification ou installation des dépendances."
    sleep 5
    goto finish
fi
if [ "${NEED_RESTART:-0}" -eq 1 ]; then
    info "Dépendances installées. Redémarrage du script..."
    sleep 5
    exec "$0" "$@"
fi
# Gestion du dépôt glpi_install
if [ -d "${REP_SCRIPT}/glpi_install" ]; then
    cd "${REP_SCRIPT}/glpi_install" && git pull origin "${BRANCHE}"&& cd ..
else
    git clone "${GIT}" -b "${BRANCHE}" "${REP_SCRIPT}/glpi_install" || {
        warn "Échec du clonage du dépôt git ${GIT}."
        goto finish
    }
fi
chmod +x "${REP_SCRIPT}/glpi_install/glpi-install"
# Lancer le script principal en remplaçant le processus courant
if [ -x "${REP_SCRIPT}/glpi_install/glpi-install" ]; then
    exec "${REP_SCRIPT}/glpi_install/glpi-install" "$@"
else
    warn "Le script '${REP_SCRIPT}/glpi_install/glpi-install' n'est pas exécutable ou introuvable."
    goto finish
fi
end install script
finish:
exit 0
# Fin du script d'installation