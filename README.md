# Golem Provider sur Synology DS916+ / DSM 7

Guide d'utilisation et d'administration du Provider **Golem** installé sur un **Synology DS916+ sous DSM 7**, via **Container Manager**, avec dashboard servi par **Web Station / Nginx**.

L'installation actuelle fonctionne sur le **mainnet** et met à disposition une partie du CPU, de la RAM et du stockage du NAS en échange de paiements en **GLM**.

> **Sécurité importante** : le fichier `golem-key.json` contient la clé privée du wallet Golem. Ne jamais publier, envoyer ou copier son contenu dans un dépôt Git, un ticket ou une conversation. Conserver au moins une copie sécurisée hors du NAS.

---

# 1. Guide utilisateur

## 1.1 Dashboard

Dashboard :

```text
http://golem.domain.fr/
```

Il affiche notamment :

- état du Provider ;
- réseau Golem ;
- profil JOUR / NUIT ;
- CPU, RAM et stockage proposés ;
- jobs en cours et traités ;
- revenus GLM ;
- tarifs ;
- état VM / Driver.

Le dashboard lit :

```text
/volume2/docker/golem/dashboard/data/status.json
```

Ce fichier est généré par :

```text
/volume2/docker/golem/dashboard/update-status.sh
```

---

## 1.2 Vérifier l'état du Provider

```bash
sudo docker exec golem-provider golemsp status
```

Les indicateurs importants doivent être :

```text
Service     is running
VM          valid
Driver      Ok
network     mainnet
```

Cette commande permet aussi de voir le wallet, le solde GLM et les statistiques de jobs.

---

## 1.3 Voir la configuration actuelle

```bash
sudo docker exec golem-provider golemsp settings show
```

On y trouve notamment :

- nombre de cores proposés ;
- mémoire proposée ;
- stockage proposé ;
- tarif CPU ;
- tarif horaire ;
- tarif de démarrage.

---

## 1.4 Modifier manuellement les ressources

### Profil JOUR

Configuration actuelle :

```text
CPU    : 2 cores
RAM    : 2 GiB
Disque : 20 GiB
```

Commande :

```bash
sudo docker exec golem-provider golemsp settings set --cores 2 --memory 2GiB --disk 20GiB
```

Puis :

```bash
sudo docker restart golem-provider
```

### Profil NUIT

Configuration actuelle :

```text
CPU    : 3 cores
RAM    : 4 GiB
Disque : 20 GiB
```

Commande :

```bash
sudo docker exec golem-provider golemsp settings set --cores 3 --memory 4GiB --disk 20GiB
```

Puis :

```bash
sudo docker restart golem-provider
```

> En fonctionnement normal, ne pas appliquer manuellement ces profils : le scheduler DSM s'en charge automatiquement.

---

## 1.5 Modifier les tarifs

Le tarif est **unique pour les profils JOUR et NUIT**.

Les scripts de permutation JOUR / NUIT ne modifient **jamais** les tarifs. Ils ne changent que les ressources proposées :

- CPU ;
- RAM ;
- stockage.

Toute modification de prix se fait donc **manuellement en CLI** et reste ensuite valable pour les deux profils.

Voir d'abord les tarifs actuels :

```bash
sudo docker exec golem-provider golemsp settings show
```

Tarifs actuellement configurés :

```text
CPU/h : 0.010 GLM
Env/h : 0.002 GLM
Start : 0 GLM
```

Ces valeurs sont appliquées aux deux presets :

```text
vm
wasmtime
```

Pour modifier les tarifs, la commande actuellement utilisée est :

```bash
sudo docker exec golem-provider golemsp settings set --cpu-per-hour 0.010 --env-per-hour 0.002 --starting-fee 0
```

Adapter simplement les valeurs numériques au tarif souhaité.

Exemple pour passer à `0.008 GLM / CPU·h` tout en conservant `0.002 GLM / h` d'environnement :

```bash
sudo docker exec golem-provider golemsp settings set --cpu-per-hour 0.008 --env-per-hour 0.002 --starting-fee 0
```

Avant toute modification, on peut vérifier les options exactes supportées par la version installée :

```bash
sudo docker exec golem-provider golemsp settings set --help
```

Après modification, redémarrer le Provider afin de republier proprement l'offre :

```bash
sudo docker restart golem-provider
```

Puis vérifier :

```bash
sudo docker exec golem-provider golemsp settings show
```

Le résultat doit afficher le nouveau tarif pour les presets `vm` et `wasmtime`.

> **Important :** les scripts `golem-profile.sh day` et `golem-profile.sh night` ne doivent pas contenir d'options `--cpu-per-hour`, `--env-per-hour` ou `--starting-fee`. Le prix reste volontairement indépendant du profil horaire.

---

## 1.6 Vérifier les jobs

```bash
sudo docker exec golem-provider golemsp status
```

Chercher notamment :

```text
last 1h in progress
```

Une valeur supérieure à `0` indique un travail en cours.

---

## 1.7 Vérifier les connexions réseau

Statut général :

```bash
sudo docker exec golem-provider golemsp status
```

Logs récents :

```bash
sudo docker logs --tail=100 golem-provider
```

Logs en temps réel :

```bash
sudo docker logs -f golem-provider
```

Quitter avec `Ctrl+C`.

Des lignes du type `Established P2P session` indiquent que le nœud communique avec le réseau Golem.

---

## 1.8 Voir la consommation CPU / RAM

```bash
sudo docker stats golem-provider
```

Quitter avec `Ctrl+C`.

Occupation disque Docker :

```bash
sudo docker system df
```

---

## 1.9 Redémarrer Golem

```bash
sudo docker restart golem-provider
```

Puis :

```bash
sudo docker exec golem-provider golemsp status
```

---

## 1.10 Arrêter / démarrer Golem

Arrêt :

```bash
sudo docker stop golem-provider
```

Démarrage :

```bash
sudo docker start golem-provider
```

---

## 1.11 À ne jamais faire

Ne jamais supprimer les volumes Docker sans sauvegarde du wallet.

Éviter notamment :

```bash
docker compose down -v
```

Le `-v` supprime les volumes.

Ne jamais partager :

```text
golem-key.json
```

---

# 2. Guide administrateur

## 2.1 Architecture générale

```text
                        Internet
                           |
                    Golem Network
                           |
                 +------------------+
                 | golem-provider   |
                 | Docker / KVM     |
                 +------------------+
                           |
              +------------+------------+
              |                         |
       golem-profile.sh          update-status.sh
              |                         |
              |                         v
              |                    status.json
              |                         |
              v                         v
        Scheduler DSM             Web Station
         JOUR / NUIT                 Nginx
                                        |
                                        v
                            http://golem.domain.fr/
```

Le dashboard n'exécute pas de commande Docker directement. Il lit uniquement un fichier JSON généré côté NAS. Cela évite d'exposer le socket Docker ou des privilèges root au serveur Web.

---

## 2.2 Matériel / environnement

```text
Synology DS916+
DSM 7
Architecture : x86_64
CPU : Intel Pentium N3710
4 cores / threads visibles
RAM : environ 7.7 GiB
```

Virtualisation :

```text
/dev/kvm
```

Vérification :

```bash
ls -l /dev/kvm
```

Docker :

```bash
docker --version
docker compose version
```

---

## 2.3 Projet Container Manager

Nom du conteneur :

```text
golem-provider
```

Nom du projet :

```text
golem
```

Dossier :

```text
/volume2/docker/golem
```

---

## 2.4 Configuration Docker Compose

Configuration de référence :

```yaml
services:
  provider:
    image: golemfactory/provider:0.17.9
    container_name: golem-provider
    command: ['golemsp', 'run', '--no-interactive']
    restart: unless-stopped
    network_mode: host

    devices:
      - /dev/kvm:/dev/kvm

    volumes:
      - golem-yagna:/root/.local/share/yagna
      - golem-provider:/root/.local/share/ya-provider

    environment:
      NODE_NAME: 'DS916-Golem'
      YA_PAYMENT_NETWORK_GROUP: 'mainnet'
      SUBNET: 'public'
      YA_RT_CORES: 2
      YA_RT_MEM: 1.0
      YA_RT_STORAGE: 20

volumes:
  golem-yagna:
  golem-provider:
```

> Les valeurs `YA_RT_*` sont celles du compose initial. Les ressources réellement proposées sont ensuite pilotées par `golemsp settings set` et par le script de profils.

---

## 2.5 Volumes persistants

```text
golem-yagna
golem-provider
```

Ils contiennent notamment :

- identité du nœud ;
- configuration Golem ;
- données persistantes du Provider ;
- wallet / informations associées.

Ils ne doivent pas être supprimés par inadvertance.

---

## 2.6 Sauvegarde du wallet

Fichier de sauvegarde :

```text
golem-key.json
```

Une copie sécurisée doit être conservée hors du NAS.

Ne jamais placer ce fichier dans :

- un dossier Web Station public ;
- le dashboard ;
- un dépôt Git ;
- un partage public.

---

## 2.7 Inventaire des fichiers

```text
/volume2/docker/golem/
|
|-- docker-compose.yml
|-- golem-profile.sh
|-- profile.log
|-- golem-key.json
|
`-- dashboard/
    |-- index.html
    |-- update-status.sh
    `-- data/
        `-- status.json
```

### Rôle des fichiers

`docker-compose.yml`  
Configuration du conteneur Golem.

`golem-profile.sh`  
Script intelligent de permutation JOUR / NUIT.

`profile.log`  
Historique des changements de profil.

`golem-key.json`  
Sauvegarde privée du wallet.

`dashboard/index.html`  
Interface Web.

`dashboard/update-status.sh`  
Collecte `golemsp status` + `golemsp settings show` et génère le JSON.

`dashboard/data/status.json`  
Données consommées par le dashboard.

---

## 2.8 Scheduler JOUR / NUIT

Script :

```text
/volume2/docker/golem/golem-profile.sh
```

### JOUR

```text
Fenêtre de permutation : 08:00 -> 09:00
CPU Golem            : 2 cores
RAM Golem            : 2 GiB
Disque               : 20 GiB
```

### NUIT

```text
Fenêtre de permutation : 23:00 -> 00:00
CPU Golem             : 3 cores
RAM Golem             : 4 GiB
Disque                : 20 GiB
```


> **Politique de tarification :** le scheduler JOUR / NUIT ne modifie pas les prix. Le tarif est global et unique, actuellement `0.010 GLM / CPU·h`, `0.002 GLM / h` d'environnement et `0 GLM` au démarrage. Toute modification de prix est effectuée manuellement avec `golemsp settings set`.

Le script vérifie qu'aucun job n'est en cours.

S'il y a un job :

```text
attente 5 minutes
      |
      v
nouvelle vérification
```

Si le job continue au-delà de la fenêtre autorisée :

```text
aucun redémarrage
aucun job interrompu
profil inchangé
attente du prochain créneau
```

---

## 2.9 Tâches DSM

Dans :

```text
Panneau de configuration
> Planificateur de tâches
```

Utilisateur :

```text
root
```

### Profil JOUR

Horaire :

```text
08:00 tous les jours
```

Commande :

```bash
/volume2/docker/golem/golem-profile.sh day >> /volume2/docker/golem/profile.log 2>&1
```

### Profil NUIT

Horaire :

```text
23:00 tous les jours
```

Commande :

```bash
/volume2/docker/golem/golem-profile.sh night >> /volume2/docker/golem/profile.log 2>&1
```

### Mise à jour Dashboard

Fréquence :

```text
toutes les heures
```

Commande :

```bash
/volume2/docker/golem/dashboard/update-status.sh
```

Utilisateur : `root`.

---

## 2.10 Fonctionnement de `golem-profile.sh`

Le script :

1. reçoit `day` ou `night` ;
2. vérifie que l'heure est dans la fenêtre autorisée ;
3. vérifie le profil actuel ;
4. vérifie le nombre de jobs en cours ;
5. attend 5 minutes si nécessaire ;
6. abandonne si la fenêtre horaire est dépassée ;
7. modifie CPU / RAM / disque ;
8. redémarre le Provider ;
9. vérifie la nouvelle configuration ;
10. écrit le résultat dans `profile.log`.

---

## 2.11 Dashboard Web Station

URL :

```text
http://golem.domain.fr/
```

Racine Web Station :

```text
/volume2/docker/golem/dashboard
```

Fichier principal :

```text
index.html
```

Données :

```text
data/status.json
```

Le JavaScript lit le JSON avec un chemin relatif :

```javascript
fetch('./data/status.json?ts=' + Date.now())
```

---

## 2.12 Collecteur Dashboard

Script :

```text
/volume2/docker/golem/dashboard/update-status.sh
```

Il interroge principalement :

```bash
docker exec golem-provider golemsp status
```

et :

```bash
docker exec golem-provider golemsp settings show
```

Puis génère :

```text
/volume2/docker/golem/dashboard/data/status.json
```

Exemple :

```json
{
  "timestamp": "2026-09-01 18:08:53",
  "service": "is running",
  "network": "mainnet",
  "vm": "valid",
  "driver": "Ok",
  "profile": "NIGHT",
  "cores": "3",
  "memory": "4",
  "disk": "20",
  "jobs_last_hour": "0",
  "jobs_in_progress": "0",
  "jobs_total": "0",
  "glm_total": "0",
  "glm_pending": "0",
  "glm_issued": "0",
  "cpu_price": "0.025000000000000001",
  "hour_price": "0.005000000000000000"
}
```

---

## 2.13 Logs

Profil :

```bash
tail -n 50 /volume2/docker/golem/profile.log
```

Temps réel :

```bash
tail -f /volume2/docker/golem/profile.log
```

Provider :

```bash
sudo docker logs --tail=100 golem-provider
```

Temps réel :

```bash
sudo docker logs -f golem-provider
```

---

## 2.14 Vérifications après redémarrage du NAS

```bash
sudo docker ps | grep golem-provider
```

Puis :

```bash
sudo docker exec golem-provider golemsp status
```

Attendu :

```text
Service     is running
VM          valid
Driver      Ok
network     mainnet
```

Puis :

```bash
sudo docker exec golem-provider golemsp settings show
```

---

## 2.15 Mise à jour de Golem

Avant mise à jour :

1. vérifier la sauvegarde du wallet ;
2. vérifier qu'aucun job n'est en cours ;
3. noter la version actuelle ;
4. vérifier la version recommandée officiellement ;
5. mettre à jour l'image dans Container Manager ;
6. reconstruire sans supprimer les volumes ;
7. vérifier le statut.

Version :

```bash
sudo docker exec golem-provider golemsp --version
```

Après mise à jour :

```bash
sudo docker exec golem-provider golemsp status
```

et :

```bash
sudo docker exec golem-provider golemsp settings show
```

---

## 2.16 Diagnostic rapide

Conteneur :

```bash
sudo docker ps | grep golem
```

Statut :

```bash
sudo docker exec golem-provider golemsp status
```

Configuration :

```bash
sudo docker exec golem-provider golemsp settings show
```

Logs :

```bash
sudo docker logs --tail=100 golem-provider
```

CPU / RAM :

```bash
sudo docker stats golem-provider
```

KVM :

```bash
ls -l /dev/kvm
```

JSON dashboard :

```bash
cat /volume2/docker/golem/dashboard/data/status.json
```

Régénération manuelle :

```bash
sudo /volume2/docker/golem/dashboard/update-status.sh
```

Logs scheduler :

```bash
tail -n 50 /volume2/docker/golem/profile.log
```

---

## 2.17 Politique de ressources

| Période | CPU Golem | RAM Golem | Stockage |
|---|---:|---:|---:|
| JOUR | 2 / 4 cores | 2 GiB | 20 GiB |
| NUIT | 3 / 4 cores | 4 GiB | 20 GiB |

Objectifs :

- préserver environ la moitié du CPU en journée ;
- augmenter la capacité vendue la nuit ;
- ne jamais interrompre volontairement un job en cours ;
- ne pas appliquer tardivement un profil hors de son créneau.

---

## 2.18 Sauvegardes recommandées

À sauvegarder :

```text
/volume2/docker/golem/docker-compose.yml
/volume2/docker/golem/golem-profile.sh
/volume2/docker/golem/dashboard/index.html
/volume2/docker/golem/dashboard/update-status.sh
```

À sauvegarder **séparément et de manière sécurisée** :

```text
golem-key.json
```

`status.json` et `profile.log` ne sont pas critiques.

---

## 2.19 Restauration minimale

En cas de reconstruction du NAS :

1. réinstaller Container Manager ;
2. restaurer le projet Golem ;
3. restaurer les volumes si disponibles ;
4. restaurer le wallet depuis `golem-key.json` si nécessaire ;
5. restaurer les scripts ;
6. recréer les tâches DSM ;
7. recréer le portail Web Station ;
8. vérifier `/dev/kvm` ;
9. démarrer le Provider ;
10. vérifier `golemsp status`.

---

# Mémo express

```bash
sudo docker exec golem-provider golemsp status
sudo docker exec golem-provider golemsp settings show
sudo docker logs --tail=100 golem-provider
sudo docker stats golem-provider
```

Profil JOUR :

```bash
sudo docker exec golem-provider golemsp settings set --cores 2 --memory 2GiB --disk 20GiB
sudo docker restart golem-provider
```

Profil NUIT :

```bash
sudo docker exec golem-provider golemsp settings set --cores 3 --memory 4GiB --disk 20GiB
sudo docker restart golem-provider
```

Dashboard :

```text
http://golem.domain.fr/
```

---

**Installation : Synology DS916+ / DSM 7 / Golem Provider / Container Manager / Web Station**
