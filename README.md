# Installing and updating GLPI on Debian and Red Hat
 ![Image](https://glpi-project.org/wp-content/uploads/2022/01/hero-img-2.png)

## About this script

### Latest version of GLPI : 10.0.17

This script was written to quickly and automatically install the latest version of GLPI on Ubuntu, Debian, Alma Linux, Centos, Rocky Linux and Red Hat servers.

## Distribution and Web server

| OS | VERSION | COMPATIBILITY | WEB SERVER |
|:--:|:--:|:--:|:--:|
|Debian|11|✅|Apache|
|Debian|12|✅|Apache|
|Ubuntu|23.10|✅|Apache|
|Ubuntu|24.10|⚠️ A tester|Apache|
|Alma Linux|9.5|✅|Engine X (Nginx)|
|Centos|9|✅|Engine X (Nginx)|
|Rocky Linux|9.5|✅|Engine X (Nginx)|
|Red Hat|9.5|✅|Engine X (Nginx)|

The script will update the host system and install the Web server, MariaDB, PHP and dependencies, download and install the latest version from the [GLPI Official Repository](https://github.com/glpi-project/glpi) and configure the database for you.

Once the script has run, all you need to do is connect to GLPI.

GLPI is installed without SSL. If you need to open access to GLPI from the outside and/or an SSL certificate, I recommend using a reverse proxy.

## Default accounts

| Login | Password | Role |
|:--:|:--:|:--:|
|glpi|Defined at installation|admin account|
|post-only|Defined at installation|post-only account|
|tech|Defined at installation|technician account|
|normal|Defined at installation|normal account|

## Read the documentation

Please note that I have no connection with the team that develops GLPI and/or TecLib.
If you encounter a problem with this script on one of the compatible distributions, you can create a request, and I'll be happy to help you.
If you encounter a problem with GLPI and/or need more information on how it works, I recommend that you read the following documentation:

[Documentation GLPI Administrators](https://glpi-install.readthedocs.io/), [Documentation GLPI Users](https://glpi-user-documentation.readthedocs.io/)

## How to use

GLPI is installed by running the following command in your terminal.

>[!IMPORTANT]
>⚠️ It is strongly recommended to run this script on a new installation or on an installation made with this script.
>
>⚠️ Make sure the script is no longer present in the ``/root`` directory.
>
>⚠️ You must be logged in as root. To do this, type ```su -``` into the console.
>
>⚠️ Git must be installed on your machine, to install it do :
>
>| Debian | Red Hat |
>|:--:|:--:|
>| ```apt install -y -qq git``` | ```dnf install -y -qq git``` |

For the distribution Debian and Red Hat

```bash
git clone https://github.com/Papy-Poc/glpi_install.git -b main && chmod -R +x glpi_install && ./glpi_install/glpi-install.sh
```
