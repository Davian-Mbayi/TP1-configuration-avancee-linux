
# TP1 � Configuration avanc�e du syst�me Linux

## Pr�sentation

Ce d�p�t contient les travaux r�alis�s dans le cadre du TP1 du module **Administration d'un Linux Server**.

L'objectif est de mettre en �uvre l'administration avanc�e d'un environnement Rocky Linux 9 � travers trois missions.

## Environnement technique

- Syst�me : Rocky Linux 9.8
- Virtualisation : Oracle VirtualBox
- Serveur principal : srv-core
- Serveur secondaire : srv-edge
- Gestionnaire de services : systemd
- R�seau : NetworkManager, bond active-backup, VLAN 802.1Q
- Automatisation : Bash et systemd timers
- Gestion de versions : Git et GitHub

## Missions

### Mission 1 � Services et processus
- Cr�ation d'un service systemd personnalis�.
- Gestion des red�marrages automatiques.
- Limitation des ressources CPU et m�moire.
- Analyse de la s�quence de d�marrage.
### Mission 1.1 — Analyse du démarrage de Linux

L'analyse du démarrage de la machine `srv-core` a été réalisée avec les commandes `systemd-analyze`, `systemd-analyze blame` et `systemd-analyze critical-chain`.

Le temps total de démarrage mesuré est de **12,164 secondes**, réparti entre 2,113 secondes pour le noyau, 5,227 secondes pour l'initrd et 4,823 secondes pour l'espace utilisateur. La cible `multi-user.target` est atteinte après 2,604 secondes dans l'espace utilisateur.

La commande `systemd-analyze blame` met notamment en évidence les périphériques série virtuels, les périphériques disque et les interfaces réseau. La chaîne critique montre que `rsyslog.service` dépend de `network-online.target`, lui-même lié au démarrage de NetworkManager.

Ces commandes permettent d'identifier les unités et dépendances impliquées dans le démarrage et de disposer d'une mesure de référence pour les optimisations demandées dans le TP.

### Mission 2 � R�seau avanc�
- Agr�gation de liens active-backup.
- Configuration du VLAN 42.
- Routage par r�gles.

### Mission 3 � Automatisation
- D�veloppement d'un script Bash robuste.
- Archivage et rotation des donn�es.
- Planification avec systemd timer.
- Comparaison avec cron.

### Mission bonus
- D�clenchement automatique avec une unit� systemd path.

## Organisation

- TP1/configs/ : fichiers de configuration.
- TP1/captures/ : preuves et r�sultats des tests.
- TP1/RAPPORT.md : compte rendu d�taill�.

## Auteur

� compl�ter.


