# Installation et mise à jour de GLPI sur Débian et Red Hat

  ![Image](https://glpi-project.org/wp-content/uploads/2022/01/hero-img-2.png)

## À propos de ce script

### Dernière version de GLPI : 10.0.18

Ce script a été écrit pour installer rapidement et de façon automatique la dernière version de GLPI sur les serveurs Ubuntu, Debian, Alma Linux, Centos, Rocky Linux et Red Hat.
Le programme d'installation analyse les informations de localisation de la distribution pour sélectionner la langue d'installation par défaut. 

## Distribution et serveur Web

>[!IMPORTANT]
>
>| OS | VERSION | COMPATIBILITÉ | SERVEUR WEB |
>|:--:|:--:|:--:|:--:|
>|Debian|11|✅|Apache|
>|Debian|12|✅|Apache|
>|Ubuntu|23.10|✅|Apache|
>|Ubuntu|24.04|✅|Apache|
>|Ubuntu|24.10|⚠️ A tester|Apache|
>|Alma Linux|9.5|✅|Engine X (Nginx)|
>|Centos|9|✅|Engine X (Nginx)|
>|Rocky Linux|9.5|✅|Engine X (Nginx)|
>|Red Hat|9.5|✅|Engine X (Nginx)|

Le script fera la mise à jour du système hôte et installera le serveur Web (Apache ou Engine X), MariaDB, PHP et les dépendances, téléchargera et installera la dernière version de GLPI depuis le [Dépôt Officiel de GLPI](https://github.com/glpi-project/glpi) et configurera la base de données pour vous.

Une fois le script exécuté, la seule chose que vous aurez à faire sera de vous connecter à GLPI.

L'installation de GLPI se fait sans SSL. Si vous avez besoin d'ouvrir l'accès à GLPI depuis l'extérieur et/ou d'un certificat SSL, je vous recommande d'utiliser un reverse proxy.

## Comptes par défaut

| Identifiant | Mot de passe | Rôle |
|:--:|:--:|:--:|
|glpi|Défini à l'installation|compte administrateur|
|post-only|Défini à l'installation|compte post-only|
|tech|Défini à l'installation|compte technicien|
|normal|Défini à l'installation|compte normal|

## Lire la documentation

Sachez que je n'ai aucun lien avec l'équipe qui développe GLPI et/ou TecLib.
Si vous rencontrez un problème avec ce script sur une des distributions compatibles, vous pouvez créer une requète, je vous aiderai avec plaisir.
Si vous rencontrez un problème avec GLPI et/ou avez besoin de plus d'informations sur son fonctionnement, je vous recommande de lire les documentations :

[Documentation Administrateurs de GLPI](https://glpi-install.readthedocs.io/), [Documentation Utilisateurs de GLPI](https://glpi-user-documentation.readthedocs.io/)

## Comment utiliser

GLPI s'installe en lançant la commande suivante dans votre terminal.

>[!IMPORTANT]
>⚠️ Il est fortement recommandé d'exécuter ce script sur une nouvelle installation ou sur une installation faite avec ce script.
>
>⚠️ S'assurer qu'il n'y a plus le script dans le répertoire ```/root```.
>
>⚠️ Vous devez etre connecté en compte 'root', pour ce faire taper dans la console ```su -```.
>
>⚠️ Git doit etre installé sur votre machine, pour l'installer faite :
>
>| Debian | Red Hat |
>|:--:|:--:|
>| ```apt install -y -qq git``` | ```dnf install -y -qq git``` |

Pour les distribution Debian et Red Hat

```bash
git clone https://github.com/Papy-Poc/glpi_install.git -b dev && chmod -R +x glpi_install && ./glpi_install/glpi-install
```
