
# TP1 -  Configuration avancée du système Linux

## Présentation

Ce dépôt contient les travaux réalisés dans le cadre du TP1 du module **Administration d'un Linux Server**.

L'objectif est de mettre en oeuvre l'administration avancée d'un environnement Rocky Linux 9 à travers trois missions.

## Environnement technique

- Système : Rocky Linux 9.8
- Virtualisation : Oracle VirtualBox
- Serveur principal : srv-core
- Serveur secondaire : srv-edge
- Gestionnaire de services : systemd
- Réseau : NetworkManager, bond active-backup, VLAN 802.1Q
- Automatisation : Bash et systemd timers
- Gestion de versions : Git et GitHub

## Missions

### Mission 1 :  Services et processus
- Création d'un service systemd personnalisé.
- Gestion des redémarrages automatiques.
- Limitation des ressources CPU et mémoire.
- Analyse de la séquence de démarrage.
### Mission 1.1 — Analyse du démarrage de Linux

L'analyse du démarrage de la machine `srv-core` a été réalisée avec les commandes `systemd-analyze`, `systemd-analyze blame` et `systemd-analyze critical-chain`.

Le temps total de démarrage mesuré est de **12,164 secondes**, réparti entre 2,113 secondes pour le noyau, 5,227 secondes pour l'initrd et 4,823 secondes pour l'espace utilisateur. La cible `multi-user.target` est atteinte après 2,604 secondes dans l'espace utilisateur.

La commande `systemd-analyze blame` met notamment en évidence les périphériques série virtuels, les périphériques disque et les interfaces réseau. La chaîne critique montre que `rsyslog.service` dépend de `network-online.target`, lui-même lié au démarrage de NetworkManager.

Ces commandes permettent d'identifier les unités et dépendances impliquées dans le démarrage et de disposer d'une mesure de référence pour les optimisations demandées dans le TP.

### Mission 2 : Réseau avancé
- Agrégation de liens active-backup.
- Configuration du VLAN 42.
- Routage par règles.

### Mission 3 : Automatisation
- Développement d'un script Bash robuste.
- Archivage et rotation des données.
- Planification avec systemd timer.
- Comparaison avec cron.

### Mission bonus
- Déclenchement automatique avec une unité systemd path.

## Organisation

- TP1/configs/ : fichiers de configuration.
- TP1/captures/ : preuves et résultats des tests.
- TP1/RAPPORT.md : compte rendu détaillé.


