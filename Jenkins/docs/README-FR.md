# Guide Complet d'Utilisation de Vagrant pour Jenkins avec HTTPS et Reverse Proxy

Ce guide détaille l'utilisation de Vagrant pour créer une machine virtuelle exécutant Jenkins avec HTTPS activé et un reverse proxy pour Jenkins. La configuration de la machine virtuelle est définie dans un fichier Vagrantfile, tandis que les scripts de provisionnement installent Jenkins, Nginx, et configurent les règles de proxy.

## Prérequis

Avant de commencer, assurez-vous d'avoir installé les logiciels suivants sur votre machine locale :

1. [Vagrant](https://www.vagrantup.com/)
2. [VirtualBox](https://www.virtualbox.org/)

## Installation

1. Clonez le référentiel depuis GitHub :

   ```bash
   git clone https://github.com/ouznoreyni/vagrant-boilerplates-stacks.git
   ```

2. Accédez au répertoire du projet :

   ```bash
   cd vagrant-boilerplates-stacks/Jenkins
   ```

3. **Personnalisation du système d'exploitation (OS)** : Ouvrez le fichier `Vagrantfile` et modifiez la variable `base_image` pour choisir le système d'exploitation souhaité.

4. **Configuration des ressources de la VM** : Ajustez la mémoire, le CPU, le nom d'hôte, et l'adresse IP dans le fichier `Vagrantfile` selon vos besoins.

## Exécution de la machine virtuelle

1. Ouvrez une invite de commande ou un terminal et accédez au répertoire du projet.

2. Exécutez la commande suivante pour démarrer la VM :

   ```bash
   vagrant up
   ```

## Accès à Jenkins et Portainer via le Reverse Proxy

- **Jenkins** :

  - Jenkins est accessible depuis votre navigateur à l'adresse [http://192.168.56.10](http://192.168.56.10).

- **Portainer** :
  - Portainer, bien que principalement utilisé pour l'installation de Docker, est également accessible via le reverse proxy à l'adresse [http://192.168.56.10/portainer/](http://192.168.56.10/portainer/).
  - Notez que l'utilisation de Portainer n'est pas nécessaire pour les opérations courantes dans le cadre de ce projet, mais il peut être exploré pour des besoins spécifiques liés à la gestion de conteneurs Docker.

## Description de la Configuration

### HTTPS pour Jenkins

Jenkins est configuré pour utiliser HTTPS. Un certificat SSL auto-signé est généré lors de la provision de la machine virtuelle.

### Reverse Proxy pour Jenkins

Nginx est utilisé comme reverse proxy pour rediriger le trafic HTTP et HTTPS vers Jenkins sur le port 8080.

## Types de Provisionnement

### Docker Provisioning

Le script `install_jenkins_docker.sh` utilise Docker pour installer Jenkins. Il crée également les volumes Docker nécessaires pour stocker les données de Jenkins.

### Bash Provisioning

Le script `jenkins_setup.sh` utilise des commandes Bash pour effectuer diverses tâches, notamment la génération de certificats SSL, l'installation de Jenkins et la configuration de Nginx comme reverse proxy pour Jenkins.

### Choix du Type de Provisionnement

Vous pouvez choisir d'utiliser le provisionnement Docker, le provisionnement Bash ou les deux en fonction de vos préférences et des exigences de votre environnement. Pour ce faire, commentez ou décommentez les lignes correspondantes dans le fichier `Vagrantfile`.

```ruby
# Provisioning with a separate script
jenkins.vm.provision "shell", path: "jenkins_setup.sh" # Bash provisioning
# jenkins.vm.provision "shell", path: "install_jenkins_docker.sh" # Docker provisioning
```

Assurez-vous de n'exécuter qu'un seul type de provisionnement à la fois, en fonction de vos besoins spécifiques.

## Adaptation à d'autres Systèmes d'Exploitation

- **Windows** : Vagrant et VirtualBox sont compatibles avec Windows. Les commandes Vagrant doivent être exécutées dans l'invite de commande.

- **macOS** : Les instructions pour macOS sont similaires à celles de Linux. Utilisez le terminal pour exécuter les commandes Vagrant.
