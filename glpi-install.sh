#!/bin/bash
#
# GLPI install script
# Author: PapyPoc & Poupix
# Version: 1.4.0
#

DEBIAN_VERSIONS=("11" "12") # Constante pour les versions de Debian acceptables
UBUNTU_VERSIONS=("23.10" "24.10") # Constante pour les versions d'Ubuntu acceptables
ALMA_VERSIONS=("9.5") # Constante pour les versions d'Almalinux acceptables
CENTOS_VERSIONS=("9") # Constante pour les versions de Centos acceptables
ROCKY_VERSIONS=("9.5") # Constante pour les versions de Rocky Linux acceptables
REDHAT_VERSIONS=("9.5") # Constante pour les versions de Red Hat acceptables
REP_SCRIPT="/root/glpi_install" # Constante pour le script d'installation de GLPI
REP_BACKUP="/root/glpi_sauve/" # Constante pour le répertoire de sauvergarde avant MàJ
REP_GLPI="/var/www/html/glpi/" # Constante pour le répertoire d'installation du site Web GLPI
SLQROOTPWD=$(openssl rand -base64 48 | cut -c1-18) # Constante pour le MdP root de MariaDB
SQLGLPIPWD=$(openssl rand -base64 48 | cut -c1-18) # Constante pour le MdP GLPI de MariaDB
ADMINGLPIPWD=$(openssl rand -base64 48 | cut -c1-12) # Constante pour pour le MdP du compte GLPI de GLPI
POSTGLPIPWD=$(openssl rand -base64 48 | cut -c1-12) # Constante pour pour le MdP du compte POST_ONLY de GLPI
TECHGLPIPWD=$(openssl rand -base64 48 | cut -c1-12) # Constante pour pour le MdP du compte TECH de GLPI
NORMGLPIPWD=$(openssl rand -base64 48 | cut -c1-12) # Constante pour pour le MdP du compte NORMAL de GLPI
CURRENT_DATE_TIME=$(date +"%d-%m-%Y_%H-%M-%S") # Constante pour la date courante
BDD_BACKUP="bdd_glpi-${CURRENT_DATE_TIME}.sql" # Constante pour le nommage du fichier DUMP de la BDD de GLPI
NEW_VERSION=$(curl -s https://api.github.com/repos/glpi-project/glpi/releases/latest | jq -r '.name') # Constante pour la dernière version de GLPI
TIMEZONE=$(timedatectl | grep "Time zone" | awk '{print $3}')
LANG=$(locale | grep LANG | cut -d= -f2 | cut -d. -f1)
function warn(){
    echo -e '\e[31m'"$1"'\e[0m';
}
function info(){
    echo -e '\e[36m'"$1"'\e[0m';
}
function check_root(){
    # Vérification des privilèges root
    if [[ "$(id -u)" -ne 0 ]]; then
            warn "Ce script doit étre exécuté en tant que root" >&2
            exit 0
    else
            info "Privilège Root: OK"
    fi
}
function compatible() {
    local version="$1"
    local -n versions_array="$2"
    [[ ${versions_array[*]} =~ ${version} ]]
}
function check_distro(){
    # Vérifie si le fichier os-release existe
    if [ -f /etc/os-release ]; then
    # Source le fichier /etc/os-release pour obtenir les informations de la distribution
    source /etc/os-release
    # Vérifie si la distribution est basée sur Debian, Ubuntu, Alma Linux, Centos ou Rocky Linux
        if [[ "${ID}" =~ ^(debian|ubuntu|almalinux|centos|rocky|rhel)$ ]]; then
            if compatible "${VERSION_ID}" DEBIAN_VERSIONS || compatible "${VERSION_ID}" UBUNTU_VERSIONS || compatible "${VERSION_ID}" ALMA_VERSIONS || compatible "${VERSION_ID}" CENTOS_VERSIONS || compatible "${VERSION_ID}" ROCKY_VERSIONS || compatible "${VERSION_ID}" REDHAT_VERSIONS; then
                info "La version de votre systeme d'exploitation (${ID} ${VERSION_ID}) est compatible."
            else
                warn "La version de votre système d'exploitation (${ID} ${VERSION_ID}) n'est pas considérée comme compatible."
                warn "Voulez-vous toujours forcer l'installation ? Attention, si vous choisissez de forcer le script, c'est à vos risques et périls."
                info "Etes-vous sûr de vouloir continuer ? [yes/no]"
                read -r response
                case "$response" in
                    O|o)
                        info "Continuing..."
                        ;;
                    N|n)
                        info "Exiting..."
                        exit 1
                        ;;
                    *)
                        warn "Réponse non valide. Quitter..."
                        exit 1
                        ;;
                esac
            fi
        fi
    else
        warn "Il s'agit d'une autre distribution que Debian ou Ubuntu qui n'est pas compatible."
        exit 1
    fi
}
function check_install(){
    # Vérifie si le répertoire existe
    if [ -d "$1" ]; then
        output=$(php ${REP_GLPI}bin/console -V 2>&1)
        sleep 2
        glpi_cli_version=$(sed -n 's/.*GLPI CLI \([^ ]*\).*/\1/p' <<< "$output")
        warn "Le site est déjà installé. Version ""$glpi_cli_version"
        info "Nouvelle version trouver : GLPI version $NEW_VERSION"
        if [ "$glpi_cli_version" == "$NEW_VERSION" ]; then
            info "Vous avez déjà la dernière version de GLPI. Mise à jour annuler"
            sleep 5
            exit 0;
        else
            info "Voulez-vous mettre à jour GLPI (O/N): "
            read -r MaJ
            case "$MaJ" in
                "O" | "o")
                    update
                    exit 0;;
                "N" | "n")
                    info "Sortie du programme."
                    efface_script
                    exit 0;;
                *)
                    warn "Action non reconnue. Sortie du programme."
                    efface_script
                    exit 0;;
            esac
        fi
    else
        warn "Nouvelle installation de GLPI"
        install
    fi
}
function update_distro(){
    if [[ "${ID}" =~ ^(debian|ubuntu)$ ]]; then
        info "Recherche des mises à jour"
        apt-get update > /dev/null 2>&1
        info "Application des mises à jour"
        apt-get upgrade -y > /dev/null 2>&1
    elif [[ "${ID}" =~ ^(almalinux|centos|rocky|rhel)$ ]]; then
        info "Recherche des mises à jour"
        dnf update -y > /dev/null 2>&1
        info "Application des mises à jour"
        dnf upgrade -y > /dev/null 2>&1
    fi
}
function network_info(){
    INTERFACE=$(ip route | awk 'NR==1 {print $5}')
    IPADRESS=$(ip addr show "$INTERFACE" | grep inet | awk '{ print $2; }' | sed 's/\/.*$//' | head -n 1)
    # HOST=$(hostname)
}
function install_packages(){
    if [[ "${ID}" =~ ^(debian|ubuntu)$ ]]; then
        sleep 1
        info "Installation des extensions de php"
        apt install -y --no-install-recommends php-{mysql,mbstring,curl,gd,xml,intl,ldap,apcu,opcache,xmlrpc,zip,bz2} > /dev/null 2>&1
        info "Installation des service lamp..."
        apt-get install -y --no-install-recommends sudo curl tar apache2 mariadb-server perl curl jq php > /dev/null 2>&1
        info "Activation de MariaDB"
        systemctl enable mariadb > /dev/null 2>&1
        info "Activation d'Apache"
        systemctl enable apache2 > /dev/null 2>&1
        info "Redémarage d'Apache"
        systemctl restart apache2 > /dev/null 2>&1
    elif [[ "${ID}" =~ ^(almalinux|centos|rocky|rhel)$ ]]; then
        sleep 1
        dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm > /dev/null 2>&1
        dnf module reset -y php nginx mariadb > /dev/null 2>&1
        dnf module install -y php:8.2 > /dev/null 2>&1
        dnf module install -y nginx:1.24 > /dev/null 2>&1
        dnf module install -y mariadb:10.11 > /dev/null 2>&1
        info "Activation des mises à jour automatique"
        dnf install dnf-automatic -y > /dev/null 2>&1
        sed -i 's/^\(;\?\)\(apply_updates =\).*/\2 yes/' /etc/dnf/automatic.conf
        sed -i 's/^\(;\?\)\(reboot =\).*/\2 when-needed/' /etc/dnf/automatic.conf
        sed -i 's/^\(;\?\)\(upgrade_type =\).*/\2 security/' /etc/dnf/automatic.conf
        mkdir /etc/systemd/system/dnf-automatic.timer.d
        cat > /etc/systemd/system/dnf-automatic.timer.d/override.conf << EOF
[Unit]
Description=dnf-automatic timer
ConditionPathExists=!/run/ostree-booted
Wants=network-online.target

[Timer]
OnCalendar=*-*-* 6:00
RandomizedDelaySec=60m
Persistent=true
EOF
        systemctl enable --now dnf-automatic.timer > /dev/null 2>&1
        info "Installation des extensions de php"
        dnf install -y php-{mysqlnd,mbstring,curl,gd,xml,intl,ldap,apcu,opcache,zip,bz2} > /dev/null 2>&1
        info "Installation des service lamp..."
        dnf install -y crontabs logrotate cronie tar nginx mariadb-server perl curl jq php epel-release > /dev/null 2>&1
        sed -i 's/^\(;\?\)\(user =\).*/\2 nginx/' /etc/php-fpm.d/www.conf
        sed -i 's/^\(;\?\)\(group =\).*/\2 nginx/' /etc/php-fpm.d/www.conf
        info "Activation et démarrage de MariaDB, d'ENGINE X et de PHP-FPM"
        systemctl enable --now mariadb nginx php-fpm > /dev/null 2>&1
        firewall-cmd --permanent --zone=public --add-service=http > /dev/null 2>&1
        firewall-cmd --reload > /dev/null 2>&1
    fi
}
function mariadb_configure(){
    info "Configuration de MariaDB"
    sleep 1
    systemctl start mariadb > /dev/null 2>&1
    (echo ""; echo "y"; echo "y"; echo "$SLQROOTPWD"; echo "$SLQROOTPWD"; echo "y"; echo "y"; echo "y"; echo "y") | mysql_secure_installation > /dev/null 2>&1
    sleep 1
    mysql -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost';" > /dev/null 2>&1
    # Create a new database
    mysql -e "CREATE DATABASE glpi;" > /dev/null 2>&1
    # Create a new user
    mysql -e "CREATE USER 'glpi_user'@'localhost' IDENTIFIED BY '$SQLGLPIPWD';" > /dev/null 2>&1
    # Grant privileges to the new user for the new database
    mysql -e "GRANT ALL PRIVILEGES ON glpi.* TO 'glpi_user'@'localhost';" > /dev/null 2>&1
    # Reload privileges
    mysql -e "FLUSH PRIVILEGES;" > /dev/null 2>&1
    # 
    mysql -e "GRANT SELECT ON mysql.time_zone_name TO 'glpi_user'@'localhost'" > /dev/null 2>&1
    # Initialize time zones datas
    info "Configuration de TimeZone"
    mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql -u root -p"$SLQROOTPWD" mysql > /dev/null 2>&1
    # Restart MariaDB
    systemctl restart mariadb
    sleep 1
}
function install_glpi(){
    info "Téléchargement et installation de la version ${NEW_VERSION} de GLPI..."
    # Get download link for the latest release
    DOWNLOADLINK=$(curl -s https://api.github.com/repos/glpi-project/glpi/releases/latest | jq -r '.assets[0].browser_download_url')
    wget -O /tmp/glpi-latest.tgz "$DOWNLOADLINK" > /dev/null 2>&1
    tar xzf /tmp/glpi-latest.tgz -C /var/www/html/
}
function setup_glpi(){
    info "Configuration de GLPI..."
    mkdir -p /var/log/glpi
    mkdir -p /etc/glpi/config
    mkdir -p /var/lib/glpi/files
    mv -f ${REP_GLPI}files /var/lib/glpi
    cat > /etc/glpi/config/local_define.php << EOF
<?php
    define('GLPI_VAR_DIR', '/var/lib/glpi/files');
    define('GLPI_LOG_DIR', '/var/log/glpi/config');
EOF
    sleep 1
    cat > ${REP_GLPI}inc/downstream.php << EOF
<?php
    define('GLPI_CONFIG_DIR', '/etc/glpi/config');
    if (file_exists(GLPI_CONFIG_DIR . '/local_define.php')) {
        require_once GLPI_CONFIG_DIR . '/local_define.php';
    }
EOF
    if [[ "${ID}" =~ ^(debian|ubuntu)$ ]]; then
        # Add permissions
        chown -R www-data:www-data  /etc/glpi
        chmod -R 777 /etc/glpi
        sleep 1
        chown -R www-data:www-data  /var/log/glpi
        chmod -R 777 /var/log/glpi
        sleep 1
        chown -R www-data:www-data /var/lib/glpi/files
        chmod -R 777 /var/lib/glpi/files
        sleep 1
        chown -R www-data:www-data ${REP_GLPI}
        chmod -R 777 ${REP_GLPI}
        sleep 1
        # Setup vhost
         cat > /etc/apache2/sites-available/glpi.conf << EOF
<VirtualHost *:80>
    ServerName glpi.lan
    DocumentRoot ${REP_GLPI}public
    <Directory ${REP_GLPI}public>
        Require all granted
        RewriteEngine On
        RewriteCond %{HTTP:Authorization} ^(.+)$
        RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteRule ^(.*)$ index.php [QSA,L]
    </Directory>
    ErrorLog /var/log/glpi/error.log
    CustomLog /var/log/glpi/access.log combined
</VirtualHost>
EOF
        phpversion=$(php -v | grep -i '(cli)' | awk '{print $2}' | cut -c 1,2,3)
        sed -i 's/^\(;\?\)\(session.cookie_httponly\).*/\2 =on/' /etc/php/"$phpversion"/apache2/php.ini
        sleep 1
        # Disable Apache Web Server Signature
        echo "ServerSignature Off" >> /etc/apache2/apache2.conf
        echo "ServerTokens Prod" >> /etc/apache2/apache2.conf
        # Activation du module rewrite d'apache
        a2enmod rewrite > /dev/null 2>&1
        # Déactivation du site par défaut et activation site glpi
        a2dissite 000-default.conf > /dev/null 2>&1
        a2ensite glpi.conf > /dev/null 2>&1
        # Restart d'apache
        systemctl restart apache2 > /dev/null 2>&1
        sudo -u www-data php ${REP_GLPI}bin/console db:install --db-host="localhost" --db-port=3306 --db-name=glpi --db-user=glpi_user --db-password="${SQLGLPIPWD}" --default-language="${LANG}" --force --no-telemetry --quiet --no-interaction
    elif [[ "${ID}" =~ ^(almalinux|centos|rocky|rhel)$ ]]; then
        chown -R nginx:nginx /etc/glpi
        chmod -R 777 /etc/glpi
        sleep 1
        chown -R nginx:nginx /var/log/glpi
        chmod -R 777 /var/log/glpi
        sleep 1
        chown -R nginx:nginx /var/lib/glpi
        chmod -R 777 /var/lib/glpi
        # Add permissions
        chown -R nginx:nginx ${REP_GLPI}
        chmod -R 777 ${REP_GLPI}
        sleep 1
        cat > /etc/nginx/conf.d/glpi.conf << EOF
server {
    listen 80;
    server_name glpi.localhost;
    root ${REP_GLPI}public;
    location / {
        try_files \$uri /index.php\$is_args\$args;
    }
    location ~ ^/index\.php$ {
        # the following line needs to be adapted, as it changes depending on OS distributions and PHP versions
        fastcgi_pass unix:/var/run/php-fpm/www.sock;
        fastcgi_split_path_info ^(.+\.php)(/.*)$;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }
}
EOF
        cat > /etc/logrotate.d/glpi << EOF
# Rotate GLPI logs daily, only if not empty
# Save 14 days old logs under compressed mode
/var/lib/glpi/files/_log/*.log {
    su nginx nginx
    daily
    rotate 14
    compress
    notifempty
    missingok
    create 644 nginx nginx
}
EOF
    chmod 0644 /etc/logrotate.d/glpi
    chown root:root /etc/logrotate.d/glpi
    chcon system_u:object_r:etc_t:s0 /etc/logrotate.d/glpi
    sed -i 's/^\(;\?\)\(session.cookie_httponly\).*/\2 = on/' /etc/php.ini > /dev/null 2>&1
    setsebool -P httpd_can_network_connect on
    setsebool -P httpd_can_network_connect_db on
    setsebool -P httpd_can_sendmail on
    semanage fcontext -a -t httpd_sys_rw_content_t "${REP_GLPI}(/.*)?" > /dev/null 2>&1
    semanage fcontext -a -t httpd_sys_rw_content_t "/var/lib/glpi(/.*)?" > /dev/null 2>&1
    semanage fcontext -a -t httpd_sys_rw_content_t "/var/log/glpi(/.*)?" > /dev/null 2>&1
    semanage fcontext -a -t httpd_sys_rw_content_t "/etc/glpi(/.*)?" > /dev/null 2>&1
    semanage fcontext -a -t httpd_sys_rw_content_t "${REP_GLPI}marketplace" > /dev/null 2>&1
    restorecon -R ${REP_GLPI} > /dev/null 2>&1
    restorecon -R /var/lib/glpi > /dev/null 2>&1
    restorecon -R /var/log/glpi > /dev/null 2>&1
    restorecon -R /etc/glpi > /dev/null 2>&1
    restorecon -R ${REP_GLPI}marketplace > /dev/null 2>&1
    # Restart de Nginx et php-fpm
    systemctl restart nginx php-fpm
    sudo -u nginx php ${REP_GLPI}bin/console db:install --db-host="localhost" --db-port=3306 --db-name=glpi --db-user=glpi_user --db-password="${SQLGLPIPWD}" --default-language="${LANG}" --force --no-telemetry --quiet --no-interaction 
    fi
    sleep 5
    rm -rf ${REP_GLPI}install/install.php
    sleep 5
    sed -i '$i \   public $date_default_timezone_set = ("'${TIMEZONE}'");' /etc/glpi/config/config_db.php
    # Change timezone and language
    mysql -e "INSERT INTO glpi.glpi_configs (context, name, value) VALUES ('core', 'timezone', '${TIMEZONE}');" > /dev/null 2>&1
    mysql -e "UPDATE glpi.glpi_configs SET value = "${LANG}" WHERE name = 'language';" > /dev/null 2>&1
    if [[ "${ID}" =~ ^(debian|ubuntu)$ ]]; then
        # Change permissions
        chown -Rc www-data:www-data /etc/glpi
        chmod -R 755 /etc/glpi
        chown -Rc www-data:www-data /var/log/glpi
        chmod -R 755 /var/log/glpi
        chown -Rc www-data:www-data ${REP_GLPI}
        chmod -R 755 ${REP_GLPI}
        systemctl restart apache2
        # Setup Cron task
        echo "*/2 * * * * www-data /usr/bin/php ${REP_GLPI}front/cron.php &>/dev/null" >> /etc/cron.d/glpi
    elif [[ "${ID}" =~ ^(almalinux|centos|rocky|rhel)$ ]]; then
         # Change permissions
        chown -R nginx:nginx /etc/glpi
        chmod -R 755 /etc/glpi
        chown -R nginx:nginx /var/log/glpi
        chmod -R 755 /var/log/glpi
        chown -R nginx:nginx ${REP_GLPI}
        chmod -R 755 ${REP_GLPI}
        systemctl restart nginx php-fpm
        echo "*/2 * * * * nginx /usr/bin/php ${REP_GLPI}front/cron.php &>/dev/null" >> /etc/cron.d/glpi
    fi
}
function maj_user_glpi(){
    info "Changement des mots de passe de GLPI..."
    # Changer le mot de passe de l'admin glpi 
    mysql -u glpi_user -p"${SQLGLPIPWD}" -e "USE glpi; UPDATE glpi_users SET password = MD5('${ADMINGLPIPWD}') WHERE name = 'glpi';"
    # Changer le mot de passe de l'utilisateur post-only
    mysql -u glpi_user -p"${SQLGLPIPWD}" -e "USE glpi; UPDATE glpi_users SET password = MD5('${POSTGLPIPWD}') WHERE name = 'post-only';"
    # Changer le mot de passe de l'utilisateur tech
    mysql -u glpi_user -p"${SQLGLPIPWD}" -e "USE glpi; UPDATE glpi_users SET password = MD5('${TECHGLPIPWD}') WHERE name = 'tech';"
    # Changer le mot de passe de l'utilisateur normal
    mysql -u glpi_user -p"${SQLGLPIPWD}" -e "USE glpi; UPDATE glpi_users SET password = MD5('${NORMGLPIPWD}') WHERE name = 'normal';"
}
function display_credentials(){
    info "<==========================> Détail de l'installation de GLPI <=================================>"
    info "GLPI Version: ${NEW_VERSION}"
    info "Répertoire d'installation de GLPI: ${REP_GLPI}"
    warn "Il est important d'enregistrer ces informations. Si vous les perdez, elles seront irrécupérables."
    echo ""
    info "Les comptes utilisateurs par défaut sont :"
    info "UTILISATEUR  -  MOT DE PASSE       -  ACCES"
    info "glpi         -  ${ADMINGLPIPWD}       -  compte admin"
    info "post-only    -  ${POSTGLPIPWD}       -  compte post-only"
    info "tech         -  ${TECHGLPIPWD}       -  compte tech"
    info "normal       -  ${NORMGLPIPWD}       -  compte normal"
    echo ""
    info "Vous pouvez accéder à la page web de GLPI à partir d'une adresse IP ou d'un nom d'hôte :"
    info "http://${IPADRESS}" 
    echo ""
    info "==> Database:"
    info "Mot de passe root: ${SLQROOTPWD}"
    info "Mot de passe glpi_user: ${SQLGLPIPWD}"
    info "Nom de la base de données GLPI: glpi"
    info "<===============================================================================================>"
    echo ""
    info "Si vous rencontrez un problème avec ce script, veuillez le signaler sur GitHub : https://github.com/PapyPoc/glpi_install/issues"
}
function write_credentials(){
    cat <<EOF > /root/sauve_mdp.txt
<==========================> Détail de l'installation de GLPI <=================================>
GLPI Version: ${NEW_VERSION}
Répertoire d'installation de GLPI: ${REP_GLPI}
Il est important d'enregistrer ces informations. Si vous les perdez, elles seront irrécupérables.

Les comptes utilisateurs par défaut sont :
UTILISATEUR       -  MOT DE PASSE       -  ACCES
info "glpi        -  ${ADMINGLPIPWD}       -  compte admin"
info "post-only   -  ${POSTGLPIPWD}       -  compte post-only"
info "tech        -  ${TECHGLPIPWD}       -  compte tech"
info "normal      -  ${NORMGLPIPWD}       -  compte normal"

Vous pouvez accéder à la page web de GLPI à partir d'une adresse IP ou d'un nom d'hôte :
http://${IPADRESS}

==> Database:
Mot de passe root: ${SLQROOTPWD}
Mot de passe glpi_user: ${SQLGLPIPWD}
Nom de la base de données GLPI: glpi
<===============================================================================================>

Si vous rencontrez un probléme avec ce script, veuillez le signaler sur GitHub : https://github.com/PapyPoc/glpi_install/issues
EOF
    chmod 700 /root/sauve_mdp.txt
    echo ""
    warn "Fichier de sauve_mdp.txt enregistrer dans /home"
    echo ""
}
function efface_script(){
    # Vérifie si le répertoire existe
    if [ -e "$REP_SCRIPT" ]; then
            warn "Le script est déjà présent."
            warn "Effacement en cours"
            rm -Rf "$REP_SCRIPT"
    fi
}
function install(){
    update_distro
    install_packages
    network_info
    mariadb_configure
    sleep 5
    install_glpi
    sleep 5
    setup_glpi
    sleep 5
    maj_user_glpi
    display_credentials
    write_credentials
    efface_script
}
function maintenance(){
    if [ "$1" == "1" ]; then
        warn "Mode maintenance activer"
        if [[ "${ID}" =~ ^(debian|ubuntu)$ ]]; then
            sudo www-data php ${REP_GLPI}bin/console glpi:maintenance:enable  > /dev/null 2>&1
        elif [[ "${ID}" =~ ^(almalinux|centos|rocky|rhel)$ ]]; then
            sudo nginx php ${REP_GLPI}bin/console glpi:maintenance:enable  > /dev/null 2>&1
        fi
    elif [ "$1" == "0" ]; then
        info "Mode maintenance désactiver"
        if [[ "${ID}" =~ ^(debian|ubuntu)$ ]]; then
            sudo www-data php ${REP_GLPI}bin/console glpi:maintenance:disable  > /dev/null 2>&1
        elif [[ "${ID}" =~ ^(almalinux|centos|rocky|rhel)$ ]]; then
            sudo nginx php ${REP_GLPI}bin/console glpi:maintenance:disable  > /dev/null 2>&1
        fi
    fi
}
function backup_glpi(){
        # Vérifie si le répertoire existe
        if [ ! -d "$REP_BACKUP" ]; then
            info "Création du  répertoire de sauvegarde avant mise à jour"
            mkdir "$REP_BACKUP"
        fi
        # Sauvergarde de la bdd
        info "Dump de la base de donnée"
        PASSWORD=$(sed -n 's/.*Mot de passe root: \([^ ]*\).*/\1/p' /root/sauve_mdp.txt)
        mysqldump -u root -p"$PASSWORD" --databases glpi > "${REP_BACKUP}${BDD_BACKUP}" > /dev/null 2>&1
        info "La base de donnée a été sauvergardé avec succè."
        # Sauvegarde des fichiers
        info "Sauvegarde des fichiers du sites"
        cp -Rf ${REP_GLPI} ${REP_BACKUP}backup_glpi
        info "Les fichiers du site GLPI ont été sauvegardés avec succès."
        info "Suppression des fichiers du site"
        rm -rf ${REP_GLPI}
}
function update_glpi(){
        info "Remise en place des dossiers marketplace et plugins"
        cp -Rf ${REP_BACKUP}backup_glpi/plugins ${REP_GLPI} > /dev/null 2>&1
        cp -Rf ${REP_BACKUP}backup_glpi/marketplace ${REP_GLPI} > /dev/null 2>&1
        cat > ${REP_GLPI}inc/downstream.php << EOF
<?php
    define('GLPI_CONFIG_DIR', '/etc/glpi');
    if (file_exists(GLPI_CONFIG_DIR . '/local_define.php')) {
        require_once GLPI_CONFIG_DIR . '/local_define.php';
    }
EOF
        info "Mise à jour de la base de donnée du site"
        if [[ "${ID}" =~ ^(debian|ubuntu)$ ]]; then
            chown -R www-data:www-data ${REP_GLPI} > /dev/null 2>&1
            sudo www-data php ${REP_GLPI}bin/console db:update --quiet --no-interaction --force  > /dev/null 2>&1
        elif [[ "${ID}" =~ ^(almalinux|centos|rocky|rhel)$ ]]; then
            chown -R nginx:nginx ${REP_GLPI} > /dev/null 2>&1
            semanage fcontext -a -t httpd_sys_rw_content_t "${REP_GLPI}(/.*)?" > /dev/null 2>&1
            semanage fcontext -a -t httpd_sys_rw_content_t "${REP_GLPI}marketplace" > /dev/null 2>&1
            restorecon -Rv ${REP_GLPI} > /dev/null 2>&1
            restorecon -Rv ${REP_GLPI}marketplace > /dev/null 2>&1
            sudo nginx php ${REP_GLPI}bin/console db:update --quiet --no-interaction --force  > /dev/null 2>&1
        fi
        
        info "Nettoyage de la mise à jour"
        rm -rf ${REP_GLPI}install/install.php > /dev/null 2>&1
        rm -Rf "$REP_BACKUP"backup_glpi > /dev/null 2>&1
}
function update(){
    maintenance "1"
    backup_glpi
    install_glpi
    update_glpi
    maintenance "0"
    efface_script
}
clear
check_root
check_distro
check_install ${REP_GLPI}
