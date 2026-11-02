
# TP1 — Configuration avancée du système Linux

## Présentation

Ce dépôt contient les travaux réalisés dans le cadre du TP1 du module **Administration d'un Linux Server**.

L'objectif est de mettre en œuvre l'administration avancée d'un environnement Rocky Linux 9 à travers trois missions.

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

### Mission 1 — Services et processus
- Création d'un service systemd personnalisé.
- Gestion des redémarrages automatiques.
- Limitation des ressources CPU et mémoire.
- Analyse de la séquence de démarrage.

### Mission 2 — Réseau avancé
- Agrégation de liens active-backup.
- Configuration du VLAN 42.
- Routage par règles.

### Mission 3 — Automatisation
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

## Auteur

À compléter.


